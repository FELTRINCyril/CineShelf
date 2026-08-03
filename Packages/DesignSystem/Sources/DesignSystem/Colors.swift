import SwiftUI

extension Bundle {
    /// Bundle de ressources du package (Colors.xcassets, Archivo).
    public static let designSystem: Bundle = .module
}

// Les accesseurs aux jeux sémantiques sont générés dans
// `ColorTokens.generated.swift` par `scripts/generate-colors.py`, depuis
// `Resources/colors.tokens.json`. Pourquoi ils ne s'écrivent plus à la main :
// `docs/01` §B.1.
