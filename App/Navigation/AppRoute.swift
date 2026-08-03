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
}
