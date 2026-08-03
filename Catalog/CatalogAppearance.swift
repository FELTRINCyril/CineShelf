import SwiftUI

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

// MARK: - Bascule clair / sombre / contraste élevé
//
// `\.colorSchemeContrast` est en lecture seule dans SwiftUI : on ne peut pas
// forcer le contraste élevé avec `.environment(...)`. La bascule agit donc au
// niveau de la fenêtre, où chaque plateforme expose ce qu'il faut :
//
//   - macOS : `NSWindow.appearance`, qui a des variantes accessibilityHighContrast*
//   - iOS   : `UIWindow.traitOverrides` (iOS 17+), qui expose `accessibilityContrast`
//
// C'est aussi ce qui fait que les Color Sets se résolvent vraiment sur leurs
// apparences « Any HC » et « Dark HC » — un simple override d'environnement
// SwiftUI ne changerait pas la résolution du catalogue d'assets.

struct CatalogAppearance: Equatable {
    var scheme: ColorScheme = .dark
    var highContrast: Bool = false

    var colorScheme: ColorScheme { scheme }
}

extension View {
    /// Applique l'apparence à la fenêtre qui porte cette vue.
    func catalogAppearance(_ appearance: CatalogAppearance) -> some View {
        self
            .environment(\.colorScheme, appearance.scheme)
            .background(WindowAppearanceApplier(appearance: appearance))
    }
}

#if canImport(AppKit)

    private struct WindowAppearanceApplier: NSViewRepresentable {
        let appearance: CatalogAppearance

        func makeNSView(context: Context) -> NSView { NSView() }

        func updateNSView(_ view: NSView, context: Context) {
            let name = appearanceName(for: appearance)
            // La fenêtre n'est pas encore attachée au premier passage de mise à jour.
            Task { @MainActor in
                view.window?.appearance = NSAppearance(named: name)
            }
        }

        private func appearanceName(for appearance: CatalogAppearance) -> NSAppearance.Name {
            switch (appearance.scheme, appearance.highContrast) {
            case (.dark, false): .darkAqua
            case (.dark, true): .accessibilityHighContrastDarkAqua
            case (_, false): .aqua
            case (_, true): .accessibilityHighContrastAqua
            }
        }
    }

#elseif canImport(UIKit)

    private struct WindowAppearanceApplier: UIViewRepresentable {
        let appearance: CatalogAppearance

        func makeUIView(context: Context) -> UIView { UIView() }

        func updateUIView(_ view: UIView, context: Context) {
            Task { @MainActor in
                guard let window = view.window else { return }
                window.overrideUserInterfaceStyle = appearance.scheme == .dark ? .dark : .light
                window.traitOverrides.accessibilityContrast = appearance.highContrast ? .high : .normal
            }
        }
    }

#endif
