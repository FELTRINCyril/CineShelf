import CineShelfCore
import DesignSystem
import SwiftUI

// MARK: - V8 second jalon · Abandon à mi-parcours, et reprise. Bloc `11g`
//
// « Trois issues, aucune destructrice par défaut » — c'est le sous-titre de la planche, et
// c'est la seule règle qui compte ici : « Tout abandonner » existe, mais il n'est ni le
// premier ni celui qu'on atteint par inadvertance.
//
// Avant ce jalon, « Abandonner » remettait le parcours à zéro sans rien demander : les
// corrections de masse et la correspondance des colonnes partaient en silence.

/// Ce que l'utilisateur décide en quittant un import commencé.
enum ImportAbandonChoice {
    /// Le brouillon est conservé, rien n'entre en bibliothèque.
    case resumeLater
    /// Les lignes valides entrent maintenant, le reste reste reprenable.
    case importReady
    /// Brouillon, corrections et correspondance supprimés. Le fichier source n'est pas touché.
    case discardEverything
}

struct ImportAbandonSheet: View {
    let readyCount: Int
    let refusedCount: Int
    let correctedCauseCount: Int
    let totalCauseCount: Int
    let onChoose: (ImportAbandonChoice) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Text("Abandonner l'import ?")
                .title2Style()
                .foregroundStyle(Color.textPrimary)

            Text(summary)
                .calloutStyle()
                .foregroundStyle(Color.textSecondary)

            VStack(spacing: Space.s2) {
                choice(
                    .resumeLater, "Reprendre plus tard",
                    """
                    Le brouillon est conservé : fichier, correspondance des colonnes et \
                    corrections déjà appliquées. Rien n'entre en bibliothèque.
                    """,
                    isDestructive: false)
                if readyCount > 0 {
                    choice(
                        .importReady,
                        readyCount == 1
                            ? "Importer la ligne prête" : "Importer les \(readyCount) lignes prêtes",
                        """
                        Les lignes valides entrent maintenant. Les \(refusedCount) en erreur \
                        restent dans un brouillon reprenable.
                        """,
                        isDestructive: false)
                }
                choice(
                    .discardEverything, "Tout abandonner",
                    """
                    Le brouillon, les corrections et la correspondance sont supprimés. \
                    Le fichier source n'est pas touché.
                    """,
                    isDestructive: true)
            }

            // La planche le dit en toutes lettres, et c'est une promesse de comportement autant
            // qu'un texte : fermer la fenêtre ne doit pas être plus destructeur qu'un choix.
            Text("Fermer la fenêtre ou quitter l'app équivaut à « Reprendre plus tard ».")
                .metaStyle()
                .foregroundStyle(Color.textTertiary)

            Button("Continuer l'import", action: onCancel)
                .buttonStyle(.plain)
                .actionStyle()
                .foregroundStyle(Color.textSecondary)
                .frame(minHeight: Space.minHitTarget)
        }
        .padding(Space.s5)
        .frame(minWidth: 440)
    }

    private var summary: String {
        let corrected =
            totalCauseCount > 0
            ? "Tu as corrigé \(correctedCauseCount) causes sur \(totalCauseCount). " : ""
        return corrected
            + "\(readyCount) lignes sont prêtes, \(refusedCount) restent en erreur. "
            + "Rien n'a encore été écrit dans la bibliothèque."
    }

    /// Un drapeau local plutôt qu'un rang `.destructive` ajouté à `ActionButtonStyle` : le
    /// rang appartient à `DesignSystem`, et l'étendre serait une retouche du système hors d'un
    /// lot `I`. Ici seule la teinte du libellé change, ce qui est une décision d'écran.
    private func choice(
        _ value: ImportAbandonChoice,
        _ label: String,
        _ description: String,
        isDestructive: Bool
    ) -> some View {
        Button {
            onChoose(value)
        } label: {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text(label)
                    .headlineStyle()
                    .foregroundStyle(isDestructive ? Color.danger : Color.textPrimary)
                Text(description)
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.s3)
            .background(Color.bgSurface)
            .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minHeight: Space.minHitTarget)
    }
}

// MARK: - Le bandeau de reprise

/// « Import en attente », au retour.
///
/// **Posé sur l'écran d'import et non sur l'écran Titres**, contrairement à la planche `11g`.
/// Le mettre sur Titres ferait connaître `ImportDraftStore` à une autre `Feature` et ouvrirait
/// un routage entre les deux, ce qui sort du périmètre de ce jalon. La conséquence est réelle
/// et inscrite en écart : un utilisateur qui ne rouvre pas Import ne saura pas qu'un brouillon
/// l'attend.
struct ImportResumeBanner: View {
    let draft: ImportDraft
    let refusedCount: Int?
    let onResume: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s3) {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text("Import en attente · \(draft.fileName)")
                    .headlineStyle()
                    .foregroundStyle(Color.textPrimary)
                Text(detail)
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer(minLength: Space.s4)
            Button("Reprendre", action: onResume)
                .buttonStyle(ActionButtonStyle(rank: .primary))
            Button("Abandonner", action: onDiscard)
                .buttonStyle(.plain)
                .actionStyle()
                .foregroundStyle(Color.danger)
                .frame(minHeight: Space.minHitTarget)
        }
        .padding(Space.s3)
        .background(Color.bgSurface)
        .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
    }

    private var detail: String {
        var parts: [String] = []
        if let refusedCount, refusedCount > 0 { parts.append("\(refusedCount) lignes en erreur") }
        if !draft.corrections.isEmpty {
            let count = draft.corrections.count
            parts.append("\(count) correction\(count == 1 ? "" : "s") appliquée\(count == 1 ? "" : "s")")
        }
        parts.append("abandonné le " + Self.stamp.string(from: draft.savedAt))
        return parts.joined(separator: " · ")
    }

    /// Jour et heure, sans l'année : le brouillon est récent par construction — il n'y en a
    /// qu'un, et il est remplacé au prochain import.
    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("dMMHm")
        return formatter
    }()
}
