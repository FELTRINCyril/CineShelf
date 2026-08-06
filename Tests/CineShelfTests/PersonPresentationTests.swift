import DesignSystem
import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// **Pas d'`import CineShelf` ici, et c'est structurel** : `CineShelfTests` n'a pas d'app hôte,
// elle *compile* les fichiers de `App/` dont elle a besoin (voir `project.yml`). `AssetURL`,
// `PosterCardModel(_ person:)` et `PersonFormat` sont donc des symboles de cette cible, pas
// d'un module importé.
//
// > **La CI l'a attrapé, pas moi.** La première version portait `@testable import CineShelf`,
// > et elle compilait en local — `DerivedData` gardait le module app d'un build précédent. Sur
// > une machine propre : « unable to resolve module dependency: 'CineShelf' ». C'est la même
// > famille que les seuils de performance calés sur la machine locale : vert ici, rouge là-bas,
// > et le local est le mauvais juge.

// MARK: - V4 · Le chemin de l'image d'une personne
//
// **Ce fichier existe à cause d'un chemin mort trouvé en écrivant `V4`.**
// `PosterCardModel(_ person:)` ne passait **aucune** `imageURL` : une personne à qui
// l'utilisateur avait attaché un portrait rendait quand même ses initiales — dans la
// recherche, dans le casting d'une fiche titre, et désormais dans la grille des personnes.
//
// Le commentaire d'origine invoquait le §11 du handoff, « Portraits de personnes : aucun ».
// C'est vrai des **échantillons** du paquet de design, pas du modèle : `MediaAttachment` porte
// un `person`, et `V2` en attache depuis le glisser-déposer. Le repli en initiales de
// `PersonTile` est prévu pour l'absence d'image, pas pour la masquer.
//
// C'est la même famille que `MediaFill` chargé par `AsyncImage` pendant quatre sessions : un
// chemin qui a l'air branché et que rien n'emprunte. Là-bas, l'échantillon était nul ; ici,
// c'était le code de production.

@Suite("Présentation des personnes")
@MainActor
struct PersonPresentationTests {

    private func fixture() throws -> (context: ModelContext, library: Library) {
        let container = try ModelContainer(
            for: Persistence.schema,
            migrationPlan: CineShelfMigrationPlan.self,
            configurations: ModelConfiguration(
                schema: Persistence.schema, isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let library = Library(name: "Sonde", isDefault: true)
        context.insert(library)
        try context.save()
        return (context, library)
    }

    /// Attache un média à une personne, par le chemin réel : un `MediaAsset` et une
    /// `MediaAttachment`, comme l'import d'image en produit.
    @discardableResult
    private func attachPortrait(
        to person: Person, in context: ModelContext, slot: MediaSlot = .primary, order: Int = 0
    ) -> MediaAsset {
        let asset = MediaAsset()
        asset.blurHash = "L6PZfSjE.AyE_3t7t7R**0o#DgR4"
        context.insert(asset)

        let attachment = MediaAttachment()
        attachment.slot = slot
        attachment.orderIndex = order
        attachment.asset = asset
        attachment.person = person
        context.insert(attachment)
        return asset
    }

    @Test("Une personne sans image n'a pas d'URL de portrait")
    func personWithoutImageHasNoURL() throws {
        let (context, library) = try fixture()
        // **Une entrée quelconque** : ni « A », ni une chaîne vide, ni un nom ASCII pur.
        let person = PersonRepository(context: context)
            .create(firstName: "Cillian", lastName: "Ó Murchú", in: library)
        try context.save()

        #expect(AssetURL.portrait(for: person) == nil)
        #expect(PosterCardModel(person).imageURL == nil)
    }

    /// **Le test qui aurait attrapé le défaut.**
    @Test("Une personne avec un portrait attaché porte son URL jusqu'à la carte")
    func personWithImageCarriesItsURL() throws {
        let (context, library) = try fixture()
        let person = PersonRepository(context: context)
            .create(firstName: "Cillian", lastName: "Ó Murchú", in: library)
        let asset = attachPortrait(to: person, in: context)
        try context.save()

        let url = try #require(
            AssetURL.portrait(for: person), "un portrait attaché doit donner une URL")
        // Le schéma interne, pas une URL réseau : c'est `MediaFill` qui le résout.
        #expect(url.scheme == AssetURL.scheme)
        // **Décodée, pas comparée en texte.** Première rédaction de ce test : un `contains`
        // sur l'`uuidString`, qui a échoué — `URL` met l'hôte en minuscules, donc la
        // comparaison littérale était sensible à une casse dont rien ne garantit qu'elle
        // survive. `decode` est le chemin que la résolution d'image emprunte vraiment.
        let decoded = try #require(AssetURL.decode(url))
        #expect(decoded.assetID == asset.id)
        #expect(decoded.preset == .card)

        let card = PosterCardModel(person)
        #expect(card.imageURL == url, "la carte doit porter l'URL, pas se replier sur les initiales")
        #expect(card.kind == .person)
        // Le blurHash suit, sinon la tuile saute au chargement au lieu de fondre.
        #expect(card.blurHash == asset.blurHash)
    }

    /// **Le même choix que `TitleFormat.primaryAsset`**, et il faut le vérifier plutôt que le
    /// supposer : l'emplacement `primary` gagne, quel que soit son rang.
    @Test("L'emplacement principal l'emporte sur un rang plus petit en galerie")
    func primarySlotWinsOverLowerOrder() throws {
        let (context, library) = try fixture()
        let person = PersonRepository(context: context)
            .create(firstName: "Cillian", lastName: "Ó Murchú", in: library)
        // La pièce de galerie a le **rang 0**, la principale le rang 3 : si le choix se faisait
        // sur le seul rang, ce test échouerait. Prendre 0 et 1 n'aurait rien départagé.
        attachPortrait(to: person, in: context, slot: .gallery, order: 0)
        let primary = attachPortrait(to: person, in: context, slot: .primary, order: 3)
        try context.save()

        #expect(PersonFormat.primaryAsset(of: person)?.id == primary.id)
    }

    @Test("Sans emplacement principal, le plus petit rang sert de portrait")
    func fallsBackToLowestOrder() throws {
        let (context, library) = try fixture()
        let person = PersonRepository(context: context)
            .create(firstName: "Cillian", lastName: "Ó Murchú", in: library)
        // Rangs 5 et 2, ni 0 ni 1 : un `min` mal écrit sur des rangs qui commencent à zéro
        // passerait par accident.
        attachPortrait(to: person, in: context, slot: .gallery, order: 5)
        let lowest = attachPortrait(to: person, in: context, slot: .gallery, order: 2)
        try context.save()

        #expect(PersonFormat.primaryAsset(of: person)?.id == lowest.id)
    }

    // MARK: Les libellés de la fiche

    @Test("Les rôles sortent dans l'ordre du bloc 4d, pas celui de l'énumération")
    func roleLineFollowsTheBlock() throws {
        let (context, library) = try fixture()
        let person = PersonRepository(context: context)
            .create(firstName: "Cillian", lastName: "Ó Murchú", in: library)
        PersonRepository(context: context).setRoles([.actor, .director], on: person, journal: .batched)
        try context.save()

        // « Interprétation · Réalisation » — l'ordre du prototype. `PersonRole.allCases`
        // commence par `actor` parce que c'est le rôle par défaut d'une création, ce qui n'est
        // pas un ordre d'affichage.
        #expect(PersonFormat.roleLine(of: person) == "Interprétation · Réalisation")
    }

    @Test("L'âge d'un vivant se calcule, celui d'un défunt se lit")
    func lifePartsDistinguishLivingFromDead() throws {
        let (context, library) = try fixture()
        let repository = PersonRepository(context: context)

        let living = repository.create(firstName: "Vivante", in: library)
        // **Une date quelconque** : le 17 mai 1974, ni un 1er, ni un 31, ni un mois de bord.
        living.birthDate = Calendar.current.date(
            from: DateComponents(year: 1_974, month: 5, day: 17))

        let dead = repository.create(firstName: "Défunt", in: library)
        dead.birthDate = Calendar.current.date(from: DateComponents(year: 1_921, month: 9, day: 8))
        dead.deathDate = Calendar.current.date(from: DateComponents(year: 1_987, month: 3, day: 22))
        dead.ageAtDeath = 65
        try context.save()

        let livingParts = PersonFormat.lifeParts(of: living)
        #expect(livingParts.contains { $0.hasPrefix("Né le") })
        #expect(livingParts.contains { $0.hasSuffix("ans") })

        let deadParts = PersonFormat.lifeParts(of: dead)
        #expect(deadParts.contains { $0.hasPrefix("Mort le") })
        // **« 65 ans au décès », pas l'âge qu'il aurait aujourd'hui.** C'est la distinction que
        // `PersonFilter` fait déjà pour ses tranches d'âge, et les deux doivent s'accorder :
        // afficher un âge que le filtre n'utilise pas rendrait le filtre incompréhensible.
        #expect(deadParts.contains("65 ans au décès"))
    }
}
