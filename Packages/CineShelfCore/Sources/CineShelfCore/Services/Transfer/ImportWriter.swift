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
        /// Un titre existant complété. Les champs remplis, avec leur valeur d'avant.
        case completed(UUID, previousValues: [String: String?])
        /// Un doublon dont rien n'était à compléter : l'existant avait déjà tout.
        case unchanged(UUID)
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
        let year = row.cell("year").flatMap(CSVValueParser.year)

        if let existing = resolver.existingTitle(named: name, year: year) {
            return complete(existing, from: row)
        }
        return create(titleNamed: name, from: row)
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
        guard !previous.isEmpty else { return .unchanged(title.id) }

        apply(row, to: title, overwriting: false)
        return .completed(title.id, previousValues: previous)
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
            guard overwriting || isEmpty(field.key, on: title) else { continue }
            set(field.key, to: value, on: title)
        }
        // **L'invariant, appelé ici et nulle part ailleurs dans ce fichier.** Il vient après
        // les relations : `filterKeys` les dénormalise, donc le rafraîchir avant les attacher
        // laisserait le titre introuvable par le filtre correspondant.
        title.refreshDerived()
    }

    // MARK: Les champs, un par un

    /// Ce champ est-il vide sur ce titre ?
    ///
    /// Sert à la règle « compléter sans écraser ».
    ///
    /// **Le compilateur ne garde rien ici, et il ne faut pas se raconter le contraire.** La clé
    /// est une `String`, donc ce `switch` a un `default` et une clé ajoutée au schéma y tombe
    /// **silencieusement** : elle serait considérée comme jamais vide, donc jamais complétée sur
    /// un doublon. Aucune erreur, aucun test rouge, juste une colonne qui n'arrive pas.
    ///
    /// Le filet est donc un test et non une garde de compilation :
    /// `everySchemaFieldIsHandledByTheWriter` parcourt `CSVSchema.title.fields` et exige que
    /// chaque clé soit citée ici **et** dans `set(_:to:on:)`. Il échoue à l'ajout d'une colonne,
    /// ce qui est le moment où on peut encore décider.
    private func isEmpty(_ key: String, on title: Title) -> Bool {
        scalarIsEmpty(key, on: title) ?? relationIsEmpty(key, on: title)
    }

    /// Les champs qui portent une valeur. `nil` si la clé n'en est pas un.
    private func scalarIsEmpty(_ key: String, on title: Title) -> Bool? {
        switch key {
        case "title": title.name.isEmpty
        case "original_title": title.originalName?.isEmpty ?? true
        case "year", "release_date": title.releaseDate == nil
        case "runtime": title.runtimeMinutes == nil
        case "rating": title.rating == nil
        case "summary": title.summary?.isEmpty ?? true
        case "season_count": title.seasonCount == nil
        case "episode_count": title.episodeCount == nil
        // `kindRaw`, `createdAt` et les booléens ont toujours une valeur : ils ne sont jamais
        // « vides », donc un doublon ne les complète pas.
        case "kind", "added_at", "is_private", "is_archived": false
        default: nil
        }
    }

    /// Les champs qui portent une relation.
    private func relationIsEmpty(_ key: String, on title: Title) -> Bool {
        switch key {
        case "collection": title.collection == nil
        case "genres": (title.genres ?? []).isEmpty
        case "director": credits(of: title, role: .director).isEmpty
        case "cast": credits(of: title, role: .cast).isEmpty
        default: false
        }
    }

    /// La valeur actuelle d'un champ, en texte, pour le diff d'annulation.
    private func currentValue(_ key: String, on title: Title) -> String? {
        switch key {
        case "original_title": title.originalName
        case "year", "release_date": title.releaseDate.map { ISO8601DateFormatter().string(from: $0) }
        case "runtime": title.runtimeMinutes.map(String.init)
        case "rating": title.rating.map { String($0) }
        case "summary": title.summary
        case "collection": title.collection?.name
        case "genres": (title.genres ?? []).isEmpty ? nil : CSVSchema.joinMultiValue((title.genres ?? []).map(\.name))
        case "season_count": title.seasonCount.map(String.init)
        case "episode_count": title.episodeCount.map(String.init)
        default: nil
        }
    }

    /// Écrit une cellule sur un titre.
    ///
    /// Les valeurs illisibles sont **ignorées** et non forcées : la ligne a été validée, donc
    /// une conversion qui échoue ici est une incohérence entre le validateur et l'écrivain, pas
    /// une donnée fautive. L'ignorer laisse le champ vide ; l'écrire de force écrirait une
    /// valeur inventée.
    private mutating func set(_ key: String, to value: String, on title: Title) {
        if setScalar(key, to: value, on: title) { return }
        setRelation(key, to: value, on: title)
    }

    /// Écrit un champ de valeur. Rend `false` si la clé n'en est pas un.
    private func setScalar(_ key: String, to value: String, on title: Title) -> Bool {
        if setText(key, to: value, on: title) { return true }
        if setNumber(key, to: value, on: title) { return true }
        return setTyped(key, to: value, on: title)
    }

    /// Le texte libre.
    private func setText(_ key: String, to value: String, on title: Title) -> Bool {
        switch key {
        case "title": title.name = value
        case "original_title": title.originalName = value
        case "summary": title.summary = value
        default: return false
        }
        return true
    }

    /// Les nombres. Une conversion qui échoue laisse le champ tel quel : la ligne a été
    /// validée, donc l'échec serait une incohérence entre le validateur et l'écrivain, pas une
    /// donnée fautive — et écrire de force inventerait une valeur.
    private func setNumber(_ key: String, to value: String, on title: Title) -> Bool {
        switch key {
        case "runtime": title.runtimeMinutes = CSVValueParser.integer(value)
        case "rating": title.rating = CSVValueParser.decimal(value)
        case "season_count": title.seasonCount = CSVValueParser.integer(value)
        case "episode_count": title.episodeCount = CSVValueParser.integer(value)
        default: return false
        }
        return true
    }

    /// Les champs à conversion : booléens, énumération, dates.
    private func setTyped(_ key: String, to value: String, on title: Title) -> Bool {
        switch key {
        case "is_private": title.isPrivate = CSVValueParser.boolean(value) ?? title.isPrivate
        case "is_archived": title.isArchived = CSVValueParser.boolean(value) ?? title.isArchived
        case "kind": setKind(value, on: title)
        case "year": setYear(value, on: title)
        case "release_date": setReleaseDate(value, on: title)
        // `added_at` est délibérément ignoré à l'écriture : `createdAt` dit quand la fiche est
        // entrée **dans ce catalogue**, et le réécrire depuis un fichier étranger mentirait sur
        // l'historique local. La colonne reste exportable, et la relire n'est pas une erreur —
        // c'est le seul champ dont l'aller-retour n'est pas symétrique, et c'est un choix.
        case "added_at": break
        default: return false
        }
        return true
    }

    private func setKind(_ value: String, on title: Title) {
        guard
            let raw = CSVValueParser.enumerated(
                value, allowedValues: TitleKind.allCases.map(\.rawValue)),
            let kind = TitleKind(rawValue: raw)
        else { return }
        title.kind = kind
    }

    /// Une année seule devient le 1er janvier, avec la précision qui le dit.
    ///
    /// Sans `releasePrecision`, l'interface afficherait « 1er janvier 2021 » là où le fichier ne
    /// disait que « 2021 ».
    private func setYear(_ value: String, on title: Title) {
        guard let year = CSVValueParser.year(value), let date = Self.firstDay(of: year) else {
            return
        }
        title.releaseDate = date
        title.releasePrecision = .year
    }

    private func setReleaseDate(_ value: String, on title: Title) {
        guard let date = CSVValueParser.date(value) else { return }
        title.releaseDate = date
        title.releasePrecision = .day
    }

    /// Écrit une relation.
    private mutating func setRelation(_ key: String, to value: String, on title: Title) {
        switch key {
        case "collection": title.collection = resolver.collection(named: value)
        case "genres": attachGenres(value, to: title)
        case "director": attachCredits(value, role: .director, to: title)
        case "cast": attachCredits(value, role: .cast, to: title)
        default: break
        }
    }

    private mutating func attachGenres(_ value: String, to title: Title) {
        let genres = CSVSchema.splitMultiValue(value)
            .compactMap { resolver.genre(named: $0, target: .title) }
        guard !genres.isEmpty else { return }
        title.genres = (title.genres ?? []) + genres
    }

    /// Rattache des personnes à un titre, dans l'ordre du fichier.
    ///
    /// `orderIndex` suit l'ordre de la cellule : c'est l'ordre du générique, et l'export le
    /// relit tel quel. Les personnes sont résolues par le résolveur, donc dédoublonnées contre
    /// l'existant **et** dans le lot.
    private mutating func attachCredits(_ value: String, role: CreditRole, to title: Title) {
        let base = (title.credits ?? []).filter { $0.role == role }.count
        for (offset, name) in CSVSchema.splitMultiValue(value).enumerated() {
            guard let person = resolver.person(named: name) else { continue }
            let credit = Credit(role: role, orderIndex: base + offset)
            credit.person = person
            credit.title = title
            context.insert(credit)
        }
    }

    private func credits(of title: Title, role: CreditRole) -> [Credit] {
        (title.credits ?? []).filter { $0.role == role }
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
