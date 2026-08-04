import Foundation

// MARK: - Déduire à quel champ va chaque colonne
//
// Trois passes, dans cet ordre, et l'ordre **est** la garantie de reproductibilité :
//
//   1. le nom de colonne est l'en-tête ou la clé du champ            -> sûre
//   2. le nom de colonne est un alias déclaré du champ               -> déduite
//   3. le contenu des premières valeurs a la forme d'un seul champ   -> déduite
//                                                                      sinon non reconnue
//
// **Un champ n'est réclamé qu'une fois.** Sans cette règle, un fichier portant `year` et
// `annee` alimenterait deux fois l'année et personne ne saurait laquelle a gagné. La passe
// la plus sûre prend, les suivantes se rabattent sur ce qui reste — et à qualité égale,
// c'est la colonne la plus à gauche, parce qu'un résultat qui dépend de l'ordre des clés
// d'un dictionnaire n'est pas reproductible.
//
// **Aucune écriture, aucun magasin.** C'est l'étape 1 de l'import, dont la planche 11d
// affirme « Aucune donnée n'est écrite à cette étape ».

/// Ce qu'une passe de correspondance a produit.
public struct ColumnAnalysis: Sendable, Hashable {

    /// L'entité visée.
    public let entity: ActivityEntityType
    /// Un rapprochement par colonne du fichier, dans l'ordre du fichier.
    public let matches: [ColumnMatch]
    /// Les champs requis qu'aucune colonne n'alimente.
    ///
    /// La quatrième statistique de la planche 11d, « champ requis sans colonne ». C'est le
    /// seul cas où l'étape 1 doit **bloquer** : sans titre, aucune ligne ne peut créer quoi
    /// que ce soit, et l'aperçu ne dirait que « 1 284 lignes en erreur ».
    public let missingRequiredFieldKeys: [String]

    public init(entity: ActivityEntityType, matches: [ColumnMatch], missingRequiredFieldKeys: [String]) {
        self.entity = entity
        self.matches = matches
        self.missingRequiredFieldKeys = missingRequiredFieldKeys
    }

    public func matches(quality: ColumnMatchQuality) -> [ColumnMatch] {
        matches.filter { $0.quality == quality }
    }

    /// Les noms des colonnes qu'aucun champ ne réclame.
    ///
    /// **Le rapport les nomme**, et c'est une exigence explicite de la fiche : c'est la
    /// contrepartie de l'abandon des champs libres. Une colonne « notes_perso » qui
    /// disparaîtrait en silence ferait croire à un import complet.
    public var ignoredColumnNames: [String] {
        matches(quality: .unrecognized).map(\.columnName)
    }

    /// Vrai si l'étape 1 peut passer à l'aperçu.
    public var canProceed: Bool { missingRequiredFieldKeys.isEmpty }

    /// La correspondance à mémoriser, telle quelle.
    public var mapping: ColumnMapping {
        ColumnMapping(entity: entity, matches: matches)
    }

    /// La même analyse, une colonne réaffectée à la main.
    ///
    /// Ce que fait le menu de la planche 11d. Une réaffectation est **sûre** par
    /// construction : l'utilisateur ne déduit pas, il décide. Le champ est libéré de la
    /// colonne qui le tenait, sinon deux colonnes l'alimenteraient.
    public func assigning(fieldKey: String?, toColumnAt index: Int) -> ColumnAnalysis {
        let updated = matches.map { match -> ColumnMatch in
            if match.columnIndex == index {
                return ColumnMatch(
                    columnIndex: index,
                    columnName: match.columnName,
                    fieldKey: fieldKey,
                    quality: fieldKey == nil ? .unrecognized : .certain,
                    rationale: fieldKey == nil ? nil : "Choisie à la main."
                )
            }
            guard let key = fieldKey, match.fieldKey == key else { return match }
            return ColumnMatch(
                columnIndex: match.columnIndex,
                columnName: match.columnName,
                fieldKey: nil,
                quality: .unrecognized,
                rationale: nil
            )
        }
        let taken = Set(updated.compactMap(\.fieldKey))
        let missing =
            CSVSchema.schema(for: entity)?.requiredFields
            .map(\.key)
            .filter { !taken.contains($0) } ?? []
        return ColumnAnalysis(entity: entity, matches: updated, missingRequiredFieldKeys: missing)
    }
}

/// Rapproche les colonnes d'un fichier des champs d'un schéma.
public struct ColumnMatcher: Sendable {

    /// Combien de valeurs sont regardées pour déduire du contenu.
    ///
    /// Trois, comme la planche 11d qui montre « Trois premières valeurs ». Assez pour
    /// distinguer une année d'une durée, et assez peu pour que l'écran montre exactement ce
    /// sur quoi la déduction s'est faite — une déduction qu'on ne peut pas vérifier d'un
    /// coup d'œil est pire qu'une colonne laissée non reconnue.
    public static let sampleSize = 3

    public let schema: CSVSchema

    public init(schema: CSVSchema) {
        self.schema = schema
    }

    /// Rapproche un en-tête, éclairé par les premières lignes du fichier.
    ///
    /// - Parameters:
    ///   - header: les noms de colonnes, dans l'ordre du fichier.
    ///   - rows: les premières lignes de données. Vides, seules les deux passes par le nom
    ///     jouent — c'est le cas d'un fichier qui n'a que son en-tête, et ce n'est pas une
    ///     erreur.
    /// - Returns: un rapprochement par colonne, plus les champs requis sans colonne.
    public func analyze(header: [String], rows: [CSVRow] = []) -> ColumnAnalysis {
        let samples = self.samples(from: rows, columnCount: header.count)
        var claimed: Set<String> = []
        var results = [ColumnMatch?](repeating: nil, count: header.count)

        for pass in Pass.allCases {
            for (index, name) in header.enumerated() where results[index] == nil {
                guard
                    let found = candidate(
                        for: name, at: index, pass: pass, samples: samples, excluding: claimed)
                else { continue }
                claimed.insert(found.key)
                results[index] = ColumnMatch(
                    columnIndex: index,
                    columnName: name,
                    fieldKey: found.key,
                    quality: pass.quality,
                    rationale: found.rationale
                )
            }
        }

        let matches = results.enumerated().map { index, match in
            match
                ?? ColumnMatch(
                    columnIndex: index,
                    columnName: header[index],
                    fieldKey: nil,
                    quality: .unrecognized
                )
        }
        return ColumnAnalysis(
            entity: schema.entity,
            matches: matches,
            missingRequiredFieldKeys: schema.requiredFields.map(\.key).filter { !claimed.contains($0) }
        )
    }

    // MARK: Les passes

    private enum Pass: CaseIterable {
        case exactName
        case alias
        case content

        var quality: ColumnMatchQuality {
            switch self {
            case .exactName: .certain
            case .alias, .content: .inferred
            }
        }
    }

    private func candidate(
        for columnName: String,
        at index: Int,
        pass: Pass,
        samples: [[String]],
        excluding claimed: Set<String>
    ) -> (key: String, rationale: String?)? {
        let available = schema.fields.filter { !claimed.contains($0.key) }
        let folded = columnName.foldedForMatching.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folded.isEmpty else { return nil }

        switch pass {
        case .exactName:
            let field = available.first {
                $0.header.foldedForMatching == folded || $0.key.foldedForMatching == folded
            }
            return field.map { ($0.key, nil) }

        case .alias:
            let field = available.first { field in
                field.aliases.contains { $0.foldedForMatching == folded }
            }
            return field.map { ($0.key, "Nom de colonne reconnu : « \(columnName) ».") }

        case .content:
            guard index < samples.count else { return nil }
            return contentCandidate(from: samples[index], among: available)
        }
    }

    /// La déduction par le contenu, et sa règle d'abstention.
    ///
    /// Une forme ne désigne un champ que si **un seul** champ disponible la porte. Trois
    /// dates dans une colonne sans nom reconnaissable pourraient être une date de sortie
    /// comme une date d'ajout : deviner, ce serait écrire la mauvaise. La colonne reste alors
    /// non reconnue, ce qui n'est pas une erreur et se corrige d'un menu.
    private func contentCandidate(
        from values: [String],
        among available: [CSVField]
    ) -> (key: String, rationale: String?)? {
        let usable = values.filter { !$0.isBlank }
        guard !usable.isEmpty else { return nil }
        guard let shape = CSVValueSniffer.shape(of: usable) else { return nil }

        let candidates = available.filter { $0.shape == shape }
        guard candidates.count == 1, let field = candidates.first else { return nil }
        return (field.key, "Déduite du contenu : « \(usable.joined(separator: " · ")) ».")
    }

    /// Les premières valeurs de chaque colonne, colonne par colonne.
    ///
    /// Les lignes mal découpées sont écartées de l'échantillon : leurs champs sont décalés,
    /// donc une valeur y appartient à une autre colonne que celle qu'on croit — déduire
    /// là-dessus, c'est déduire sur du bruit. Elles restent dans l'aperçu, elles ne servent
    /// simplement pas à décider.
    private func samples(from rows: [CSVRow], columnCount: Int) -> [[String]] {
        var columns = [[String]](repeating: [], count: columnCount)
        for row in rows where !row.isMalformed {
            for index in 0..<columnCount where index < row.fields.count {
                guard columns[index].count < Self.sampleSize else { continue }
                columns[index].append(row.fields[index])
            }
            if columns.allSatisfy({ $0.count >= Self.sampleSize }) { break }
        }
        return columns
    }
}

// MARK: - Reconnaître une forme dans des valeurs

/// Devine la forme commune d'un échantillon de cellules.
///
/// Séparé du matcher pour être testable seul, et pour que la même reconnaissance serve
/// ailleurs si le besoin vient. Aucune valeur ne « ressemble » à du texte : `.text` n'est
/// jamais rendu, sinon toute colonne inconnue tomberait dans le premier champ textuel libre.
public enum CSVValueSniffer {

    /// La forme que **toutes** les valeurs partagent, ou `nil` si elles n'en partagent pas.
    ///
    /// L'ordre d'essai va du plus spécifique au plus large : une année est aussi un entier,
    /// et un entier est aussi un nombre décimal. Tester l'année d'abord évite qu'une colonne
    /// d'années soit prise pour une durée.
    public static func shape(of values: [String]) -> CSVValueShape? {
        let trimmed = values.map { $0.trimmingCharacters(in: .whitespaces) }
        if trimmed.allSatisfy(isYear) { return .year }
        if trimmed.allSatisfy(isBoolean) { return .boolean }
        if trimmed.allSatisfy(isDate) { return .date }
        if trimmed.allSatisfy(isMultiValue) { return .multiValue }
        if trimmed.allSatisfy(isInteger) { return .integer }
        if trimmed.allSatisfy(isDecimal) { return .decimal }
        return nil
    }

    static func isYear(_ value: String) -> Bool {
        guard value.count == 4, let number = Int(value) else { return false }
        return CatalogBounds.years.contains(number)
    }

    static func isBoolean(_ value: String) -> Bool {
        CSVValueParser.boolean(value) != nil
    }

    static func isDate(_ value: String) -> Bool {
        CSVValueParser.date(value) != nil
    }

    /// Une cellule multivaleur se reconnaît à son séparateur, pas à son contenu.
    ///
    /// Exiger le séparateur **dans toutes** les valeurs de l'échantillon : un seul titre
    /// contenant une barre oblique ne fait pas de la colonne des titres une liste de genres.
    static func isMultiValue(_ value: String) -> Bool {
        value.contains(CSVSchema.multiValueSeparator)
            && CSVSchema.splitMultiValue(value).count > 1
    }

    static func isInteger(_ value: String) -> Bool {
        Int(value) != nil
    }

    static func isDecimal(_ value: String) -> Bool {
        CSVValueParser.decimal(value) != nil
    }
}
