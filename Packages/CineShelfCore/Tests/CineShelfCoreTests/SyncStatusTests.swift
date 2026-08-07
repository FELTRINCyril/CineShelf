import Foundation
import Testing

@testable import CineShelfCore

// MARK: - L17 · Écrite et couverte en simulation, pas vérifiée
//
// **Ce que ces tests prouvent** : que la machine tient les priorités qu'on lui a données, que
// les six cas ont un message et une action, et que le calcul d'espace ne compte pas deux fois.
//
// **Ce qu'ils ne prouvent pas, et qu'aucun test local ne peut prouver** : que les événements
// arrivent dans cet ordre, sous cette forme, avec cette charge utile. Les notifications réelles
// du coordinateur CloudKit n'existeront qu'au prompt 21. Au vert, cette suite vaut « couverte
// en simulation ».

@Suite("État de synchronisation")
struct SyncStatusTests {

    @Test("Les six cas ont un message, et seuls ceux qui appellent une action en portent une")
    func everyCaseSpeaks() {
        let cases: [SyncStatus] = [
            .upToDate(Date(timeIntervalSince1970: 1_754_012_345)),
            .syncing(.upload, 0.4), .syncing(.download, nil),
            .offline, .needsAccount, .quotaExceeded(bytes: 96 * 1_024 * 1_024),
            .failed("CKErrorPartialFailure")
        ]
        for state in cases {
            #expect(!state.message.isEmpty, "\(state) n'a pas de message")
        }

        // L'action n'existe que là où il y a quelque chose à faire. « Hors ligne » n'en a pas :
        // la reconnexion suffit, et un bouton inerte apprend à ne pas croire l'interface.
        #expect(SyncStatus.needsAccount.actionLabel == "Ouvrir Réglages")
        #expect(SyncStatus.quotaExceeded(bytes: 1).actionLabel == "Gérer le stockage")
        #expect(SyncStatus.failed("x").actionLabel == "Réessayer")
        #expect(SyncStatus.offline.actionLabel == nil)
        #expect(SyncStatus.upToDate(nil).actionLabel == nil)
        #expect(SyncStatus.syncing(.upload, 0.5).actionLabel == nil)
    }

    @Test("Le message de quota annonce la taille occupée")
    func quotaMessageCarriesTheSize() {
        // `docs/04` §5 : « Ton stockage iCloud est plein. » **+ taille occupée par CineShelf**.
        // Sans la taille, le message ne dit pas si l'app est en cause.
        let message = SyncStatus.quotaExceeded(bytes: 96 * 1_024 * 1_024).message
        #expect(message.contains("plein"))
        #expect(message.contains(StorageFootprint.formatted(96 * 1_024 * 1_024)))
    }

    @Test("Un compte absent survit à une perte de réseau")
    func accountProblemOutranksOffline() {
        // **C'est la priorité qui compte, pas la transition.** Le dernier événement arrivé ne
        // gagne pas : sinon l'utilisateur verrait « modifications enregistrées localement » sur
        // un compte qui n'existe pas, et il attendrait une reconnexion qui ne réparerait rien.
        var machine = SyncMachine()
        machine.apply(.accountUnavailable)
        machine.apply(.networkLost)
        #expect(machine.status == .needsAccount)

        machine.apply(.networkRestored)
        #expect(machine.status == .needsAccount, "Le réseau revenu ne crée pas un compte")

        machine.apply(.accountAvailable)
        #expect(machine.status == .upToDate(nil))
    }

    @Test("Un quota dépassé ne disparaît pas parce qu'un envoi démarre")
    func quotaOutranksProgress() {
        var machine = SyncMachine()
        machine.apply(.quotaExceeded(bytes: 5_000))
        machine.apply(.started(.upload))
        machine.apply(.progressed(0.7))
        machine.apply(.finished(at: Date(timeIntervalSince1970: 1_754_012_345)))
        #expect(machine.status == .quotaExceeded(bytes: 5_000))
    }

    @Test("Une progression hors échange est ignorée plutôt que de fabriquer un état")
    func progressOutsideSyncIsIgnored() {
        var machine = SyncMachine(status: .upToDate(nil))
        machine.apply(.progressed(0.5))
        #expect(machine.status == .upToDate(nil), "Une progression en retard a relancé une barre")
    }

    @Test("La progression est bornée à zéro et un")
    func progressIsClamped() {
        var machine = SyncMachine()
        machine.apply(.started(.download))
        machine.apply(.progressed(1.8))
        #expect(machine.status == .syncing(.download, 1))
        machine.apply(.progressed(-3))
        #expect(machine.status == .syncing(.download, 0))
    }

    @Test("Un échange nominal va du départ à la date de fin")
    func nominalRunReachesUpToDate() {
        // Une date **quelconque** : ni maintenant, ni une date ronde.
        let finished = Date(timeIntervalSince1970: 1_754_012_345)
        let status = SyncMachine.status(after: [
            .started(.upload), .progressed(0.25), .progressed(0.9), .finished(at: finished)
        ])
        #expect(status == .upToDate(finished))
    }

    @Test("Seuls trois états demandent l'attention")
    func attentionIsRare() {
        #expect(SyncStatus.needsAccount.needsAttention)
        #expect(SyncStatus.quotaExceeded(bytes: 1).needsAttention)
        #expect(SyncStatus.failed("x").needsAttention)
        // « Hors ligne » est une information, pas une interruption : le bloc `9c` réserve le
        // bandeau aux secondes.
        #expect(!SyncStatus.offline.needsAttention)
        #expect(!SyncStatus.upToDate(nil).needsAttention)
        #expect(!SyncStatus.syncing(.upload, nil).needsAttention)
    }
}

@Suite("Espace occupé")
struct StorageFootprintTests {

    /// **`appLocations()` était le maillon manquant du calcul d'espace.**
    ///
    /// `total(of:)` était livré avec sa règle de dédoublonnage par `L17`, et **rien ne savait
    /// quoi lui passer** : la liste des emplacements n'existait nulle part, donc le chiffre
    /// n'était calculable par personne. C'est « une capacité écrite jamais lue », vue du côté
    /// de l'entrée.
    ///
    /// Le test porte sur la **règle**, pas sur les dossiers réels de la machine : un nom de
    /// paquet qui n'existe pas doit rendre une liste vide plutôt que des chemins fantômes dont
    /// `size(of:)` rendrait 0 — deux comportements indistinguables sur le total, et c'est
    /// justement pourquoi il faut assener la liste et non la somme.
    @Test("Les emplacements de l'app ne contiennent que des dossiers qui existent")
    func appLocationsAreRealDirectories() {
        let absent = StorageFootprint.appLocations(bundleName: "CineShelf-\(UUID().uuidString)")
        #expect(absent.isEmpty, "Un paquet inconnu ne doit rendre aucun emplacement")

        // Et le chemin réel : on fabrique le dossier, il doit apparaître. Sans ce second temps,
        // une fonction qui rendrait toujours `[]` passerait le premier.
        let name = "CineShelfProbe-\(UUID().uuidString)"
        let created = URL.cachesDirectory.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: created, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: created) }

        let found = StorageFootprint.appLocations(bundleName: name)
        #expect(found.count == 1)
        #expect(found.first?.lastPathComponent == name)
    }

    private func makeTree() throws -> URL {
        let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = root.appendingPathComponent("externe/images", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        // Des tailles **quelconques**, pas des puissances de deux : une somme fausse se
        // remarque moins quand tous les nombres sont ronds.
        try Data(repeating: 0, count: 3_517).write(to: root.appendingPathComponent("magasin.sqlite"))
        try Data(repeating: 0, count: 12_289).write(to: nested.appendingPathComponent("a.heic"))
        return root
    }

    @Test("La taille d'un dossier est récursive")
    func sizeIsRecursive() throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(StorageFootprint.size(of: root) == 3_517 + 12_289)
    }

    @Test("Un dossier absent pèse zéro, ce n'est pas une erreur")
    func missingDirectoryIsZero() {
        let absent = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(StorageFootprint.size(of: absent) == 0)
    }

    @Test("Un emplacement imbriqué n'est pas compté deux fois")
    func nestedLocationsAreNotDoubleCounted() throws {
        // **Le cas est réel** : le stockage externe de SwiftData vit à côté du magasin, et le
        // cache de vignettes peut se retrouver sous le même parent. Additionner à l'aveugle
        // doublerait le chiffre au moment précis où l'utilisateur cherche à faire de la place.
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let total = StorageFootprint.total(of: [root, root.appendingPathComponent("externe")])
        #expect(total == 3_517 + 12_289)

        // Et le même emplacement donné deux fois ne compte qu'une.
        #expect(StorageFootprint.total(of: [root, root]) == 3_517 + 12_289)
    }
}
