import Foundation

// MARK: - Exporter
//
// Le seul endroit où une entité devient des cellules. La conversion inverse — des cellules
// vers une entité — appartient à `L11b`, et c'est délibérément séparé : l'export lit et
// n'écrit rien, donc il est testable sans magasin ni sauvegarde.
//
// `@MainActor` parce qu'il touche des `@Model`, qui appartiennent au contexte qui les a
// lus et ne sont pas `Sendable`. Aucun coût réel : un export parcourt une collection déjà
// chargée par la vue qui le demande.

/// Convertit des entités en lignes de CSV, selon une sélection de colonnes.
@MainActor
public struct CSVExporter {

    /// Comment écrire les dates. ISO 8601 sans l'heure : c'est ce qu'un tableur reconnaît
    /// comme une date, et c'est trié correctement en texte.
    ///
    /// Volontairement différent de `BulkEditDiff`, qui écrit une date-heure complète en
    /// UTC. Les deux ne servent pas au même public : le diff est relu par du code, un CSV
    /// est relu par un humain dans Excel — lui montrer `1970-06-15T00:00:00Z` dans une
    /// colonne « Naissance » serait du bruit.
    ///
    /// **Fuseau courant, et non UTC.** Un test l'a attrapé : une date de sortie construite
    /// au 15 juin en heure locale s'écrivait `1970-06-14` en UTC. Or `Title.releaseYear`
    /// utilise `Calendar.current`, donc la colonne « Année » est locale : en UTC, les deux
    /// colonnes du **même fichier** se contrediraient, et un titre du 1er janvier
    /// afficherait l'année précédente dans sa date. La cohérence interne du fichier et
    /// l'accord avec ce que l'utilisateur voit dans l'app priment sur l'universalité d'un
    /// fuseau — un CSV est relu par un humain, pas par un serveur.
    static let dateStyle = Date.ISO8601FormatStyle(
        dateSeparator: .dash, timeZone: .current
    ).year().month().day()

    /// Le format des nombres décimaux.
    ///
    /// Point décimal et non virgule, malgré la locale française : une virgule dans une
    /// cellule numérique force la mise entre guillemets, et surtout les deux conventions
    /// coexisteraient dans le même fichier selon la locale de l'exportateur. Un fichier
    /// n'est pas relu par la machine qui l'a écrit.
    static func decimal(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%g", value)
    }

    static func boolean(_ value: Bool) -> String { value ? "oui" : "non" }

    public let writer: CSVWriter

    public init(writer: CSVWriter = CSVWriter()) {
        self.writer = writer
    }

    // MARK: Titres

    /// Les cellules d'un titre, pour les clés demandées et dans leur ordre.
    ///
    /// Une clé inconnue rend une cellule vide plutôt que de décaler les colonnes suivantes :
    /// un fichier décalé est illisible, une cellule vide se voit.
    public func row(for title: Title, keys: [String]) -> [String] {
        keys.map { value(of: title, forKey: $0) }
    }

    public func value(of title: Title, forKey key: String) -> String {
        textValue(of: title, forKey: key) ?? numberValue(of: title, forKey: key) ?? ""
    }

    /// Les champs de texte et les relations. `nil` si la clé n'en est pas un.
    private func textValue(of title: Title, forKey key: String) -> String? {
        switch key {
        case "title": title.name
        case "original_title": title.originalName ?? ""
        case "kind": title.kind.rawValue
        case "summary": title.summary ?? ""
        case "collection": title.collection?.name ?? ""
        case "genres": CSVSchema.joinMultiValue((title.genres ?? []).map(\.name).sorted())
        case "is_private": Self.boolean(title.isPrivate)
        case "is_archived": Self.boolean(title.isArchived)
        default: nil
        }
    }

    /// Les nombres et les dates. `nil` si la clé n'en est pas un.
    private func numberValue(of title: Title, forKey key: String) -> String? {
        switch key {
        case "year": title.releaseYear.map(String.init) ?? ""
        case "release_date": title.releaseDate.map { Self.dateStyle.format($0) } ?? ""
        case "runtime": title.runtimeMinutes.map(String.init) ?? ""
        case "rating": title.rating.map(Self.decimal) ?? ""
        case "season_count": title.seasonCount.map(String.init) ?? ""
        case "episode_count": title.episodeCount.map(String.init) ?? ""
        default: nil
        }
    }

    /// Le fichier complet pour une sélection de titres.
    public func export(titles: [Title], keys: [String]) -> Data {
        writer.data(
            header: CSVSchema.title.header(for: keys),
            rows: titles.map { row(for: $0, keys: keys) }
        )
    }

    // MARK: Personnes

    public func row(for person: Person, keys: [String]) -> [String] {
        keys.map { value(of: person, forKey: $0) }
    }

    public func value(of person: Person, forKey key: String) -> String {
        switch key {
        case "first_name": person.firstName
        case "last_name": person.lastName
        case "roles":
            CSVSchema.joinMultiValue(person.roles.map(\.rawValue).sorted())
        case "birth_date": person.birthDate.map { Self.dateStyle.format($0) } ?? ""
        case "death_date": person.deathDate.map { Self.dateStyle.format($0) } ?? ""
        case "bio": person.bio ?? ""
        case "genres":
            CSVSchema.joinMultiValue((person.genres ?? []).map(\.name).sorted())
        case "is_private": Self.boolean(person.isPrivate)
        case "is_archived": Self.boolean(person.isArchived)
        default: ""
        }
    }

    public func export(people: [Person], keys: [String]) -> Data {
        writer.data(
            header: CSVSchema.person.header(for: keys),
            rows: people.map { row(for: $0, keys: keys) }
        )
    }

    // MARK: Gabarits

    /// Un fichier vierge à remplir dans un tableur.
    public func template(for schema: CSVSchema, keys: [String]? = nil) -> Data {
        let selected = keys ?? schema.defaultExportFields.map(\.key)
        return writer.template(header: schema.header(for: selected))
    }
}
