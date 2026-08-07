import Foundation
import SwiftData

// MARK: - L16 · Les tâches d'entretien qui n'ont pas d'écran propre
//
// **La seule passe du dépôt qui supprime définitivement.** Tout le reste marque `deletedAt` —
// « une suppression synchronisée est irréversible », dit `docs/02` §« Suppressions ». Ici on
// appelle `context.delete`, et ce qui part ne revient pas, sur aucun appareil.
//
// Trois choses que la fiche `L16` demande, et une quatrième que la sonde a trouvée :
//
// - les `MediaAttachment` orphelins, et l'invariante `hasExactlyOneOwner` ;
// - les médias non référencés ;
// - la purge de la corbeille au-delà de 30 jours ;
// - **les `Credit` sans personne**, que la fiche ne nomme pas et qui existent quand même.
//
// **L'ordre des étapes n'est pas cosmétique : c'est lui qui rend la passe idempotente en un
// seul tour.** Mesuré par une sonde hors dépôt le 2026-08-07 : purger un titre laisse son
// affiche **non référencée**. Collecter les médias non référencés *avant* la purge en
// laisserait donc derrière, et il faudrait relancer la passe pour les voir — une passe qu'il
// faut jouer deux fois pour converger n'est pas idempotente, elle est incomplète.
//
// **Et une référence depuis la corbeille est une référence.** C'est le piège de cette tâche,
// et il annule tout le reste : un asset attaché à un titre à la corbeille est encore attaché —
// mesuré. Une passe qui le supprimerait rendrait la restauration inutile, puisqu'on
// récupérerait un titre **sans son affiche**. `deletedAt` n'aurait alors servi à rien.

/// Ce qu'une passe de maintenance a réellement fait.
///
/// **Des comptes et non un booléen** : une passe d'entretien qui dit « terminé » sans dire ce
/// qu'elle a supprimé est une passe qu'on ne peut pas relire. C'est aussi ce qui permet de
/// vérifier l'idempotence — un second tour doit rendre un rapport **vide**.
public struct MaintenanceReport: Sendable, Hashable {
    /// Attachements supprimés faute de propriétaire.
    public var orphanAttachmentsRemoved = 0
    /// Attachements qui en avaient **plusieurs**, ramenés à un seul.
    public var multiOwnerAttachmentsRepaired = 0
    /// Crédits supprimés faute de personne ou de titre.
    public var headlessCreditsRemoved = 0
    /// Médias qu'aucun attachement ne désigne. **Comptés, jamais supprimés.**
    ///
    /// **La première version les supprimait, et c'était une destruction de données.** Un média
    /// sans propriétaire est un **état de première classe** dans ce dépôt, pas un déchet :
    /// `MediaRepository.detach` l'écrit — « le média n'est pas supprimé, et c'est délibéré : il
    /// devient orphelin, ce que le filtre de galerie de `L1 bis` sait montrer » — et
    /// `GalleryFilter.MediaSource.orphan` le rend filtrable, sous le libellé « Sans
    /// rattachement ».
    ///
    /// Trois gestes ordinaires en produisent : détacher une image, **remplacer une jaquette**
    /// (`setSingle` détache l'ancienne), et supprimer un attachement orphelin de fusion. Les
    /// détruire au lancement suivant aurait fait perdre l'ancienne jaquette de chaque titre
    /// dont on change l'affiche, sans corbeille et sans trace.
    ///
    /// La fiche `L16` dit « médias non référencés » sans dire « supprimer » ; le bloc `7g`
    /// dessine « **Analyser** » à côté de « Vider maintenant ». Ce compte est ce qu'Analyser
    /// affiche.
    public var unreferencedAssets = 0
    /// Entités purgées de la corbeille, par type.
    public var purgedByEntity: [String: Int] = [:]

    public init() {}

    public var purgedCount: Int { purgedByEntity.values.reduce(0, +) }

    /// `true` si la passe n'a **rien modifié**. C'est la forme que doit prendre le second tour,
    /// et c'est ainsi que l'idempotence se vérifie.
    ///
    /// `unreferencedAssets` n'y entre pas : c'est une **observation**, pas une action. Un
    /// catalogue qui porte trois orphelins en portera toujours trois au second tour, et les
    /// compter dans `isEmpty` ferait échouer l'idempotence sur une base parfaitement saine.
    public var isEmpty: Bool {
        orphanAttachmentsRemoved == 0 && multiOwnerAttachmentsRepaired == 0
            && headlessCreditsRemoved == 0 && purgedCount == 0
    }
}

/// L'entretien : orphelins, médias non référencés, purge de la corbeille.
///
/// `@MainActor` comme les repositories : elle touche des `@Model`, qui appartiennent au
/// contexte qui les a lus.
@MainActor
public struct MaintenanceService {

    /// La durée de rétention à la corbeille.
    ///
    /// Source : `docs/03` §« Corbeille / restauration » — « `deletedAt` + purge à **30 jours** »,
    /// et `docs/02` §« Suppressions » qui répète le chiffre. C'est une durée de calendrier, pas
    /// un nombre de secondes rond : voir `expiry(from:)`.
    public nonisolated static let retentionDays = 30

    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// La date avant laquelle une entité à la corbeille est expirée.
    ///
    /// **Calculée par le calendrier et non par `now - 30 * 86 400`.** Trente jours ne font pas
    /// 2 592 000 secondes quand un changement d'heure tombe au milieu : la soustraction en
    /// secondes purgerait une heure trop tôt ou trop tard selon le sens. L'écart est petit, et
    /// il porte sur une opération **irréversible** — c'est précisément là qu'on ne prend pas
    /// l'approximation qui simplifie.
    /// **Le repli est `.distantPast` et non `now`, et ce n'est pas un détail de style.** Avec
    /// `?? now`, un échec du calcul de calendrier rendrait `deletedAt < now` vrai pour **tout**
    /// ce qui est à la corbeille : la corbeille entière serait purgée en un tour. Le repli d'une
    /// fonction irréversible se choisit du côté où l'on ne perd rien — ici, ne purger personne.
    public nonisolated static func expiry(from now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -retentionDays, to: now) ?? .distantPast
    }

    /// Joue la passe complète.
    ///
    /// - Parameters:
    ///   - now: l'instant de référence. Injectable pour que les tests n'aient pas à attendre
    ///     trente jours, et pour qu'ils prennent un instant **quelconque** plutôt que minuit.
    ///   - calendar: le calendrier, pour la même raison.
    /// - Returns: ce qui a été fait. Un second appel immédiat doit rendre `isEmpty`.
    /// - Throws: l'erreur de `ModelContext.save()` ou d'un `fetch`. **Elle remonte plutôt
    ///   qu'être avalée** : une passe qui échoue à mi-chemin laisse la base dans un état que
    ///   l'appelant doit connaître — et comme la passe est idempotente, la relancer est sans
    ///   danger. C'est l'appelant qui décide si ça vaut un message ; au lancement, `CineShelfApp`
    ///   choisit de ne pas bloquer l'ouverture pour un ménage.
    @discardableResult
    public func run(now: Date = .now, calendar: Calendar = .current) throws -> MaintenanceReport {
        var report = MaintenanceReport()
        // **Sans ce repli, un échec à mi-passe laisse les suppressions ARMÉES.** Les
        // `context.delete` des étapes précédentes restent en attente dans le contexte
        // principal, et la première écriture de l'interface — un repository quelconque suivi
        // d'un `save()` — les commite. On obtiendrait une purge partielle, non journalisée,
        // déclenchée par une action sans rapport, à un instant arbitraire.
        // **Sa portée s'arrête à la purge, et il faut le dire.** L'étape 1 sauvegarde en son
        // sein — SwiftData n'applique `nullify` et `cascade` qu'au `save()`, et les dérivés se
        // recalculent après. Un échec survenu ensuite annule donc les étapes 2 à 4, pas la
        // purge. C'est acceptable parce que la purge est la seule étape irréversible **par
        // nature** : ce qu'elle supprime était expiré, et la relancer donnera le même résultat.
        var committed = false
        defer { if !committed { context.rollback() } }

        // 1. La purge d'abord — elle **produit** des orphelins et des médias non référencés,
        //    que les étapes suivantes ramassent dans le même tour.
        report.purgedByEntity = try purgeExpiredTrash(before: Self.expiry(from: now, calendar: calendar))

        // 2. Les attachements sans propriétaire, ou avec plusieurs.
        let attachments = try repairAttachments()
        report.orphanAttachmentsRemoved = attachments.removed
        report.multiOwnerAttachmentsRepaired = attachments.repaired

        // 3. Les crédits décapités. Après la purge, parce que c'est elle qui en fabrique.
        report.headlessCreditsRemoved = try removeHeadlessCredits()

        // 4. Les médias que plus rien ne référence. **En dernier**, et c'est tout le sujet de
        //    l'ordre : les étapes 1 à 3 ont supprimé des attachements, donc libéré des médias.
        report.unreferencedAssets = try countUnreferencedAssets()

        try context.save()
        committed = true
        return report
    }

    // MARK: 1 · La corbeille

    /// Supprime définitivement ce qui traîne à la corbeille depuis plus de trente jours.
    ///
    /// **Une personne se purge par un chemin à elle**, et c'est la trouvaille de la sonde :
    /// `Person.credits` ne déclare pas `deleteRule: .cascade` — seuls `flags`, `handles`,
    /// `attachments` et `links` l'ont. Un `context.delete(person)` laisse donc ses crédits en
    /// place avec `person == nil`, mesuré **2 crédits sur 2**. Un crédit sans personne est une
    /// ligne de générique vide : il ne s'affiche pas, il ne se restaure pas — la personne est
    /// partie pour de bon — et il compte quand même dans `title.credits`.
    ///
    /// **Le schéma est fermé depuis le 2026-08-03**, donc la règle de suppression ne se corrige
    /// pas ici : ce serait un `VersionedSchema` et un `MigrationStage` pour un défaut qui se
    /// répare dans le repository. C'est le même arbitrage que l'unicité de `Genre.nameKey`, que
    /// CloudKit interdit de déclarer et que le code tient à la main.
    private func purgeExpiredTrash(before expiry: Date) throws -> [String: Int] {
        var counts: [String: Int] = [:]
        // Les entités **vivantes** dont une relation vient d'être coupée par une purge.
        //
        // **Elles doivent être rafraîchies, et rien ne le faisait.** `Genre.titles` et
        // `TitleCollection.titles` sont en `nullify` : purger un genre le retire des titres
        // vivants, mais `filterKeys` garde `FilterKey.genre(id)` — une clé morte qui ne
        // disparaîtra jamais, puisque plus aucune écriture ne touchera ce titre. C'est la règle
        // « `refreshDerived()` à chaque écriture » appliquée aux mutations **indirectes**, qui
        // sont précisément celles qu'on oublie.
        var touched: Set<Title> = []
        var touchedPeople: Set<Person> = []

        for person in try expired(Person.self, before: expiry) {
            for credit in person.credits ?? [] {
                touched.formUnion([credit.title].compactMap { $0 })
                context.delete(credit)
            }
            context.delete(person)
            counts["person", default: 0] += 1
        }
        for title in try expired(Title.self, before: expiry) {
            context.delete(title)
            counts["title", default: 0] += 1
        }
        for collection in try expired(TitleCollection.self, before: expiry) {
            let orphaned = collection.titles ?? []
            context.delete(collection)
            counts["collection", default: 0] += 1
            touched.formUnion(orphaned)
        }
        for genre in try expired(Genre.self, before: expiry) {
            touched.formUnion(genre.titles ?? [])
            touchedPeople.formUnion(genre.people ?? [])
            context.delete(genre)
            counts["genre", default: 0] += 1
        }
        for link in try expired(SavedLink.self, before: expiry) {
            context.delete(link)
            counts["savedLink", default: 0] += 1
        }
        for asset in try expired(MediaAsset.self, before: expiry) {
            // **Pas de boucle sur les attachements ici** : `MediaAsset` déclare
            // `@Relationship(deleteRule: .cascade, inverse: \MediaAttachment.asset)`, donc la
            // cascade s'en charge — comme pour `crops` et `flags`. La première version les
            // supprimait à la main, ce qui refaisait un balayage complet de la table **par
            // asset purgé**. Vérifié dans `MediaAsset.swift`, et non supposé : c'est
            // exactement l'inverse de `Person.credits`, où la cascade manque vraiment.
            context.delete(asset)
            counts["mediaAsset", default: 0] += 1
        }

        // **Un `save()` ici, et il n'est pas facultatif.** SwiftData n'applique les règles
        // `nullify` et `cascade` qu'à la sauvegarde : avant elle, `title.genres` contient encore
        // le genre supprimé, donc `refreshDerived()` recomposerait exactement les mêmes clés —
        // y compris celle du genre qui part. Mesuré par le test qui a rougi sur
        // `dune.filterKeys` : la correction était écrite et ne servait à rien.
        //
        // C'est la même famille que « un test de `#Predicate` passe par le magasin » : ce qui
        // est en attente ne se comporte pas comme ce qui est écrit.
        try context.save()

        // Puis, et seulement sur ce qui a survécu : un titre purgé n'a plus rien à recalculer.
        for title in touched where !title.isDeleted && title.deletedAt == nil {
            title.refreshDerived()
        }
        for person in touchedPeople where !person.isDeleted && person.deletedAt == nil {
            person.refreshDerived()
        }
        return counts
    }

    /// Les entités à la corbeille depuis assez longtemps.
    ///
    /// **Le prédicat est construit à la main et le filtrage se fait en Swift** : `deletedAt` est
    /// une date optionnelle, et un `#Predicate` sur `Optional<Date>` comparé à une borne est
    /// précisément le genre d'expression dont la traduction SQL surprend. Le volume est celui de
    /// la corbeille, pas du catalogue.
    private func expired<T: PersistentModel & Trashable>(
        _ type: T.Type, before expiry: Date
    ) throws -> [T] {
        try context.fetch(FetchDescriptor<T>()).filter {
            guard let deletedAt = $0.deletedAt else { return false }
            return deletedAt < expiry
        }
    }

    // MARK: 2 · Les attachements

    /// Rétablit l'invariante `hasExactlyOneOwner`.
    ///
    /// Deux cas, et ils ne se traitent pas pareil :
    ///
    /// - **aucun propriétaire** — l'attachement ne désigne plus rien, il est supprimé. C'est le
    ///   cas que `docs/04` §« Ce que CloudKit ne garantit pas » décrit : « `MediaAttachment`
    ///   orphelins si un parent est supprimé pendant qu'un autre appareil y attache un média » ;
    /// - **plusieurs propriétaires** — l'attachement est *réparé* et non supprimé, parce qu'il
    ///   porte une donnée réelle : une image attachée à un titre **et** à une personne est le
    ///   résultat d'une fusion CloudKit, et supprimer le tout ferait perdre l'image aux deux.
    ///   Le titre est gardé en priorité, puis la personne, puis la collection — un ordre stable
    ///   vaut mieux qu'un choix arbitraire qui différerait d'un appareil à l'autre.
    private func repairAttachments() throws -> (removed: Int, repaired: Int) {
        var removed = 0
        var repaired = 0
        for attachment in try allAttachments() where !attachment.hasExactlyOneOwner {
            let owners = [attachment.title != nil, attachment.person != nil, attachment.collection != nil]
            if owners.allSatisfy({ !$0 }) {
                context.delete(attachment)
                removed += 1
            } else {
                split(attachment)
                repaired += 1
            }
        }
        return (removed, repaired)
    }

    /// Sépare un attachement à plusieurs propriétaires en un attachement par propriétaire.
    ///
    /// **Scinder plutôt que nullifier, et la première version nullifiait.** Elle gardait le
    /// titre et posait `person = nil` — ce qui fait perdre l'image à la personne, définitivement
    /// : un `MediaAttachment` n'a pas de `deletedAt`, il n'y a pas de corbeille pour lui. Si
    /// c'était son seul portrait, sa fiche devenait vide sans un mot.
    ///
    /// L'attachement n'est qu'une **arête** vers un `MediaAsset` : en créer une seconde ne
    /// duplique aucune image, et les deux propriétaires gardent la leur. C'est la seule
    /// réparation qui ne perde rien, et le raisonnement qui justifiait de ne pas supprimer
    /// l'attachement — « ça ferait perdre l'image aux deux » — conduit ici jusqu'au bout.
    private func split(_ attachment: MediaAttachment) {
        guard let asset = attachment.asset else { return }
        // Le titre garde l'attachement d'origine : un ordre stable, pour que deux appareils
        // qui réparent la même fusion aboutissent au même état.
        let owners: [(Person?, TitleCollection?)] = [
            (attachment.person, nil), (nil, attachment.collection)
        ]
        if attachment.title != nil {
            attachment.person = nil
            attachment.collection = nil
            for (person, collection) in owners where person != nil || collection != nil {
                let extra = MediaAttachment(slot: attachment.slot, orderIndex: attachment.orderIndex)
                extra.asset = asset
                extra.person = person
                extra.collection = collection
                context.insert(extra)
            }
        } else if attachment.person != nil, let collection = attachment.collection {
            attachment.collection = nil
            let extra = MediaAttachment(slot: attachment.slot, orderIndex: attachment.orderIndex)
            extra.asset = asset
            extra.collection = collection
            context.insert(extra)
        }
    }

    private func allAttachments() throws -> [MediaAttachment] {
        try context.fetch(FetchDescriptor<MediaAttachment>())
    }

    // MARK: 3 · Les crédits décapités

    /// Supprime les crédits qui ne relient plus deux entités.
    ///
    /// Un `Credit` est une **arête** entre un titre et une personne : privé de l'un des deux, il
    /// ne porte plus rien d'exploitable — `characterName` sans personne ne désigne personne — et
    /// il continue de compter dans `title.credits`, donc de gonfler un générique avec des lignes
    /// vides.
    private func removeHeadlessCredits() throws -> Int {
        var removed = 0
        for credit in try context.fetch(FetchDescriptor<Credit>())
        where credit.person == nil || credit.title == nil {
            context.delete(credit)
            removed += 1
        }
        return removed
    }

    // MARK: 4 · Les médias non référencés

    /// **Compte** les médias que plus aucun attachement ne désigne. Il n'en supprime aucun.
    ///
    /// **Une référence depuis la corbeille est une référence, et c'est le piège de la tâche.**
    /// Mesuré : un asset attaché à un titre à la corbeille est encore attaché — l'attachement
    /// survit à `softDelete`, qui ne fait que poser une date. Compter ce média comme non
    /// référencé le supprimerait, et restaurer le titre rendrait alors une fiche **sans
    /// affiche** : `deletedAt` n'aurait servi à rien, ce qui est exactement ce qu'il est là pour
    /// éviter.
    ///
    /// Le parcours se fait donc sur **tous** les attachements sans filtrer sur l'état de leur
    /// propriétaire. C'est involontairement simple, et c'est le point à ne pas « optimiser ».
    ///
    /// Un média à la corbeille mais **encore attaché** n'est pas supprimé ici non plus : c'est
    /// l'étape 1 qui le purgera, à sa date, avec ses attachements.
    private func countUnreferencedAssets() throws -> Int {
        let referenced = Set(try allAttachments().compactMap { $0.asset?.id })
        return try context.fetch(FetchDescriptor<MediaAsset>())
            .filter { !referenced.contains($0.id) }
            .count
    }
}

// MARK: - Ce qui a une corbeille

/// Une entité qui se met à la corbeille au lieu de se supprimer.
///
/// **Un protocole plutôt que six branches recopiées** : la passe de purge fait la même chose
/// pour chacune, et une septième entité à corbeille se brancherait en ajoutant une ligne de
/// conformité. Six recopies, c'est six endroits où en oublier un.
public protocol Trashable {
    var deletedAt: Date? { get set }
}

extension Title: Trashable {}
extension Person: Trashable {}
extension TitleCollection: Trashable {}
extension Genre: Trashable {}
extension SavedLink: Trashable {}
extension MediaAsset: Trashable {}
