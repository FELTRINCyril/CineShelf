import DesignSystem
import SwiftUI

/// Les sections de premier niveau de l'app.
///
/// Leur *répartition* dépend de la disposition, pas leur définition : en compact elles se
/// distribuent entre les cinq onglets de `CompactTab`, en régulier entre la barre de
/// navigation haute et le menu de profil. Voir la planche 2, blocs `3a` à `3c`.
enum AppSection: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case home
    case titles
    case people
    case collections
    case gallery
    case savedLinks
    case activity
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
        case .savedLinks: "Signets"
        case .activity: "Fil"
        case .search: "Recherche"
        case .myList: "Ma liste"
        case .libraryAdmin: "Gestion"
        case .transfer: "Import / Export"
        case .settings: "Réglages"
        }
    }

    /// Les symboles viennent d'`Icon` quand le design system en définit un :
    /// les recopier à la main ferait diverger l'app du catalogue.
    var symbol: String {
        switch self {
        case .home: Icon.home
        case .titles: Icon.titles
        case .people: Icon.people
        case .collections: Icon.collections
        case .gallery: Icon.gallery
        case .savedLinks: Icon.bookmarks
        case .activity: Icon.feed
        case .search: Icon.search
        case .myList: Icon.myList
        case .libraryAdmin: "slider.horizontal.3"
        case .transfer: Icon.importItem
        case .settings: Icon.settings
        }
    }

    /// Les six entrées de la **barre de navigation haute** — planche 2 bloc `3a`, relevées
    /// dans cet ordre : `CINESHELF · Accueil · Titres · Personnes · Collections · Galerie ·
    /// Ma liste`.
    ///
    /// **`search` n'y est pas** : le prototype la met à droite, avec son raccourci ⌘K, donc
    /// elle est rendue par `TopNavigationBar` à part. **`savedLinks` non plus** : le
    /// prototype ne la montre pas dans la barre, elle vit dans le menu de profil.
    ///
    /// Renommée depuis `sidebar` par `V0` : il n'y a plus de barre latérale, et garder le
    /// nom aurait fait chercher un composant qui n'existe plus.
    static let navigationBar: [AppSection] = [
        .home, .titles, .people, .collections, .gallery, .myList
    ]

    /// Les sections regroupées derrière le menu de profil, pendant régulier de l'onglet
    /// « Gérer ».
    /// **`activity` y entre par `V5b`.** Le bloc `5e` la montre dans la barre haute, à la
    /// place qu'occupent « Ma liste » ou « Signets » selon l'écran — le prototype substitue
    /// l'entrée courante plutôt que d'en afficher onze. Elle rejoint donc les sections de
    /// service, comme les signets, plutôt que la barre principale à six entrées.
    static let utility: [AppSection] = [
        .savedLinks, .activity, .libraryAdmin, .transfer, .settings
    ]
}

/// Les cinq onglets de la disposition compacte — planche 2 bloc `3c`, relevés dans cet
/// ordre : **Accueil · Titres · Recherche · Ma liste · Gérer**.
///
/// **Ils ne couvrent pas toutes les sections, et c'est une lacune du design, pas un choix.**
/// Personnes, Collections, Galerie et Signets n'ont aucun onglet sur iPhone et le handoff
/// ne dit pas où on les atteint — son §6 ne parle que de la *mise en page* des huit écrans
/// non dessinés, pas de leur accessibilité. `V0` les met derrière « Gérer », qui est
/// l'onglet fourre-tout du prototype, plutôt que de les rendre inatteignables. L'écart est
/// inscrit dans `docs/PROMPTS.md`.
enum CompactTab: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case home
    case titles
    case search
    case myList
    case manage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: AppSection.home.title
        case .titles: AppSection.titles.title
        case .search: AppSection.search.title
        case .myList: AppSection.myList.title
        case .manage: "Gérer"
        }
    }

    var symbol: String {
        switch self {
        case .home: Icon.home
        case .titles: Icon.titles
        case .search: Icon.search
        case .myList: Icon.myList
        case .manage: "slider.horizontal.3"
        }
    }

    /// La section affichée par cet onglet. « Gérer » n'en a pas : c'est une liste.
    var section: AppSection? {
        switch self {
        case .home: .home
        case .titles: .titles
        case .search: .search
        case .myList: .myList
        case .manage: nil
        }
    }

    /// Ce que l'onglet « Gérer » liste : les quatre sections que la barre d'onglets ne
    /// couvre pas, puis les sections de service.
    static let managed: [AppSection] = [.people, .collections, .gallery] + AppSection.utility

    /// L'onglet qui donne accès à une section, pour aligner la sélection quand on passe de
    /// la disposition régulière à la disposition compacte.
    static func containing(_ section: AppSection) -> CompactTab {
        switch section {
        case .home: .home
        case .titles: .titles
        case .search: .search
        case .myList: .myList
        case .people, .collections, .gallery, .savedLinks, .activity, .libraryAdmin, .transfer,
            .settings:
            .manage
        }
    }
}
