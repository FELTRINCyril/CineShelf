import DesignSystem
import SwiftUI

/// Les sections de premier niveau de l'app.
///
/// Leur *répartition* dépend de la disposition, pas leur définition : en
/// compact elles se distribuent entre les cinq onglets de `CompactTab`, en
/// large entre la barre latérale et le menu de profil. Voir `docs/01` partie C.
enum AppSection: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
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
        case .savedLinks: "Signets"
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
        case .home: "house"
        case .titles: Icon.titles
        case .people: Icon.people
        case .collections: Icon.collections
        case .gallery: Icon.gallery
        case .savedLinks: Icon.bookmarks
        case .search: Icon.search
        case .myList: "list.star"
        case .libraryAdmin: "slider.horizontal.3"
        case .transfer: Icon.importItem
        case .settings: Icon.settings
        }
    }

    /// Les entrées de la barre latérale en disposition large — `docs/01` partie C.
    ///
    /// `search` n'y figure pas volontairement : sur Mac on l'atteint par ⌘F, et
    /// sur iPhone c'est un onglet. Les sections de service (`myList`,
    /// `libraryAdmin`, `transfer`, `settings`) vivent dans le menu de profil,
    /// pendant large de l'onglet « Plus ».
    static let sidebar: [AppSection] = [
        .home, .titles, .people, .collections, .gallery, .savedLinks
    ]

    /// Les sections regroupées derrière le menu de profil et l'onglet « Plus ».
    static let utility: [AppSection] = [.myList, .libraryAdmin, .transfer, .settings]
}

/// Les cinq onglets de la disposition compacte — `docs/01` partie C.
///
/// Ils ne correspondent pas un pour un aux sections : « Catalogue » en regroupe
/// trois derrière un sélecteur segmenté, et « Plus » sert de porte d'entrée aux
/// sections de service, qui seraient sinon inatteignables sur iPhone.
enum CompactTab: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case home
    case catalogue
    case gallery
    case search
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Accueil"
        case .catalogue: "Catalogue"
        case .gallery: "Galerie"
        case .search: "Recherche"
        case .more: "Plus"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .catalogue: Icon.titles
        case .gallery: Icon.gallery
        case .search: Icon.search
        case .more: "ellipsis.circle"
        }
    }

    /// La section affichée par cet onglet, hors « Catalogue » dont le contenu
    /// dépend du segment choisi et « Plus » qui est une liste.
    var section: AppSection? {
        switch self {
        case .home: .home
        case .gallery: .gallery
        case .search: .search
        case .catalogue, .more: nil
        }
    }

    /// L'onglet qui donne accès à une section, pour aligner la sélection quand
    /// on passe de la disposition large à la disposition compacte.
    static func containing(_ section: AppSection) -> CompactTab {
        switch section {
        case .home: .home
        case .titles, .people, .collections: .catalogue
        case .gallery: .gallery
        case .search: .search
        case .savedLinks, .myList, .libraryAdmin, .transfer, .settings: .more
        }
    }
}

/// Le sélecteur segmenté de l'onglet « Catalogue ».
enum CatalogueSegment: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case titles
    case people
    case collections

    var id: String { rawValue }

    var section: AppSection {
        switch self {
        case .titles: .titles
        case .people: .people
        case .collections: .collections
        }
    }

    var title: String { section.title }

    /// Le segment correspondant à une section, s'il y en a un.
    static func matching(_ section: AppSection) -> CatalogueSegment? {
        allCases.first { $0.section == section }
    }
}
