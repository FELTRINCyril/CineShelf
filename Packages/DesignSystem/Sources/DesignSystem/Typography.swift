import SwiftUI

#if canImport(CoreText)
    import CoreText
#endif

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

    private static let lock = NSLock()
    nonisolated(unsafe) private static var didRegister = false

    /// Idempotent, sûr depuis n'importe quel thread. À appeler au démarrage de l'app
    /// (`init()` de l'`App`) — les previews du package l'appellent automatiquement.
    public static func register() {
        lock.lock()
        defer { lock.unlock() }
        guard !didRegister else { return }
        didRegister = true

        #if canImport(CoreText)
            let urls = Face.allCases.compactMap {
                Bundle.designSystem.url(forResource: $0.fileName, withExtension: "ttf")
            }
            CTFontManagerRegisterFontURLs(urls as CFArray, .process, true) { _, _ in false }
        #endif
    }
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
