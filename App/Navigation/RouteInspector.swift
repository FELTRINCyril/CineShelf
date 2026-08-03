import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// Le contenu de l'inspecteur, piloté par la route affichée — ⌥⌘I.
///
/// Un seul `.inspector`, monté par `RegularRootView`, dont le contenu suit le
/// sommet de la pile. Deux `.inspector` imbriqués — un global et un dans la
/// fiche — donneraient deux panneaux concurrents.
///
/// Comme `AppSectionDestination`, c'est un point de contact assumé entre la
/// navigation et les features : la résolution est centralisée ici plutôt que
/// dispersée, et aucune feature n'en connaît une autre.
struct RouteInspector: View {
    let route: AppRoute?

    var body: some View {
        Group {
            switch route {
            case .title(let id):
                TitleInspector(titleID: id)
            default:
                StateView(
                    .empty(
                        symbol: "slider.horizontal.3",
                        title: "Inspecteur.",
                        message: "Sélectionne un élément pour le modifier ici, sans quitter la liste."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bgSurface)
        .inspectorColumnWidth(min: 280, ideal: 340, max: 460)
    }
}

/// L'éditeur de titre dans l'inspecteur.
///
/// Charge le titre par son identifiant : la route ne porte qu'un `UUID`, et
/// c'est bien ainsi — un `@Model` dans une énumération `Codable` ne survivrait
/// pas à la restauration.
private struct TitleInspector: View {
    let titleID: UUID

    @Query private var titles: [Title]

    init(titleID: UUID) {
        self.titleID = titleID
        _titles = Query(filter: #Predicate<Title> { $0.id == titleID })
    }

    var body: some View {
        if let title = titles.first {
            TitleEditor(title: title, isInspector: true)
                // Sans identité explicite, SwiftUI réutilise la vue quand la
                // route change et garde le brouillon du titre précédent — qu'un
                // « Enregistrer » écrirait alors sur le nouveau.
                .id(title.id)
        } else {
            StateView(
                .empty(
                    symbol: Icon.titles,
                    title: "Rien à modifier.",
                    message: "Ce titre n'existe plus."
                )
            )
        }
    }
}
