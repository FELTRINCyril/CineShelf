import Foundation
import SwiftData

/// Écritures sur les genres.
///
/// CloudKit interdit `@Attribute(.unique)` : `findOrCreate(name:target:in:)`
/// cherche sur `nameKey` avant d'insérer. C'est notre remplacement de la
/// contrainte d'unicité, côté application.
@MainActor
public struct GenreRepository {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Le genre existant de même clé, cible et bibliothèque, sinon un genre neuf.
    ///
    /// **La règle vit dans `EntityResolver` depuis `L11b`, et ce fichier la lui délègue.**
    /// L'import ne peut pas passer ici — ce type est `@MainActor` — donc il aurait fallu
    /// recopier la recherche dans l'acteur. Deux copies d'une règle de dédoublonnage finissent
    /// par diverger, et une divergence ici crée des doublons **en silence** : c'est
    /// exactement ce que `nameKey` existe pour empêcher.
    ///
    /// Ce qui reste ici est ce que le résolveur ne fait pas, faute de savoir dans quel
    /// contexte il est appelé : l'entrée de journal.
    public func findOrCreate(name: String, target: GenreTarget = .title, in library: Library) throws -> Genre {
        var resolver = EntityResolver(context: context, library: library)
        guard let genre = resolver.genre(named: name, target: target) else {
            throw GenreError.emptyName
        }
        // Journaliser **seulement** une vraie création : `createdIDs` le dit, et retrouver un
        // genre existant n'est pas un événement du catalogue.
        if resolver.createdIDs.contains(genre.id) {
            ActivityRecorder(context: context).record(.create, genre)
        }
        return genre
    }

    public func rename(_ genre: Genre, to name: String) {
        genre.name = name
        genre.refreshDerived()
        ActivityRecorder(context: context).record(.update, genre)
    }

    /// Épingle ou désépingle un genre — la configuration de l'accueil, pas une navigation.
    ///
    /// **Ce que `V5a` avait laissé ouvert.** Le rail « Mes genres · Drame » du bloc `3a` lit
    /// `GenreQuery.pinned` trié sur `pinIndex` depuis `25d25b0`, mais **rien n'écrivait ces deux
    /// champs** : ils étaient posés à la fermeture du schéma et aucun chemin ne les touchait.
    /// L'accueil savait donc afficher une configuration que l'utilisateur ne pouvait pas faire.
    ///
    /// **L'épinglage s'ajoute en queue, jamais en tête.** `pinIndex` est un ordre d'affichage :
    /// poser un genre neuf à 0 déplacerait tous les rails existants de l'accueil à chaque
    /// épinglage, alors que l'utilisateur n'a touché qu'une bascule. La queue est le seul choix
    /// qui laisse en place ce qui était déjà là.
    ///
    /// **Le désépinglage ne renumérote rien**, et c'est délibéré : le tri ne dépend que de
    /// l'ordre relatif, donc un trou dans la suite (0, 1, 3) rend exactement la même chose.
    /// Renuméroter ferait écrire *tous* les genres épinglés pour en retirer un — donc autant
    /// d'objets à synchroniser vers CloudKit, et autant d'occasions de conflit sur un champ que
    /// personne n'a modifié.
    /// > **Le rang se calcule *avant* la bascule, et l'ordre des deux lignes est le sujet.**
    /// > Poser `isPinned = true` d'abord fait entrer le genre dans sa propre mesure : il
    /// > devient son propre maximum, et le premier épinglage d'une bibliothèque vierge rend 1
    /// > au lieu de 0. Le défaut est invisible sur un genre isolé — l'ordre reste bon, il
    /// > commence juste à 1 — et il ne se voit qu'en retirant un rang du **milieu**. C'est le
    /// > test `unpinningLeavesAHole` qui l'a trouvé, et il l'a trouvé parce qu'il ne prenait
    /// > ni le premier ni le dernier.
    public func setPinned(_ genre: Genre, _ pinned: Bool) {
        guard genre.isPinned != pinned else { return }
        if pinned { genre.pinIndex = nextPinIndex() }
        genre.isPinned = pinned
        genre.refreshDerived()
        ActivityRecorder(context: context).record(.update, genre)
    }

    /// Le rang suivant : un de plus que le plus grand déjà pris.
    ///
    /// **Le maximum, et non le compte.** Le compte se trompe dès qu'un trou existe — trois
    /// genres épinglés aux rangs 0, 1 et 3 donneraient 3, un rang déjà occupé, et les deux
    /// rails se retrouveraient dans un ordre que SwiftData choisit seul. Les trous sont la
    /// normale ici, puisque le désépinglage n'en rebouche aucun.
    private func nextPinIndex() -> Int {
        let descriptor = FetchDescriptor<Genre>(
            predicate: GenreQuery.pinned,
            sortBy: [SortDescriptor(\.pinIndex, order: .reverse)]
        )
        guard let highest = try? context.fetch(descriptor).first else { return 0 }
        return highest.pinIndex + 1
    }

    /// Corbeille plutôt que suppression : un genre supprimé en dur emporte
    /// toutes ses associations avec les titres et les personnes, et les
    /// recréer ne les ramène pas. Voir `docs/02` §3.5.
    public func softDelete(_ genre: Genre) {
        genre.deletedAt = .now
        genre.updatedAt = .now
        ActivityRecorder(context: context).record(.delete, genre)
    }

    public func restore(_ genre: Genre) {
        genre.deletedAt = nil
        genre.updatedAt = .now
        ActivityRecorder(context: context).record(.restore, genre)
    }

    /// Le nom d'un genre ne peut pas être vide.
    ///
    /// Un genre sans nom aurait une `nameKey` vide, donc il ferait doublon avec tous les
    /// autres genres sans nom, et le dédoublonnage les fusionnerait silencieusement.
    public enum GenreError: Error, Sendable, Hashable {
        case emptyName
    }

    private func find(key: String, target: GenreTarget, in library: Library) throws -> Genre? {
        // Le filtre `deletedAt == nil` est porté par `GenreQuery` : sans lui,
        // `findOrCreate` ressusciterait silencieusement un genre mis à la corbeille,
        // et l'utilisateur retrouverait ses anciennes associations sans les avoir
        // demandées.
        var descriptor = FetchDescriptor<Genre>(
            predicate: GenreQuery.living(key: key, target: target, inLibrary: library.id)
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
