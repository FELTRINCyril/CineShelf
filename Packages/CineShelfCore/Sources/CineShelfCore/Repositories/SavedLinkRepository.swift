import Foundation
import SwiftData

/// Écritures sur les signets — les liens **autonomes**, ceux qui n'appartiennent à aucune
/// fiche.
///
/// **Écrit par `V5b`, et il manquait.** L'écran des signets créait, renommait et supprimait
/// depuis la vue, ce que `docs/04` §1 interdit : « aucune logique métier dans une `View` ».
/// Le défaut n'était pas théorique — `refreshDerived()` maintient `searchText`, donc un signet
/// écrit sans lui devient introuvable par la recherche, en silence.
@MainActor
public struct SavedLinkRepository {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Crée un signet à partir d'une adresse **déjà validée par l'appelant**.
    ///
    /// **La garde n'est pas rejouée ici**, et c'est un choix : `LinkGuard.refusal(for:)` rend
    /// un motif que l'écran doit montrer à l'utilisateur, pas un booléen. Le refaire dans le
    /// repository imposerait de le traduire en erreur, donc d'avoir deux vocabulaires pour le
    /// même refus. L'appelant refuse avant d'écrire ; ce type écrit.
    @discardableResult
    public func create(urlString: String, in library: Library) -> SavedLink {
        let link = SavedLink(urlString: urlString)
        link.library = library
        link.refreshDerived()
        context.insert(link)
        ActivityRecorder(context: context).record(.create, link)
        return link
    }

    public func update(_ link: SavedLink, journal: JournalPolicy, _ mutate: (SavedLink) -> Void) {
        mutate(link)
        link.refreshDerived()
        if journal == .perEntity {
            ActivityRecorder(context: context).record(.update, link)
        }
    }

    /// Corbeille plutôt que suppression, comme partout ailleurs : `L16` purge à trente jours,
    /// et le fil doit pouvoir nommer ce qui a disparu.
    public func softDelete(_ link: SavedLink) {
        link.deletedAt = .now
        link.refreshDerived()
        ActivityRecorder(context: context).record(.delete, link)
    }

    public func restore(_ link: SavedLink) {
        link.deletedAt = nil
        link.refreshDerived()
        ActivityRecorder(context: context).record(.restore, link)
    }
}
