import DesignSystem
import SwiftUI

/// L'écran affiché pour une route poussée.
///
/// Un seul point de résolution, appelé par les deux dispositions : c'est ce qui
/// évite qu'une feature ait à connaître les destinations d'une autre.
/// Les fiches réelles arriveront avec leurs prompts respectifs.
struct RouteDestination: View {
    let route: AppRoute

    @Environment(NavigationModel.self) private var navigation

    var body: some View {
        switch route {
        case .title(let id):
            TitleDetailView(titleID: id)
                .toolbar { toolbarContent }
        case .person(let id):
            PersonDetailView(personID: id)
                .toolbar { toolbarContent }
        case .collection(let id):
            CollectionDetailView(collectionID: id)
                .toolbar { toolbarContent }
        default:
            placeholder
        }
    }

    /// Les fiches non encore écrites. **Personnes et Collections sont parties par `V5b`** ;
    /// restent les genres — qui n'ont pas de fiche dans le design, seulement une section dans
    /// l'écran Collections — et les images, qui s'ouvrent dans la visionneuse de `V3`.
    private var placeholder: some View {
        StateView(
            .empty(
                symbol: symbol,
                title: title,
                message: "Cette fiche sera remplie par un prochain prompt."
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bgCanvas)
        .navigationTitle(title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
    }

    /// ⌥↑ / ⌥↓ se déplacent dans la liste d'où vient l'élément affiché.
    /// Les boutons restent visibles mais désactivés quand il n'y a pas de
    /// voisin : un raccourci qui disparaît est plus déroutant qu'un bouton gris.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                navigation.goToPrevious()
            } label: {
                Label("Précédent", systemImage: "chevron.up")
            }
            .disabled(!navigation.canGoToPrevious)
            .keyboardShortcut(.upArrow, modifiers: .option)

            Button {
                navigation.goToNext()
            } label: {
                Label("Suivant", systemImage: "chevron.down")
            }
            .disabled(!navigation.canGoToNext)
            .keyboardShortcut(.downArrow, modifiers: .option)
        }
    }

    private var symbol: String {
        switch route {
        case .title: Icon.titles
        case .person: Icon.people
        case .collection: Icon.collections
        case .genre: Icon.genres
        case .media: Icon.gallery
        }
    }

    private var title: String {
        switch route {
        case .title: "Titre"
        case .person: "Personne"
        case .collection: "Collection"
        case .genre: "Genre"
        case .media: "Image"
        }
    }
}
