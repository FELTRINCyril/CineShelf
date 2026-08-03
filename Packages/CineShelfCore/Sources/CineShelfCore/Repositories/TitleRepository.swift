import Foundation
import SwiftData

/// Écritures sur les titres (`docs/04` §3).
///
/// Invariant central : aucune écriture ne contourne `refreshDerived()`. C'est ce
/// qui garantit que `sortName` et `searchText` restent cohérents — ils
/// remplacent les colonnes générées et l'index FTS que CloudKit ne permet pas.
@MainActor
public struct TitleRepository {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func create(name: String, kind: TitleKind = .movie, in library: Library) -> Title {
        let title = Title(name: name, kind: kind)
        title.library = library
        title.refreshDerived()
        context.insert(title)
        ActivityRecorder(context: context).record(.create, title)
        return title
    }

    public func update(_ title: Title, _ mutate: (Title) -> Void) {
        mutate(title)
        title.refreshDerived()
        ActivityRecorder(context: context).record(.update, title)
    }

    /// Corbeille plutôt que suppression : une suppression synchronisée est
    /// irréversible. La purge à 30 jours est une tâche de maintenance.
    public func softDelete(_ title: Title) {
        title.deletedAt = .now
        title.updatedAt = .now
        ActivityRecorder(context: context).record(.delete, title)
    }

    public func restore(_ title: Title) {
        title.deletedAt = nil
        title.updatedAt = .now
        ActivityRecorder(context: context).record(.restore, title)
    }

    // MARK: Relations
    //
    // **Les seules portes autorisées pour muter une relation d'un titre**, et la
    // règle SwiftLint `no_relation_write_outside_core` interdit les autres.
    //
    // La raison n'est pas le goût de l'encapsulation. Depuis `L1`,
    // `refreshDerived()` compose `filterKeys` à partir des relations : la
    // bibliothèque, la collection, les genres et les personnes créditées y sont
    // dénormalisés pour être interrogeables en SQL. Une relation écrite sans
    // rafraîchissement laisse donc `filterKeys` en arrière, et le titre devient
    // introuvable par le filtre correspondant — **sans erreur, sans avertissement,
    // et sans qu'aucun test de critère ne bronche**, puisque la relation, elle, est
    // bien posée.
    //
    // C'est le seul invariant du modèle qu'aucun type ne protégeait. Ces méthodes
    // le protègent, et elles existent maintenant plutôt qu'au moment où `V4` et `V5`
    // écriront l'édition du casting, des genres et de la collection : la porte se
    // ferme avant que quelqu'un ait pris l'habitude de passer par la fenêtre.
    //
    // Chacune délègue à `update(_:_:)`, qui appelle `refreshDerived()` et journalise.

    public func setCollection(_ collection: TitleCollection?, on title: Title) {
        update(title) { $0.collection = collection }
    }

    public func setGenres(_ genres: [Genre], on title: Title) {
        update(title) { $0.genres = genres }
    }

    /// Déplace un titre vers une autre bibliothèque.
    ///
    /// Ne touche qu'au titre : la clôture transitive de ses dépendances — médias,
    /// crédits, liens — est le sujet de `L15`, pas d'ici.
    public func move(_ title: Title, to library: Library) {
        update(title) { $0.library = library }
    }

    /// Crédite une personne sur un titre.
    ///
    /// Seul le **titre** est rafraîchi : `Person.filterKeys` ne porte pas les
    /// crédits (bibliothèque, genres et rôles seulement), donc la personne n'a rien
    /// de dérivé à recalculer. Si un critère de filtre de personne venait un jour à
    /// dépendre de ses crédits — « a joué dans au moins un film », par exemple — il
    /// faudrait la rafraîchir ici aussi.
    @discardableResult
    public func addCredit(
        person: Person,
        role: CreditRole = .cast,
        characterName: String? = nil,
        orderIndex: Int? = nil,
        to title: Title
    ) -> Credit {
        let credit = Credit(
            role: role,
            characterName: characterName,
            orderIndex: orderIndex ?? (title.credits?.count ?? 0)
        )
        credit.person = person
        credit.title = title
        context.insert(credit)
        update(title) { _ in }
        return credit
    }

    /// Retire un crédit du casting d'un titre.
    ///
    /// **Le détachement précède la suppression, et l'ordre n'est pas cosmétique.**
    /// `ModelContext.delete(_:)` ne retire pas immédiatement l'objet des relations
    /// inverses : jusqu'à la sauvegarde, `title.credits` contient encore le crédit
    /// supprimé. Un `refreshDerived()` appelé à ce moment-là recompose donc
    /// `filterKeys` **avec** la personne qu'on vient de décréditer, et le titre reste
    /// indéfiniment retrouvable par un filtre sur elle.
    ///
    /// Mettre `credit.title` à `nil` d'abord met la relation inverse à jour tout de
    /// suite, et le rafraîchissement voit le bon état. Attrapé par
    /// `RelationMutatorTests.creditMutatorsMaintainKeys`, qui a échoué sur la
    /// première version.
    public func removeCredit(_ credit: Credit, from title: Title) {
        credit.title = nil
        credit.person = nil
        context.delete(credit)
        update(title) { _ in }
    }
}
