import CineShelfCore
import DesignSystem
import SwiftUI

// MARK: - V8 second jalon · La correction en masse. Bloc `11f`
//
// « On ne corrige pas 417 lignes, on corrige six causes. » L'aperçu groupe déjà par cause ;
// ce qui manquait est la décision qu'on prend sur une cause, et son effet montré **avant**
// d'être appliqué.
//
// **Une seule des quatre stratégies de la planche est livrée**, et c'est dit plutôt que
// simulé : « Saisir une valeur pour toutes » est la seule que `ImportCorrection` sait
// exprimer. Les trois autres — déduire l'année du titre, chercher dans la fiche existante,
// importer en brouillon — demandent des règles qui n'existent pas dans le cœur, et deux
// d'entre elles exigeraient d'interroger le magasin depuis l'aperçu, ce que la coupe
// `L11a`/`L11b` interdit. Un bouton inerte apprend à ne pas croire l'interface.

struct ImportCorrectionSheet: View {
    let cause: ImportCauseGroup
    let analysis: ImportAnalysis
    let schema: CSVSchema
    let onApply: (ImportCorrection) -> Void
    let onCancel: () -> Void

    @State private var value = ""

    /// Le champ visé par la cause, quand elle en nomme un.
    ///
    /// Une cause porte la clé du champ fautif — c'est ce qui permet à `ImportCorrection` de
    /// viser les bonnes cellules sans que l'écran calcule un index de colonne.
    private var fieldKey: String? { cause.fieldKey }

    private var field: CSVField? { fieldKey.flatMap(schema.field(forKey:)) }

    /// Les lignes que la correction toucherait.
    private var targetCount: Int { cause.count }

    /// L'effet, trois lignes, avant d'appliquer. « Aperçu de l'effet » de la planche.
    private var preview: [ImportCorrectionPreview] {
        guard let key = fieldKey, !value.isEmpty else { return [] }
        return ImportValidator(schema: schema)
            .preview(ImportCorrection(fieldKey: key, value: value), on: analysis)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            header

            if let field {
                strategy(field)
                previewSection
            } else {
                // Une cause qui ne nomme aucun champ — une ligne mal découpée, un en-tête
                // illisible — ne se corrige pas cellule par cellule : c'est le fichier qu'il
                // faut reprendre. Le dire est plus utile qu'un champ de saisie sans effet.
                Text(
                    """
                    Cette cause ne vise aucune colonne : elle vient du découpage du fichier. \
                    Corrige-la dans le tableur, puis redépose le fichier.
                    """
                )
                .calloutStyle()
                .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 0)
            actions
        }
        .padding(Space.s5)
        .frame(minWidth: 460, minHeight: 380)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Cause · \(targetCount) \(targetCount == 1 ? "ligne" : "lignes")")
                .labelStyle()
                .foregroundStyle(Color.danger)
            Text(cause.label)
                .title2Style()
                .foregroundStyle(Color.textPrimary)
            if let field {
                Text(field.help)
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    private func strategy(_ field: CSVField) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Saisir une \(field.header.lowercased()) pour toutes")
                .headlineStyle()
                .foregroundStyle(Color.textPrimary)
            Text("Une seule valeur appliquée aux \(targetCount) lignes. À réserver aux fichiers homogènes.")
                .metaStyle()
                .foregroundStyle(Color.textTertiary)
            TextField(field.header, text: $value)
                .textFieldStyle(.plain)
                .calloutStyle()
                .padding(Space.s3)
                .background(Color.bgFill)
                .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
                .frame(minHeight: Space.minHitTarget)
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if !preview.isEmpty {
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("Aperçu de l'effet · \(preview.count) premières lignes concernées")
                    .labelStyle()
                    .foregroundStyle(Color.textTertiary)
                ForEach(preview) { line in
                    HStack(spacing: Space.s3) {
                        Text(String(format: "%04d", line.number))
                            .numericStyle()
                            .foregroundStyle(Color.textTertiary)
                        Text(line.before.isEmpty ? "(vide)" : line.before)
                            .calloutStyle()
                            .foregroundStyle(Color.textTertiary)
                        Text("->")
                            .metaStyle()
                            .foregroundStyle(Color.textTertiary)
                        Text(line.after)
                            .calloutStyle()
                            .foregroundStyle(Color.textPrimary)
                    }
                    .frame(minHeight: Space.minHitTarget)
                }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Réversible jusqu'à l'import · chaque correction est annulable une par une")
                .metaStyle()
                .foregroundStyle(Color.textTertiary)
            HStack(spacing: Space.s3) {
                Button("Annuler", action: onCancel)
                    .buttonStyle(ActionButtonStyle(rank: .secondary))
                Button("Appliquer aux \(targetCount) lignes") {
                    guard let key = fieldKey else { return }
                    onApply(ImportCorrection(fieldKey: key, value: value))
                }
                .buttonStyle(ActionButtonStyle(rank: .primary))
                .disabled(fieldKey == nil || value.isEmpty)
            }
        }
    }
}
