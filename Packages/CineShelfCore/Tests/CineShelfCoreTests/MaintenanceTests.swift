import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// MARK: - L16 · La passe d'entretien, et la corbeille
//
// **Rigueur maximale, et pour une raison précise : c'est la seule passe du dépôt qui supprime
// définitivement.** Un défaut ici ne se voit pas — il se voit trente jours plus tard, sur une
// donnée qu'on ne peut plus récupérer.
//
// **Les sources**, parce qu'un test de suppression qui ne cite que lui-même décrit ce que le
// code fait au lieu de ce qu'il doit faire :
//
// - **`docs/03` §« Corbeille / restauration »** — « `deletedAt` + purge à 30 jours » ;
// - **`docs/02` §« Suppressions »** — « `deletedAt` plutôt que `context.delete`, avec purge à
//   30 jours. Une suppression synchronisée est irréversible » ;
// - **`docs/04` §« Ce que CloudKit ne garantit pas »** — « `MediaAttachment` orphelins si un
//   parent est supprimé pendant qu'un autre appareil y attache un média → tâche de maintenance » ;
// - **la fiche `L16`** de `docs/PROMPTS.md` — orphelins, médias non référencés, corbeille,
//   « passe rejouable et idempotente » ;
// - **une sonde hors dépôt du 2026-08-07**, pour ce qui a été *mesuré* plutôt que spécifié.

@MainActor
struct MaintenanceTests {

    /// Un instant **quelconque** : un mardi à 22 h 13 en heure locale, ni minuit, ni le 1er du
    /// mois. La règle du dépôt le demande, et elle a déjà mordu sur le hero du jour — minuit
    /// fait coïncider « jour UTC » et « jour local », donc il ne départage pas les
    /// implémentations.
    static let reference: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 17
        components.hour = 22
        components.minute = 13
        return Calendar.current.date(from: components) ?? .now
    }()

    /// Une date à la corbeille depuis `days` jours, comptés par le calendrier.
    static func trashed(daysAgo days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: reference) ?? reference
    }

    // MARK: Le seuil de trente jours

    /// Source du chiffre : `docs/03` et `docs/02`, qui écrivent tous deux « 30 jours ».
    ///
    /// **Les deux côtés de la borne, et la borne elle-même.** 29 jours reste, 31 part. Le cas à
    /// exactement 30 jours est celui qui départage `<` de `<=` : il **reste**, parce que la
    /// documentation dit « purge à 30 jours » et non « après 29 » — un élément supprimé le 1er
    /// est encore là le 31, et part le 32e jour.
    @Test("Vingt-neuf jours restent, trente et un partent")
    func retentionBoundary() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)

        let recent = titles.create(name: "Récent", in: library)
        let expired = titles.create(name: "Expiré", in: library)
        let onTheEdge = titles.create(name: "Pile trente", in: library)
        titles.softDelete(recent)
        titles.softDelete(expired)
        titles.softDelete(onTheEdge)
        recent.deletedAt = Self.trashed(daysAgo: 29)
        expired.deletedAt = Self.trashed(daysAgo: 31)
        onTheEdge.deletedAt = Self.trashed(daysAgo: 30)
        try context.save()

        let report = try MaintenanceService(context: context).run(now: Self.reference)

        #expect(report.purgedByEntity["title"] == 1)
        let survivors = try context.fetch(FetchDescriptor<Title>()).map(\.name).sorted()
        #expect(survivors == ["Pile trente", "Récent"])
    }

    /// **La borne se calcule par le calendrier, pas par 30 × 86 400 secondes.**
    ///
    /// Un changement d'heure décale la soustraction en secondes d'une heure, dans un sens ou
    /// dans l'autre selon la saison — et ce décalage porte sur une opération **irréversible**.
    /// Le test prend un instant qui traverse le changement d'heure d'octobre.
    @Test("La borne de rétention traverse un changement d'heure sans dériver")
    func expiryUsesCalendar() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 3
        components.hour = 14
        components.minute = 41
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: components))

        let expiry = MaintenanceService.expiry(from: now, calendar: calendar)
        let elapsed = calendar.dateComponents([.day], from: expiry, to: now).day

        #expect(elapsed == 30, "La borne doit être à 30 jours de calendrier, pas 30 × 86 400 s")
    }

    // MARK: Le piège de la tâche

    /// **Une référence depuis la corbeille est une référence.**
    ///
    /// Mesuré par la sonde : `softDelete` ne fait que poser une date, donc l'attachement d'un
    /// titre à la corbeille **survit**, et son média est encore référencé. Une passe qui le
    /// compterait comme non référencé le supprimerait — et restaurer le titre rendrait une fiche
    /// **sans affiche**. `deletedAt` n'aurait alors servi à rien, ce qui est exactement ce
    /// contre quoi `docs/02` l'a introduit.
    ///
    /// C'est le test qui décide de la valeur de cette tâche.
    @Test("Le média d'un titre à la corbeille survit à l'entretien, et revient avec lui")
    func trashedTitleKeepsItsPoster() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let media = MediaRepository(context: context)

        let dune = titles.create(name: "Dune", in: library)
        let asset = media.create(MediaAssetDraft(byteSize: 2_048, checksum: "aff-dune"))
        media.attach(asset, to: dune, slot: .primary)
        try context.save()

        // À la corbeille depuis trois jours : loin de la borne, donc ce test ne parle que de la
        // référence et pas du seuil.
        titles.softDelete(dune)
        dune.deletedAt = Self.trashed(daysAgo: 3)
        try context.save()

        let report = try MaintenanceService(context: context).run(now: Self.reference)

        #expect(report.unreferencedAssets == 0, "Le média d'un titre à la corbeille est référencé")
        #expect(try context.fetchCount(FetchDescriptor<MediaAsset>()) == 1)

        // Et la restauration le ramène pour de vrai — c'est la seconde moitié de la promesse.
        titles.restore(dune)
        try context.save()
        #expect(dune.attachments?.count == 1)
        #expect(dune.attachments?.first?.asset?.checksum == "aff-dune")
    }

    /// **Ce test affirmait le contraire, et il verrouillait une destruction de données.**
    ///
    /// Il s'appelait « Un média qu'aucun attachement ne désigne est supprimé » et assénait
    /// `fetchCount(MediaAsset) == 0`. Or un média sans propriétaire est un **état de première
    /// classe** : `MediaRepository.detach` l'écrit — « le média n'est pas supprimé, et c'est
    /// délibéré : il devient orphelin » — et `GalleryFilter.MediaSource.orphan` le rend
    /// filtrable sous « Sans rattachement ».
    ///
    /// Trois gestes ordinaires en produisent, dont **remplacer une jaquette** : `setSingle`
    /// détache l'ancienne. La passe aurait donc détruit l'affiche précédente de chaque titre
    /// dont on change l'image, au lancement suivant, sans corbeille et sans trace.
    ///
    /// C'est la cinquième fois qu'un test de ce dépôt encode une intention fausse — voir
    /// `CLAUDE.md`. Trouvé par une revue adverse, pas par la suite.
    ///
    /// **Trois médias, un seul orphelin** : ni zéro, ni tous. La version d'origine n'en créait
    /// qu'un, et son commentaire décrivait un test qui n'avait pas été écrit.
    @Test("Un média sans rattachement est compté, jamais supprimé")
    func unreferencedAssetIsCountedNotRemoved() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let media = MediaRepository(context: context)

        let dune = titles.create(name: "Dune", in: library)
        let attached = media.create(MediaAssetDraft(byteSize: 1_024, checksum: "attache"))
        media.attach(attached, to: dune, slot: .primary)
        let replaced = media.create(MediaAssetDraft(byteSize: 512, checksum: "ancienne-jaquette"))
        let oldAttachment = media.attach(replaced, to: dune, slot: .gallery)
        let neverAttached = media.create(MediaAssetDraft(byteSize: 256, checksum: "jamais-attache"))
        _ = neverAttached
        try context.save()

        // Le geste réel : on détache, comme `setSingle` le fait en remplaçant une jaquette.
        media.detach(oldAttachment)
        try context.save()

        let report = try MaintenanceService(context: context).run(now: Self.reference)

        #expect(report.unreferencedAssets == 2, "L'ancienne jaquette et le jamais-attaché")
        #expect(
            try context.fetchCount(FetchDescriptor<MediaAsset>()) == 3,
            "Aucun média ne doit être détruit : la galerie les montre sous « Sans rattachement »")
        #expect(report.isEmpty, "Compter n'est pas agir : la passe n'a rien modifié")
    }

    /// **Un média orphelin mis à la corbeille garde ses trente jours.**
    ///
    /// L'ancienne version le détruisait au lancement suivant : `removeUnreferencedAssets` ne
    /// regardait pas `deletedAt`, donc la rétention valait **zéro seconde** pour tout média sans
    /// rattachement — y compris ceux que l'utilisateur venait de jeter depuis la galerie.
    @Test("Un média orphelin à la corbeille survit à ses premiers jours")
    func trashedOrphanKeepsItsRetention() throws {
        let (context, _) = try makeTestLibrary()
        let media = MediaRepository(context: context)

        let asset = media.create(MediaAssetDraft(byteSize: 512, checksum: "jete"))
        media.softDelete(asset)
        asset.deletedAt = Self.trashed(daysAgo: 1)
        try context.save()

        try MaintenanceService(context: context).run(now: Self.reference)
        #expect(try context.fetchCount(FetchDescriptor<MediaAsset>()) == 1)

        // Et il part quand son temps est venu, par l'étape 1 — pas par la collecte.
        asset.deletedAt = Self.trashed(daysAgo: 31)
        try context.save()
        let report = try MaintenanceService(context: context).run(now: Self.reference)
        #expect(report.purgedByEntity["mediaAsset"] == 1)
        #expect(try context.fetchCount(FetchDescriptor<MediaAsset>()) == 0)
    }

    // MARK: L'invariante d'attachement

    /// Source : `docs/04` — « `MediaAttachment` orphelins si un parent est supprimé pendant
    /// qu'un autre appareil y attache un média → tâche de maintenance ».
    @Test("Un attachement sans propriétaire est supprimé, et son média avec s'il est seul")
    func ownerlessAttachmentIsRemoved() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let media = MediaRepository(context: context)

        let dune = titles.create(name: "Dune", in: library)
        let asset = media.create(MediaAssetDraft(byteSize: 4_096, checksum: "aff"))
        let attachment = media.attach(asset, to: dune, slot: .primary)
        try context.save()

        // La fusion CloudKit décrite par `docs/04` : le parent a disparu de l'autre côté.
        attachment.title = nil
        try context.save()
        #expect(!attachment.hasExactlyOneOwner)

        let report = try MaintenanceService(context: context).run(now: Self.reference)

        #expect(report.orphanAttachmentsRemoved == 1)
        #expect(try context.fetchCount(FetchDescriptor<MediaAttachment>()) == 0)
        // **Le média, lui, reste** : privé de son attachement il devient orphelin, ce que la
        // galerie sait montrer. C'est l'ordre des étapes qui le fait compter dans le même tour.
        #expect(report.unreferencedAssets == 1)
        #expect(try context.fetchCount(FetchDescriptor<MediaAsset>()) == 1)
    }

    /// **Plusieurs propriétaires se réparent, ils ne se suppriment pas.**
    ///
    /// L'image porte une donnée réelle ; supprimer l'attachement la ferait perdre aux deux
    /// parents. Le titre gagne, par un ordre stable — un choix arbitraire différerait d'un
    /// appareil à l'autre, ce qui est précisément ce que CloudKit rendrait visible.
    @Test("Un attachement à deux propriétaires est réparé, pas supprimé")
    func multiOwnerAttachmentIsRepaired() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)
        let media = MediaRepository(context: context)

        let dune = titles.create(name: "Dune", in: library)
        let villeneuve = people.create(
            firstName: "Denis", lastName: "Villeneuve", roles: [.director], in: library)
        let asset = media.create(MediaAssetDraft(byteSize: 8_192, checksum: "portrait"))
        let attachment = media.attach(asset, to: dune, slot: .primary)
        attachment.person = villeneuve
        try context.save()

        let report = try MaintenanceService(context: context).run(now: Self.reference)

        #expect(report.multiOwnerAttachmentsRepaired == 1)
        #expect(report.orphanAttachmentsRemoved == 0)
        #expect(attachment.hasExactlyOneOwner)
        #expect(attachment.title?.name == "Dune")
        #expect(attachment.person == nil)

        // **Et la personne garde son portrait.** Ce test assénait seulement `person == nil`,
        // donc il verrouillait une perte : si c'était son unique image, sa fiche devenait vide
        // définitivement — un `MediaAttachment` n'a pas de corbeille. La réparation **scinde**,
        // elle ne nullifie pas.
        #expect(villeneuve.attachments?.count == 1, "La personne garde une arête vers le média")
        #expect(villeneuve.attachments?.first?.asset?.checksum == "portrait")
        #expect(villeneuve.attachments?.first?.hasExactlyOneOwner == true)
        // Un seul média pour deux arêtes : scinder ne duplique aucune image.
        #expect(try context.fetchCount(FetchDescriptor<MediaAsset>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<MediaAttachment>()) == 2)
    }

    // MARK: Le défaut que la sonde a trouvé

    /// **Purger une personne laissait ses crédits derrière**, mesuré 2 sur 2.
    ///
    /// `Person.credits` ne déclare pas `deleteRule: .cascade` — seuls `flags`, `handles`,
    /// `attachments` et `links` l'ont. Un crédit sans personne est une ligne de générique vide :
    /// il ne s'affiche pas, il ne se restaure pas, et il compte dans `title.credits`.
    ///
    /// **Le schéma est fermé**, donc la correction est dans le service et non dans le modèle.
    @Test("Purger une personne emporte ses crédits, et n'en laisse aucun décapité")
    func purgingPersonRemovesItsCredits() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)

        // Deux titres crédités de la même personne : un seul ne montrerait pas que les deux
        // arêtes partent.
        let dune = titles.create(name: "Dune", in: library)
        let tenet = titles.create(name: "Tenet", in: library)
        let villeneuve = people.create(
            firstName: "Denis", lastName: "Villeneuve", roles: [.director], in: library)
        titles.addCredit(person: villeneuve, role: .director, to: dune)
        titles.addCredit(person: villeneuve, role: .director, to: tenet)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Credit>()) == 2)

        people.softDelete(villeneuve)
        villeneuve.deletedAt = Self.trashed(daysAgo: 45)
        try context.save()

        let report = try MaintenanceService(context: context).run(now: Self.reference)

        #expect(report.purgedByEntity["person"] == 1)
        #expect(try context.fetchCount(FetchDescriptor<Credit>()) == 0, "Aucun crédit décapité")
        // Les titres, eux, ne sont pas touchés : purger une personne n'est pas purger sa
        // filmographie.
        #expect(try context.fetchCount(FetchDescriptor<Title>()) == 2)
    }

    /// Le filet, pour les crédits décapités qui existeraient **déjà** en base.
    ///
    /// La correction ci-dessus empêche d'en créer ; elle ne répare pas ceux qu'une version
    /// antérieure a laissés. Les deux sont nécessaires, et c'est exactement le motif d'une passe
    /// de maintenance : elle rattrape le passé, le repository protège l'avenir.
    @Test("Un crédit sans personne déjà en base est nettoyé")
    func existingHeadlessCreditIsCleaned() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)

        let dune = titles.create(name: "Dune", in: library)
        let villeneuve = people.create(
            firstName: "Denis", lastName: "Villeneuve", roles: [.director], in: library)
        let credit = titles.addCredit(person: villeneuve, role: .director, to: dune)
        try context.save()

        credit.person = nil
        try context.save()

        let report = try MaintenanceService(context: context).run(now: Self.reference)
        #expect(report.headlessCreditsRemoved == 1)
        #expect(try context.fetchCount(FetchDescriptor<Credit>()) == 0)
    }

    /// **`survey()` compte sans agir.** C'est ce qui autorise un écran de réglages à l'appeler
    /// à l'ouverture : `run()` supprime, ouvrir un écran ne doit jamais supprimer.
    @Test("Analyser sans agir ne modifie rien")
    func surveyDoesNotMutate() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let media = MediaRepository(context: context)

        let dune = titles.create(name: "Dune", in: library)
        let attached = media.create(MediaAssetDraft(byteSize: 1_024, checksum: "attache"))
        media.attach(attached, to: dune, slot: .primary)
        let orphan = media.create(MediaAssetDraft(byteSize: 256, checksum: "orphelin"))
        _ = orphan
        // Une entité expirée : `survey` ne doit pas la purger non plus, alors que `run` le
        // ferait. Sans elle, le test passerait même si `survey` appelait `run`.
        let expired = titles.create(name: "Expiré", in: library)
        titles.softDelete(expired)
        expired.deletedAt = Self.trashed(daysAgo: 40)
        try context.save()

        let found = try MaintenanceService(context: context).survey()

        #expect(found == 1)
        #expect(try context.fetchCount(FetchDescriptor<MediaAsset>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Title>()) == 2, "Rien ne doit être purgé")
        #expect(expired.deletedAt != nil)
    }

    // MARK: L'idempotence, exigée par la fiche

    /// « Passe rejouable et idempotente » — fiche `L16`.
    ///
    /// **Le second tour doit être vide, et c'est plus fort que « ne casse rien ».** Une passe
    /// qu'il faut jouer deux fois pour converger n'est pas idempotente, elle est incomplète : le
    /// premier tour laisserait des orphelins que seul le second verrait. C'est ce que l'ordre
    /// des étapes évite — la purge fabrique des médias non référencés, donc elle passe **avant**
    /// leur collecte.
    @Test("Un second passage immédiat ne trouve plus rien")
    func passIsIdempotent() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)
        let media = MediaRepository(context: context)

        // Un état sale sur les quatre fronts à la fois : c'est le seul cas qui exerce l'ordre.
        let dune = titles.create(name: "Dune", in: library)
        let asset = media.create(MediaAssetDraft(byteSize: 1_024, checksum: "aff-dune"))
        media.attach(asset, to: dune, slot: .primary)
        let villeneuve = people.create(
            firstName: "Denis", lastName: "Villeneuve", roles: [.director], in: library)
        titles.addCredit(person: villeneuve, role: .director, to: dune)
        let orphan = media.create(MediaAssetDraft(byteSize: 256, checksum: "orphelin"))
        _ = orphan
        titles.softDelete(dune)
        people.softDelete(villeneuve)
        dune.deletedAt = Self.trashed(daysAgo: 40)
        villeneuve.deletedAt = Self.trashed(daysAgo: 40)
        try context.save()

        let first = try MaintenanceService(context: context).run(now: Self.reference)
        #expect(!first.isEmpty)
        // Les deux médias sont **comptés** comme orphelins dans le MÊME tour : celui de Dune
        // parce que la purge a emporté son attachement, l'autre parce qu'il n'en a jamais eu.
        // C'est ce compte qui prouve que l'ordre des étapes tient — collecter avant la purge
        // n'en aurait vu qu'un.
        #expect(first.unreferencedAssets == 2)

        let second = try MaintenanceService(context: context).run(now: Self.reference)
        #expect(second.isEmpty, "Second tour : \(second)")
    }

    /// Et une base **saine** ne doit rien perdre. Le contrôle négatif de toute cette suite :
    /// sans lui, une passe qui supprimerait tout passerait la moitié des tests ci-dessus.
    @Test("Une base saine traverse l'entretien sans rien perdre")
    func healthyLibraryIsUntouched() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)
        let media = MediaRepository(context: context)

        let dune = titles.create(name: "Dune", in: library)
        _ = titles.create(name: "Tenet", in: library)
        let villeneuve = people.create(
            firstName: "Denis", lastName: "Villeneuve", roles: [.director], in: library)
        titles.addCredit(person: villeneuve, role: .director, to: dune)
        let asset = media.create(MediaAssetDraft(byteSize: 1_024, checksum: "aff"))
        media.attach(asset, to: dune, slot: .primary)
        try context.save()

        let report = try MaintenanceService(context: context).run(now: Self.reference)

        #expect(report.isEmpty, "Une base saine ne doit rien déclencher : \(report)")
        #expect(try context.fetchCount(FetchDescriptor<Title>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Person>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Credit>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<MediaAsset>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<MediaAttachment>()) == 1)
    }
}
