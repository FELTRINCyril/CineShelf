import Foundation
import SwiftData

// MARK: - Écrire une ligne validée dans le magasin
//
// **Le piège central de `L11b`, et la façon dont il est désarmé.** Les repositories sont
// `@MainActor` parce que `SpotlightIndexer` l'est, et `ImportActor` est un acteur : les deux ne
// peuvent pas se rencontrer. `L10` avait résolu le dilemme en restant sur le fil principal, ce
// qui est tenable pour cinquante entités et pas pour 1 284.
//
// Ce fichier est donc une **quatrième porte d'écriture**, et le dépôt en a refusé deux. Ce qui
// la rend acceptable est ce qui manquait aux précédentes :
//
//  1. Elle est **dans `CineShelfCore`**, à côté des repositories, sous la même règle de lint.
//  2. Elle appelle `refreshDerived()` sur **chaque** entité écrite, sans exception — et le test
//     `derivedValuesAreIdempotentAfterImport` le prouve autrement qu'en me croyant : il
//     rappelle `refreshDerived()` après l'import et vérifie que **rien ne change**. Un oubli
//     laisserait un dérivé faux, donc un écart au second appel. C'est la même ruse que la
//     comparaison de locale : on ne vérifie pas que la ligne a été écrite, on vérifie que le
//     résultat est celui qu'elle produit.
//  3. Elle **ne saute pas** Spotlight : elle ne l'appelle pas, et `ImportActor` le fait en une
//     passe après commit. Sauter l'indexation serait le trou muet classique — les titres
//     importés seraient absents de la recherche système sans que rien ne le dise.
//  4. Elle ne journalise rien par entité. `JournalPolicy.batched` : une entrée pour le lot.

/// Écrit les lignes validées d'un import dans un contexte donné.
///
/// Non isolé, comme `EntityResolver` : il hérite de l'isolation de son appelant. Il n'est pas
/// `Sendable`, il porte un `ModelContext`.
public struct ImportWriter: ~Copyable {

    /// Ce qu'une ligne a produit.
    public enum Outcome: Sendable, Hashable {
        /// Un titre neuf.
        case created(UUID)
        /// Un titre existant complété : les champs remplis avec leur valeur d'avant, et les
        /// relations ajoutées avec de quoi les détacher.
        case completed(
            UUID,
            previousValues: [String: String?],
            attachedGenreIDs: [UUID] = [],
            addedCreditIDs: [UUID] = [])
        /// Un doublon dont rien n'était à compléter : l'existant avait déjà tout.
        case unchanged(UUID)

        /// L'entité touchée, quelle que soit l'issue.
        public var entityID: UUID {
            switch self {
            case .created(let id), .unchanged(let id): id
            case .completed(let id, _, _, _): id
            }
        }

        /// La nature de l'issue, comparable, pour replier plusieurs lignes d'une même fiche.
        public var kind: OutcomeKind {
            switch self {
            case .created: .created
            case .completed: .completed
            case .unchanged: .unchanged
            }
        }
    }

    /// Les issues, ordonnées de la plus forte à la plus faible.
    ///
    /// **L'ordre est le contrat de repliage** : une fiche créée puis complétée par une ligne
    /// suivante du même fichier est **créée** par cet import. L'annulation doit donc la retirer,
    /// et non restaurer un état d'avant qui n'a jamais existé.
    public enum OutcomeKind: Int, Sendable, Hashable, Comparable {
        case unchanged
        case completed
        case created

        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let context: ModelContext
    let library: Library
    let schema: CSVSchema
    var resolver: EntityResolver
    public init(context: ModelContext, library: Library, schema: CSVSchema) {
        self.context = context
        self.library = library
        self.schema = schema
        self.resolver = EntityResolver(context: context, library: library)
    }

    /// Les entités de référence créées en passant.
    public var createdReferenceIDs: Set<UUID> { resolver.createdIDs }

    // MARK: Titres

    /// Écrit une ligne de titre : créé, complété, ou laissé tel quel.
    ///
    /// - Precondition: la ligne est **valide**. `ImportValidator` l'a dite prête, donc ce
    ///   fichier ne revalide pas : deux validations divergeraient, et c'est la seconde qui
    ///   gagnerait sans que personne ne l'ait décidé.
    public mutating func write(title row: ImportRow) -> Outcome {
        let name = (row.cell("title") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let year = Self.duplicateYear(of: row)

        if let existing = resolver.existingTitle(named: name, year: year) {
            return complete(existing, from: row)
        }
        return create(titleNamed: name, from: row)
    }

    /// L'année qui entre dans la clé de doublon.
    ///
    /// **Elle vient de `year` ou de `release_date`, et ne pas regarder la seconde était un bug
    /// bloquant.** `TitleQuery.living(sortName:year:inLibrary:)` traite une année nulle comme
    /// « cherche un titre **sans** date » — décision juste, deux éditions dont l'une est datée
    /// n'en sont pas une seule. Mais un fichier qui porte « Date de sortie » **sans** « Année »
    /// écrivait alors une `releaseDate` non nulle puis cherchait `releaseDate == nil` : la
    /// recherche ne trouvait jamais rien, ni contre l'existant ni dans le lot.
    ///
    /// Mesuré avant correction, sur un fichier de deux lignes identiques importé deux fois :
    /// **quatre fiches** « Dune », aucun signal, et un bilan cohérent avec lui-même.
    static func duplicateYear(of row: ImportRow) -> Int? {
        if let year = row.cell("year").flatMap(CSVValueParser.year) { return year }
        guard let date = row.cell("release_date").flatMap(CSVValueParser.date) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.component(.year, from: date)
    }

    private mutating func create(titleNamed name: String, from row: ImportRow) -> Outcome {
        let title = Title(name: name)
        title.library = library
        context.insert(title)
        apply(row, to: title, overwriting: true)
        return .created(title.id)
    }

    /// Complète un titre existant **sans jamais écraser une valeur déjà là**.
    ///
    /// La règle de doublon arrêtée le 2026-08-04. Ce qui est vide se remplit, ce qui est rempli
    /// ne bouge pas : un import ne doit pas pouvoir dégrader une fiche que l'utilisateur a
    /// soignée à la main. Les valeurs d'avant sont rendues pour que `L20` puisse rétablir
    /// l'état exact — un champ « était vide » est une information à conserver.
    private mutating func complete(_ title: Title, from row: ImportRow) -> Outcome {
        var previous: [String: String?] = [:]
        for field in schema.fields {
            guard let value = row.cell(field.key)?.trimmingCharacters(in: .whitespacesAndNewlines),
                !value.isEmpty,
                isEmpty(field.key, on: title)
            else { continue }
            previous[field.key] = currentValue(field.key, on: title)
        }

        // **Le travail se décide avant d'écrire, et pas après.** `refreshDerived()` pose
        // `updatedAt = .now`, donc appeler `apply` « pour voir » sur une ligne qui n'apporte rien
        // ferait une écriture — et une synchronisation CloudKit — par ligne inchangée. Sur un
        // réimport de 1 284 lignes, c'est 1 284 écritures pour rien.
        let additions = additiveWork(in: row, on: title)
        guard !previous.isEmpty || !additions.isEmpty else { return .unchanged(title.id) }

        let genresBefore = Set((title.genres ?? []).map(\.id))
        let creditsBefore = Set((title.credits ?? []).map(\.id))
        apply(row, to: title, overwriting: false)

        return .completed(
            title.id,
            previousValues: previous,
            attachedGenreIDs: Set((title.genres ?? []).map(\.id)).subtracting(genresBefore).sorted {
                $0.uuidString < $1.uuidString
            },
            addedCreditIDs: Set((title.credits ?? []).map(\.id)).subtracting(creditsBefore).sorted {
                $0.uuidString < $1.uuidString
            })
    }

    /// Les champs additifs dont la cellule apporte au moins un membre qui manque.
    ///
    /// **Sans effet de bord** : les valeurs sont comparées par leur **clé repliée** aux membres
    /// déjà attachés, sans passer par le résolveur — qui créerait le genre ou la personne. C'est
    /// ce qui permet de décider s'il y a du travail avant d'en faire.
    private func additiveWork(in row: ImportRow, on title: Title) -> Set<String> {
        var keys: Set<String> = []
        for field in schema.fields where Self.isAdditive(field.key) {
            guard let raw = row.cell(field.key)?.trimmingCharacters(in: .whitespacesAndNewlines),
                !raw.isEmpty
            else { continue }
            let wanted = Set(CSVSchema.splitMultiValue(raw).map { Self.memberKey($0, for: field.key) })
            guard !wanted.subtracting(attachedMemberKeys(field.key, on: title)).isEmpty else {
                continue
            }
            keys.insert(field.key)
        }
        return keys
    }

    /// La clé d'un membre de cellule, dans la forme que le résolveur emploie.
    private static func memberKey(_ value: String, for field: String) -> String {
        guard field == "genres" else {
            let split = EntityResolver.splitName(
                value.trimmingCharacters(in: .whitespacesAndNewlines))
            return Person.sortKey(firstName: split.first, lastName: split.last)
        }
        return Genre.key(for: value)
    }

    /// Les clés des membres déjà attachés au titre pour ce champ.
    private func attachedMemberKeys(_ field: String, on title: Title) -> Set<String> {
        switch field {
        case "genres": Set((title.genres ?? []).map(\.nameKey))
        case "director": Set(credits(of: title, role: .director).compactMap(\.person?.sortName))
        case "cast": Set(credits(of: title, role: .cast).compactMap(\.person?.sortName))
        default: []
        }
    }

    /// Applique les cellules d'une ligne à un titre.
    ///
    /// - Parameters:
    ///   - row: la ligne validée.
    ///   - title: le titre à écrire.
    ///   - overwriting: `true` pour un titre neuf, où tout est à écrire. `false` pour un titre
    ///     existant, où seuls les champs vides se remplissent. Un seul chemin d'écriture pour
    ///     les deux cas : deux chemins auraient fini par ne pas écrire les mêmes champs, et
    ///     l'écart ne se serait vu que sur les fiches complétées.
    private mutating func apply(_ row: ImportRow, to title: Title, overwriting: Bool) {
        for field in schema.fields {
            guard let raw = row.cell(field.key) else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            guard overwriting || isEmpty(field.key, on: title) || Self.isAdditive(field.key) else {
                continue
            }
            set(field.key, to: value, on: title)
        }
        // **L'invariant, appelé ici et nulle part ailleurs dans ce fichier.** Il vient après
        // les relations : `filterKeys` les dénormalise, donc le rafraîchir avant les attacher
        // laisserait le titre introuvable par le filtre correspondant.
        title.refreshDerived()
    }

    /// Les champs dont écrire **n'écrase rien**, parce qu'ils ajoutent.
    ///
    /// **Sans cette exception, un réimport enrichi ne faisait rien, en silence.** Mesuré : un
    /// premier import avec « sci-fi » et un acteur, puis le même fichier enrichi de « thriller »
    /// et d'un second acteur — bilan « 0 ajoutés, 0 complétés, 1 inchangés », et les deux ajouts
    /// **abandonnés sans être comptés nulle part**. C'est le geste le plus naturel qu'un
    /// utilisateur fera après avoir complété son tableur.
    ///
    /// Ce n'est pas une entorse à « ne jamais écraser » : rien n'est retiré. Un genre ou un crédit
    /// déjà présent est reconnu et sauté — c'est le résolveur et le dédoublonnage de
    /// `attachCredits` qui s'en chargent — donc l'opération est idempotente.
    ///
    /// La collection n'en fait **pas** partie : un titre n'a qu'une collection, donc l'écrire
    /// remplacerait la précédente, ce qui est exactement ce que la règle interdit.
    static func isAdditive(_ key: String) -> Bool {
        key == "genres" || key == "director" || key == "cast"
    }

    /// Les clés que cet écrivain traite, déclarées pour être vérifiées.
    ///
    /// Une **donnée** que le test compare au schéma. Elle doit lister exactement les clés
    /// citées par `isEmpty(_:on:)` et par `set(_:to:on:)` : c'est le seul moyen de faire
    /// échouer l'ajout d'une colonne au schéma que personne n'aurait branchée ici.
    ///
    /// `added_at` y figure bien qu'il ne soit pas écrit : il est traité, et son traitement est
    /// de ne rien faire. La distinction compte — « ignoré exprès » et « oublié » se ressemblent
    /// en production et pas du tout dans un test.
    static let handledKeys: Set<String> = [
        "title", "original_title", "kind", "year", "release_date", "runtime", "rating",
        "summary", "collection", "genres", "director", "cast", "season_count",
        "episode_count", "is_private", "is_archived", "added_at"
    ]

    /// Le 1er janvier d'une année, dans le fuseau courant.
    ///
    /// Fuseau courant et non UTC, comme `CSVExporter.dateStyle` et `Title.releaseYear` : en
    /// UTC, un titre de 2021 s'afficherait en 2020 dans l'app. Le bug a déjà été attrapé une
    /// fois sur la colonne « Année » de l'export.
    static func firstDay(of year: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1))
    }
}
