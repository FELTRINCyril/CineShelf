import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - V8 · Import et export
//
// **L'interface de `L11a`, `L11b` et `L12`** — trois tâches faites, dont deux à rigueur
// maximale, qui n'avaient jamais eu d'écran. Le lecteur de CSV, le rapprochement de colonnes, la
// validation par cause, l'exécuteur d'import et l'export existaient et personne ne pouvait les
// atteindre.
//
// **Le parcours suit l'addendum 1** : correspondance (`11d`) → aperçu groupé par cause (`11e`)
// → écriture → bilan (`11j`). L'état vit dans `ImportFlow`, hors de la vue.
//
// **Ce qui reste à un second jalon, et c'est dit plutôt que promis** : la correction en masse
// depuis l'aperçu (`11f`) et l'abandon avec reprise de brouillon (`11g`). Les deux demandent
// `ImportCorrection` et `ImportDraftStore`, qui existent — c'est du travail d'écran, pas de
// cœur. Écarts inscrits.

struct TransferView: View {
    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @State private var flow = ImportFlow()
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument: CSVDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            header
            switch flow.stage {
            case .idle: idleStep
            case .mapping: ImportMappingStep(flow: $flow, onAnalyze: analyze)
            case .preview: ImportPreviewStep(flow: $flow, onImport: run)
            case .running(let progress): runningStep(progress)
            case .finished: ImportReportStep(flow: $flow, onReset: { flow = ImportFlow() })
            }
            Spacer(minLength: 0)
        }
        .padding(Space.s5)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText]) {
            load($0)
        }
        .fileExporter(
            isPresented: $isExporting, document: exportDocument,
            contentType: .commaSeparatedText, defaultFilename: "cineshelf"
        ) { _ in }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
            Text("Import / Export")
                .title2Style()
                .foregroundStyle(Color.textPrimary)
            if !flow.fileName.isEmpty {
                Text(flow.fileName)
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer(minLength: Space.s4)
            if flow.stage != .idle {
                // « Abandonner » est présent à toutes les étapes du parcours dessiné. Ici il
                // remet à zéro : la reprise de brouillon est le second jalon.
                Button("Abandonner") { flow = ImportFlow() }
                    .buttonStyle(.plain)
                    .actionStyle()
                    .foregroundStyle(Color.danger)
                    .frame(minHeight: Space.minHitTarget)
            }
        }
    }

    @ViewBuilder
    private var idleStep: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            EmptyState(
                title: "Importer un fichier CSV",
                message:
                    """
                    Choisis un fichier : ses colonnes seront rapprochées et ses lignes \
                    analysées avant toute écriture.
                    """,
                primary: .init("Choisir un fichier") { isImporting = true })

            Divider().overlay(Color.separatorLine)

            Text("Exporter")
                .labelStyle()
                .foregroundStyle(Color.textTertiary)
            HStack(spacing: Space.s3) {
                Button("Exporter les titres") { export(.title) }
                    .buttonStyle(ActionButtonStyle(rank: .secondary))
                Button("Exporter les personnes") { export(.person) }
                    .buttonStyle(ActionButtonStyle(rank: .secondary))
                Button("Modèle vide") { exportTemplate() }
                    .buttonStyle(ActionButtonStyle(rank: .secondary))
            }
            if let failure = flow.failure {
                Text(failure)
                    .calloutStyle()
                    .foregroundStyle(Color.danger)
            }
        }
    }

    private func runningStep(_ progress: Double) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Import en cours")
                .headlineStyle()
                .foregroundStyle(Color.textPrimary)
            // `ProgressTrack` est segmenté — il a été dessiné pour la barre 771/417/96 de
            // l'aperçu. Ici un seul segment suffit : c'est un avancement, pas une répartition.
            ProgressTrack(
                segments: [.init(id: "done", value: Int(progress * 100), role: .done)],
                total: 100)
            Text("\(Int(progress * 100)) %")
                .numericStyle()
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: Les étapes

    /// Lit le fichier et rapproche ses colonnes. **Rien n'est écrit.**
    private func load(_ result: Result<URL, Error>) {
        flow.failure = nil
        do {
            let url = try result.get()
            // La lecture d'un fichier choisi par l'utilisateur passe par le bac à sable : sans
            // cette paire, `Data(contentsOf:)` échoue sur un fichier hors du conteneur.
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            lastURL = url
            let data = try Data(contentsOf: url)
            let document = CSVReader().read(data)
            guard let schema = CSVSchema.schema(for: .title) else { return }
            // La correspondance mémorisée, si ce fichier a déjà été importé — c'est la
            // promesse « réutiliser cette correspondance pour les prochains fichiers de même
            // en-tête » du bloc `11d`.
            // **Le mappage mémorisé n'est pas rejoué à ce jalon.** `ImportMappingRepository`
            // rend un `ImportMapping` du magasin, et `ColumnMatcher.analyze` attend un
            // `ColumnMapping` décodé — le pont entre les deux appartient au second jalon, avec
            // la case « Mémoriser » du bloc `11d` qui l'écrirait. Écart inscrit : sans lui, un
            // fichier déjà importé refait ses déductions au lieu de retrouver les choix de
            // l'utilisateur.
            let remembered: ColumnMapping? = nil

            flow.fileName = url.lastPathComponent
            flow.columns = ColumnMatcher(schema: schema).analyze(
                header: document.header, rows: Array(document.rows.prefix(3)),
                remembered: remembered)
            flow.analysis = nil
            flow.stage = .mapping
        } catch {
            flow.failure = "Ce fichier n'a pas pu être lu."
        }
    }

    /// Analyse les lignes. **Toujours rien d'écrit** — c'est la promesse du bloc `11d`.
    private func analyze() {
        guard let columns = flow.columns, let schema = CSVSchema.schema(for: .title),
            let url = lastURL
        else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        let document = CSVReader().read(data)
        flow.analysis = ImportValidator(schema: schema).analyze(
            document: document, columns: columns)
        flow.stage = .preview
    }

    /// **L'URL est conservée pour la seconde lecture.** Garder le `Document` entier en mémoire
    /// serait plus simple et coûterait le fichier deux fois — 1 284 lignes analysées, c'est le
    /// cas dessiné.
    @State private var lastURL: URL?

    private func run(readyOnly: Bool) {
        guard let analysis = flow.analysis, let libraryID = session.current?.library?.id else {
            return
        }
        let rows = readyOnly ? analysis.readyRows : analysis.rows
        let container = modelContext.container
        let fileName = flow.fileName
        flow.stage = .running(progress: 0)

        Task {
            do {
                let actor = ImportActor(modelContainer: container)
                let result = try await actor.importRows(
                    rows, fileName: fileName, libraryID: libraryID)
                flow.result = result
                flow.stage = .finished
            } catch {
                flow.failure = "L'import a échoué."
                flow.stage = .preview
            }
        }
    }

    // MARK: L'export

    private func export(_ entity: ActivityEntityType) {
        guard let schema = CSVSchema.schema(for: entity) else { return }
        let exporter = CSVExporter()
        let keys = schema.fields.map(\.key)
        switch entity {
        case .title:
            let titles = (try? modelContext.fetch(FetchDescriptor<Title>())) ?? []
            exportDocument = CSVDocument(data: exporter.export(titles: titles, keys: keys))
        case .person:
            let people = (try? modelContext.fetch(FetchDescriptor<Person>())) ?? []
            exportDocument = CSVDocument(data: exporter.export(people: people, keys: keys))
        default:
            return
        }
        isExporting = true
    }

    /// Le modèle vide : l'en-tête et rien d'autre.
    ///
    /// **Le geste qui ferme la boucle** : on exporte un modèle, on le remplit dans un tableur,
    /// on le redépose. Sans lui, l'utilisateur doit deviner les noms de colonnes.
    private func exportTemplate() {
        guard let schema = CSVSchema.schema(for: .title) else { return }
        exportDocument = CSVDocument(data: CSVExporter().template(for: schema))
        isExporting = true
    }
}
