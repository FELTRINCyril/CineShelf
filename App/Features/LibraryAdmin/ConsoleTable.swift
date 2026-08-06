import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V6 · La table
//
// **Une `Table` SwiftUI, et rien de plus** — c'est exactement ce que le report de « `V6` au-delà
// d'une `Table` brute » laisse en v1 : une table par entité, le tri par colonne, la sélection
// multiple. Les colonnes réordonnables, l'édition en ligne et la mise en forme conditionnelle
// partent en v1.1.
//
// **Deux tables et non une générique.** `Table` tire ses colonnes du type de ses lignes ; une
// version générique demanderait d'effacer le type derrière un protocole, donc de perdre les
// `KeyPathComparator` qui font le tri par colonne. Deux vues courtes valent mieux qu'une
// abstraction qui reprend à la main ce que le compilateur savait faire.

struct ConsoleTable: View {
    let entity: ConsoleEntity
    let scope: PrivacyScope
    let libraryID: UUID?
    let search: String
    @Binding var selection: Set<UUID>

    var body: some View {
        switch entity {
        case .titles:
            TitleConsoleTable(
                scope: scope, libraryID: libraryID, search: search, selection: $selection)
        case .people:
            PersonConsoleTable(
                scope: scope, libraryID: libraryID, search: search, selection: $selection)
        }
    }
}

// MARK: - Les titres — colonnes du bloc `7a`

private struct TitleConsoleTable: View {
    @Query private var titles: [Title]
    @Binding var selection: Set<UUID>
    @State private var order = [KeyPathComparator(\Title.sortName)]

    init(scope: PrivacyScope, libraryID: UUID?, search: String, selection: Binding<Set<UUID>>) {
        _selection = selection
        var filter = TitleFilter()
        filter.searchText = search
        _titles = Query(
            filter: filter.predicate(
                hidingPrivate: scope.hidesPrivateContent, libraryID: libraryID),
            sort: filter.descriptors)
    }

    var body: some View {
        Table(titles.sorted(using: order), selection: $selection, sortOrder: $order) {
            TableColumn("Titre", value: \.sortName) { title in
                Text(title.name).calloutStyle()
            }
            TableColumn("Année", value: \.releaseYearSortKey) { title in
                Text(title.releaseYear.map(String.init) ?? "—").numericStyle()
            }
            TableColumn("Durée", value: \.runtimeSortKey) { title in
                Text(title.runtimeMinutes.map { "\($0) min" } ?? "—").numericStyle()
            }
            TableColumn("Note", value: \.ratingSortKey) { title in
                Text(TitleFormat.ratingText(title.rating) ?? "—").numericStyle()
            }
            TableColumn("Genres") { title in
                Text(TitleFormat.genreNames(of: title).joined(separator: ", "))
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }
            TableColumn("Ajouté", value: \.createdAt) { title in
                Text(title.createdAt.formatted(.dateTime.day().month().year()))
                    .numericStyle()
            }
        }
    }
}

// MARK: - Les personnes

private struct PersonConsoleTable: View {
    @Query private var people: [Person]
    @Binding var selection: Set<UUID>
    @State private var order = [KeyPathComparator(\Person.sortName)]

    init(scope: PrivacyScope, libraryID: UUID?, search: String, selection: Binding<Set<UUID>>) {
        _selection = selection
        var filter = PersonFilter()
        filter.searchText = search
        _people = Query(
            filter: filter.predicate(
                hidingPrivate: scope.hidesPrivateContent, libraryID: libraryID),
            sort: filter.descriptors)
    }

    var body: some View {
        Table(people.sorted(using: order), selection: $selection, sortOrder: $order) {
            TableColumn("Nom", value: \.sortName) { person in
                Text(person.displayName).calloutStyle()
            }
            TableColumn("Rôles") { person in
                Text(PersonFormat.roleLine(of: person) ?? "—")
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }
            TableColumn("Crédits") { person in
                Text(PersonFormat.creditCount(of: person) ?? "—").numericStyle()
            }
            TableColumn("Ajouté", value: \.createdAt) { person in
                Text(person.createdAt.formatted(.dateTime.day().month().year()))
                    .numericStyle()
            }
        }
    }
}

// MARK: - Les clés de tri
//
// **`Table` trie sur des `Comparable` non optionnels.** Un `Int?` ou un `Double?` ne peut pas
// servir de `value:` à une colonne, et une valeur manquante doit se ranger quelque part de
// stable — sinon deux titres sans année s'échangent à chaque tri, et la table scintille.
//
// **Les manquants vont en fin de tri croissant**, pas en tête : « trier par année » et voir en
// premier trois cents titres sans année n'apprend rien. `Int.max` les repousse.

extension Title {
    fileprivate var releaseYearSortKey: Int { releaseYear ?? Int.max }
    fileprivate var runtimeSortKey: Int { runtimeMinutes ?? Int.max }
    fileprivate var ratingSortKey: Double { rating ?? .greatestFiniteMagnitude }
}
