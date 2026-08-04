import CoreTransferable
import Foundation
import UniformTypeIdentifiers

// `CoreTransferable` et non SwiftUI : la conformité est de la logique, elle appartient donc
// à `CineShelfCore` (`docs/04` §1). Le bouton de partage et le `.fileExporter` viendront
// avec `V8`.

extension UTType {
    /// Le type de fichier d'une archive CineShelf.
    ///
    /// **Conforme à `.package`**, pas à `.data` : le paquet est un dossier, et c'est cette
    /// conformité qui fait que le Finder l'affiche comme un fichier unique et qu'AirDrop
    /// l'envoie d'un bloc au lieu de proposer un dossier à parcourir.
    ///
    /// Construit par extension de nom de fichier et **non** par `UTType(exportedAs:)`, qui
    /// *piège le processus* quand le type n'est pas déclaré dans l'`Info.plist` du bundle
    /// courant — donc sous `swift test`, où le binaire de test n'en a pas. C'est le même
    /// piège que CloudKit, qui termine le processus faute d'identifiant de paquet (journal
    /// du 2026-08-02). Ici, le type déclaré par l'app est trouvé quand il existe, et un
    /// type dynamique équivalent est fabriqué sinon : l'export fonctionne dans les deux
    /// cas, et rien ne s'arrête.
    public static var cineShelfArchive: UTType {
        UTType(filenameExtension: ArchiveLayout.fileExtension, conformingTo: .package) ?? .package
    }
}

/// Un paquet `.cineshelfarchive` sur le disque, transportable par le système.
///
/// Un chemin et non un contenu : l'archive est un dossier de plusieurs dizaines de
/// mégaoctets une fois les affiches dedans, et `Transferable` sait déplacer un fichier sans
/// le charger en mémoire. Une représentation par `Data` obligerait à tout lire pour un
/// AirDrop.
public struct ArchiveFile: Transferable, Sendable, Equatable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .cineShelfArchive) { archive in
            SentTransferredFile(archive.url)
        } importing: { received in
            // Le fichier reçu vit dans un emplacement temporaire que le système reprend au
            // retour de cette fermeture : on le déplace avant de rendre la valeur, sinon
            // l'URL portée pointerait vers un fichier disparu — et l'erreur ne se verrait
            // qu'à la relecture, loin d'ici.
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "cineshelf-recu-\(UUID().uuidString).\(ArchiveLayout.fileExtension)",
                    isDirectory: true)
            try FileManager.default.moveItem(at: received.file, to: destination)
            return ArchiveFile(url: destination)
        }
    }
}
