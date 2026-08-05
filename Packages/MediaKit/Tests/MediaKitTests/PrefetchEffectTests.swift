import CoreGraphics
import Foundation
import Testing

@testable import MediaKit

// MARK: - V3 · Le préchargement fait-il quelque chose ?
//
// **Quatre sessions durant, le préchargement n'était qu'une intention** : l'API existait,
// aucune vue ne l'appelait, et rien ne mesurait son effet. C'est le premier endroit où la
// question se pose pour de vrai, et elle mérite une réponse chiffrée plutôt qu'une
// affirmation.
//
// **Ce qui est assené, et ce qui est seulement rapporté.** `CLAUDE.md` l'exige, et la mesure
// du 2026-08-04 le justifie — décodage de vignette 15 ms en local, 266 ms sur le runner
// GitHub. Donc :
//
// - **assené** : le *mécanisme*. Un affichage qui suit un préchargement terminé trouve son
//   image en mémoire ; sans préchargement il ne trouve rien. Ce rapport est indépendant de la
//   machine, parce que le préchargement est **drainé** avant l'affichage suivant — ce qui est
//   exactement le cas d'un défilement plus lent que le décodage, donc le cas normal ;
// - **rapporté seulement** : le *recouvrement* réel avec un défilement plus rapide que le
//   décodage. Ce chiffre dépend de la machine, il n'est donc l'objet d'aucune assertion — il
//   s'imprime, et c'est à lui qu'on demande si le préchargement sert.

@Suite("Effet du préchargement")
struct PrefetchEffectTests {

    /// Le gabarit d'une vignette de galerie : `poster.l`, en 2:3.
    private static let target = CGSize(width: 140, height: 210)

    private struct Bench {
        let cache: ThumbnailCache
        let ids: [UUID]
        let directory: URL

        func tearDown() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    /// Un cache neuf et `count` médias distincts qui partagent les mêmes octets.
    ///
    /// Les octets sont partagés exprès : ce qu'on mesure est le coût de **génération** d'une
    /// vignette, pas celui de fabriquer deux cents images différentes. Les identifiants, eux,
    /// sont distincts — sans quoi la clé de cache serait la même et tout serait un succès.
    private func makeBench(count: Int) async throws -> Bench {
        let directory = try TestImage.makeScratchDirectory()
        let png = try TestImage.makePNGData(width: 600, height: 900)
        let ingested = try MediaIngestor().ingest(data: png)

        let originals = Originals()
        let ids = (0..<count).map { _ in UUID() }
        for id in ids {
            await originals.register(id, data: ingested.data)
        }

        let cache = ThumbnailCache(
            source: { await originals.data(for: $0) },
            directory: directory,
            prefetchConcurrency: ThumbnailCache.defaultPrefetchConcurrency)
        return Bench(cache: cache, ids: ids, directory: directory)
    }

    /// Le nombre d'affichages qui ont trouvé leur vignette déjà en mémoire.
    ///
    /// La présence est relevée **avant** de demander l'image, sinon on mesurerait sa propre
    /// demande. `drained` sépare les deux régimes : drainé, on mesure le mécanisme ; non
    /// drainé, on mesure le recouvrement, qui dépend de la machine.
    private func hits(
        over trace: [Int], prefetching: Bool, drained: Bool, in bench: Bench
    ) async -> Int {
        var scheduler = PrefetchScheduler(window: PrefetchWindow(ahead: 8, behind: 2), step: 2)
        var hits = 0

        for index in trace {
            let wasWarm = await bench.cache.hasMemoryEntry(
                for: bench.ids[index], targetSize: Self.target, scale: 2)
            if wasWarm { hits += 1 }
            _ = await bench.cache.thumbnail(
                for: bench.ids[index], targetSize: Self.target, scale: 2)

            guard prefetching,
                let order = scheduler.advance(appeared: index, count: bench.ids.count)
            else { continue }

            await bench.cache.prefetch(
                order.prefetch.map { bench.ids[$0] }, targetSize: Self.target, scale: 2)
            await bench.cache.cancelPrefetch(
                order.cancel.map { bench.ids[$0] }, targetSize: Self.target, scale: 2)

            if drained {
                await bench.cache.drainPrefetches()
            } else {
                // Le temps qu'un doigt met à faire défiler d'un élément. Court exprès : c'est
                // le régime où le décodage ne suit pas, donc le pire cas pour le
                // préchargement.
                try? await Task.sleep(for: .milliseconds(5))
            }
        }
        return hits
    }

    @Test("Sans préchargement, aucun affichage ne trouve son image en cache")
    func withoutPrefetchNothingIsWarm() async throws {
        let bench = try await makeBench(count: 24)
        defer { bench.tearDown() }

        let trace = Array(0..<24)
        let warm = await hits(over: trace, prefetching: false, drained: false, in: bench)

        // La ligne de base, et elle est la moitié de la mesure : sans elle, « 23 succès sur
        // 24 » ne dirait pas si le préchargement y est pour quelque chose.
        #expect(warm == 0)
    }

    @Test("Avec préchargement, l'affichage trouve son image déjà décodée")
    func prefetchWarmsWhatComesNext() async throws {
        let bench = try await makeBench(count: 24)
        defer { bench.tearDown() }

        let trace = Array(0..<24)
        let warm = await hits(over: trace, prefetching: true, drained: true, in: bench)

        // Le premier affichage ne peut pas être chaud : rien n'a encore été commandé. Les
        // vingt-trois suivants doivent l'être. La borne laisse deux éléments de jeu pour
        // l'éviction de `NSCache`, qui peut vider à tout moment.
        #expect(warm >= trace.count - 3)
        print("[V3] préchargement drainé : \(warm) affichages chauds sur \(trace.count)")
    }

    @Test("Recouvrement réel — rapporté, jamais assené")
    func overlapIsReportedNotAsserted() async throws {
        let count = 24
        let trace = Array(0..<count)

        let cold = try await makeBench(count: count)
        defer { cold.tearDown() }
        let baseline = await hits(over: trace, prefetching: false, drained: false, in: cold)

        let warmed = try await makeBench(count: count)
        defer { warmed.tearDown() }
        let overlapped = await hits(over: trace, prefetching: true, drained: false, in: warmed)

        // **Aucune assertion sur `overlapped`.** Sur un runner GitHub, virtualisé et sans
        // accélération d'image, le décodage peut être vingt fois plus lent qu'en local : un
        // seuil ici serait un budget d'expérience utilisateur assené sur une machine qui n'en
        // a pas les moyens, et c'est exactement ce que `CLAUDE.md` interdit. Ce qui est
        // assené est la ligne de base, qui ne dépend d'aucune horloge.
        #expect(baseline == 0)
        print(
            """
            [V3] recouvrement à 5 ms par pas : \(overlapped) affichages chauds sur \(count), \
            contre \(baseline) sans préchargement
            """)
    }
}
