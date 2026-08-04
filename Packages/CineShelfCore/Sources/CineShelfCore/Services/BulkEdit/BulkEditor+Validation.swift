import Foundation

// MARK: - Valider avant d'écrire
//
// La validation ne regarde que la mutation, pas les entités : une valeur hors bornes
// est fautive quelle que soit la sélection. Les refus qui dépendent de l'entité — elle
// n'existe pas, elle est à la corbeille, la relation est d'une autre bibliothèque —
// sont établis par `BulkEditor` au moment du chargement.
//
// Les bornes viennent des documents, pas de l'intuition : l'année attendue entre 1888 et
// 2030 est celle de l'addendum d'import.
//
// **La note est sur 10, et c'était un bug le 2026-08-04.** La première version imposait
// 0…5 en refusant les demi-étoiles, sur la foi de la planche 6 du design — qui parle de
// cinq étoiles **pleines à l'affichage**. Or `docs/02` §3.3 dit « Note du catalogue,
// 0–10 », et `TitleFormat.fiveStarRating` divise déjà par deux depuis le prompt 11. La
// planche 6 décrit donc le rendu, pas le modèle, et l'appliquer ici aurait refusé à
// l'import toutes les notes au-dessus de 5 — soit la moitié de l'échelle.

@MainActor
extension BulkEditor {

    /// Les bornes que les documents fixent.
    ///
    /// **Elles vivent dans `CatalogBounds` depuis que `L11a` les partage.** Ces alias
    /// restent pour que les sites d'appel de `L10` se lisent comme avant ; la source, la
    /// justification de chaque borne et l'histoire du bug de la note sont là-bas.
    enum Bounds {
        static let years = CatalogBounds.years
        static let ratings = CatalogBounds.ratings
        static let minimumRuntime = CatalogBounds.runtimeMinutes.lowerBound
    }

    func validate(_ mutation: TitleBulkMutation) -> [BulkRefusal] {
        switch mutation {
        case .setRating(let value):
            // Pas de contrainte d'arrondi : `ratingText` écrit « 8,4 / 10 », donc une
            // décimale est une valeur normale du modèle.
            guard Bounds.ratings.contains(value) else {
                return [outOfRange(field: "La note", expected: "entre 0 et 10")]
            }
            return []

        case .setRuntime(let minutes):
            guard minutes >= Bounds.minimumRuntime else {
                return [outOfRange(field: "La durée", expected: "au moins 1 minute")]
            }
            return []

        case .setReleaseDate(let date, _):
            let year = Calendar(identifier: .gregorian).component(.year, from: date)
            guard Bounds.years.contains(year) else {
                return [
                    outOfRange(
                        field: "L'année",
                        expected: "entre \(Bounds.years.lowerBound) et \(Bounds.years.upperBound)")
                ]
            }
            return []

        case .setSummary(let text):
            return text.isBlank ? [empty(field: "Le résumé")] : []

        case .setGenres(let ids), .addGenres(let ids), .removeGenres(let ids):
            // Une opération de relation sans identifiant ne serait pas une erreur de
            // valeur mais une opération sans effet, et l'appelant croirait avoir agi.
            // `clearGenres` existe pour vider, et il est explicite.
            return ids.isEmpty ? [empty(field: "La liste de genres")] : []

        case .setKind, .setArchived, .setPrivate, .setCollection,
            .clearRating, .clearRuntime, .clearReleaseDate, .clearSummary,
            .clearCollection, .clearGenres:
            return []
        }
    }

    func validate(_ mutation: PersonBulkMutation) -> [BulkRefusal] {
        switch mutation {
        case .setRoles(let roles):
            // `Person.roleValues` a `[.actor]` pour défaut : le modèle suppose qu'une
            // personne a au moins un rôle, et vider la liste en masse laisserait des
            // personnes qu'aucun filtre de rôle ne retrouve.
            return roles.isEmpty ? [empty(field: "La liste de rôles")] : []

        case .setBio(let text):
            return text.isBlank ? [empty(field: "La biographie")] : []

        case .setGenres(let ids), .addGenres(let ids), .removeGenres(let ids):
            return ids.isEmpty ? [empty(field: "La liste de genres")] : []

        case .setArchived, .setPrivate, .clearBio, .clearGenres:
            return []
        }
    }

    // Un refus de valeur ne vise aucune entité en particulier : la mutation elle-même
    // est fautive, donc elle l'est pour toute la sélection. `entityID` nul le dit.
    private func outOfRange(field: String, expected: String) -> BulkRefusal {
        BulkRefusal(
            entityID: BulkRefusal.mutationScope,
            reason: .valueOutOfRange(field: field, expected: expected)
        )
    }

    private func empty(field: String) -> BulkRefusal {
        BulkRefusal(entityID: BulkRefusal.mutationScope, reason: .valueEmpty(field: field))
    }
}

extension String {
    /// Vide, ou uniquement des espaces et des retours à la ligne.
    ///
    /// `isEmpty` ne suffit pas : un champ rempli d'espaces est vide pour l'utilisateur,
    /// et l'accepter écrirait un résumé invisible que rien ne signalerait.
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
