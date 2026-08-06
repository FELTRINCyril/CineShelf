import SwiftUI

// Le seul point où la navigation touche une feature. Isolé dans son propre
// fichier pour que la logique de navigation (AppSection, AppRoute,
// NavigationModel) reste compilable — et donc testable — sans embarquer les
// onze vues de feature ni une app hôte.

extension AppSection {

    /// L'écran de la section.
    ///
    /// La navigation passe toujours par la vue de feature : c'est dans ces vues
    /// que les prochains prompts écriront le contenu.
    @ViewBuilder
    var destination: some View {
        switch self {
        case .home: HomeView()
        case .titles: TitlesView()
        case .people: PeopleView()
        case .collections: CollectionsView()
        case .activity: ActivityFeedView()
        case .gallery: GalleryView()
        case .savedLinks: SavedLinksView()
        case .search: SearchView()
        case .myList: MyListView()
        case .libraryAdmin: LibraryAdminView()
        case .transfer: TransferView()
        case .settings: SettingsView()
        }
    }
}
