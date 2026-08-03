import CineShelfCore
import Foundation

/// Une destination poussée sur une pile de navigation.
///
/// À distinguer d'`AppSection`, qui est une destination de *premier* niveau
/// (un onglet, une entrée de barre latérale). `AppRoute` est ce qui s'empile
/// par-dessus : une fiche, un genre, une image.
///
/// `Codable` parce que la pile est restaurée au lancement, et `Hashable` parce
/// que `NavigationStack` l'exige.
enum AppRoute: Hashable, Codable, Sendable {
    case title(UUID)
    case person(UUID)
    case collection(UUID)
    case genre(UUID)
    case media(UUID)

    /// L'identifiant de l'entité visée, quelle que soit sa nature.
    var entityID: UUID {
        switch self {
        case .title(let id), .person(let id), .collection(let id),
            .genre(let id), .media(let id):
            id
        }
    }

    /// La route qui ouvre un item Spotlight.
    ///
    /// Le **décodage** de l'identifiant vit dans `CineShelfCore`
    /// (`SpotlightItemID`) : c'est une règle du domaine, testable sans écran. Ce
    /// qui reste ici est la seule chose qui soit vraiment de l'app — la
    /// correspondance vers sa propre énumération de navigation.
    ///
    /// `nil` sur un identifiant qu'on ne sait pas ouvrir. L'index du système peut
    /// contenir des items d'une version antérieure, et ne rien ouvrir vaut mieux
    /// que d'ouvrir au hasard.
    init?(spotlight identifier: String) {
        guard let item = SpotlightItemID(rawValue: identifier) else { return nil }
        switch item.kind {
        case .title: self = .title(item.entityID)
        case .person: self = .person(item.entityID)
        case .collection: self = .collection(item.entityID)
        }
    }
}
