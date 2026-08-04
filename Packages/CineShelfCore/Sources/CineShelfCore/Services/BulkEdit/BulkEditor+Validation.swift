import Foundation

// MARK: - Valider avant d'écrire
//
// La validation ne regarde que la mutation, pas les entités : une valeur hors bornes
// est fautive quelle que soit la sélection. Les refus qui dépendent de l'entité — elle
// n'existe pas, elle est à la corbeille, la relation est d'une autre bibliothèque —
// sont établis par `BulkEditor` au moment du chargement.
//
// Les bornes viennent des documents, pas de l'intuition : l'année attendue entre 1888 et
// 2030 est celle de l'addendum d'import, et la note sur cinq étoiles pleines celle de la
// planche 6. Une note à 4,5 est donc **refusée** : le design a écarté la demi-étoile.

@MainActor
extension BulkEditor {

    /// Les bornes que les documents fixent.
    enum Bounds {
        /// 1888 : *Roundhay Garden Scene*, le plus ancien film connu. La borne haute
        /// laisse la place aux sorties annoncées.
        static let years = 1888...2030
        /// Cinq étoiles pleines, pas de demi-étoile (planche 6).
        static let ratings = 0.0...5.0
        /// Une minute au moins. Pas de borne haute : *Logistics* dure 51 420 minutes.
        static let minimumRuntime = 1
    }

    func validate(_ mutation: TitleBulkMutation) -> [BulkRefusal] {
        switch mutation {
        case .setRating(let value):
            guard Bounds.ratings.contains(value) else {
                return [outOfRange(field: "La note", expected: "entre 0 et 5")]
            }
            // Une note qui n'est pas un multiple de 1 passerait le test de bornes mais
            // rendrait une demi-étoile que le design a explicitement écartée.
            guard value == value.rounded() else {
                return [outOfRange(field: "La note", expected: "un nombre entier d'étoiles")]
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
