import Foundation
import SwiftData

@testable import CineShelfCore

/// Un magasin **sur disque**, et un dossier de travail qui se supprime tout seul.
///
/// Sur disque et non en mémoire, contrairement au reste de la suite : `MediaAsset.data`
/// est en `.externalStorage`, et l'objet de `L12` est précisément d'écrire puis relire
/// des octets. Un magasin volatil ne prouverait pas que le chemin des fichiers marche.
@MainActor
final class ArchiveSandbox {
    let root: URL
    private var contexts: [ModelContext] = []

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cineshelf-archive-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func makeContext(_ name: String = UUID().uuidString) throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(CineShelfSchemaV1.models, version: CineShelfSchemaV1.versionIdentifier),
            migrationPlan: nil,
            configurations: ModelConfiguration(url: root.appendingPathComponent("\(name).store"))
        )
        let context = ModelContext(container)
        contexts.append(context)
        return context
    }

    func archiveURL(_ name: String = "Test") -> URL {
        root.appendingPathComponent("\(name).\(ArchiveLayout.fileExtension)", isDirectory: true)
    }
}

/// Le catalogue que les tests d'archive écrivent, et ce qu'il porte d'hostile.
///
/// Les cinq entrées difficiles viennent de la sonde de `L12` : ce sont celles qu'un auteur
/// de tests ne choisit pas spontanément, et deux défauts s'y cachaient.
@MainActor
struct ArchiveFixture {
    let context: ModelContext
    let library: Library
    let profile: Profile
    let collection: TitleCollection
    let genre: Genre
    /// Un titre sans rien de particulier, pour que l'aller-retour ait un cas nominal.
    let plainTitle: Title
    /// Porte un `kindRaw` hors de `TitleKind` — ce qu'écrirait une version future de l'app.
    let futureTitle: Title
    /// Guillemets, point-virgule, contre-obliques, idéogramme, NUL, sauts de ligne mêlés.
    let nastyTitle: Title
    /// Privé **et** archivé **et** en corbeille.
    let hiddenTitle: Title
    let person: Person
    /// Des octets, un checksum renseigné.
    let assetWithBytes: MediaAsset
    /// Deux assets **sans checksum**, avec des octets différents. Le cas de `DemoCatalog`,
    /// et celui qui interdit de nommer les fichiers de `media/` par le checksum.
    let assetNoChecksumA: MediaAsset
    let assetNoChecksumB: MediaAsset
    /// Rattaché à un titre **et** à une personne : viole `hasExactlyOneOwner`, et rien
    /// dans le modèle ne l'empêche d'exister.
    let twoOwnerAttachment: MediaAttachment

    init(in context: ModelContext) throws {
        self.context = context

        library = Library(name: "Ma bibliothèque", isDefault: true)
        context.insert(library)

        profile = Profile(name: "Cyril", isDefault: true)
        profile.library = library
        profile.hidesPrivateContent = true
        context.insert(profile)

        collection = TitleCollection(name: "Trilogie « Le Parrain »")
        collection.library = library
        context.insert(collection)

        genre = Genre(name: "Drame")
        genre.library = library
        context.insert(genre)

        plainTitle = Title(name: "Le Parrain")
        plainTitle.library = library
        plainTitle.collection = collection
        plainTitle.genres = [genre]
        plainTitle.releaseDate = Date(timeIntervalSince1970: 47_000_000)
        plainTitle.rating = 9.5
        plainTitle.summary = "La chronique d'une famille."
        context.insert(plainTitle)

        futureTitle = Self.makeFutureTitle(in: context, library: library)
        nastyTitle = Self.makeNastyTitle(in: context, library: library)
        hiddenTitle = Self.makeHiddenTitle(in: context, library: library)

        person = Person(firstName: "Marlon", lastName: "Brando")
        person.library = library
        person.birthDate = Date(timeIntervalSince1970: -1_470_000_000)
        person.deathDate = Date(timeIntervalSince1970: 1_090_000_000)
        person.roles = [.actor, .social]
        person.genres = [genre]
        context.insert(person)

        assetWithBytes = MediaAsset(kind: .image)
        assetWithBytes.data = Data((0..<4096).map { UInt8($0 % 251) })
        assetWithBytes.checksum = "abc123"
        assetWithBytes.pixelWidth = 800
        assetWithBytes.pixelHeight = 1200
        assetWithBytes.byteSize = 4096
        context.insert(assetWithBytes)

        assetNoChecksumA = MediaAsset(kind: .image)
        assetNoChecksumA.data = Data(repeating: 0xAA, count: 64)
        context.insert(assetNoChecksumA)
        assetNoChecksumB = MediaAsset(kind: .image)
        assetNoChecksumB.data = Data(repeating: 0xBB, count: 64)
        context.insert(assetNoChecksumB)

        twoOwnerAttachment = MediaAttachment(slot: .gallery, orderIndex: 1)
        twoOwnerAttachment.asset = assetWithBytes
        twoOwnerAttachment.title = plainTitle
        twoOwnerAttachment.person = person
        context.insert(twoOwnerAttachment)

        insertSatellites()

        for title in [plainTitle, futureTitle, nastyTitle, hiddenTitle] { title.refreshDerived() }
        person.refreshDerived()
        try context.save()
    }

    /// Un `kindRaw` hors de `TitleKind`, comme en écrirait une version future de l'app.
    private static func makeFutureTitle(in context: ModelContext, library: Library) -> Title {
        let title = Title(name: "Un format venu du futur")
        title.library = library
        title.kindRaw = "miniseries-4k-hdr"
        title.releasePrecisionRaw = "decade"
        context.insert(title)
        return title
    }

    /// Tout ce qui casse habituellement un sérialiseur de texte, dans un seul enregistrement.
    private static func makeNastyTitle(in context: ModelContext, library: Library) -> Title {
        let title = Title(name: #"Le mur de 6" ; "guillemets", \backslash et 改"#)
        title.library = library
        title.summary = "Ligne 1\nLigne 2\r\nLigne 3\tavec tabulation\u{0}et un NUL"
        title.originalName = "  espaces  en  trop  "
        context.insert(title)
        return title
    }

    /// Privé **et** archivé **et** en corbeille : les trois états qu'une sauvegarde pourrait
    /// perdre sans qu'un compte bouge.
    private static func makeHiddenTitle(in context: ModelContext, library: Library) -> Title {
        let title = Title(name: "Privé, jeté, archivé")
        title.library = library
        title.isPrivate = true
        title.isArchived = true
        title.deletedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(title)
        return title
    }

    /// Les entités qu'aucun test ne désigne nommément, mais qui doivent être là pour que les
    /// dix-neuf fichiers de l'archive soient tous non vides.
    ///
    /// Un fichier vide passerait l'aller-retour sans rien prouver : c'est la raison d'être de
    /// ce bloc, pas un décor.
    private func insertSatellites() {
        let handle = SocialHandle(platform: "Bluesky", handle: "@brando")
        handle.person = person
        context.insert(handle)

        let credit = Credit(role: .cast, characterName: "Don Vito ; « le Parrain »", orderIndex: 0)
        credit.title = plainTitle
        credit.person = person
        context.insert(credit)

        let remote = MediaAsset(kind: .image)
        remote.externalURLString = "https://exemple.test/affiche.jpg"
        context.insert(remote)

        let crop = MediaCrop(context: .hero)
        crop.asset = assetWithBytes
        crop.positionX = 33.5
        crop.zoom = 87.25
        context.insert(crop)

        let attachment = MediaAttachment(slot: .primary, orderIndex: 0)
        attachment.asset = assetWithBytes
        attachment.title = plainTitle
        context.insert(attachment)

        let flag = TitleFlag()
        flag.profile = profile
        flag.title = plainTitle
        flag.isWatched = true
        flag.personalRating = 8.5
        context.insert(flag)

        let personFlag = PersonFlag()
        personFlag.profile = profile
        personFlag.person = person
        personFlag.isFavorite = true
        context.insert(personFlag)

        let mediaFlag = MediaFlag()
        mediaFlag.profile = profile
        mediaFlag.asset = assetWithBytes
        mediaFlag.isFavorite = true
        context.insert(mediaFlag)

        let resourceLink = ResourceLink(urlString: "https://exemple.test/a?b=c&d=é")
        resourceLink.title = plainTitle
        resourceLink.faviconData = Data(repeating: 0x42, count: 128)
        context.insert(resourceLink)

        let savedLink = SavedLink(urlString: "https://exemple.test/signet")
        savedLink.library = library
        savedLink.genre = genre
        savedLink.name = "Un signet"
        context.insert(savedLink)

        let entry = ActivityEntry()
        entry.actionRaw = ActivityAction.bulkEdit.rawValue
        entry.entityTypeRaw = ActivityEntityType.batch.rawValue
        entry.summary = "Édition en masse de 12 titres"
        entry.payload = Data("{\"version\":1,\"entries\":[]}".utf8)
        context.insert(entry)

        let mapping = ImportMapping(name: "Mon tableur", headerSignature: "titre;année;note")
        mapping.library = library
        mapping.columnMapData = Data("{}".utf8)
        context.insert(mapping)

        let legacy = LegacyRecord()
        legacy.entityTypeRaw = ActivityEntityType.title.rawValue
        legacy.entityID = plainTitle.id
        legacy.legacyTable = "movies"
        legacy.legacyID = "42"
        context.insert(legacy)
    }
}

/// Le compte de chaque entité d'un magasin, pour comparer deux magasins d'un coup.
@MainActor
func entityCounts(in context: ModelContext) throws -> [String: Int] {
    func count<Model: PersistentModel>(_ type: Model.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<Model>())
    }
    return [
        "libraries": try count(Library.self),
        "profiles": try count(Profile.self),
        "title_flags": try count(TitleFlag.self),
        "person_flags": try count(PersonFlag.self),
        "media_flags": try count(MediaFlag.self),
        "titles": try count(Title.self),
        "people": try count(Person.self),
        "social_handles": try count(SocialHandle.self),
        "collections": try count(TitleCollection.self),
        "genres": try count(Genre.self),
        "credits": try count(Credit.self),
        "media_assets": try count(MediaAsset.self),
        "media_attachments": try count(MediaAttachment.self),
        "media_crops": try count(MediaCrop.self),
        "resource_links": try count(ResourceLink.self),
        "saved_links": try count(SavedLink.self),
        "activity_entries": try count(ActivityEntry.self),
        "import_mappings": try count(ImportMapping.self),
        "legacy_records": try count(LegacyRecord.self)
    ]
}
