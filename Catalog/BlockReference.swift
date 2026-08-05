import DesignSystem
import SwiftUI

// MARK: - La porte d'acceptation visuelle
//
// **Ce que le catalogue ne savait pas faire.** `PersonTile` a été livrée en rectangle 2:3
// là où la direction montre des cercles, et elle a passé tous les tests *et* sa planche du
// catalogue. Il a fallu trois lots et un écran qui s'en servait pour s'en apercevoir : le
// catalogue montre chaque composant **seul**, jamais à côté de ce que son bloc annonce. On
// y vérifiait qu'un composant existe et qu'il tient dans les quatre apparences, pas qu'il
// **ressemble** au bloc — ce qui était pourtant sa seule raison d'être.
//
// **Ce que ce fichier ajoute.** À côté de chaque composant, la valeur attendue du bloc qui
// le spécifie, et ce que le code fait quand les deux diffèrent. Un écart se lit alors sans
// ouvrir un `.dc.html`.
//
// **Aucune assertion, et c'est délibéré.** Un test qui comparerait ces nombres à ceux du
// code se contenterait de recopier les mêmes valeurs deux fois : il attraperait un
// changement de constante et rien de ce que l'œil attrape — la forme, la police, le poids,
// le fait qu'un cercle soit devenu un rectangle. La porte est **visuelle**, et sa valeur
// vient de ce qu'elle rend le désaccord voyant, pas de ce qu'elle le mesure.
//
// **Les valeurs viennent d'où ?** Des en-têtes des composants, qui citent chacun le CSS
// relevé, et de l'arbitrage de la revue visuelle du 2026-08-04 inscrit dans
// `docs/PROMPTS.md`. Les dix écarts qu'elle a trouvés sont le premier contenu de cette
// porte : on sait déjà ce qu'elle doit montrer, donc on peut vérifier qu'elle le montre.

/// Ce qu'un bloc annonce pour un composant, et ce que le code en fait.
struct BlockSpec: Identifiable {
    /// Le nom du composant, tel qu'il s'appelle dans `DesignSystem`.
    let component: String
    /// Le ou les blocs qui le spécifient, avec leur planche.
    let source: String
    let measures: [Measure]

    var id: String { component }

    struct Measure: Identifiable {
        let name: String
        /// Ce que le bloc annonce, en texte — pas un nombre à comparer.
        let expected: String
        let verdict: Verdict

        var id: String { name }
    }

    /// Trois états, et le second est ce qui rend une correction constatable : il disparaît
    /// quand elle est faite.
    enum Verdict {
        /// Le code fait ce que le bloc dit.
        case matches
        /// Écart reconnu, correction due. Le numéro est celui de la revue du 2026-08-04.
        case toFix(gap: Int, code: String)
        /// Écart arbitré **au jeton** : le code ne bouge pas, et le motif est inscrit.
        case keptAtToken(gap: Int, code: String, reason: String)
    }
}

// MARK: - Le rendu

/// La référence de bloc, posée à côté de son composant.
struct BlockNote: View {
    private let spec: BlockSpec

    init(_ spec: BlockSpec) {
        self.spec = spec
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack(spacing: Space.s2) {
                Text(spec.component).font(Typo.headline).foregroundStyle(.textPrimary)
                Text(spec.source).font(Typo.meta).foregroundStyle(.textTertiary)
            }
            VStack(alignment: .leading, spacing: Space.s2) {
                ForEach(spec.measures) { measure in
                    row(measure)
                }
            }
        }
        .padding(Space.s4)
        .frame(maxWidth: 620, alignment: .leading)
        .background(.bgInset)
    }

    private func row(_ measure: BlockSpec.Measure) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s3) {
                Text(measure.name)
                    .font(Typo.callout)
                    .foregroundStyle(.textSecondary)
                    .frame(width: 176, alignment: .leading)
                Text(measure.expected)
                    .font(Typo.callout)
                    .foregroundStyle(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let divergence = divergence(measure.verdict) {
                Text(divergence)
                    .font(Typo.micro)
                    .foregroundStyle(color(measure.verdict))
                    .padding(.leading, 176 + Space.s3)
            }
        }
    }

    /// Le texte de désaccord, ou `nil` quand il n'y en a pas — une ligne conforme n'ajoute
    /// rien, sinon la porte serait illisible là où tout va bien.
    private func divergence(_ verdict: BlockSpec.Verdict) -> String? {
        switch verdict {
        case .matches:
            nil
        case .toFix(let gap, let code):
            "Écart \(gap), à corriger. Le code fait : \(code)"
        case .keptAtToken(let gap, let code, let reason):
            "Écart \(gap), gardé au jeton. Le code fait : \(code). \(reason)"
        }
    }

    private func color(_ verdict: BlockSpec.Verdict) -> Color {
        switch verdict {
        case .matches: .textTertiary
        case .toFix: .danger
        case .keptAtToken: .textSecondary
        }
    }
}
