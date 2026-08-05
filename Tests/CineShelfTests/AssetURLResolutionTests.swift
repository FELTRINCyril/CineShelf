import CineShelfCore
import Foundation
import Testing

// `V2` · Le défaut le plus grave du dépôt, et le test qui l'empêche de revenir.
//
// **`MediaFill` chargeait ses images avec `AsyncImage(url:)`, donc par `URLSession`.** Or
// `AssetURL` fabrique des URL au schéma `cineshelf-asset://`, une convention **interne** qui
// porte un `UUID` du modèle jusqu'au `ThumbnailCache`. `URLSession` ne sait pas la résoudre,
// `phase.image` restait donc toujours `nil`, et les sept appelants de `MediaFill` rendaient
// un aplat : **aucune affiche ne s'est jamais affichée dans la nouvelle direction.**
//
// **Personne ne l'a vu parce que le catalogue ne pouvait pas le montrer.** Ses échantillons
// ont `imageURL: nil` — une tuile sans image y rend exactement le même aplat qu'une tuile
// dont le chargement échoue. Deux causes, une apparence.
//
// Ce que ce fichier verrouille est donc **la propriété**, pas le composant : une URL d'asset
// n'est pas chargeable par le réseau, elle ne se résout que par le cache. Un test de rendu
// n'aurait rien attrapé (le rendu était « correct » : un aplat), et un test d'intégration
// aurait demandé un magasin, un cache et une image réelle pour dire la même chose.

struct AssetURLResolutionTests {

    /// Un identifiant fixe, construit sans force unwrap : `swiftlint` le refuse **aussi**
    /// dans les tests, et une valeur en dur ne mérite de toute façon pas un `!`.
    private static let sampleID = UUID(
        uuid: (
            0x3F, 0x25, 0x04, 0xE0, 0x4F, 0x89, 0x11, 0xD3,
            0x9A, 0x0C, 0x03, 0x05, 0xE8, 0x2C, 0x33, 0x01
        ))

    @Test("Une URL d'asset porte le schéma interne, jamais un schéma réseau")
    func assetURLUsesTheInternalScheme() {
        let url = AssetURL.url(for: Self.sampleID, preset: .card)

        #expect(url.scheme == AssetURL.scheme)
        #expect(url.scheme != "http" && url.scheme != "https" && url.scheme != "file")
    }

    @Test("Le schéma interne n'est pas résoluble par URLSession, et c'est le piège")
    func theInternalSchemeIsNotNetworkLoadable() async throws {
        // Mesuré le 2026-08-05 : « unsupported URL ». C'est **exactement** ce que
        // `AsyncImage(url:)` fait sous le capot, donc exactement pourquoi il ne rendait rien.
        //
        // L'assertion porte sur `URLSession` et non sur `AsyncImage` parce que c'est la
        // couche qui décide : `AsyncImage` n'expose pas son erreur, il se replie
        // silencieusement sur sa branche de placeholder — la défaillance silencieuse qui a
        // coûté quatre sessions.
        let url = AssetURL.url(for: Self.sampleID, preset: .card)

        await #expect(throws: (any Error).self) {
            _ = try await URLSession.shared.data(from: url)
        }
    }

    @Test("Toute URL d'asset se décode en identifiant et preset")
    func everyAssetURLRoundTrips() throws {
        // Le contrat que le chargeur de l'app honore : si `decode` échoue, l'image ne se
        // charge pas — et c'est ce chemin qui remplace le réseau.
        for preset in [AssetPreset.thumb, .card, .hero] {
            let url = AssetURL.url(for: Self.sampleID, preset: preset)
            let decoded = try #require(AssetURL.decode(url), "\(preset.rawValue)")

            #expect(decoded.assetID == Self.sampleID)
            #expect(decoded.preset == preset)
        }
    }

    @Test("Une URL d'un autre schéma n'est pas décodée, elle reste au chargement normal")
    func foreignSchemesAreNotDecoded() throws {
        // `MediaAsset.externalURLString` existe : un média distant doit continuer à passer par
        // le chemin réseau. `decode` doit donc rendre `nil` plutôt que de deviner.
        let remote = try #require(URL(string: "https://example.org/poster.jpg"))

        #expect(AssetURL.decode(remote) == nil)
    }
}
