import CineShelfCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - V2 · Les quatre gestes d'import, sur un seul chemin
//
// `PhotosPicker`, `.fileImporter`, le glisser-déposer et le collage. Tous rendent des
// **octets**, et tous les remettent à `MediaImportService` : c'est là que le
// redimensionnement, le HEIC, le blurhash, l'empreinte et le dédoublonnage se font une fois
// pour les quatre.
//
// **Le glisser-déposer accepté partout, et c'est le bloc `9a` qui le dit** : l'indice de son
// état vide de galerie est « glisser-déposer accepté partout ». Ce modificateur est donc
// posé sur le conteneur, pas sur une zone dédiée — une cible de dépôt visible serait un
// élément d'interface que la direction ne dessine nulle part.
//
// **Ce que ce fichier ne fait pas.** Il ne recadre pas et il n'ouvre aucun éditeur : le
// recadrage se règle après avoir vu l'image, et `CropEditor` est un écran à part.

/// Rend un conteneur capable de recevoir des images par les quatre gestes.
struct MediaImportSurface: ViewModifier {
    let title: Title
    let slot: MediaSlot
    let onOutcome: (MediaImportOutcome) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isFileImporterPresented = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            // Le dépôt : le liseré n'apparaît que pendant le survol d'un fichier, donc il ne
            // coûte aucun élément permanent à l'écran.
            .overlay {
                if isTargeted {
                    Rectangle()
                        .strokeBorder(Color.accent, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .dropDestination(for: Data.self) { items, _ in
                receive(items.enumerated().map { .init(name: "dépôt \($0.offset + 1)", data: $0.element) })
                return true
            } isTargeted: {
                isTargeted = $0
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                receive(urls.compactMap { try? MediaImportService.Payload.read(fileURL: $0) })
            }
            .photosPicker(
                isPresented: .constant(false), selection: $photoSelection, matching: .images
            )
            .onChange(of: photoSelection) { _, items in
                guard items.isEmpty == false else { return }
                Task { await receivePhotos(items) }
            }
            // Le collage, et il n'a pas le même chemin sur les deux plateformes.
            //
            // `onPasteCommand` est **indisponible sur iOS** — le build iOS l'a refusé, et
            // c'est bien ainsi : sur iOS le collage passe par le menu d'édition du système,
            // pas par un raccourci capté par une vue. Un `PasteButton` aurait uniformisé au
            // prix d'un bouton visible que la direction ne dessine nulle part.
            //
            // Sur Mac, `⌘V` est capté ici. Sur iOS, le geste reste offert par le déclencheur
            // (`paste`), que l'écran place où il veut — un élément de menu, pas un bouton.
            #if os(macOS)
                .onPasteCommand(of: [.image, .png, .jpeg]) { providers in
                    Task { await receivePasted(providers) }
                }
            #endif
            .environment(
                \.mediaImportTrigger,
                MediaImportTrigger(
                    chooseFile: { isFileImporterPresented = true },
                    choosePhotos: { photoSelection = [] },
                    paste: { pasteFromClipboard() }))
    }

    private func receive(_ payloads: [MediaImportService.Payload]) {
        guard payloads.isEmpty == false else { return }
        let outcome = MediaImportService(context: modelContext)
            .importImages(payloads, into: title, slot: slot)
        // La sauvegarde est ici et pas dans le service : le service décide *quoi* écrire, la
        // vue décide *quand* — c'est elle qui sait si l'utilisateur a fini son geste.
        try? modelContext.save()
        onOutcome(outcome)
    }

    /// Photos rend ses données de façon asynchrone, et une par une.
    private func receivePhotos(_ items: [PhotosPickerItem]) async {
        var payloads: [MediaImportService.Payload] = []
        for (index, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            payloads.append(.init(name: "photo \(index + 1)", data: data))
        }
        photoSelection = []
        receive(payloads)
    }

    /// Lit une image du presse-papiers, sur les deux plateformes.
    ///
    /// Deux API et une seule intention : `NSPasteboard` sur Mac, `UIPasteboard` sur iOS. Le
    /// type demandé est **PNG ou JPEG**, pas « image » : le presse-papiers d'un navigateur
    /// contient souvent aussi du HTML et une URL, et demander le type générique rendrait
    /// parfois le balisage.
    private func pasteFromClipboard() {
        #if os(macOS)
            let types: [NSPasteboard.PasteboardType] = [.png, .tiff]
            guard let type = NSPasteboard.general.availableType(from: types),
                let data = NSPasteboard.general.data(forType: type)
            else { return }
            receive([.init(name: "collage", data: data)])
        #else
            guard let image = UIPasteboard.general.image,
                let data = image.pngData()
            else { return }
            receive([.init(name: "collage", data: data)])
        #endif
    }

    /// `@MainActor` explicite : `NSItemProvider` n'est pas `Sendable`, et le laisser
    /// traverser une frontière d'isolation est refusé par la concurrence stricte — à juste
    /// titre. Le fournisseur reste donc sur le fil principal ; ce qui traverse est la `Data`
    /// que son rappel produit, et elle l'est.
    #if os(macOS)
        @MainActor
        private func receivePasted(_ providers: [NSItemProvider]) async {
            var payloads: [MediaImportService.Payload] = []
            for (index, provider) in providers.enumerated() {
                guard let data = try? await provider.loadData(for: .image) else { continue }
                payloads.append(.init(name: "collage \(index + 1)", data: data))
            }
            receive(payloads)
        }
    #endif
}

extension View {
    /// Accepte des images par dépôt, collage, sélecteur de fichier et Photos.
    func mediaImportSurface(
        for title: Title,
        slot: MediaSlot = .gallery,
        onOutcome: @escaping (MediaImportOutcome) -> Void
    ) -> some View {
        modifier(MediaImportSurface(title: title, slot: slot, onOutcome: onOutcome))
    }
}

// MARK: - Déclencher les deux gestes qui demandent un bouton

/// Les deux gestes qui ne peuvent pas être passifs.
///
/// Le dépôt et le collage arrivent d'eux-mêmes ; choisir un fichier ou une photo demande une
/// action explicite. Le déclencheur passe par l'environnement pour que **le bouton n'ait pas
/// à connaître le titre** : il vit dans une barre d'actions, la surface d'import vit sur le
/// conteneur, et les deux ne se croisent pas dans la hiérarchie.
struct MediaImportTrigger: Sendable {
    let chooseFile: @MainActor () -> Void
    let choosePhotos: @MainActor () -> Void
    /// Le collage explicite, pour iOS où aucune vue ne capte `⌘V`.
    let paste: @MainActor () -> Void

    /// Le défaut : ne fait rien. Un bouton hors d'une surface d'import est inerte plutôt que
    /// cassé — c'est le cas d'une preview, où aucun titre n'existe.
    static let inert = MediaImportTrigger(chooseFile: {}, choosePhotos: {}, paste: {})
}

extension EnvironmentValues {
    @Entry var mediaImportTrigger: MediaImportTrigger = .inert
}

// MARK: - Lecture d'un fournisseur d'élément

extension NSItemProvider {
    /// Les octets d'un type, en `async` plutôt qu'en closure.
    @MainActor
    fileprivate func loadData(for type: UTType) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }
    }
}
