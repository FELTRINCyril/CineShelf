import SwiftUI

// MARK: - StateView — vide / chargement / erreur
//
// Un seul composant, trois cas. Jamais de spinner centré : le chargement
// est un squelette de la géométrie finale.

public struct StateView<Skeleton: View>: View {

    public enum Kind: Sendable {
        /// Vide : symbole, titre, une phrase, **et un bouton**.
        case empty(symbol: String, title: String, message: String, actionTitle: String?)
        /// Chargement : squelette redacted de la géométrie finale.
        case loading
        /// Erreur : ce qui s'est passé, comment le réparer. Jamais de message technique.
        case failure(symbol: String, title: String, message: String, retryTitle: String)

        // Swift n'autorise pas de valeur par défaut sur un case d'énumération.
        // Ces fabriques les apportent — en omettant le paramètre par défaut
        // plutôt qu'en le déclarant avec `= …` : une méthode dont tous les
        // paramètres sont défaultés a exactement la signature du case et
        // devient une redéclaration invalide.

        /// Cas vide sans bouton d'action.
        public static func empty(symbol: String, title: String, message: String) -> Kind {
            .empty(symbol: symbol, title: title, message: message, actionTitle: nil)
        }

        /// Cas d'erreur au symbole et au libellé de reprise habituels.
        public static func failure(title: String, message: String) -> Kind {
            .failure(
                symbol: "exclamationmark.icloud",
                title: title,
                message: message,
                retryTitle: "Réessayer"
            )
        }
    }

    private let kind: Kind
    private let action: (() -> Void)?
    private let skeleton: Skeleton

    public init(_ kind: Kind, action: (() -> Void)? = nil, @ViewBuilder skeleton: () -> Skeleton) {
        self.kind = kind
        self.action = action
        self.skeleton = skeleton()
    }

    public var body: some View {
        switch kind {
        case .loading:
            skeleton
                .redacted(reason: .placeholder)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Chargement en cours")
                .allowsHitTesting(false)

        case .empty(let symbol, let title, let message, let actionTitle):
            // `self.` obligatoire : `message` est ici la valeur liée par le motif.
            self.message(
                Layout(
                    symbol: symbol, tint: .textTertiary, title: title,
                    body: message, button: actionTitle, prominent: true))

        case .failure(let symbol, let title, let message, let retryTitle):
            self.message(
                Layout(
                    symbol: symbol, tint: .statusDanger, title: title,
                    body: message, button: retryTitle, prominent: false))
        }
    }

    /// Ce que les cas « vide » et « erreur » ont en commun : la même mise en
    /// page, six réglages. Un type plutôt que six paramètres à la file.
    private struct Layout {
        let symbol: String
        let tint: Color
        let title: String
        let body: String
        let button: String?
        let prominent: Bool
    }

    @ViewBuilder
    private func message(_ layout: Layout) -> some View {
        let tint = layout.tint
        let (title, body) = (layout.title, layout.body)
        let (button, prominent) = (layout.button, layout.prominent)

        VStack(spacing: Space.md) {
            Image(systemName: layout.symbol)
                .font(.system(.largeTitle))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(spacing: Space.xs) {
                Text(title)
                    .font(Typo.bodyEmphasis)
                    .foregroundStyle(.textPrimary)
                Text(body)
                    .font(Typo.body)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 340)

            if let button, let action {
                Group {
                    if prominent {
                        Button(button, action: action)
                            .buttonStyle(.borderedProminent)
                            .tint(.accentSolid)
                    } else {
                        Button(button, action: action)
                            .buttonStyle(.bordered)
                    }
                }
                .controlSize(.large)
                .frame(minHeight: Space.minHitTarget)
                .padding(.top, Space.xs)
            }
        }
        .padding(Space.panelPadding)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

extension StateView where Skeleton == EmptyView {
    public init(_ kind: Kind, action: (() -> Void)? = nil) {
        self.init(kind, action: action, skeleton: { EmptyView() })
    }
}

// MARK: - Cas prêts à l'emploi

extension StateView.Kind {
    public static var noTitles: Self {
        .empty(
            symbol: Icon.titles, title: "Aucun film pour l'instant.",
            message: "Ajoute un premier titre pour commencer ton étagère.",
            actionTitle: "Ajouter un film")
    }

    public static var noResults: Self {
        .empty(
            symbol: Icon.search, title: "Aucun résultat.",
            message: "Essaie un autre terme, ou retire un filtre actif.",
            actionTitle: "Effacer les filtres")
    }

    public static var syncFailed: Self {
        .failure(
            title: "Impossible de synchroniser.",
            message: "Vérifie ta connexion iCloud.")
    }
}

#Preview("Vide") {
    StateView(.noTitles) {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bgCanvas)
}

#Preview("Erreur") {
    StateView(.syncFailed) {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bgCanvas)
}
