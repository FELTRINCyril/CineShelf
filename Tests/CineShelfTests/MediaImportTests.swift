import CineShelfCore
import CoreGraphics
import Foundation
import ImageIO
import MediaKit
import SwiftData
import Testing
import UniformTypeIdentifiers

// `V2` · L'import d'images, et ce qu'un défaut y coûterait.
//
// **Rigueur au-dessus du cran de la tâche, et c'est justifié par le critère du dépôt** : la
// question n'est pas la couche mais l'irréversibilité. Un rattachement faux écrit une ligne
// en base que personne ne relit — une jaquette attribuée au mauvais titre, une image en
// double dans une galerie, un emplacement unique qui en porte deux. Aucun de ces trois ne se
// voit à l'écran comme une erreur : ça ressemble à une image de plus.
//
// Tout passe par le magasin, contexte neuf compris là où l'ordre de stockage décide.

@MainActor
struct MediaImportTests {

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let title: Title
        let service: MediaImportService
    }

    private func makeFixture() throws -> Fixture {
        let container = try Persistence.makeContainer(cloudKit: false, inMemory: true)
        let context = ModelContext(container)
        let library = Library(name: "Principale")
        context.insert(library)
        let title = Title(name: "Stalker")
        title.library = library
        context.insert(title)
        try context.save()
        return Fixture(
            container: container, context: context, title: title,
            service: MediaImportService(context: context))
    }

    /// Un PNG réel, de couleur variable pour que deux appels donnent deux empreintes.
    ///
    /// Un vrai encodage et non des octets bidon : `MediaIngestor` décode pour redimensionner,
    /// et un test sur des données factices n'exercerait que son chemin d'erreur.
    private func png(level: Double, side: Int = 40) throws -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        let bitmap = try #require(
            CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        // `setGray` et non la surcharge a trois composantes : celle-ci contient, a la lettre,
        // le motif que `no_literal_color` cherche — un nom finissant par « Color » suivi d'un
        // premier parametre `red:`. La regle n'exclut aucun commentaire, donc meme le citer la
        // declenche : troisieme fois, apres `RGBColor` a `L5`. Un gris suffit de toute facon,
        // ce qui doit varier d'un appel a l'autre etant l'**empreinte**.
        bitmap.setFillColor(gray: level, alpha: 1)
        bitmap.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let image = try #require(bitmap.makeImage())

        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func payload(_ name: String, level: Double) throws -> MediaImportService.Payload {
        MediaImportService.Payload(name: name, data: try png(level: level))
    }

    // MARK: Le chemin nominal

    @Test("Une image importée crée un asset, une pièce jointe, et se relit du magasin")
    func importedImageIsPersisted() throws {
        let fixture = try makeFixture()

        let outcome = fixture.service.importImages(
            [try payload("affiche.png", level: 0.4)], into: fixture.title, slot: .primary)
        try fixture.context.save()

        #expect(outcome.attached.count == 1)
        #expect(outcome.failures.isEmpty)
        #expect(outcome.deduplicated == 0)

        // Contexte neuf : ce qui compte est ce qui est **écrit**, pas ce qui est en attente.
        let fresh = ModelContext(fixture.container)
        let assets = try fresh.fetch(FetchDescriptor<MediaAsset>())
        let attachments = try fresh.fetch(FetchDescriptor<MediaAttachment>())

        #expect(assets.count == 1)
        #expect(attachments.count == 1)
        #expect(attachments.first?.slot == .primary)
        // Le pipeline a bien tourné : redimensionné, encodé, empreinté, résumé.
        #expect(assets.first?.checksum.isEmpty == false)
        #expect(assets.first?.blurHash?.isEmpty == false)
        #expect(assets.first?.pixelWidth ?? 0 > 0)
        #expect(assets.first?.data?.isEmpty == false)
    }

    @Test("L'invariante d'un seul propriétaire tient sur chaque pièce jointe créée")
    func everyAttachmentHasExactlyOneOwner() throws {
        let fixture = try makeFixture()
        _ = fixture.service.importImages(
            [try payload("a.png", level: 0.2), try payload("b.png", level: 0.6)],
            into: fixture.title)
        try fixture.context.save()

        let fresh = ModelContext(fixture.container)
        let attachments = try fresh.fetch(FetchDescriptor<MediaAttachment>())

        #expect(attachments.count == 2)
        for attachment in attachments {
            // C'est l'invariante que les trois surcharges de `attach` rendent impossible à
            // violer. Le test la vérifie quand même : la garde est structurelle côté
            // appelant, pas côté modèle.
            #expect(attachment.hasExactlyOneOwner, "un seul propriétaire")
            #expect(attachment.asset != nil, "une pièce jointe sans média serait un fantôme")
        }
    }

    // MARK: Le dédoublonnage

    @Test("La même image importée deux fois ne crée qu'un asset, et le rapport le dit")
    func sameImageTwiceYieldsOneAsset() throws {
        let fixture = try makeFixture()
        let same = try png(level: 0.5)

        let first = fixture.service.importImages(
            [.init(name: "x.png", data: same)], into: fixture.title)
        let second = fixture.service.importImages(
            [.init(name: "copie-de-x.png", data: same)], into: fixture.title)
        try fixture.context.save()

        let fresh = ModelContext(fixture.container)

        #expect(try fresh.fetch(FetchDescriptor<MediaAsset>()).count == 1)
        #expect(first.deduplicated == 0)
        // **La moitié qui compte** : sans elle, l'écran annoncerait « 1 importée » et
        // l'utilisateur croirait avoir ajouté une image qui existait déjà.
        #expect(second.deduplicated == 1)
    }

    @Test("Un doublon n'est pas rattaché deux fois à la même galerie")
    func duplicateIsNotAttachedTwiceToTheSameGallery() throws {
        let fixture = try makeFixture()
        let same = try png(level: 0.5)

        _ = fixture.service.importImages(
            [.init(name: "x.png", data: same)], into: fixture.title)
        _ = fixture.service.importImages(
            [.init(name: "x.png", data: same)], into: fixture.title)
        try fixture.context.save()

        let fresh = ModelContext(fixture.container)

        // Le dédoublonnage à l'octet porte sur l'**asset** ; sans cette garde-ci, la même
        // image apparaîtrait deux fois dans la galerie du titre, ce qui ne ressemble pas à un
        // bug mais à une image de plus.
        #expect(try fresh.fetch(FetchDescriptor<MediaAttachment>()).count == 1)
    }

    // MARK: Les emplacements uniques

    @Test("Un emplacement unique n'en garde qu'une : la seconde remplace la première")
    func singleSlotKeepsOnlyOne() throws {
        let fixture = try makeFixture()

        _ = fixture.service.importImages(
            [try payload("v1.png", level: 0.3)], into: fixture.title, slot: .primary)
        _ = fixture.service.importImages(
            [try payload("v2.png", level: 0.7)], into: fixture.title, slot: .primary)
        try fixture.context.save()

        let fresh = ModelContext(fixture.container)
        let primaries = try fresh.fetch(FetchDescriptor<MediaAttachment>())
            .filter { $0.slot == .primary }

        // Deux `.primary` sur un titre rendraient `TitleFormat.primaryAsset` indéterminé : la
        // jaquette changerait d'un lancement à l'autre, selon l'ordre de stockage. C'est le
        // défaut le plus difficile à croire quand on le voit, et le plus facile à écrire.
        #expect(primaries.count == 1)
        // Les deux assets restent : l'ancien devient orphelin, et `L1 bis` sait le montrer.
        #expect(try fresh.fetch(FetchDescriptor<MediaAsset>()).count == 2)
    }

    @Test("La galerie, elle, en accepte autant qu'on veut")
    func galleryAcceptsMany() throws {
        let fixture = try makeFixture()

        _ = fixture.service.importImages(
            [
                try payload("a.png", level: 0.1), try payload("b.png", level: 0.4),
                try payload("c.png", level: 0.8)
            ], into: fixture.title)
        try fixture.context.save()

        let fresh = ModelContext(fixture.container)
        let gallery = try fresh.fetch(FetchDescriptor<MediaAttachment>())
            .filter { $0.slot == .gallery }

        #expect(gallery.count == 3)
        // L'ordre est celui de l'import, et il est **écrit** : sans `orderIndex`, la galerie
        // se réordonnerait à chaque lecture.
        #expect(Set(gallery.map(\.orderIndex)).count == 3)
    }

    // MARK: Les entrées hostiles

    @Test("Des octets qui ne sont pas une image sont refusés, nommément")
    func nonImageBytesAreRejectedByName() throws {
        let fixture = try makeFixture()

        let outcome = fixture.service.importImages(
            [
                .init(name: "notes.txt", data: Data("pas une image".utf8)),
                try payload("vraie.png", level: 0.5)
            ], into: fixture.title)
        try fixture.context.save()

        // Un fichier refusé **n'annule pas les autres** : déposer huit images dont une
        // corrompue doit en importer sept, pas zéro.
        #expect(outcome.attached.count == 1)
        #expect(outcome.failures.count == 1)
        #expect(outcome.failures.first?.name == "notes.txt", "l'écran nomme le fichier")
        #expect(try ModelContext(fixture.container).fetch(FetchDescriptor<MediaAsset>()).count == 1)
    }

    @Test("Un lot vide ne crée rien et ne se plaint pas")
    func emptyBatchDoesNothing() throws {
        let fixture = try makeFixture()

        let outcome = fixture.service.importImages([], into: fixture.title)

        #expect(outcome.isEmpty)
        #expect(try fixture.context.fetch(FetchDescriptor<MediaAsset>()).isEmpty)
    }

    // MARK: Le recadrage

    @Test("Un recadrage écrit une ligne par contexte, et la met à jour au second passage")
    func cropIsOnePerContextAndUpdates() throws {
        let fixture = try makeFixture()
        _ = fixture.service.importImages(
            [try payload("a.png", level: 0.4)], into: fixture.title, slot: .backdrop)
        try fixture.context.save()

        let repository = MediaRepository(context: fixture.context)
        let asset = try #require(
            try fixture.context.fetch(FetchDescriptor<MediaAsset>()).first)

        repository.setCrop(CropValues(x: 30, y: 70, zoom: 150), on: asset, in: .hero)
        repository.setCrop(CropValues(x: 40, y: 60, zoom: 120), on: asset, in: .hero)
        repository.setCrop(CropValues(x: 50, y: 50, zoom: 100), on: asset, in: .card)
        try fixture.context.save()

        let fresh = ModelContext(fixture.container)
        let crops = try fresh.fetch(FetchDescriptor<MediaCrop>())

        // Deux lignes pour le même couple (média, contexte) rendraient le recadrage
        // indéterminé — `CropDisplay.of(_:in:)` en prendrait une au hasard.
        #expect(crops.count == 2, "une par contexte, pas une par appel")
        let hero = try #require(crops.first { $0.context == .hero })
        #expect(hero.positionX == 40)
        #expect(hero.zoom == 120)
    }
}
