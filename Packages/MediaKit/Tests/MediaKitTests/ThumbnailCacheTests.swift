import CoreGraphics
import Foundation
import Testing

@testable import MediaKit

/// Sérialisée : le test de performance alloue quelques centaines de mégaoctets
/// de `CGImage`, et `NSCache` évince sous pression mémoire — y compris les
/// entrées des autres tests s'ils tournent en parallèle.
@Suite("Cache de vignettes", .serialized)
struct ThumbnailCacheTests {
    @Test("La taille demandée est arrondie au preset qui la couvre")
    func presetsCoverRequestedSizes() {
        #expect(ThumbnailPreset.covering(CGSize(width: 104, height: 156)) == .thumb)
        #expect(ThumbnailPreset.covering(CGSize(width: 148, height: 222)) == .card)
        #expect(ThumbnailPreset.covering(CGSize(width: 340, height: 227)) == .card)
        #expect(ThumbnailPreset.covering(CGSize(width: 900, height: 500)) == .hero)
        #expect(ThumbnailPreset.covering(CGSize(width: 4000, height: 3000)) == .hero)
    }

    @Test("Le nom de fichier suit docs/04 §4")
    func keyFollowsTheDocumentedShape() throws {
        let assetID = try #require(UUID(uuidString: "1B4E28BA-2FA1-11D2-883F-0016D3CCA427"))
        let key = ThumbnailCache.key(assetID: assetID, preset: .card, scale: 2)

        #expect(key == "1B4E28BA-2FA1-11D2-883F-0016D3CCA427-card@2x")
    }

    @Test("La vignette est générée, plus petite que l'original, et bornée par le preset")
    func thumbnailIsGeneratedAndBounded() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }

        let image = await fixture.cache.thumbnail(
            for: fixture.assetID,
            targetSize: CGSize(width: 148, height: 222),
            scale: 2
        )

        let thumbnail = try #require(image)
        #expect(max(thumbnail.width, thumbnail.height) == ThumbnailPreset.card.maxPixelSize(scale: 2))
    }

    @Test("Un asset inconnu ne donne pas de vignette")
    func unknownAssetYieldsNil() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }

        let image = await fixture.cache.thumbnail(
            for: UUID(),
            targetSize: CGSize(width: 148, height: 222),
            scale: 2
        )

        #expect(image == nil)
    }

    @Test("La vignette est écrite sur disque, et relue sans toucher à l'original")
    func diskCacheIsUsedOnSecondCall() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let size = CGSize(width: 148, height: 222)

        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        await fixture.cache.flushPendingWrites()
        #expect(fixture.sourceReads.value == 1)

        let file = fixture.directory
            .appendingPathComponent(ThumbnailCache.key(assetID: fixture.assetID, preset: .card, scale: 2))
            .appendingPathExtension("heic")
        #expect(FileManager.default.fileExists(atPath: file.path))

        // Un cache neuf sur le même dossier : la mémoire est vide, le disque non.
        let second = ThumbnailCache(source: fixture.source, directory: fixture.directory)
        let image = await second.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)

        #expect(image != nil)
        #expect(fixture.sourceReads.value == 1)
    }

    /// `NSCache` peut évincer à tout moment sous pression mémoire : on vérifie
    /// que l'entrée est bien posée, et non qu'elle survit indéfiniment.
    @Test("La vignette est posée en mémoire dès le premier appel")
    func thumbnailLandsInMemory() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let size = CGSize(width: 148, height: 222)

        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)

        #expect(await fixture.cache.hasMemoryEntry(for: fixture.assetID, targetSize: size, scale: 2))
        #expect(fixture.sourceReads.value == 1)
    }

    @Test("Une fois le cache chaud, l'original n'est plus relu")
    func warmCacheNeverReadsTheOriginalAgain() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let size = CGSize(width: 148, height: 222)

        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        await fixture.cache.flushPendingWrites()

        for _ in 0..<5 {
            _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        }

        #expect(fixture.sourceReads.value == 1)
    }

    @Test("Purger la mémoire force une relecture, purger le disque aussi")
    func purgingForcesRegeneration() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let size = CGSize(width: 148, height: 222)

        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        await fixture.cache.flushPendingWrites()
        await fixture.cache.purgeMemoryCache()
        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        // Le disque a suffi.
        #expect(fixture.sourceReads.value == 1)

        await fixture.cache.flushPendingWrites()
        await fixture.cache.purgeMemoryCache()
        await fixture.cache.purgeDiskCache()
        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        #expect(fixture.sourceReads.value == 2)
    }

    @Test("Deux presets donnent deux entrées de cache distinctes")
    func presetsAreCachedSeparately() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }

        let small = await fixture.cache.thumbnail(
            for: fixture.assetID,
            targetSize: CGSize(width: 104, height: 156),
            scale: 1
        )
        let large = await fixture.cache.thumbnail(
            for: fixture.assetID,
            targetSize: CGSize(width: 340, height: 227),
            scale: 1
        )

        let smallWidth = try #require(small).width
        let largeWidth = try #require(large).width
        #expect(smallWidth < largeWidth)
        #expect(fixture.sourceReads.value == 2)
    }

    @Test("Le cache disque est ramené sous sa limite, les plus anciennes d'abord")
    func diskCacheIsPurgedOverTheLimit() async throws {
        let fixture = try await Fixture(diskLimit: 4_096)
        defer { fixture.tearDown() }

        for index in 0..<12 {
            let side = 100 + index
            _ = await fixture.cache.thumbnail(
                for: fixture.assetID,
                targetSize: CGSize(width: side, height: side),
                scale: CGFloat(1 + index % 3)
            )
        }
        await fixture.cache.flushPendingWrites()
        await fixture.cache.purgeDiskCacheIfNeeded()

        let total = try totalSize(of: fixture.directory)
        #expect(total <= 4_096)
    }

    /// Les budgets de `docs/04` §4, un par chemin : génération à froid < 30 ms,
    /// relecture disque < 5 ms, relecture mémoire < 1 ms.
    @Test("Performance : 200 vignettes")
    func twoHundredThumbnails() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let size = CGSize(width: 148, height: 222)
        let pixels = ThumbnailPreset.card.maxPixelSize(scale: 2)
        let original = try #require(await fixture.originalBytes())
        let clock = ContinuousClock()

        // 1. Le chemin d'affichage seul : décodage partiel et redimension.
        let decoding = clock.measure {
            for _ in 0..<200 {
                _ = ImageDecoder.thumbnail(from: original, maxPixelSize: pixels, cacheImmediately: true)
            }
        }

        // 2. Le même travail au travers du cache, écritures disque comprises.
        let assetIDs = (0..<200).map { _ in UUID() }
        for assetID in assetIDs { await fixture.register(assetID) }
        let throughCache = await clock.measure {
            for assetID in assetIDs {
                _ = await fixture.cache.thumbnail(for: assetID, targetSize: size, scale: 2)
            }
            await fixture.cache.flushPendingWrites()
        }

        // 3. Relecture depuis le disque, mémoire vidée.
        await fixture.cache.purgeMemoryCache()
        let fromDisk = await clock.measure {
            for assetID in assetIDs {
                _ = await fixture.cache.thumbnail(for: assetID, targetSize: size, scale: 2)
            }
        }

        // 4. Relecture mémoire sur un lot qui tient sous la limite du NSCache.
        let hot = Array(assetIDs.prefix(20))
        for assetID in hot { _ = await fixture.cache.thumbnail(for: assetID, targetSize: size, scale: 2) }
        let fromMemory = await clock.measure {
            for _ in 0..<10 {
                for assetID in hot {
                    _ = await fixture.cache.thumbnail(for: assetID, targetSize: size, scale: 2)
                }
            }
        }

        print(
            """
            PERF vignette \(pixels) px depuis un original 2000×3000, par unité :
              décodage + redimension seuls : \(Self.formatted(decoding, over: 200)) ms
              au travers du cache, écriture disque comprise : \
            \(Self.formatted(throughCache, over: 200)) ms
              relecture depuis le disque : \(Self.formatted(fromDisk, over: 200)) ms
              relecture depuis la mémoire : \(Self.formatted(fromMemory, over: 200)) ms
            """
        )

        // Ce que ce test peut affirmer, et ce qu'il ne peut pas.
        //
        // Il a longtemps assené les budgets de `docs/04` §4 tels quels — 30 ms de
        // génération à froid, 5 ms de relecture disque, 1 ms de relecture mémoire —
        // et il échouait sur la CI depuis le 2 août. Le runner GitHub est virtualisé
        // et son accélération d'image n'est pas disponible (`AppleM2ScalerParavirtDriver`
        // échoue au démarrage) : le décodage y retombe sur un chemin logiciel.
        //
        //   | Chemin              | En local | Sur le runner |
        //   |---------------------|----------|---------------|
        //   | décodage à froid    | 15,2 ms  | 266,5 ms      |
        //   | relecture disque    |  2,5 ms  |  15,8 ms      |
        //
        // Un facteur 17 sur le même code. Assener un budget d'expérience utilisateur
        // sur ce matériel-là ne mesure pas le code, ça mesure la machine — et
        // `docs/04` §4 le dit lui-même : ces chiffres se vérifient avec Instruments
        // sur le plus vieil appareil visé, pas sur un Mac, et encore moins sur un
        // runner partagé.
        //
        // Le test assène donc deux choses différentes.

        // 1. Des **rapports**, indépendants de la machine. C'est eux qui portent le
        //    sens : ce qui protège le défilement, ce n'est pas la vitesse de
        //    génération, c'est que le défilement n'y passe jamais. Un cache qui
        //    cesserait d'être lu ramènerait ces rapports à 1 — sur n'importe quelle
        //    machine, y compris la plus lente.
        //    Mesuré : disque 6× moins cher que le décodage en local, 17× sur la CI.
        #expect(
            Self.seconds(fromDisk) * 3 < Self.seconds(decoding),
            "La relecture disque doit être franchement moins chère qu'une génération à froid"
        )
        #expect(
            Self.seconds(fromMemory) * 3 < Self.seconds(fromDisk),
            "La relecture mémoire doit être franchement moins chère que le disque"
        )
        // `NSCache` peut évincer sous pression : la comparaison reste au sens large.
        #expect(Self.seconds(fromDisk) < Self.seconds(throughCache))

        // 2. Des **plafonds absolus généreux**, calés sur l'environnement le plus
        //    lent où ce test tourne réellement — la CI — et non sur le budget. Ils
        //    n'attrapent qu'une régression d'un ordre de grandeur, ce qui est
        //    exactement leur rôle : le budget d'UX, lui, se vérifie sur appareil.
        //    800 ms ≈ 3× les 266 ms du runner ; 60 ms ≈ 4× ses 15,8 ms.
        #expect(Self.milliseconds(decoding, over: 200) < 800)
        #expect(Self.milliseconds(fromDisk, over: 200) < 60)
    }

    private static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    /// Millisecondes par unité — la grandeur sur laquelle portent les budgets.
    private static func milliseconds(_ duration: Duration, over count: Int) -> Double {
        seconds(duration) / Double(count) * 1_000
    }

    /// La même valeur, pour l'affichage.
    private static func formatted(_ duration: Duration, over count: Int) -> String {
        String(format: "%.2f", milliseconds(duration, over: count))
    }

    private func totalSize(of directory: URL) throws -> Int {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        )
        return try files.reduce(0) { $0 + (try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
    }
}

// MARK: - L5 · Préchargement

extension ThumbnailCacheTests {

    /// La taille de la carte de grille, celle que `AssetPreset.card` demande.
    static let cardSize = CGSize(width: 196, height: 294)

    @Test("Le préchargement remplit le cache sans que personne n'attende")
    func prefetchFillsTheCacheOffThePath() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }

        // `prefetch` ne rend rien : c'est un ordre. La vignette doit exister ensuite,
        // alors qu'aucun appel à `thumbnail` n'a eu lieu avant.
        await fixture.cache.prefetch([fixture.assetID], targetSize: Self.cardSize, scale: 2)
        await fixture.cache.drainPrefetches()

        #expect(
            await fixture.cache.hasMemoryEntry(
                for: fixture.assetID, targetSize: Self.cardSize, scale: 2))
        #expect(fixture.sourceReads.value == 1)
    }

    @Test("Un affichage adopte le préchargement en vol plutôt que de le doubler")
    func displayAdoptsAnInFlightPrefetch() async throws {
        let fixture = try await Fixture(slowSourceBy: .milliseconds(150))
        defer { fixture.tearDown() }

        await fixture.cache.prefetch([fixture.assetID], targetSize: Self.cardSize, scale: 2)
        let image = await fixture.cache.thumbnail(
            for: fixture.assetID, targetSize: Self.cardSize, scale: 2)

        #expect(image != nil)
        // **La mesure qui porte le sens** : une seule lecture de l'original pour deux
        // demandes concurrentes. Sans coalescence, l'affichage aurait redécodé par-dessus
        // le préchargement — donc exactement le travail que le préchargement existe pour
        // éviter.
        #expect(fixture.sourceReads.value == 1)
    }

    @Test("L'annulation empêche le travail de se faire")
    func cancellationStopsTheWork() async throws {
        let fixture = try await Fixture(slowSourceBy: .milliseconds(200))
        defer { fixture.tearDown() }

        await fixture.cache.prefetch([fixture.assetID], targetSize: Self.cardSize, scale: 2)
        await fixture.cache.cancelPrefetch([fixture.assetID], targetSize: Self.cardSize, scale: 2)
        await fixture.cache.drainPrefetches()

        #expect(
            await fixture.cache.hasMemoryEntry(
                for: fixture.assetID, targetSize: Self.cardSize, scale: 2) == false)
    }

    @Test("Ce qu'un affichage attend n'est plus annulable")
    func adoptedWorkSurvivesCancellation() async throws {
        let fixture = try await Fixture(slowSourceBy: .milliseconds(150))
        defer { fixture.tearDown() }

        await fixture.cache.prefetch([fixture.assetID], targetSize: Self.cardSize, scale: 2)

        // L'affichage adopte, puis la vue qui avait préchargé sort de l'écran et annule.
        async let displayed = fixture.cache.thumbnail(
            for: fixture.assetID, targetSize: Self.cardSize, scale: 2)
        await fixture.cache.cancelPrefetch([fixture.assetID], targetSize: Self.cardSize, scale: 2)

        // Annuler ici laisserait la vue sans image, et rien ne le signalerait.
        #expect(await displayed != nil)
    }

    @Test("La file d'attente borne les préchargements simultanés")
    func prefetchConcurrencyIsBounded() async throws {
        let fixture = try await Fixture(prefetchConcurrency: 2, slowSourceBy: .milliseconds(200))
        defer { fixture.tearDown() }

        var ids = [fixture.assetID]
        for _ in 0..<7 {
            let extra = UUID()
            await fixture.register(extra)
            ids.append(extra)
        }

        await fixture.cache.prefetch(ids, targetSize: Self.cardSize, scale: 2)
        let load = await fixture.cache.prefetchLoad

        #expect(load.running == 2, "8 demandes, 2 créneaux")
        #expect(load.pending == 6)

        await fixture.cache.cancelAllPrefetches()
        await fixture.cache.drainPrefetches()
    }

    @Test("Une clé déjà demandée n'entre pas deux fois dans la file")
    func prefetchIgnoresDuplicates() async throws {
        let fixture = try await Fixture(prefetchConcurrency: 1, slowSourceBy: .milliseconds(200))
        defer { fixture.tearDown() }

        let other = UUID()
        await fixture.register(other)

        // Trois fois la même paire de clés : appeler `prefetch` à chaque événement de
        // défilement doit être sans conséquence.
        for _ in 0..<3 {
            await fixture.cache.prefetch(
                [fixture.assetID, other], targetSize: Self.cardSize, scale: 2)
        }
        let load = await fixture.cache.prefetchLoad

        #expect(load.running + load.pending == 2)

        await fixture.cache.cancelAllPrefetches()
        await fixture.cache.drainPrefetches()
    }

    @Test("Le préchargement ne rejoue pas ce que la mémoire porte déjà")
    func prefetchSkipsWhatIsAlreadyCached() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }

        _ = await fixture.cache.thumbnail(
            for: fixture.assetID, targetSize: Self.cardSize, scale: 2)
        let readsAfterDisplay = fixture.sourceReads.value

        await fixture.cache.prefetch([fixture.assetID], targetSize: Self.cardSize, scale: 2)
        await fixture.cache.drainPrefetches()

        #expect(fixture.sourceReads.value == readsAfterDisplay)
    }

}
