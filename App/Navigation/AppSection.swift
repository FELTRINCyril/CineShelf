import SwiftUI

/// Les sections de premier niveau de l'app, dans l'ordre d'affichage.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case titles
    case people
    case collections
    case gallery
    case savedLinks
    case search
    case myList
    case libraryAdmin
    case transfer
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Accueil"
        case .titles: "Titres"
        case .people: "Personnes"
        case .collections: "Collections"
        case .gallery: "Galerie"
        case .savedLinks: "Liens"
        case .search: "Recherche"
        case .myList: "Ma liste"
        case .libraryAdmin: "Gestion"
        case .transfer: "Import / Export"
        case .settings: "Réglages"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .titles: "film.stack"
        case .people: "person.2"
        case .collections: "square.stack"
        case .gallery: "photo.on.rectangle.angled"
        case .savedLinks: "link"
        case .search: "magnifyingglass"
        case .myList: "bookmark"
        case .libraryAdmin: "slider.horizontal.3"
        case .transfer: "arrow.up.arrow.down"
        case .settings: "gearshape"
        }
    }

    /// Sections épinglées dans la barre d'onglets en disposition compacte.
    static let compactTabs: [AppSection] = [.home, .titles, .people, .gallery, .search]

    @ViewBuilder
    var destination: some View {
        switch self {
        case .home: HomeView()
        case .titles: TitlesView()
        case .people: PeopleView()
        case .collections: CollectionsView()
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
