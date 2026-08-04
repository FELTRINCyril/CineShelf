import Foundation
import SwiftData

// MARK: - Les champs d'un titre, un par un
//
// Séparé de `ImportWriter` parce que ce sont deux sujets : là-bas, la décision — créer,
// compléter, ne rien faire ; ici, la correspondance entre une clé de colonne et une propriété du
// modèle. Le fichier avait dépassé les 500 lignes du lint, et la coupe naturelle est celle-là.
//
// **Le compilateur ne garde rien dans ces `switch`** : la clé est une `String`, donc une colonne
// ajoutée au schéma tombe dans le `default` — jamais écrite sur un titre neuf, jamais complétée
// sur un doublon, et sans aucun signal. Le filet est
// `ImportDerivedValuesTests.everySchemaFieldIsHandledByTheWriter`, qui compare `handledKeys` au
// schéma.

extension ImportWriter {

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
    func isEmpty(_ key: String, on title: Title) -> Bool {
        scalarIsEmpty(key, on: title) ?? relationIsEmpty(key, on: title)
    }

    /// Les champs qui portent une valeur. `nil` si la clé n'en est pas un.
    func scalarIsEmpty(_ key: String, on title: Title) -> Bool? {
        if let text = textIsEmpty(key, on: title) { return text }
        return switch key {
        case "year", "release_date": title.releaseDate == nil
        case "runtime": title.runtimeMinutes == nil
        case "rating": title.rating == nil
        case "season_count": title.seasonCount == nil
        case "episode_count": title.episodeCount == nil
        // Un titre public est « vide » du point de vue du privé : c'est ce qui permet à une
        // ligne « Privé = oui » d'atteindre un doublon.
        //
        // **La monotonie est gardée deux fois, et aucune des deux n'est du code mort.** Ici, en
        // refusant d'atteindre un titre déjà privé ; et dans `setTyped`, qui ne sait que
        // *rendre* privé. Vérifié : casser **une seule** des deux laisse la propriété tenir, donc
        // les tests restent verts — c'est en cassant les deux que le test mord. Quiconque
        // simplifie l'une en la croyant redondante doit savoir qu'il retire un filet, pas un
        // doublon.
        case "is_private": title.isPrivate == false
        // `kindRaw`, `createdAt` et l'archivage ont toujours une valeur : ils ne sont jamais
        // « vides », donc un doublon ne les complète pas.
        case "kind", "added_at", "is_archived": false
        default: nil
        }
    }

    /// Les champs de texte. `nil` si la clé n'en est pas un.
    func textIsEmpty(_ key: String, on title: Title) -> Bool? {
        switch key {
        case "title": title.name.isEmpty
        case "original_title": title.originalName?.isEmpty ?? true
        case "summary": title.summary?.isEmpty ?? true
        default: nil
        }
    }

    /// Les champs qui portent une relation.
    func relationIsEmpty(_ key: String, on title: Title) -> Bool {
        switch key {
        case "collection": title.collection == nil
        case "genres": (title.genres ?? []).isEmpty
        case "director": credits(of: title, role: .director).isEmpty
        case "cast": credits(of: title, role: .cast).isEmpty
        default: false
        }
    }

    /// La valeur actuelle d'un champ, en texte, pour le diff d'annulation.
    func currentValue(_ key: String, on title: Title) -> String? {
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
    mutating func set(_ key: String, to value: String, on title: Title) {
        if setScalar(key, to: value, on: title) { return }
        setRelation(key, to: value, on: title)
    }

    /// Écrit un champ de valeur. Rend `false` si la clé n'en est pas un.
    func setScalar(_ key: String, to value: String, on title: Title) -> Bool {
        if setText(key, to: value, on: title) { return true }
        if setNumber(key, to: value, on: title) { return true }
        return setTyped(key, to: value, on: title)
    }

    /// Le texte libre.
    func setText(_ key: String, to value: String, on title: Title) -> Bool {
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
    func setNumber(_ key: String, to value: String, on title: Title) -> Bool {
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
    func setTyped(_ key: String, to value: String, on title: Title) -> Bool {
        switch key {
        // **Le privé est monotone : un fichier peut rendre privé, jamais rendre public.**
        // Le cas est arrivé de la revue : un doublon existant public, une ligne « Privé = oui »,
        // et la règle « ne jamais écraser » faisait ignorer la demande — le titre restait public
        // *et* était réindexé dans Spotlight. Entre les deux erreurs possibles, celle qui expose
        // un contenu que l'utilisateur a marqué privé est la seule qui ne se répare pas : c'est la
        // fuite que `L3` a fermée, et l'index système est unique pour l'appareil.
        //
        // Dans l'autre sens, un fichier ne peut pas rendre public ce qui est privé : ce serait une
        // dégradation, et « ne jamais écraser » s'applique pleinement.
        case "is_private": title.isPrivate = title.isPrivate || (CSVValueParser.boolean(value) ?? false)
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

    func setKind(_ value: String, on title: Title) {
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
    ///
    /// **Une date complète dans cette colonne garde son jour.** L'aide du champ le promet — « une
    /// date complète est acceptée » — et `CSVValueParser.year` l'accepte, donc la validation
    /// laissait passer `2021-10-15`. L'écrivain, lui, n'en gardait que l'année : le jour et le
    /// mois étaient jetés **en silence**, sur une cellule que rien ne refusait. C'est exactement
    /// ce que l'en-tête de `CSVValueParser` interdit.
    func setYear(_ value: String, on title: Title) {
        if let exact = CSVValueParser.date(value) {
            title.releaseDate = exact
            title.releasePrecision = .day
            return
        }
        guard let year = CSVValueParser.year(value), let date = Self.firstDay(of: year) else {
            return
        }
        title.releaseDate = date
        title.releasePrecision = .year
    }

    func setReleaseDate(_ value: String, on title: Title) {
        guard let date = CSVValueParser.date(value) else { return }
        title.releaseDate = date
        title.releasePrecision = .day
    }

    /// Écrit une relation.
    mutating func setRelation(_ key: String, to value: String, on title: Title) {
        switch key {
        case "collection": title.collection = resolver.collection(named: value)
        case "genres": attachGenres(value, to: title)
        case "director": attachCredits(value, role: .director, to: title)
        case "cast": attachCredits(value, role: .cast, to: title)
        default: break
        }
    }

    mutating func attachGenres(_ value: String, to title: Title) {
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
    mutating func attachCredits(_ value: String, role: CreditRole, to title: Title) {
        // **Les doublons de la cellule sont écartés, et les oublier écrivait deux crédits.**
        // Mesuré : « Denis Villeneuve/denis villeneuve » créait *une* personne — le résolveur fait
        // son travail — et *deux* `Credit` vers elle, avec deux `orderIndex`. La fiche montrait le
        // même acteur deux fois, et rien d'autre ne le signalait. Le côté genres était couvert par
        // un test ; l'entrée équivalente sur la colonne voisine n'avait pas été essayée.
        //
        // Les personnes déjà créditées de ce rôle sur ce titre comptent aussi : c'est ce qui
        // permet à un second import d'ajouter un acteur manquant sans redoubler les autres.
        var seen = Set((title.credits ?? []).filter { $0.role == role }.compactMap(\.person?.id))
        var nextIndex = seen.count

        for name in CSVSchema.splitMultiValue(value) {
            guard let person = resolver.person(named: name), seen.insert(person.id).inserted else {
                continue
            }
            let credit = Credit(role: role, orderIndex: nextIndex)
            credit.person = person
            credit.title = title
            context.insert(credit)
            nextIndex += 1
        }
    }

    func credits(of title: Title, role: CreditRole) -> [Credit] {
        (title.credits ?? []).filter { $0.role == role }
    }

}
