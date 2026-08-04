import DesignSystem
import SwiftUI

// Les trois composants de `I6`.
//
// Ce qu'on vient vérifier ici, et qui ne se voit pas dans un test :
//
// - que le badge reste lisible **sur une image claire comme sur une sombre** — c'est
//   toute la raison d'être de `chip.onImage`, et le seul moyen de s'en assurer est de le
//   poser sur une affiche ;
// - que les cinq étoiles se lisent aux trois tailles **et à AX5**, où elles doivent
//   grandir sans se chevaucher ;
// - que la barre segmentée se lit quand un segment est minuscule — 7,5 % de la piste,
//   c'est le cas réel des 96 doublons sur 1 284 lignes.

struct IndicatorSheet: View {
    @State private var rating: Double? = 4

    var body: some View {
        Sheet(
            "Badge · Notation · Progression · I6",
            note: """
                Les états d'une carte et d'une fiche. Aucun jeton neuf : la barre de \
                progression applique la convention que le handoff a laissée ouverte \
                (§10, point 4), et c'est ce composant qui la tient.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                badges
                badgesOnPosters
                ratings
                progress
            }
        }
    }

    private var badges: some View {
        section(
            "Badge d'état · quatre teintes",
            note: """
                Les trois teintes pleines portent un texte `accent.onAccent` — sombre. \
                Un texte clair sur l'ambre ne passerait pas le contraste, et c'est \
                précisément ce que ce jeton existe pour dire.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack(spacing: Space.s2) {
                    StateBadge("Vu")
                    StateBadge("À voir")
                    StateBadge("Archivé")
                    StateBadge("Privé", symbol: Icon.isPrivate)
                }
                HStack(spacing: Space.s2) {
                    StateBadge("Drame", tone: .accent)
                    StateBadge("771 prêtes", tone: .success)
                    StateBadge("417 en erreur", tone: .danger)
                }
            }
        }
    }

    private var badgesOnPosters: some View {
        section(
            "Le badge à sa vraie place",
            note: """
                `PosterTile` le pose lui-même depuis `I6` — la tuile ne garde que les deux \
                décisions qui sont bien les siennes : à partir de quel cran il s'affiche \
                (jamais sous `m`, il serait illisible) et lequel des trois états gagne.
                """
        ) {
            HStack(alignment: .top, spacing: Space.s3) {
                PosterTile(.samples[1], scale: .l) {}
                PosterTile(.samples[2], scale: .l) {}
                PosterTile(.samples[7], scale: .l) {}
                PosterTile(.samples[7], scale: .s) {}
            }
        }
    }

    private var ratings: some View {
        section(
            "Barre de notation · cinq crans",
            note: """
                Cinq étoiles pleines, aucune demi-étoile — et c'est une règle de **rendu**. \
                Le modèle note sur 10 (`docs/02` §3.3) ; cette barre reçoit une note déjà \
                convertie sur 5 et ne décide rien de ce qui s'écrit en base. Une note \
                fractionnaire s'affiche « 4,5 ★ » ailleurs, sur la tuile détaillée.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s4) {
                ForEach(RatingBar.Scale.allCases, id: \.self) { scale in
                    HStack(spacing: Space.s4) {
                        RatingBar(4, scale: scale)
                        Text(label(for: scale))
                            .font(Typo.micro)
                            .foregroundStyle(.textTertiary)
                    }
                }
                labelled("non notée") { RatingBar(nil) }
                labelled("4,5 — une note de 9/10 arrondit au cran le plus proche") {
                    RatingBar(4.5)
                }
                labelled("éditable · touche l'étoile atteinte pour effacer") {
                    RatingBar(rating, scale: .detail) { rating = Double($0) }
                }
            }
        }
    }

    private var progress: some View {
        section(
            "Indicateur de progression",
            note: """
                Piste `bg.fill`, segments `success` · `danger` · `text.tertiary`. Le \
                handoff signale qu'aucun jeton de piste n'existe et que « toute future \
                barre devra reprendre cette convention » : c'est ce composant qui la \
                tient, plutôt qu'une note que personne ne relira.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s4) {
                labelled("import · 1 284 lignes, 771 prêtes, 417 en erreur, 96 doublons") {
                    ProgressTrack(
                        segments: [
                            ProgressSegment(id: "ok", value: 771, role: .done),
                            ProgressSegment(id: "ko", value: 417, role: .failed),
                            ProgressSegment(id: "dup", value: 96, role: .neutral)
                        ],
                        total: 1284)
                }
                labelled("synchronisation · 312 sur 1 284 — le reste reste vide") {
                    ProgressTrack(value: 312, total: 1284)
                }
                labelled("rien de fait") { ProgressTrack(value: 0, total: 100) }
                labelled("terminé") { ProgressTrack(value: 100, total: 100, role: .done) }
            }
            .frame(maxWidth: 460, alignment: .leading)
        }
    }

    // MARK: - Habillage

    private func label(for scale: RatingBar.Scale) -> String {
        switch scale {
        case .compact: "compact · 16 pt · panneau"
        case .form: "form · 20 pt · formulaire"
        case .detail: "detail · 30 pt · fiche"
        }
    }

    private func labelled(
        _ label: String, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            content()
            Text(label).font(Typo.micro).foregroundStyle(.textTertiary)
        }
    }

    private func section(
        _ title: String, note: String, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(title).font(Typo.title2(.large)).foregroundStyle(.textPrimary)
            Text(note).font(Typo.body).foregroundStyle(.textSecondary)
            content()
        }
    }
}
