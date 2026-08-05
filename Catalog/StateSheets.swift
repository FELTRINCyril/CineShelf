import DesignSystem
import SwiftUI

// Les deux composants de `I10`.
//
// Ce qu'on vient vérifier ici, et qui ne se voit pas dans un test :
//
// - qu'un état vide **sans corps ni action** ne laisse pas un trou : c'est le cas d'un
//   écran qui n'a rien à proposer, et c'est celui qu'on oublie de dessiner ;
// - que la colonne de texte reste lisible aux deux extrêmes — une phrase courte ne se perd
//   pas au milieu de 400 pt, une longue ne devient pas un pavé ;
// - que les quatre tons de bandeau se distinguent **sans lire le libellé**, donc à la
//   pastille et au fond seuls ;
// - que le bandeau ne masque rien : il pousse le contenu, et on le voit en le posant
//   au-dessus d'une grille.

struct StateSheet: View {
    @State private var dismissed: Set<String> = []

    var body: some View {
        Sheet(
            "Vide · Bandeau · I10",
            note: """
                Les deux composants d'interruption. Un bandeau se pose **sous la barre** et \
                laisse le contenu utilisable : le seul écran plein que la direction autorise \
                est le verrouillage biométrique, et il appartient à `V7`.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                emptyStates
                banners
                bannerOverContent
            }
        }
    }

    private var emptyStates: some View {
        section(
            "État vide · les cinq emplacements",
            note: """
                Le titre est le seul obligatoire. Les six écrans du bloc `9a` remplissent \
                les cinq, mais un écran qui n'a rien à proposer ne doit pas inventer une \
                action — d'où le cas nu, à droite.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s5) {
                framed(620, height: 380) {
                    EmptyState(
                        title: "Aucun titre pour l'instant",
                        message: """
                            Ta collection est vide. Importe un CSV depuis Movix ou ajoute un \
                            premier film à la main.
                            """,
                        primary: .init("Importer un CSV") {},
                        secondary: .init("Nouveau titre") {},
                        hint: "⇧⌘I pour l'import")
                }
                framed(620, height: 380) {
                    EmptyState(
                        title: "Aucun titre ne correspond",
                        message: """
                            Deux filtres sont actifs : genre « Drame » et note ≥ 4. \
                            Retire-en un pour voir plus large.
                            """,
                        primary: .init("Réinitialiser les filtres") {},
                        hint: "1 284 titres au total")
                }
                framed(620, height: 380) {
                    EmptyState(title: "Aucune image")
                }
                BlockNote(.emptyState)
            }
        }
    }

    private var banners: some View {
        section(
            "Bandeau · quatre tons",
            note: """
                Le ton se lit à la pastille et au fond, sans le libellé. Aucun jeton neuf : \
                les trois teintés sont leur couleur à 12 %, le neutre est `bg.fill` — la \
                même palette que `StateBadge`, et la cohérence est voulue.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s4) {
                VStack(spacing: 0) {
                    ForEach(Self.samples, id: \.kind) { sample in
                        if !dismissed.contains(sample.kind) {
                            Banner(
                                kind: LocalizedStringKey(sample.kind),
                                text: LocalizedStringKey(sample.text),
                                tone: sample.tone,
                                action: .init(LocalizedStringKey(sample.action)) {},
                                dismiss: sample.dismissible
                                    ? { dismissed.insert(sample.kind) } : nil)
                        }
                    }
                }
                .frame(width: 720)
                if !dismissed.isEmpty {
                    Button("Remettre les bandeaux renvoyés") { dismissed.removeAll() }
                        .font(Typo.callout)
                }
                BlockNote(.banner)
            }
        }
    }

    private var bannerOverContent: some View {
        section(
            "Le bandeau à sa vraie place",
            note: """
                Sous la barre, au-dessus du contenu, pleine largeur. Il **pousse** la grille \
                au lieu de la recouvrir : c'est la différence avec une alerte, et c'est ce \
                qui rend le contenu encore utilisable pendant l'interruption.
                """
        ) {
            VStack(spacing: 0) {
                Banner(
                    kind: "Synchronisation",
                    text: "Synchronisation iCloud en cours — 312 titres sur 1 284.",
                    tone: .accent,
                    action: .init("Détails") {})
                AdaptiveTileGrid(
                    Array(PosterCardModel.samples.prefix(8)), cardWidth: PosterScale.m.width
                ) {
                    PosterTile($0, scale: .m) {}
                }
                .padding(.vertical, Space.s4)
            }
            .frame(width: 720)
            .background(.bgInset)
            .breakpoint(forWidth: 720)
            .clipped()
        }
    }

    // MARK: - Habillage

    private struct Sample {
        let kind: String
        let text: String
        let tone: Banner.Tone
        let action: String
        let dismissible: Bool
    }

    /// Les quatre bandeaux du bloc `9c`, texte inclus — c'est la copie qui montre que le
    /// composant tient une phrase entière et pas un fragment.
    private static let samples: [Sample] = [
        .init(
            kind: "Hors ligne",
            text: """
                Tu es hors ligne. La collection reste entièrement consultable ; 3 \
                modifications partiront à la reconnexion.
                """,
            tone: .neutral, action: "Voir les modifications", dismissible: false),
        .init(
            kind: "Synchronisation",
            text: "Synchronisation iCloud en cours — 312 titres sur 1 284. Tu peux continuer à naviguer.",
            tone: .accent, action: "Détails", dismissible: false),
        .init(
            kind: "Quota iCloud",
            text: "Quota iCloud dépassé : 5 Go sur 5 Go. Les nouvelles images ne sont plus synchronisées.",
            tone: .danger, action: "Gérer le stockage", dismissible: true),
        .init(
            kind: "Import",
            text: "Import terminé : 908 titres créés, 18 fusionnés, 26 en attente de correction.",
            tone: .success, action: "Corriger maintenant", dismissible: true)
    ]

    private func framed(
        _ width: CGFloat, height: CGFloat, @ViewBuilder content: () -> some View
    ) -> some View {
        content()
            .frame(width: width, height: height)
            .background(.bgInset)
            .breakpoint(forWidth: width)
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
