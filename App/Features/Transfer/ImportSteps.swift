import CineShelfCore
import DesignSystem
import SwiftUI
import UniformTypeIdentifiers

// MARK: - V8 · Les trois étapes dessinées

/// Étape 1 — la correspondance des colonnes. Bloc `11d`.
///
/// **Une colonne non reconnue n'est pas une erreur**, et l'écran le dit avec les mots du
/// prototype : « elles sont ignorées par défaut, et l'import peut avancer ». Ce qui bloque est
/// un **champ requis sans colonne**, et rien d'autre.
struct ImportMappingStep: View {
    @Binding var flow: ImportFlow
    /// « Réutiliser cette correspondance pour les prochains fichiers de même en-tête ».
    ///
    /// **La case manquait, et son absence rendait la lecture inutile** : `ImportMapping` était
    /// une entité que rien n'écrivait, donc la correspondance mémorisée qu'on cherchait à
    /// l'ouverture n'existait jamais. Lire et écrire se livrent ensemble.
    @Binding var remembersMapping: Bool
    let onAnalyze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            if let columns = flow.columns {
                counts(columns)

                ForEach(Array(columns.matches.enumerated()), id: \.offset) { index, match in
                    row(match, at: index, in: columns)
                }

                if !columns.ignoredColumnNames.isEmpty {
                    note(
                        "\(columns.ignoredColumnNames.count) colonnes non reconnues",
                        detail:
                            "Elles ne sont pas une erreur : par défaut elles sont ignorées, "
                            + "et l'import peut avancer sans y toucher. "
                            + columns.ignoredColumnNames.joined(separator: ", "))
                }

                if !columns.missingRequiredFieldKeys.isEmpty {
                    // **Le seul blocage de l'étape 1.** Sans titre, l'aperçu n'annoncerait que
                    // « toutes les lignes en erreur », ce qui ne renseigne sur rien.
                    Text(
                        "Champ requis sans colonne : "
                            + columns.missingRequiredFieldKeys.joined(separator: ", ")
                    )
                    .calloutStyle()
                    .foregroundStyle(Color.danger)
                }

                Toggle(
                    "Réutiliser cette correspondance pour les prochains fichiers de même en-tête",
                    isOn: $remembersMapping
                )
                .calloutStyle()
                .foregroundStyle(Color.textSecondary)
                .frame(minHeight: Space.minHitTarget)

                HStack(spacing: Space.s3) {
                    Button("Analyser les lignes", action: onAnalyze)
                        .buttonStyle(ActionButtonStyle(rank: .primary))
                        .disabled(!flow.canAnalyze)
                    Text("Aucune donnée n'est écrite à cette étape.")
                        .metaStyle()
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
    }

    private func counts(_ columns: ColumnAnalysis) -> some View {
        HStack(spacing: Space.s4) {
            ForEach(ColumnMatchQuality.allCases, id: \.self) { quality in
                let count = columns.matches(quality: quality).count
                Text("\(count) \(label(for: quality))")
                    .numericStyle()
                    .foregroundStyle(tint(for: quality))
            }
        }
    }

    private func row(_ match: ColumnMatch, at index: Int, in columns: ColumnAnalysis) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s3) {
            Text(match.columnName)
                .calloutStyle()
                .foregroundStyle(Color.textPrimary)
                .frame(width: 180, alignment: .leading)
            // `rationale` porte la raison de la déduction — « déduite du contenu », l'alias
            // reconnu. Le prototype montre « trois premières valeurs » ; elles vivent dans le
            // document, pas dans le rapprochement, et les reporter ici demanderait de garder le
            // fichier entier en mémoire. La raison dit la même chose en moins de place.
            Text(match.rationale ?? "—")
                .metaStyle()
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(match.fieldKey ?? "ignorée")
                .calloutStyle()
                .foregroundStyle(tint(for: match.quality))
                .frame(width: 160, alignment: .leading)
        }
        .frame(minHeight: Space.minHitTarget)
    }

    private func note(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(title).headlineStyle().foregroundStyle(Color.textPrimary)
            Text(detail).metaStyle().foregroundStyle(Color.textTertiary)
        }
        .padding(Space.s3)
        .background(Color.bgSurface)
        .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
    }

    /// **Deux jetons détournés, et c'est documenté au bloc `11h`.** Le système n'a pas de
    /// couleur d'avertissement : une correspondance déduite passe en `accent`, une colonne non
    /// reconnue en `danger` parce qu'elle demande une décision. Un `warning` réglerait ça
    /// proprement ; il n'a pas été inventé ici.
    private func tint(for quality: ColumnMatchQuality) -> Color {
        switch quality {
        case .certain: Color.success
        case .inferred: Color.accent
        case .unrecognized: Color.danger
        }
    }

    private func label(for quality: ColumnMatchQuality) -> String {
        switch quality {
        case .certain: "sûres"
        case .inferred: "déduites"
        case .unrecognized: "non reconnues"
        }
    }
}

/// Étape 2 — l'aperçu, **groupé par cause et non par ligne**. Bloc `11e`.
///
/// « On ne corrige pas 417 lignes, on corrige six causes. » C'est la phrase du prototype, et
/// c'est ce que `ImportAnalysis.causeGroups` rend déjà — trié par effectif décroissant, à ordre
/// stable pour que deux exécutions du même fichier se comparent.
struct ImportPreviewStep: View {
    @Binding var flow: ImportFlow
    let onImport: (Bool) -> Void
    /// Ouvre la correction de masse sur une cause. Bloc `11f`.
    let onCorrect: (ImportCauseGroup) -> Void
    /// Défait la correction à cet index. « Annulable une par une » de la planche.
    let onUndoCorrection: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            if let report = flow.report {
                HStack(spacing: Space.s5) {
                    figure("\(report.analyzedCount)", "lignes analysées", Color.textPrimary)
                    figure("\(report.readyCount)", "prêtes", Color.success)
                    figure("\(report.refusedCount)", "en erreur", Color.danger)
                }

                if let malformation = report.headerMalformation {
                    // **L'en-tête fautif se dit à part**, et `L11a` l'a appris à ses dépens :
                    // sans ça le rapport réclamait une colonne que le fichier portait.
                    Text("L'en-tête du fichier est illisible : \(String(describing: malformation))")
                        .calloutStyle()
                        .foregroundStyle(Color.danger)
                }

                if !report.causes.isEmpty {
                    Text("\(report.refusedCount) erreurs, \(report.causes.count) causes")
                        .headlineStyle()
                        .foregroundStyle(Color.textPrimary)
                    ForEach(report.causes) { group in
                        causeRow(group)
                    }
                }

                appliedCorrections

                if !report.ignoredColumnNames.isEmpty {
                    Text("Colonnes ignorées : " + report.ignoredColumnNames.joined(separator: ", "))
                        .metaStyle()
                        .foregroundStyle(Color.textTertiary)
                }

                HStack(spacing: Space.s3) {
                    if flow.offersReadyOnly {
                        Button(flow.readyLabel()) { onImport(true) }
                            .buttonStyle(ActionButtonStyle(rank: .primary))
                    }
                    if flow.offersDraftAll {
                        Button("Tout importer, erreurs en brouillon") { onImport(false) }
                            .buttonStyle(ActionButtonStyle(rank: .secondary))
                    }
                }
                if let failure = flow.failure {
                    Text(failure).calloutStyle().foregroundStyle(Color.danger)
                }
            }
        }
    }

    private func figure(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(value).title2Style().foregroundStyle(tint)
            Text(label).labelStyle().foregroundStyle(Color.textTertiary)
        }
    }

    private func causeRow(_ group: ImportCauseGroup) -> some View {
        HStack(spacing: Space.s3) {
            Text("\(group.count)")
                .numericStyle()
                .foregroundStyle(Color.danger)
                .frame(width: 48, alignment: .trailing)
            Text(group.label)
                .calloutStyle()
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if group.isCorrectable {
                Button("Corriger…") { onCorrect(group) }
                    .buttonStyle(ActionButtonStyle(rank: .secondary))
            } else {
                // Une cause sans champ visé vient du **découpage** du fichier : aucune
                // correction de cellule ne la répare, et le dire vaut mieux qu'un bouton qui
                // ouvrirait une feuille sans effet.
                Text("à corriger dans le fichier")
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(minHeight: Space.minHitTarget)
    }

    /// Les corrections déjà appliquées, chacune annulable. Bloc `11f`, « une par une ».
    @ViewBuilder
    private var appliedCorrections: some View {
        if !flow.corrections.isEmpty {
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("Corrections appliquées")
                    .labelStyle()
                    .foregroundStyle(Color.textTertiary)
                ForEach(Array(flow.corrections.enumerated()), id: \.offset) { index, correction in
                    HStack(spacing: Space.s3) {
                        Text("\(correction.fieldKey) = « \(correction.value) »")
                            .calloutStyle()
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Annuler") { onUndoCorrection(index) }
                            .buttonStyle(.plain)
                            .actionStyle()
                            .foregroundStyle(Color.accent)
                            .frame(minHeight: Space.minHitTarget)
                    }
                    .frame(minHeight: Space.minHitTarget)
                }
            }
        }
    }
}

/// Étape 4 — le bilan. Bloc `11j`.
struct ImportReportStep: View {
    @Binding var flow: ImportFlow
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            if let result = flow.result {
                Text(headline(result))
                    .title2Style()
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: Space.s5) {
                    figure("\(result.createdTitleIDs.count)", "ajoutés")
                    figure("\(result.completedTitleIDs.count)", "complétés")
                    figure("\(result.unchangedTitleIDs.count)", "inchangés")
                }

                if let report = flow.report, report.refusedCount > 0 {
                    Text("Ce qui a été écarté, par cause")
                        .labelStyle()
                        .foregroundStyle(Color.textTertiary)
                    ForEach(report.causes) { cause in
                        Text("\(cause.count) — \(cause.label)")
                            .calloutStyle()
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                if result.wasCancelled {
                    // **L'annulation n'est pas un échec, et le bilan reste exact** : `L11b`
                    // rend un résultat même annulé, avec ce qui a été écrit avant l'arrêt.
                    Text("L'import a été interrompu. Ce qui précède a bien été écrit.")
                        .calloutStyle()
                        .foregroundStyle(Color.textSecondary)
                }

                Button("Terminer", action: onReset)
                    .buttonStyle(ActionButtonStyle(rank: .primary))
            }
        }
    }

    private func headline(_ result: ImportRunResult) -> String {
        let added = result.createdTitleIDs.count
        return added == 1 ? "1 titre ajouté" : "\(added) titres ajoutés"
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(value).title2Style().foregroundStyle(Color.textPrimary)
            Text(label).labelStyle().foregroundStyle(Color.textTertiary)
        }
    }
}

// MARK: - Le document d'export

/// Un CSV déjà encodé, prêt pour `fileExporter`.
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
