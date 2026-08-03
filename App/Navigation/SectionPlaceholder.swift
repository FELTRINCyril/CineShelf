import DesignSystem
import SwiftUI

/// L'écran d'une section tant que son contenu n'est pas écrit.
///
/// `StateView` du design system plutôt que `ContentUnavailableView` : c'est le
/// composant du système, il porte déjà les tokens, les cibles de 44 pt et le
/// comportement d'accessibilité. Un écran vide de placeholder qui ne ressemble
/// pas aux écrans vides réels ne prouve rien.
///
/// Les textes sont ceux que verra l'utilisateur : ils décrivent ce que la
/// section *contiendra*, pas le fait qu'elle soit inachevée.
struct SectionPlaceholder: View {
    let section: AppSection

    var body: some View {
        StateView(kind)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.bgCanvas)
            .navigationTitle(section.title)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
    }

    private var kind: StateView<EmptyView>.Kind {
        switch section {
        case .home:
            .empty(
                symbol: section.symbol,
                title: "Ton étagère est vide.",
                message: "Les rails par genre et les ajouts récents apparaîtront ici."
            )
        case .titles:
            .noTitles
        case .people:
            .empty(
                symbol: section.symbol,
                title: "Aucune personne.",
                message: "Les réalisateurs et les interprètes de tes titres se rangeront ici."
            )
        case .collections:
            .empty(
                symbol: section.symbol,
                title: "Aucune collection.",
                message: "Regroupe des titres en sagas, en cycles ou en listes thématiques."
            )
        case .gallery:
            .empty(
                symbol: section.symbol,
                title: "Aucune image.",
                message: "Jaquettes, photos et captures rejoindront cette galerie."
            )
        case .savedLinks:
            .empty(
                symbol: section.symbol,
                title: "Aucun signet.",
                message: "Garde ici les liens que tu veux retrouver : bandes-annonces, critiques, fiches."
            )
        case .search:
            .empty(
                symbol: section.symbol,
                title: "Cherche dans ta bibliothèque.",
                message: "Titres, personnes, collections et genres, en une seule recherche."
            )
        case .myList:
            .empty(
                symbol: section.symbol,
                title: "Ta liste est vide.",
                message: "Les titres que tu mets de côté se retrouveront ici."
            )
        case .libraryAdmin:
            .empty(
                symbol: section.symbol,
                title: "Rien à gérer pour l'instant.",
                message: "Dédoublonnage, fusions et corrections en masse se feront depuis cet écran."
            )
        case .transfer:
            .empty(
                symbol: section.symbol,
                title: "Importer ou exporter.",
                message: "Reprends un catalogue existant en CSV, ou emporte le tien ailleurs."
            )
        case .settings:
            .empty(
                symbol: section.symbol,
                title: "Réglages.",
                message: "Profils, confidentialité et synchronisation iCloud."
            )
        }
    }
}

#Preview("Placeholder") {
    NavigationStack {
        SectionPlaceholder(section: .titles)
    }
}
