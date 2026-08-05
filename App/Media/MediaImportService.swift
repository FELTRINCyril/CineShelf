import CineShelfCore
import Foundation
import MediaKit
import SwiftData
import UniformTypeIdentifiers

// MARK: - V2 · L'import réel d'une image
//
// **Quatre gestes, un seul chemin.** `PhotosPicker`, `.fileImporter`, le glisser-déposer et
// le collage rendent tous des **octets** ; à partir de là il n'y a plus qu'une route :
//
//     octets -> MediaIngestor -> MediaAssetDraft -> findOrCreate -> attach
//
// Quatre chemins parallèles auraient donné quatre dédoublonnages, quatre redimensionnements
// et quatre façons d'échouer. Ce service est le point de convergence, et les vues n'y
// apportent que des `Data`.
//
// **Le dédoublonnage est gratuit et global.** `MediaRepository.findOrCreate(_:)` cherche par
// `checksum` — le sha256 des octets **source**, pas du HEIC produit (`docs/04` §4) — donc la
// même image importée depuis Photos puis déposée depuis le Finder ne crée qu'un asset. C'est
// aussi ce qui rend un import répété inoffensif.
//
// **Ce que ce service ne fait pas.** Il ne recadre pas : `CropEditor` écrit les `MediaCrop`
// séparément, parce qu'un recadrage se règle après avoir vu l'image, jamais à l'import. Et il
// n'annule pas : un import d'une image est immédiat, et la progression de `docs/04` §7 est
// pour l'import CSV, qui compte en milliers de lignes.

/// Le résultat d'un import, tel que l'écran doit le rapporter.
struct MediaImportOutcome {
    /// Les assets réellement attachés.
    let attached: [MediaAsset]
    /// Les images déjà présentes, retrouvées par leur empreinte.
    let deduplicated: Int
    /// Les fichiers refusés, avec leur raison — l'écran les nomme, il ne les compte pas.
    let failures: [Failure]

    struct Failure {
        let name: String
        let reason: String
    }

    var isEmpty: Bool { attached.isEmpty && deduplicated == 0 && failures.isEmpty }
}

/// Importe des images et les rattache à une entité.
@MainActor
struct MediaImportService {

    private let context: ModelContext
    private let ingestor = MediaIngestor()

    init(context: ModelContext) {
        self.context = context
    }

    /// Importe des octets et les rattache à un titre.
    ///
    /// - Parameters:
    ///   - payloads: les octets, avec un nom pour le rapport d'échec.
    ///   - title: le propriétaire.
    ///   - slot: `.gallery` accepte plusieurs images ; `.primary`, `.portrait` et
    ///     `.backdrop` en désignent **une**, et le précédent est alors détaché.
    /// - Returns: ce qui a été attaché, dédoublonné, refusé.
    func importImages(
        _ payloads: [Payload], into title: Title, slot: MediaSlot = .gallery
    ) -> MediaImportOutcome {
        let repository = MediaRepository(context: context)
        var attached: [MediaAsset] = []
        var deduplicated = 0
        var failures: [MediaImportOutcome.Failure] = []

        for payload in payloads {
            do {
                let ingested = try ingestor.ingest(data: payload.data)
                let draft = ingested.draft
                // **Avant** la création : `findOrCreate` ne dit pas s'il a créé ou trouvé,
                // donc on regarde d'abord. Sans ça, le rapport annoncerait « 3 importées »
                // quand trois doublons ont été retrouvés, et l'utilisateur croirait avoir
                // ajouté des images qui existaient déjà.
                let existing = try repository.asset(withChecksum: draft.checksum)
                let asset = try repository.findOrCreate(draft)

                if existing != nil {
                    deduplicated += 1
                    // Un doublon est quand même **rattaché** : la même image peut
                    // légitimement illustrer deux titres, et c'est tout l'intérêt de
                    // dédoublonner à l'octet plutôt qu'au rattachement.
                }

                if slot.isSingle {
                    repository.setSingle(asset, on: title, slot: slot)
                } else if isAlreadyAttached(asset, to: title, slot: slot) == false {
                    repository.attach(asset, to: title, slot: slot)
                }
                attached.append(asset)
            } catch {
                failures.append(.init(name: payload.name, reason: Self.reason(for: error)))
            }
        }

        return MediaImportOutcome(
            attached: attached, deduplicated: deduplicated, failures: failures)
    }

    /// La même image deux fois dans la galerie du même titre n'a aucun sens : elle
    /// s'afficherait en double, et le dédoublonnage à l'octet ne l'attrape pas puisqu'il porte
    /// sur l'asset, pas sur la pièce jointe.
    private func isAlreadyAttached(
        _ asset: MediaAsset, to title: Title, slot: MediaSlot
    ) -> Bool {
        (title.attachments ?? []).contains { $0.slot == slot && $0.asset?.id == asset.id }
    }

    /// Ce qu'on montre à l'utilisateur d'une erreur d'ingestion.
    ///
    /// Une phrase, pas un `localizedDescription` de `CoreGraphics` : « The operation couldn't
    /// be completed » n'aide personne à comprendre qu'il a déposé un PDF.
    private static func reason(for error: any Error) -> String {
        if error is MediaIngestionError { return "Format d'image non reconnu." }
        return "Lecture impossible."
    }

    /// Des octets et un nom.
    ///
    /// Le nom ne sert qu'au rapport d'échec : le pipeline ne le lit jamais, et un média n'a
    /// pas de nom de fichier en base — c'est son empreinte qui l'identifie.
    struct Payload {
        let name: String
        let data: Data

        /// Lit un fichier choisi par `.fileImporter` ou déposé depuis le Finder.
        ///
        /// **La coordination d'accès n'est pas optionnelle** : un fichier hors du bac à sable
        /// n'est lisible qu'entre `startAccessingSecurityScopedResource()` et son `stop`. Sans
        /// elle, l'import réussit en développement — où l'app n'est pas encore sandboxée de la
        /// même façon — et échoue une fois signée.
        static func read(fileURL: URL) throws -> Payload {
            let scoped = fileURL.startAccessingSecurityScopedResource()
            defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
            return Payload(
                name: fileURL.lastPathComponent, data: try Data(contentsOf: fileURL))
        }
    }
}

extension MediaSlot {
    /// Cet emplacement désigne-t-il **une** image ?
    ///
    /// `.gallery` en accepte autant qu'on veut ; les trois autres en désignent une seule, et
    /// en laisser deux rendrait `TitleFormat.primaryAsset` indéterminé — une jaquette qui
    /// change d'un lancement à l'autre selon l'ordre de stockage.
    var isSingle: Bool { self != .gallery }
}
