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
// **Second jalon, 2026-08-07** : la correction en masse (`11f`), l'abandon à trois issues avec
// reprise de brouillon (`11g`), et le rejeu de la correspondance mémorisée — dont seule la
// jointure manquait. L'export dit désormais ce qu'il a dû échapper.

struct TransferView: View {
    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @State private var flow = ImportFlow()
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument: CSVDocument?

    /// Les valeurs que le dernier export a dû échapper. **« Et le dire »** de la correction du
    /// séparateur : l'invariant tient sans cet avertissement, mais un fichier qui part avec des
    /// séquences d'échappement dedans est un fichier que l'utilisateur doit savoir reconnaître.
    @State private var escapedOnExport: [String] = []

    /// La cause en cours de correction de masse, s'il y en a une. Bloc `11f`.
    @State private var correctingCause: ImportCauseGroup?
    /// Le dialogue d'abandon. Bloc `11g`.
    @State private var isAbandoning = false
    /// Le brouillon en attente, relu à l'ouverture de l'écran.
    @State private var pendingDraft: ImportDraft?
    /// Faut-il mémoriser la correspondance des colonnes pour les fichiers de même en-tête ?
    @State private var remembersMapping = false

    /// **L'URL est conservée pour la seconde lecture.** Garder le `Document` entier en mémoire
    /// serait plus simple et coûterait le fichier deux fois — 1 284 lignes analysées, c'est le
    /// cas dessiné.
    @State private var lastURL: URL?

    /// Le magasin de brouillons. `nil` si le dossier de l'app est inaccessible — auquel cas
    /// l'import fonctionne toujours, sans reprise : un brouillon est un confort, pas une
    /// condition.
    private var draftStore: ImportDraftStore? {
        (try? ImportDraftStore.applicationSupportDirectory()).map(ImportDraftStore.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            header
            switch flow.stage {
            case .idle: idleStep
            case .mapping:
                ImportMappingStep(
                    flow: $flow, remembersMapping: $remembersMapping, onAnalyze: analyze)
            case .preview:
                ImportPreviewStep(
                    flow: $flow, onImport: run,
                    onCorrect: { correctingCause = $0 },
                    onUndoCorrection: undoCorrection)
            case .running(let progress): runningStep(progress)
            case .finished: ImportReportStep(flow: $flow, onReset: reset)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.s5)
        .task { pendingDraft = try? draftStore?.existingDraft() }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText]) {
            load($0)
        }
        .fileExporter(
            isPresented: $isExporting, document: exportDocument,
            contentType: .commaSeparatedText, defaultFilename: "cineshelf"
        ) { _ in }
        .sheet(item: $correctingCause) { cause in
            if let analysis = flow.analysis, let schema = CSVSchema.schema(for: .title) {
                ImportCorrectionSheet(
                    cause: cause, analysis: analysis, schema: schema,
                    onApply: { apply($0) },
                    onCancel: { correctingCause = nil })
            }
        }
        .sheet(isPresented: $isAbandoning) {
            ImportAbandonSheet(
                readyCount: flow.report?.readyCount ?? 0,
                refusedCount: flow.report?.refusedCount ?? 0,
                correctedCauseCount: flow.corrections.count,
                totalCauseCount: (flow.report?.causes.count ?? 0) + flow.corrections.count,
                onChoose: abandon,
                onCancel: { isAbandoning = false })
        }
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
                // **« Abandonner » ne remet plus à zéro sans demander.** Il ouvrait le parcours
                // en silence, donc les corrections de masse et la correspondance des colonnes
                // partaient sans un mot. Trois issues désormais, et aucune destructrice par
                // défaut — bloc `11g`.
                Button("Abandonner") { isAbandoning = true }
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
            if let draft = pendingDraft {
                ImportResumeBanner(
                    draft: draft,
                    refusedCount: draft.restoredAnalysis().map(ImportReport.init)?.refusedCount,
                    onResume: { resume(draft) },
                    onDiscard: {
                        try? draftStore?.discard()
                        pendingDraft = nil
                    })
            }

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
            if !escapedOnExport.isEmpty {
                // **Le fichier est correct** — l'aller-retour rend ces valeurs à l'identique.
                // Ce qui se dit ici est qu'elles portent une séquence d'échappement, ce qui
                // compte si l'utilisateur retraite le fichier avec un autre outil.
                Text(escapedNotice)
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }
            if let failure = flow.failure {
                Text(failure)
                    .calloutStyle()
                    .foregroundStyle(Color.danger)
            }
        }
    }

    private var escapedNotice: String {
        let names = escapedOnExport.prefix(3).map { "« \($0) »" }.joined(separator: ", ")
        let rest = escapedOnExport.count > 3 ? " et \(escapedOnExport.count - 3) autres" : ""
        let subject = escapedOnExport.count == 1 ? "valeur contient" : "valeurs contiennent"
        return """
            \(escapedOnExport.count) \(subject) le séparateur « \(CSVSchema.multiValueSeparator) » : \
            \(names)\(rest). Elles sont écrites avec un antislash devant, et se relisent \
            correctement dans CineShelf.
            """
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
            // La correspondance mémorisée, si un fichier de même en-tête a déjà été importé —
            // c'est la promesse « réutiliser cette correspondance pour les prochains fichiers de
            // même en-tête » du bloc `11d`. **La jointure est ce qui manquait** : les deux
            // moitiés existaient depuis `L11a` et ne se rencontraient pas.
            let remembered = session.current?.library.flatMap { library in
                ImportMappingRepository(context: modelContext)
                    .rememberedMapping(forHeader: document.header, in: library)
            }
            // Une correspondance retrouvée est une correspondance qu'on veut garder : la case
            // part cochée dans ce cas, et décochée pour un en-tête inconnu.
            remembersMapping = remembered != nil

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
        flow.baseAnalysis = flow.analysis
        flow.corrections = []
        rememberMappingIfAsked(columns)
        flow.stage = .preview
    }

    /// Mémorise la correspondance des colonnes, si la case est cochée. Bloc `11d`.
    ///
    /// **Écrite ici et non à l'étape 1**, parce que c'est le passage à l'analyse qui vaut
    /// validation des choix de l'utilisateur : mémoriser à chaque changement de menu écrirait un
    /// mappage à moitié décidé, que le prochain fichier retrouverait.
    ///
    /// Un refus — deux colonnes de même nom — se dit sans bloquer l'analyse : la correspondance
    /// est un confort, le fichier s'importe sans elle.
    private func rememberMappingIfAsked(_ columns: ColumnAnalysis) {
        guard remembersMapping, let library = session.current?.library else { return }
        do {
            try ImportMappingRepository(context: modelContext).save(
                columns.mapping, named: flow.fileName,
                forHeader: flow.analysis?.header ?? columns.matches.map(\.columnName),
                in: library)
        } catch let error as ColumnMappingError {
            flow.failure = error.message
        } catch {
            flow.failure = "La correspondance n'a pas pu être mémorisée."
        }
    }

}

// MARK: - Les actions du parcours
//
// **Dans une extension et non dans le corps de la vue**, pour la raison que `swiftlint` a
// nommée : le corps dépassait 300 lignes. La coupe n'est pas arbitraire — ce qui suit ne
// dessine rien, ce sont les transitions et les écritures du parcours.

extension TransferView {

    // MARK: Les corrections de masse — bloc `11f`

    private func apply(_ correction: ImportCorrection) {
        guard let schema = CSVSchema.schema(for: .title) else { return }
        flow.apply(correction, using: ImportValidator(schema: schema))
        correctingCause = nil
        saveDraft()
    }

    private func undoCorrection(at index: Int) {
        guard let schema = CSVSchema.schema(for: .title) else { return }
        flow.undoCorrection(at: index, using: ImportValidator(schema: schema))
        saveDraft()
    }

    // MARK: L'abandon et la reprise — bloc `11g`

    private func abandon(_ choice: ImportAbandonChoice) {
        isAbandoning = false
        switch choice {
        case .resumeLater:
            saveDraft()
            pendingDraft = try? draftStore?.existingDraft()
            flow = ImportFlow()
        case .importReady:
            // Le brouillon est posé **avant** l'écriture : les lignes en erreur restent
            // reprenables, et c'est ce que la planche promet en toutes lettres.
            saveDraft()
            run(readyOnly: true)
        case .discardEverything:
            try? draftStore?.discard()
            pendingDraft = nil
            reset()
        }
    }

    /// Pose le brouillon de l'état courant. Sans analyse, il n'y a rien à reprendre.
    private func saveDraft() {
        guard let analysis = flow.analysis, let store = draftStore else { return }
        try? store.save(
            ImportDraft(
                analysis: analysis, fileName: flow.fileName,
                corrections: flow.corrections, savedAt: .now))
    }

    private func resume(_ draft: ImportDraft) {
        guard let analysis = draft.restoredAnalysis() else {
            flow.failure = "Ce brouillon n'a pas pu être relu."
            return
        }
        flow.fileName = draft.fileName
        flow.columns = analysis.columns
        // L'analyse rendue par le brouillon a **déjà** rejoué les corrections, dans l'ordre.
        // La pile les accompagne pour qu'elles restent annulables une par une, et
        // `baseAnalysis` se reconstruit en les défaisant toutes.
        flow.corrections = draft.corrections
        flow.baseAnalysis = draft.corrections.isEmpty ? analysis : baseOf(draft)
        flow.analysis = analysis
        flow.stage = .preview
        pendingDraft = nil
    }

    /// L'analyse du brouillon **sans** ses corrections : le point d'où l'annulation rejoue.
    private func baseOf(_ draft: ImportDraft) -> ImportAnalysis? {
        guard let schema = CSVSchema.schema(for: draft.entity) else { return nil }
        let document = draft.restoredDocument()
        let columns = ColumnMatcher(schema: schema).analyze(
            header: document.header, rows: document.rows, remembered: draft.mapping)
        return ImportValidator(schema: schema).analyze(document: document, columns: columns)
    }

    /// Remet le parcours à zéro, brouillon compris.
    private func reset() {
        flow = ImportFlow()
        remembersMapping = false
        try? draftStore?.discard()
        pendingDraft = nil
    }

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
        let result: CSVExportResult
        switch entity {
        case .title:
            let titles = (try? modelContext.fetch(FetchDescriptor<Title>())) ?? []
            result = exporter.export(titles: titles, keys: keys)
        case .person:
            let people = (try? modelContext.fetch(FetchDescriptor<Person>())) ?? []
            result = exporter.export(people: people, keys: keys)
        default:
            return
        }
        exportDocument = CSVDocument(data: result.data)
        escapedOnExport = result.distinctEscapedValues
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
