import OSLog
import SwiftUI

#if canImport(CoreText)
    import CoreText
#endif

/// Les échecs d'enregistrement de police, visibles dans la Console.
///   log stream --predicate 'subsystem == "fr.feltrin.CineShelf.DesignSystem"'
private let log = Logger(subsystem: "fr.feltrin.CineShelf.DesignSystem", category: "fonts")

// MARK: - Polices embarquées
//
// Cinq familles, toutes sous licence SIL Open Font (voir Resources/Fonts/OFL.txt) :
// Bebas Neue pour le titrage, Archivo et Archivo Narrow pour l'interface,
// Public Sans pour le corps, IBM Plex Mono pour les chiffres et métadonnées.
//
// Pourquoi des fichiers statiques et pas les variables de Google Fonts :
// `Font.custom` n'adresse une police que par son nom PostScript et n'expose aucun
// axe de variation. Régler un axe imposerait de passer par `CTFont`, ce qui fait
// perdre `relativeTo:` — donc Dynamic Type. On embarque donc chaque graisse
// utilisée sous forme de fichier statique.

public enum DesignSystemFonts {

    /// Les fontes embarquées.
    ///
    /// **Le nom PostScript n'est pas devinable depuis le nom de fichier.** Chacun
    /// a été relevé sur le fichier réel avec
    /// `CTFontManagerCreateFontDescriptorsFromURL`, et deux ne suivent aucune
    /// convention : IBM Plex Mono Regular s'appelle `IBMPlexMono` **sans**
    /// `-Regular`, et le Medium s'appelle `IBMPlexMono-Medm` — abrégé, pas
    /// `-Medium`. Écrits « comme on les attend », les deux auraient fait retomber
    /// `Font.custom` sur Helvetica en silence.
    ///
    /// `FontResolutionTests` échoue si l'un d'eux cesse de se résoudre.
    public enum Face: String, CaseIterable, Sendable {

        // Direction courante.
        case bebas = "BebasNeue-Regular"
        case archivoRegular = "Archivo-Regular"
        case archivoSemiBold = "Archivo-SemiBold"
        case narrowSemiBold = "ArchivoNarrow-SemiBold"
        case narrowBold = "ArchivoNarrow-Bold"
        case publicSansLight = "PublicSans-Light"
        case plexMono = "IBMPlexMono"
        case plexMonoMedium = "IBMPlexMono-Medm"

        // Ancienne direction — lues par le banc d'essai seulement, retirées avec
        // `Legacy/`. Voir Legacy/README.md.
        case archivoBold = "Archivo-Bold"
        case semiExpandedSemiBold = "ArchivoSemiExpanded-SemiBold"
        case semiExpandedExtraBold = "ArchivoSemiExpanded-ExtraBold"

        public var postScriptName: String { rawValue }

        /// Le nom du `.ttf` dans le bundle. Distinct du nom PostScript, et pas
        /// seulement en théorie : les deux IBM Plex Mono divergent.
        public var fileName: String {
            switch self {
            case .plexMono: "IBMPlexMono-Regular"
            case .plexMonoMedium: "IBMPlexMono-Medium"
            default: rawValue
            }
        }

        /// Famille attendue une fois la police résolue par le système.
        public var familyName: String {
            switch self {
            case .bebas: "Bebas Neue"
            case .archivoRegular, .archivoSemiBold, .archivoBold: "Archivo"
            case .narrowSemiBold, .narrowBold: "Archivo Narrow"
            case .publicSansLight: "Public Sans"
            case .plexMono, .plexMonoMedium: "IBM Plex Mono"
            case .semiExpandedSemiBold, .semiExpandedExtraBold: "Archivo SemiExpanded"
            }
        }
    }

    /// Ce que l'enregistrement des polices a produit, lisible après `register()`.
    ///
    /// Existe parce que `CTFontManagerRegisterFontURLs` ne retourne rien : son
    /// seul canal d'erreur est le `registrationHandler`, et le code d'origine en
    /// jetait le tableau `errors`. Un `.ttf` absent ou corrompu passait donc
    /// totalement silencieux à l'exécution — même classe de défaillance que
    /// `Color(_:bundle:)` qui ne signale pas un jeu de couleurs absent.
    public struct RegistrationReport: Sendable {
        /// Les fontes dont le fichier est introuvable dans le bundle.
        public let missingFiles: [String]
        /// Les erreurs remontées par CoreText, mises à plat.
        public let errors: [String]
        /// CoreText a signalé la fin de l'opération.
        ///
        /// Le header dit que le handler est appelé « as errors are discovered or
        /// upon completion » et « may be called multiple times ». Sans ce
        /// drapeau, lire `errors` reviendrait à parier sur un appel synchrone —
        /// c'est bien ce qui se passe sur macOS, mais ce n'est pas contractuel,
        /// et une erreur remontée plus tard passerait inaperçue.
        public let isComplete: Bool

        /// Aucune erreur, **et** CoreText a fini de parler.
        public var isClean: Bool { missingFiles.isEmpty && errors.isEmpty && isComplete }
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var didRegister = false

    /// Verrou distinct de `lock` : le `registrationHandler` peut être appelé
    /// avant le retour de `CTFontManagerRegisterFontURLs`, donc alors que
    /// `register()` détient encore `lock`. Réutiliser le même `NSLock`, non
    /// récursif, provoquerait un interblocage.
    private static let reportLock = NSLock()
    nonisolated(unsafe) private static var storedReport: RegistrationReport?

    /// `nil` tant que `register()` n'a pas été appelé.
    public static var registrationReport: RegistrationReport? {
        reportLock.lock()
        defer { reportLock.unlock() }
        return storedReport
    }

    private static func record(_ report: RegistrationReport) {
        reportLock.lock()
        defer { reportLock.unlock() }
        storedReport = report
    }

    /// Le handler peut être appelé plusieurs fois : les erreurs s'accumulent, et
    /// `isComplete` ne devient vrai qu'au `done` de CoreText.
    private static func appendErrors(_ messages: [String], done: Bool) {
        reportLock.lock()
        defer { reportLock.unlock() }
        let previous = storedReport
        storedReport = RegistrationReport(
            missingFiles: previous?.missingFiles ?? [],
            errors: (previous?.errors ?? []) + messages,
            isComplete: done
        )
    }

    /// Idempotent, sûr depuis n'importe quel thread. À appeler au démarrage de l'app
    /// (`init()` de l'`App`) — les previews du package l'appellent automatiquement.
    public static func register() {
        lock.lock()
        defer { lock.unlock() }
        guard !didRegister else { return }
        didRegister = true

        #if canImport(CoreText)
            var missingFiles: [String] = []
            var urls: [URL] = []
            for face in Face.allCases {
                if let url = Bundle.designSystem.url(forResource: face.fileName, withExtension: "ttf") {
                    urls.append(url)
                } else {
                    missingFiles.append(face.fileName)
                }
            }

            record(RegistrationReport(missingFiles: missingFiles, errors: [], isComplete: false))
            for file in missingFiles {
                log.error("Font file missing from bundle: \(file, privacy: .public).ttf")
            }

            CTFontManagerRegisterFontURLs(urls as CFArray, .process, true) { errors, done in
                let messages = messages(from: errors)
                appendErrors(messages, done: done)
                for message in messages {
                    log.error("Font registration rejected: \(message, privacy: .public)")
                }
                // `true` = poursuivre. `false` **arrête** l'opération, et c'est
                // ce que ce handler retournait — les fontes restantes n'auraient
                // pas été enregistrées si CoreText avait signalé quoi que ce
                // soit avant la fin.
                return true
            }
        #else
            // Aucun CoreText : rien à enregistrer, donc rien à attendre.
            record(RegistrationReport(missingFiles: [], errors: [], isComplete: true))
        #endif
    }

    #if canImport(CoreText)
        /// Les erreurs de CoreText en messages lisibles. `CFError` se pontifie en
        /// `NSError` ; le repli couvre le cas où ce pont changerait.
        private static func messages(from errors: CFArray?) -> [String] {
            guard let raw = errors as? [Any] else { return [] }
            return raw.map { item in
                if let error = item as? NSError {
                    return "\(error.domain) \(error.code) : \(error.localizedDescription)"
                }
                return String(describing: item)
            }
        }
    #endif
}
