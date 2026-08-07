import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// MARK: - L16 · La corbeille : lister, restaurer
//
// **Scindé de `MaintenanceTests` le 2026-08-07**, quand les tests ajoutés après la revue
// adverse ont fait dépasser les 500 lignes au fichier d'origine. La coupe suit celle du code :
// `MaintenanceService` supprime, `TrashService` liste et restaure.
//
// **Les sources font foi dans `MaintenanceTests`**, en tête de fichier. L'instant de référence
// et l'aide `trashed(daysAgo:)` y vivent aussi : un second instant de référence, ailleurs,
// finirait par diverger du premier.

// MARK: - La corbeille

@MainActor
struct TrashServiceTests {

    /// Le compte à rebours, sur des instants quelconques.
    ///
    /// **Ni minuit, ni un compte rond.** Supprimé il y a 12 jours à 22 h 13 : il reste 18 jours.
    @Test("Le compte à rebours part de trente jours et décroît par jour de calendrier")
    func daysRemainingCountsCalendarDays() throws {
        let deletedAt = MaintenanceTests.trashed(daysAgo: 12)
        let remaining = TrashService.daysRemaining(from: deletedAt, now: MaintenanceTests.reference)
        #expect(remaining == 18)
    }

    /// **Un élément expiré affiche un compte négatif plutôt que zéro.**
    ///
    /// Il n'est supprimé qu'au prochain passage de la maintenance : dire « 0 jour » ferait croire
    /// à un sursis qui n'existe pas, et `max(0, …)` masquerait le fait qu'une purge est en
    /// retard.
    @Test("Un élément expiré porte un compte négatif, pas zéro")
    func expiredItemShowsNegativeCount() throws {
        let deletedAt = MaintenanceTests.trashed(daysAgo: 37)
        let remaining = TrashService.daysRemaining(from: deletedAt, now: MaintenanceTests.reference)
        #expect(remaining == -7)
    }

    @Test("La corbeille liste les entités de tous les types, la plus récente d'abord")
    func trashListsEveryType() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)
        let collections = CollectionRepository(context: context)

        let dune = titles.create(name: "Dune", in: library)
        let villeneuve = people.create(
            firstName: "Denis", lastName: "Villeneuve", roles: [.director], in: library)
        let saga = collections.create(name: "Villeneuve", in: library)
        titles.softDelete(dune)
        people.softDelete(villeneuve)
        collections.softDelete(saga)
        // Des dates distinctes et non ordonnées comme les insertions : sinon le tri passerait
        // par chance.
        dune.deletedAt = MaintenanceTests.trashed(daysAgo: 5)
        villeneuve.deletedAt = MaintenanceTests.trashed(daysAgo: 2)
        saga.deletedAt = MaintenanceTests.trashed(daysAgo: 9)
        try context.save()

        let items = try TrashService(context: context).items(now: MaintenanceTests.reference)

        #expect(items.count == 3)
        #expect(items.map(\.label) == ["Denis Villeneuve", "Dune", "Villeneuve"])
        #expect(items.map(\.entity) == [.person, .title, .collection])
        #expect(items.first?.daysRemaining == 28)
    }

    /// **Une entité vivante n'est jamais dans la corbeille.** Le contrôle négatif de la liste.
    @Test("Une entité vivante n'apparaît pas dans la corbeille")
    func liveEntitiesAreNotListed() throws {
        let (context, library) = try makeTestLibrary()
        _ = TitleRepository(context: context).create(name: "Vivant", in: library)
        try context.save()

        #expect(try TrashService(context: context).items(now: MaintenanceTests.reference).isEmpty)
    }

    /// **La restauration passe par le repository, donc elle réindexe et elle journalise.**
    ///
    /// `L3` l'exige : une entité restaurée qui reste hors de l'index Spotlight est introuvable
    /// par la recherche système, et rien ne le signale. Poser `deletedAt = nil` à la main aurait
    /// l'air de marcher.
    @Test("Restaurer depuis la corbeille ramène l'entité, ses relations et son entrée de journal")
    func restoreBringsBackRelations() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)
        let genres = GenreRepository(context: context)

        let dune = titles.create(name: "Dune", in: library)
        let villeneuve = people.create(
            firstName: "Denis", lastName: "Villeneuve", roles: [.director], in: library)
        titles.addCredit(person: villeneuve, role: .director, to: dune)
        let sf = try genres.findOrCreate(name: "Science-fiction", target: .title, in: library)
        titles.setGenres([sf], on: dune, journal: .perEntity)
        try context.save()

        titles.softDelete(dune)
        dune.deletedAt = MaintenanceTests.trashed(daysAgo: 4)
        try context.save()

        let trash = TrashService(context: context)
        let item = try #require(
            trash.items(now: MaintenanceTests.reference).first { $0.entity == .title })
        #expect(try trash.restore(item))
        try context.save()

        #expect(dune.deletedAt == nil)
        #expect(dune.credits?.count == 1)
        #expect(dune.genres?.count == 1)
        // Et la corbeille est vide : la restauration l'a bien retirée de la liste.
        #expect(try trash.items(now: MaintenanceTests.reference).isEmpty)

        let entries = try context.fetch(FetchDescriptor<ActivityEntry>())
        #expect(entries.contains { $0.action == .restore }, "La restauration doit être journalisée")
    }

    /// **Les six types, listés et restaurés.** La revue a relevé que le test « tous les types »
    /// n'en couvrait que trois : `Genre`, `SavedLink` et `MediaAsset` n'apparaissaient nulle
    /// part, et `restoreSecondary` n'avait aucun appelant de test — une branche entière de la
    /// restauration était écrite sans être exercée.
    @Test("Les six types à corbeille se listent et se restaurent")
    func everyTrashableTypeRoundTrips() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)
        let collections = CollectionRepository(context: context)
        let genres = GenreRepository(context: context)
        let links = SavedLinkRepository(context: context)
        let media = MediaRepository(context: context)

        let title = titles.create(name: "Dune", in: library)
        let person = people.create(
            firstName: "Denis", lastName: "Villeneuve", roles: [.director], in: library)
        let collection = collections.create(name: "Villeneuve", in: library)
        let genre = try genres.findOrCreate(name: "Science-fiction", target: .title, in: library)
        let link = links.create(urlString: "https://example.org/dune", in: library)
        let asset = media.create(MediaAssetDraft(byteSize: 1_024, checksum: "aff"))
        titles.softDelete(title)
        people.softDelete(person)
        collections.softDelete(collection)
        genres.softDelete(genre)
        links.softDelete(link)
        media.softDelete(asset)
        try context.save()

        let trash = TrashService(context: context)
        let items = try trash.items(now: MaintenanceTests.reference)
        #expect(items.count == 6)
        #expect(
            Set(items.map(\.entity)) == [.title, .person, .collection, .genre, .savedLink, .media])

        for item in items {
            #expect(try trash.restore(item), "\(item.entity.rawValue) doit se restaurer")
        }
        try context.save()

        #expect(try trash.items(now: MaintenanceTests.reference).isEmpty)
        #expect(title.deletedAt == nil)
        #expect(genre.deletedAt == nil)
        #expect(link.deletedAt == nil)
        #expect(asset.deletedAt == nil)
    }

    /// **Les six types se purgent, pas seulement les deux qui avaient un test.**
    ///
    /// La branche `MediaAsset` est celle qui compte le plus ici : c'est la seule qui supprime
    /// des attachements appartenant à des entités **vivantes**, par cascade.
    @Test("Les six types à corbeille se purgent une fois expirés")
    func everyTrashableTypeIsPurged() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)
        let collections = CollectionRepository(context: context)
        let genres = GenreRepository(context: context)
        let links = SavedLinkRepository(context: context)
        let media = MediaRepository(context: context)

        // Un titre VIVANT porte l'affiche purgée : c'est lui qui montre que la cascade
        // s'applique à un attachement dont le propriétaire n'est pas concerné.
        let survivor = titles.create(name: "Vivant", in: library)
        let asset = media.create(MediaAssetDraft(byteSize: 512, checksum: "purge"))
        media.attach(asset, to: survivor, slot: .primary)

        let title = titles.create(name: "Dune", in: library)
        let person = people.create(firstName: "Denis", lastName: "V", roles: [.director], in: library)
        let collection = collections.create(name: "Saga", in: library)
        let genre = try genres.findOrCreate(name: "Science-fiction", target: .title, in: library)
        let link = links.create(urlString: "https://example.org/x", in: library)
        title.deletedAt = MaintenanceTests.trashed(daysAgo: 40)
        person.deletedAt = MaintenanceTests.trashed(daysAgo: 40)
        collection.deletedAt = MaintenanceTests.trashed(daysAgo: 40)
        genre.deletedAt = MaintenanceTests.trashed(daysAgo: 40)
        link.deletedAt = MaintenanceTests.trashed(daysAgo: 40)
        asset.deletedAt = MaintenanceTests.trashed(daysAgo: 40)
        try context.save()

        let report = try MaintenanceService(context: context).run(now: MaintenanceTests.reference)

        #expect(report.purgedByEntity["title"] == 1)
        #expect(report.purgedByEntity["person"] == 1)
        #expect(report.purgedByEntity["collection"] == 1)
        #expect(report.purgedByEntity["genre"] == 1)
        #expect(report.purgedByEntity["savedLink"] == 1)
        #expect(report.purgedByEntity["mediaAsset"] == 1)
        // Le titre vivant survit, et son attachement est parti avec le média par cascade.
        #expect(try context.fetchCount(FetchDescriptor<Title>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<MediaAttachment>()) == 0)
    }

    /// **Purger un genre laisse une clé morte dans `filterKeys` des titres vivants.**
    ///
    /// `Genre.titles` est en `nullify` : la relation part, mais le dérivé reste — et plus aucune
    /// écriture ne touchera ce titre, donc la clé morte y est pour toujours. C'est la règle
    /// « `refreshDerived()` à chaque écriture » appliquée aux mutations **indirectes**, qui sont
    /// celles qu'on oublie. Relevé par la revue adverse.
    @Test("Purger un genre rafraîchit les dérivés des titres qui le portaient")
    func purgingGenreRefreshesLiveTitles() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let genres = GenreRepository(context: context)

        let dune = titles.create(name: "Dune", in: library)
        let sf = try genres.findOrCreate(name: "Science-fiction", target: .title, in: library)
        titles.setGenres([sf], on: dune, journal: .perEntity)
        try context.save()
        #expect(dune.filterKeys.contains(FilterKey.genre(sf.id)))

        genres.softDelete(sf)
        sf.deletedAt = MaintenanceTests.trashed(daysAgo: 40)
        try context.save()

        try MaintenanceService(context: context).run(now: MaintenanceTests.reference)

        #expect(dune.deletedAt == nil, "Le titre survit à la purge de son genre")
        #expect(
            !dune.filterKeys.contains(FilterKey.genre(sf.id)),
            "La clé du genre purgé ne doit plus être dans les dérivés : \(dune.filterKeys)")
    }

    /// **La couture de restauration, jouée de bout en bout et relue depuis un contexte neuf.**
    ///
    /// Elle était inscrite comme non couverte, et le bilan des coutures exercées est sans
    /// exception : `MediaFill`, `PosterCardModel(_ person:)`, le séparateur multivaleur (6 pertes
    /// sur 13 entrées) et le `CRLF` de `CSVWriter` — quatre jouées, quatre défauts. Celle-ci
    /// **dé-supprime** des données, donc elle mérite le même traitement.
    ///
    /// **Ce que ce test fait que les autres ne font pas : il relit depuis un `ModelContext`
    /// neuf.** Vérifier `dune.credits` sur l'objet qu'on vient de restaurer ne prouve rien —
    /// il est encore en mémoire, ses relations aussi. C'est la même raison qui impose de passer
    /// un `#Predicate` par le magasin.
    ///
    /// Et il assène **ce qui est revenu**, pas seulement que `deletedAt` est `nil` : c'était
    /// toute la raison d'exister de la suppression douce. Un titre restauré sans ses crédits,
    /// ses genres ou son affiche serait une restauration de nom.
    ///
    /// Mesuré par une sonde hors dépôt le 2026-08-07 : **13 vérifications, aucune perte**. C'est
    /// la première couture jouée dans ce dépôt qui ne trouve pas de défaut, et le test reste
    /// pour que ça continue.
    @Test("Un titre restauré revient avec ses crédits, ses genres, ses médias et ses liens")
    func restorationBringsEverythingBack() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let library = Library(name: "Principal", isDefault: true)
        context.insert(library)
        let profile = Profile(name: "Sonde", isDefault: true)
        profile.library = library
        context.insert(profile)
        try context.save()

        let titles = TitleRepository(context: context)
        let (dune, voisin) = try Self.populateRichTitle(in: context, library: library, profile: profile)
        let duneID = dune.id
        let filterKeysBefore = dune.filterKeys

        titles.softDelete(dune)
        try context.save()

        // Le parcours de l'écran : la corbeille le voit, on clique, il revient.
        let trash = TrashService(context: context)
        let entry = try #require(
            trash.items(now: MaintenanceTests.reference).first { $0.entity == .title })
        #expect(entry.label == "Dune")
        #expect(try trash.restore(entry))
        try context.save()
        #expect(try trash.items(now: MaintenanceTests.reference).isEmpty)

        // **Relecture depuis un contexte neuf** : c'est le magasin qu'on interroge, pas la
        // mémoire.
        let fresh = ModelContext(container)
        let relu = try #require(
            fresh.fetch(FetchDescriptor<Title>()).first { $0.id == duneID })

        #expect(relu.deletedAt == nil)
        #expect(relu.credits?.count == 3)
        #expect(relu.genres?.count == 2)
        #expect(relu.attachments?.count == 2)
        #expect(relu.links?.count == 1)
        #expect(relu.collection?.name == "Saga Dune")
        #expect(relu.filterKeys == filterKeysBefore, "Les dérivés doivent revenir identiques")

        // Le détail qui décide de l'affichage : aucun crédit décapité, et les noms de
        // personnage sont là. Un compte seul ne dirait pas que les arêtes pointent encore.
        #expect((relu.credits ?? []).allSatisfy { $0.person != nil })
        #expect((relu.credits ?? []).contains { $0.characterName == "Paul Atreides" })
        let freshProfile = try #require(fresh.fetch(FetchDescriptor<Profile>()).first)
        let flag = FlagRepository(context: fresh, profile: freshProfile).flag(for: relu)
        #expect(flag?.isFavorite == true, "Le drapeau personnel survit à l'aller-retour")

        // Le voisin, et le compte global : rien d'autre n'a bougé.
        #expect(try fresh.fetchCount(FetchDescriptor<Title>()) == 2)
        let reluVoisin = try #require(
            fresh.fetch(FetchDescriptor<Title>()).first { $0.id == voisin.id })
        #expect(reluVoisin.deletedAt == nil)

        // **Et l'entretien qui suit le redémarrage ne casse rien.** C'est le vrai scénario :
        // l'app relance, `MaintenanceService` tourne, et il ne doit rien trouver à réparer sur
        // un titre qu'on vient de restaurer.
        let report = try MaintenanceService(context: fresh).run(now: MaintenanceTests.reference)
        #expect(report.isEmpty, "L'entretien ne doit rien trouver : \(report)")
        #expect(try fresh.fetchCount(FetchDescriptor<Credit>()) == 3)
        #expect(try fresh.fetchCount(FetchDescriptor<MediaAttachment>()) == 2)
    }

    /// Le décor du test de couture : un titre **riche**, et un voisin témoin.
    ///
    /// Extrait du test pour tenir sous la limite de longueur de corps, et la coupe est celle qui
    /// a un sens : monter le décor n'est pas le sujet, c'est ce qui permet de l'exercer.
    static func populateRichTitle(
        in context: ModelContext, library: Library, profile: Profile
    ) throws -> (dune: Title, voisin: Title) {
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)
        let genres = GenreRepository(context: context)
        let media = MediaRepository(context: context)
        let collections = CollectionRepository(context: context)

        // **Un voisin qui ne doit pas bouger.** Sans lui, une restauration qui restaurerait
        // tout passerait aussi — c'est le contrôle négatif du parcours.
        let voisin = titles.create(name: "Arrival", in: library)

        let dune = titles.create(name: "Dune", in: library)
        // Trois crédits, deux personnes : ni zéro, ni un, et un nom de personnage à préserver.
        let villeneuve = people.create(
            firstName: "Denis", lastName: "Villeneuve", roles: [.director], in: library)
        let chalamet = people.create(
            firstName: "Timothée", lastName: "Chalamet", roles: [.actor], in: library)
        titles.addCredit(person: villeneuve, role: .director, to: dune)
        titles.addCredit(person: chalamet, role: .cast, characterName: "Paul Atreides", to: dune)
        titles.addCredit(person: villeneuve, role: .cast, characterName: "Voix", to: dune)
        let sf = try genres.findOrCreate(name: "Science-fiction", target: .title, in: library)
        let aventure = try genres.findOrCreate(name: "Aventure", target: .title, in: library)
        titles.setGenres([sf, aventure], on: dune, journal: .perEntity)
        titles.setCollection(
            collections.create(name: "Saga Dune", in: library), on: dune, journal: .perEntity)
        media.attach(
            media.create(MediaAssetDraft(byteSize: 2_048, checksum: "affiche")), to: dune,
            slot: .primary)
        media.attach(
            media.create(MediaAssetDraft(byteSize: 4_096, checksum: "fond")), to: dune,
            slot: .backdrop)
        FlagRepository(context: context, profile: profile).toggleFavorite(dune)
        let lien = ResourceLink()
        lien.urlString = "https://example.org/dune"
        lien.title = dune
        context.insert(lien)
        try context.save()
        return (dune, voisin)
    }

    /// Restaurer une entité déjà purgée rend `false` au lieu de lever.
    ///
    /// Le cas est réel : la liste est affichée, la maintenance passe, l'utilisateur clique. Il
    /// mérite un refus, pas un plantage.
    @Test("Restaurer une entité disparue rend false")
    func restoringVanishedItemFails() throws {
        let (context, _) = try makeTestLibrary()
        let ghost = TrashedItem(
            id: UUID(), entity: .title, label: "Fantôme",
            deletedAt: MaintenanceTests.trashed(daysAgo: 3), daysRemaining: 27)
        #expect(try TrashService(context: context).restore(ghost) == false)
    }
}
