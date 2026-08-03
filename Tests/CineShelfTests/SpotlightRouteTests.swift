import CineShelfCore
import Foundation
import Testing

// La traduction d'un item Spotlight vers une route de l'app.
//
// Le décodage de l'identifiant est couvert dans `CineShelfCore`
// (`SpotlightIndexerTests`) ; ce qui se vérifie ici est la seule part qui soit
// vraiment de l'app — la correspondance vers `AppRoute`, et le refus d'ouvrir quoi que
// ce soit sur un identifiant qu'on ne comprend pas.

@MainActor
struct SpotlightRouteTests {

    @Test("Chaque type d'item ouvre la route correspondante")
    func everyKindMapsToARoute() {
        let id = UUID()

        #expect(
            AppRoute(spotlight: SpotlightItemID(kind: .title, entityID: id).rawValue)
                == .title(id))
        #expect(
            AppRoute(spotlight: SpotlightItemID(kind: .person, entityID: id).rawValue)
                == .person(id))
        #expect(
            AppRoute(spotlight: SpotlightItemID(kind: .collection, entityID: id).rawValue)
                == .collection(id))
    }

    @Test("Un identifiant incompréhensible n'ouvre rien")
    func unknownIdentifiersOpenNothing() {
        // L'index du système survit aux mises à jour de l'app : il peut contenir des
        // items d'un format antérieur. Ne rien ouvrir vaut mieux qu'ouvrir au hasard —
        // et surtout mieux que de planter au démarrage sur un item vieux de deux ans.
        for raw in ["", "title", "media:\(UUID().uuidString)", "title:pas-un-uuid"] {
            #expect(AppRoute(spotlight: raw) == nil, "« \(raw) » ne doit ouvrir aucune route")
        }
    }

    @Test("Les types indexés sont un sous-ensemble des routes")
    func indexedKindsAreAllRoutable() {
        // Si un type indexable était ajouté sans route correspondante, il produirait des
        // items Spotlight qui n'ouvrent rien. Ce test échouerait alors à la compilation
        // du `switch` exhaustif d'`AppRoute.init(spotlight:)` — mais seulement si
        // quelqu'un pense à le recompiler. L'assertion le rend explicite.
        for kind in SpotlightEntityKind.allCases {
            let raw = SpotlightItemID(kind: kind, entityID: UUID()).rawValue
            #expect(AppRoute(spotlight: raw) != nil, "\(kind.rawValue) n'a pas de route")
        }
    }
}
