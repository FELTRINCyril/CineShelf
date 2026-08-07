import Foundation

// MARK: - L17 · La machine d'états de synchronisation
//
// > **Cette tâche ne peut pas être « vérifiée » avant l'activation de CloudKit.** Elle est
// > écrite et couverte en **simulation** : la machine, les six messages, le calcul d'espace.
// > Ce qu'aucun test local ne produit — les notifications réelles du coordinateur, leur charge
// > utile, leur ordre d'arrivée, les cas de compte et de quota — reste entier. Au vert, elle
// > vaut « écrite et couverte en simulation », pas « vérifiée ». Sa ligne du tableau d'état le
// > dit, et c'est délibéré.
//
// **Les textes sont de la donnée, pas de la vue**, et la fiche l'exige. Deux raisons : le même
// message part dans un bandeau, dans une barre d'outils et — au prompt 21 — dans une
// notification système, qui n'est pas une vue du tout ; et un message rangé dans une vue n'est
// relu par aucun test.
//
// **Six cas et non cinq.** `docs/04` §5 déclare cinq cas dans son extrait de code et en liste
// **six** dans son tableau juste en dessous : « pas de compte », « iCloud Drive désactivé »,
// « quota dépassé », « hors ligne », « premier envoi », « premier téléchargement ». Le quota
// manque à l'énumération de l'extrait alors que le tableau lui donne un message et une action.
// Le tableau est plus précis que l'extrait — il porte les textes —, donc il fait foi.

/// Où en est la synchronisation.
public enum SyncStatus: Sendable, Hashable {
    /// Tout est envoyé. La date est celle du dernier échange réussi.
    case upToDate(Date?)
    /// Un échange est en cours. `nil` quand la part faite est inconnue.
    ///
    /// **`Double?` et non `Double`**, et c'est une exigence d'honnêteté : CloudKit ne rend pas
    /// toujours une progression. Une barre inventée qui avance à vitesse constante est un
    /// mensonge que l'utilisateur croit, et `docs/04` §5 demande « une barre de progression
    /// **honnête** ».
    case syncing(SyncDirection, Double?)
    /// Pas de réseau. Les écritures locales sont conservées.
    case offline
    /// Aucun compte iCloud, ou iCloud Drive désactivé.
    ///
    /// **Un seul cas pour les deux**, et le tableau de `docs/04` §5 le dit lui-même en écrivant
    /// « idem » : l'utilisateur fait le même geste — ouvrir les réglages — et l'app ne sait pas
    /// toujours distinguer les deux depuis son bac à sable.
    case needsAccount
    /// Le stockage iCloud est plein. La taille est celle qu'occupe CineShelf.
    case quotaExceeded(bytes: Int64)
    /// Autre chose. Le texte vient du coordinateur, et n'est pas montré tel quel.
    case failed(String)

    public enum SyncDirection: Sendable, Hashable {
        case upload, download
    }
}

// MARK: - Ce que chaque cas dit à l'utilisateur

extension SyncStatus {

    /// Le message, en voix d'interface. Relevé du tableau de `docs/04` §5.
    public var message: String {
        switch self {
        case .upToDate:
            "Tout est synchronisé."
        case .syncing(.upload, _):
            "Envoi en cours. Le Wi-Fi est recommandé pour un premier envoi."
        case .syncing(.download, _):
            "Téléchargement en cours. L'app reste utilisable pendant ce temps."
        case .offline:
            "Modifications enregistrées localement. Synchronisation à la reconnexion."
        case .needsAccount:
            "Connecte-toi à iCloud pour synchroniser tes bibliothèques."
        case .quotaExceeded(let bytes):
            "Ton stockage iCloud est plein. CineShelf en occupe \(StorageFootprint.formatted(bytes))."
        case .failed:
            "La synchronisation a échoué. Tes données locales sont intactes."
        }
    }

    /// L'action proposée, ou `nil` quand il n'y a rien à faire.
    ///
    /// **`nil` sur « hors ligne », et c'est le point.** Le tableau ne propose aucune action là :
    /// il n'y a rien à réparer, la reconnexion suffit. Un bouton qui ne fait rien d'utile
    /// apprend à ne pas croire l'interface — c'est la décision déjà prise pour les deux actions
    /// non rendues de la barre de sélection.
    public var actionLabel: String? {
        switch self {
        case .needsAccount: "Ouvrir Réglages"
        case .quotaExceeded: "Gérer le stockage"
        case .failed: "Réessayer"
        case .upToDate, .syncing, .offline: nil
        }
    }

    /// L'état demande-t-il l'attention de l'utilisateur ?
    ///
    /// Ce qui décide si un bandeau se pose. « Hors ligne » n'en demande pas : c'est une
    /// information, pas un problème, et le bloc `9c` réserve le bandeau aux interruptions.
    public var needsAttention: Bool {
        switch self {
        case .needsAccount, .quotaExceeded, .failed: true
        case .upToDate, .syncing, .offline: false
        }
    }
}

// MARK: - La machine

/// Ce que le coordinateur CloudKit fait savoir.
///
/// **Une énumération d'événements et non des appels directs**, parce que c'est ce qui rend la
/// machine testable sans CloudKit : au prompt 21, `NSPersistentCloudKitContainer
/// .eventChangedNotification` se traduit en ces cas, et rien d'autre ne change.
public enum SyncEvent: Sendable, Equatable {
    case accountUnavailable
    case accountAvailable
    case networkLost
    case networkRestored
    case started(SyncStatus.SyncDirection)
    case progressed(Double)
    case finished(at: Date)
    case quotaExceeded(bytes: Int64)
    case failed(String)
}

/// La machine d'états. **Une valeur**, donc reproductible et testable pas à pas.
public struct SyncMachine: Sendable {
    public private(set) var status: SyncStatus

    public init(status: SyncStatus = .upToDate(nil)) {
        self.status = status
    }

    // Applique un événement.
    //
    // **L'ordre de priorité est le sujet, pas la transition.** Un coordinateur envoie ses
    // événements dans un ordre qu'on ne contrôle pas, et certains états doivent tenir malgré
    // ce qui suit : un compte absent ne se répare pas par une progression, et un quota dépassé
    // ne disparaît pas parce qu'un envoi démarre. Sans cette priorité, le dernier événement
    // arrivé gagnerait — et l'utilisateur verrait « envoi en cours » sur un compte qui n'existe
    // pas.
    //
    // Sept événements, donc sept branches : `cyclomatic_complexity` proteste. Les séparer
    // couperait la table des priorités en deux, et c'est précisément la table qu'il faut lire
    // d'un bloc. Commentaire simple et non doc-comment : `orphaned_doc_comment` refuse un `///`
    // séparé de sa déclaration par une directive.
    // swiftlint:disable:next cyclomatic_complexity
    public mutating func apply(_ event: SyncEvent) {
        switch event {
        case .accountUnavailable:
            status = .needsAccount
        case .accountAvailable:
            if case .needsAccount = status { status = .upToDate(nil) }
        case .networkLost:
            // Le manque de compte et le quota **survivent** à une perte de réseau : les deux
            // seront toujours vrais au retour, et les masquer ferait clignoter le message.
            if !status.needsAttention { status = .offline }
        case .networkRestored:
            if case .offline = status { status = .upToDate(nil) }
        case .started(let direction):
            guard !status.needsAttention else { return }
            status = .syncing(direction, nil)
        case .progressed(let fraction):
            // Une progression n'a de sens que pendant un échange. Hors de là, elle est ignorée
            // plutôt que de fabriquer un état — un coordinateur qui envoie une progression en
            // retard ne doit pas relancer une barre déjà terminée.
            guard case .syncing(let direction, _) = status else { return }
            status = .syncing(direction, min(max(fraction, 0), 1))
        case .finished(let date):
            guard !status.needsAttention else { return }
            status = .upToDate(date)
        case .quotaExceeded(let bytes):
            status = .quotaExceeded(bytes: bytes)
        case .failed(let reason):
            status = .failed(reason)
        }
    }

    public static func status(
        after events: [SyncEvent], from initial: SyncStatus = .upToDate(nil)
    ) -> SyncStatus {
        var machine = SyncMachine(status: initial)
        for event in events { machine.apply(event) }
        return machine.status
    }
}

// MARK: - L'espace occupé

/// Ce que CineShelf occupe sur le disque.
///
/// **Trois emplacements et non un** : le magasin SwiftData, le dossier de stockage externe où
/// vont les `@Attribute(.externalStorage)` — c'est-à-dire **toutes les images**, donc l'essentiel
/// du poids —, et le cache de vignettes. Ne compter que le premier annoncerait quelques
/// mégaoctets pour une bibliothèque qui en pèse deux cents.
public enum StorageFootprint {

    /// La taille d'un dossier, récursive. `0` s'il n'existe pas — pas une erreur : un cache
    /// jamais rempli est une taille nulle, pas un incident.
    public static func size(of directory: URL) -> Int64 {
        guard
            let enumerator = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
        else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    /// La somme de plusieurs emplacements, sans compter deux fois un dossier imbriqué.
    ///
    /// **Le dédoublonnage n'est pas théorique** : le stockage externe de SwiftData vit *à côté*
    /// du fichier de magasin, dans un dossier frère, et selon la configuration le cache de
    /// vignettes peut se retrouver sous le même parent. Additionner à l'aveugle doublerait
    /// alors le chiffre annoncé à l'utilisateur au moment précis où il cherche à faire de la
    /// place.
    public static func total(of locations: [URL]) -> Int64 {
        let resolved = locations.map { $0.standardizedFileURL.path }
        let deduplicated = resolved.filter { path in
            !resolved.contains { other in other != path && path.hasPrefix(other + "/") }
        }
        return Set(deduplicated).reduce(0) { $0 + size(of: URL(fileURLWithPath: $1)) }
    }

    /// Les dossiers qu'occupe CineShelf sur cet appareil.
    ///
    /// **Écrit ici et non dans la vue, et son absence était un trou.** `total(of:)` était livré
    /// par `L17` avec sa règle de dédoublonnage — et **rien ne savait quoi lui passer** : la
    /// liste des emplacements n'existait nulle part, donc le calcul d'espace ne pouvait pas être
    /// appelé. C'est la classe « une capacité écrite jamais lue », vue du côté de l'entrée.
    ///
    /// Trois emplacements, et les trois comptent : le magasin SwiftData et son stockage externe
    /// vivent sous `Application Support`, le cache de vignettes sous `Caches`. Ne compter que le
    /// premier annoncerait quelques mégaoctets pour une bibliothèque qui en pèse deux cents.
    public static func appLocations(bundleName: String = "CineShelf") -> [URL] {
        let manager = FileManager.default
        return [URL.applicationSupportDirectory, URL.cachesDirectory].compactMap { base in
            let directory = base.appendingPathComponent(bundleName, isDirectory: true)
            return manager.fileExists(atPath: directory.path) ? directory : nil
        }
    }

    /// « 96 Mo ». Le format du système, donc la langue de l'utilisateur.
    public static func formatted(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}
