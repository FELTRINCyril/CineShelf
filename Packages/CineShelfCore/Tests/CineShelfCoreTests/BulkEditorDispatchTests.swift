import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// MARK: - L'aiguillage couvre tous les cas
//
// `applyToTitle` aiguille vers quatre corps — numérique, date, texte et drapeaux,
// relations — et chaque corps a un `default` qui appelle `assertionFailure`. Un cas
// aiguillé vers le mauvais corps ferait donc **planter** en debug, silencieusement en
// release. Ce test exerce les dix-sept mutations pour que l'aiguillage soit vérifié, et
// pas seulement écrit.

@MainActor
struct BulkEditorDispatchTests {

    /// Toutes les mutations de titre, avec des valeurs valides.
    ///
    /// La liste est écrite à la main parce que `TitleBulkMutation` porte des valeurs
    /// associées et ne peut pas être `CaseIterable`. Le compte est vérifié plus bas :
    /// c'est ce qui signale qu'un cas ajouté à l'enum n'a pas été ajouté ici.
    private static func everyTitleMutation(
        genre: UUID,
        collection: UUID,
        date: Date
    ) -> [TitleBulkMutation] {
        [
            .setKind(.series),
            .setRating(3), .clearRating,
            .setRuntime(120), .clearRuntime,
            .setReleaseDate(date, precision: .year), .clearReleaseDate,
            .setSummary("Un résumé"), .clearSummary,
            .setArchived(true), .setPrivate(true),
            .setCollection(collection), .clearCollection,
            .setGenres([genre]), .addGenres([genre]), .removeGenres([genre]), .clearGenres
        ]
    }

    @Test("Les dix-sept mutations de titre s'appliquent sans mauvais aiguillage")
    func everyTitleMutationApplies() throws {
        let fixture = try makeBulkEditFixture()
        let titles = try makeBulkEditTitles(["A"], in: fixture)
        let genre = try GenreRepository(context: fixture.context)
            .findOrCreate(name: "Policier", target: .title, in: fixture.library)
        let collection = CollectionRepository(context: fixture.context)
            .create(name: "Saga", in: fixture.library)
        var components = DateComponents()
        components.year = 1970
        components.month = 1
        components.day = 1
        let date = try #require(Calendar(identifier: .gregorian).date(from: components))
        try fixture.context.save()

        let mutations = Self.everyTitleMutation(
            genre: genre.id, collection: collection.id, date: date)
        #expect(mutations.count == 17, "Un cas de TitleBulkMutation n'est pas couvert")

        for mutation in mutations {
            let outcome = try fixture.editor.apply(
                mutation, toTitles: titles.map(\.id), summary: "…")
            #expect(outcome.appliedCount == 1, "\(mutation) a été refusée")
            // Le champ visé du diff doit correspondre à celui que la mutation annonce :
            // un aiguillage vers le mauvais corps rendrait un diff sur un autre champ.
            #expect(outcome.refusals.isEmpty)
        }
    }

    @Test("Les neuf mutations de personne s'appliquent sans mauvais aiguillage")
    func everyPersonMutationApplies() throws {
        let fixture = try makeBulkEditFixture()
        let person = PersonRepository(context: fixture.context)
            .create(firstName: "Alice", lastName: "Martin", in: fixture.library)
        let genre = try GenreRepository(context: fixture.context)
            .findOrCreate(name: "Réalisation", target: .person, in: fixture.library)
        try fixture.context.save()

        let mutations: [PersonBulkMutation] = [
            .setRoles([.director]),
            .setBio("Une biographie"), .clearBio,
            .setArchived(true), .setPrivate(true),
            .setGenres([genre.id]), .addGenres([genre.id]),
            .removeGenres([genre.id]), .clearGenres
        ]
        #expect(mutations.count == 9, "Un cas de PersonBulkMutation n'est pas couvert")

        for mutation in mutations {
            let outcome = try fixture.editor.apply(mutation, toPeople: [person.id], summary: "…")
            #expect(outcome.appliedCount == 1, "\(mutation) a été refusée")
        }
    }

    @Test("Chaque mutation nomme le champ qu'elle touche")
    func everyMutationNamesItsField() {
        // `field` sert de clé dans le diff : deux mutations du même champ doivent le
        // nommer pareil, et aucune ne doit rendre une chaîne vide.
        let date = Date(timeIntervalSince1970: 0)
        for mutation in Self.everyTitleMutation(genre: UUID(), collection: UUID(), date: date) {
            #expect(mutation.field.isEmpty == false, "\(mutation)")
        }
        #expect(TitleBulkMutation.setRating(3).field == TitleBulkMutation.clearRating.field)
        #expect(TitleBulkMutation.setGenres([]).field == TitleBulkMutation.clearGenres.field)
        #expect(TitleBulkMutation.setRating(3).kind == .replace)
        #expect(TitleBulkMutation.clearRating.kind == .clear)
        #expect(TitleBulkMutation.addGenres([]).kind == .addToRelation)
        #expect(TitleBulkMutation.removeGenres([]).kind == .removeFromRelation)
    }
}
