import OSLog
import SwiftUI

#if canImport(CoreText)
    import CoreText
#endif

/// Les échecs d'enregistrement de police, visibles dans la Console.
///   log stream --predicate 'subsystem == "fr.feltrin.CineShelf.DesignSystem"'
private let log = Logger(subsystem: "fr.feltrin.CineShelf.DesignSystem", category: "fonts")

// MARK: - Typographie
//
// Chaque rôle est déclaré relativement à un `Font.TextStyle` :
// `Font.custom(_:size:relativeTo:)` pour Archivo, `Font.system(_:design:)`
// pour SF Pro / SF Mono. Aucune taille fixe, jamais.

public enum Typo {

    // Display — Archivo (embarquée), réservée hero / titres de section / libellés de rail.
    public static let heroTitle = Font.custom(
        DesignSystemFonts.Face.displayExpandedExtraBold.postScriptName, size: Base.hero, relativeTo: .largeTitle)
    public static let pageTitle = Font.custom(
        DesignSystemFonts.Face.displayBold.postScriptName, size: Base.page, relativeTo: .title)
    public static let sectionTitle = Font.custom(
        DesignSystemFonts.Face.displaySemiBold.postScriptName, size: Base.section, relativeTo: .title3)
    /// À composer avec `.textCase(.uppercase)` et `.tracking(Typo.railTracking)`.
    public static let railLabel = Font.custom(
        DesignSystemFonts.Face.displayExpandedSemiBold.postScriptName, size: Base.railLabel, relativeTo: .caption)

    // UI + corps — SF Pro système.
    public static let cardTitle = Font.subheadline.weight(.medium)
    public static let body = Font.body
    public static let bodyEmphasis = Font.body.weight(.semibold)
    public static let fieldLabel = Font.footnote.weight(.medium)
    public static let caption = Font.caption

    // Données — SF Mono. Les métadonnées sont le sujet, pas « du petit texte gris ».
    public static let cardMeta = Font.system(.caption2, design: .monospaced)
    public static let dataValue = Font.system(.callout, design: .monospaced)
    /// Compteur du rail d'étagère (« 01–08 / 24 »).
    public static let railCounter = Font.system(.caption2, design: .monospaced).monospacedDigit()

    /// Interlettrage des libellés de rail en majuscules (0.08em à la taille de base).
    public static let railTracking: CGFloat = Base.railLabel * 0.08

    /// Tailles de base par plateforme — le point de départ de Dynamic Type,
    /// pas une taille finale : le système les met à l'échelle.
    private enum Base {
        #if os(macOS)
            static let hero: CGFloat = 26
            static let page: CGFloat = 22
            static let section: CGFloat = 15
            static let railLabel: CGFloat = 10
        #else
            static let hero: CGFloat = 34
            static let page: CGFloat = 28
            static let section: CGFloat = 20
            static let railLabel: CGFloat = 12
        #endif
    }
}

// MARK: - Polices embarquées
//
// Pourquoi des fichiers statiques et pas la variable `Archivo[wdth,wght].ttf` :
// `Font.custom` n'adresse une police que par son nom PostScript et n'expose
// aucun axe de variation. Régler `wdth` imposerait de passer par `CTFont`, ce
// qui fait perdre `relativeTo:` — donc Dynamic Type. On embarque donc deux
// familles statiques distinctes, chacune déjà découpée à la bonne chasse.
//
// L'axe `wdth` d'Archivo a six crans (62 / 75 / 87,5 / 100 / 112,5 / 125). Le
// `wdth` 112 demandé par `docs/01` §B.2 pour `heroTitle` et `railLabel` est
// donc le cran 112,5, dont le nom de famille est « Archivo SemiExpanded » —
// et non « Archivo Expanded », qui est le cran 125.

public enum DesignSystemFonts {

    /// Les fontes embarquées. Le nom PostScript n'est pas devinable depuis le
    /// nom de fichier : il a été relevé sur les fichiers réels avec
    /// `CTFontManagerCreateFontDescriptorsFromURL`. `FontResolutionTests` échoue
    /// si l'un d'eux cesse de se résoudre.
    public enum Face: String, CaseIterable, Sendable {
        case displaySemiBold = "Archivo-SemiBold"
        case displayBold = "Archivo-Bold"
        case displayExpandedSemiBold = "ArchivoSemiExpanded-SemiBold"
        case displayExpandedExtraBold = "ArchivoSemiExpanded-ExtraBold"

        /// Identique au nom de fichier ici, mais les deux notions sont
        /// distinctes : ne pas fusionner les propriétés.
        public var postScriptName: String { rawValue }
        public var fileName: String { rawValue }

        /// Famille attendue une fois la police résolue par le système.
        public var familyName: String {
            switch self {
            case .displaySemiBold, .displayBold:
                "Archivo"
            case .displayExpandedSemiBold, .displayExpandedExtraBold:
                "Archivo SemiExpanded"
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

// MARK: - Confort

extension View {
    /// Applique le rôle `railLabel` complet : casse, interlettrage, couleur.
    public func railLabelStyle() -> some View {
        self.font(Typo.railLabel)
            .textCase(.uppercase)
            .tracking(Typo.railTracking)
            .foregroundStyle(.textSecondary)
    }
}

extension EnvironmentValues {
    /// Au-delà de `.accessibility1`, les grilles de cartes passent en liste.
    public var prefersListLayout: Bool { dynamicTypeSize.isAccessibilitySize }
}
