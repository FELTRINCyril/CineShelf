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

// MARK: - Le contenu, par lot

extension BlockSpec {

    // MARK: I2

    static let posterTile = BlockSpec(
        component: "PosterTile",
        source: "planche 1 bloc 2a · planche 3 bloc 4a",
        measures: [
            .init(name: "Ratio portrait", expected: "2:3 (aspect-ratio:2/3)", verdict: .matches),
            .init(name: "Rayon d'angle", expected: "aucun, angles vifs", verdict: .matches),
            .init(name: "Ombre, bordure", expected: "aucune", verdict: .matches),
            .init(
                name: "Survol",
                expected: "agrandit de 6 % (scale 1.06), sans liseré",
                verdict: .matches),
            .init(
                name: "Texte dans la tuile",
                expected: "aucun, jamais : l'affiche parle seule",
                verdict: .matches)
        ])

    static let personTile = BlockSpec(
        component: "PersonTile",
        source: "planche 3 blocs 4b · 4c · 4d",
        measures: [
            .init(
                name: "Forme",
                expected: "cercle 1:1 (aspect-ratio:1 + border-radius:50%)",
                verdict: .matches),
            .init(
                name: "Côté au casting",
                expected: "96 pt (bloc 4b)",
                verdict: .keptAtToken(
                    gap: 10, code: "cran .m = 92 pt",
                    reason: "Aucun cran de PosterScale ne vaut 96, et l'échelle est une fonctionnalité")),
            .init(
                name: "Nom",
                expected: "toujours affiché, deux lignes réservées",
                verdict: .matches)
        ])

    // MARK: I3

    static let collectionTile = BlockSpec(
        component: "CollectionTile",
        source: "planche 3 bloc 4e",
        measures: [
            .init(
                name: "Couverture de repli",
                expected: "mosaïque 2 x 2 en 16:9, sans gouttière",
                verdict: .matches),
            .init(name: "Survol", expected: "agrandit de 3 % (scale 1.03)", verdict: .matches),
            .init(name: "Rayon d'angle", expected: "aucun", verdict: .matches)
        ])

    static let galleryThumb = BlockSpec(
        component: "GalleryThumb",
        source: "planche 4 bloc 6b",
        measures: [
            .init(
                name: "Ratio",
                expected: "celui de l'image, jamais imposé",
                verdict: .matches),
            .init(name: "Gouttière de colonne", expected: "8 pt", verdict: .matches),
            .init(name: "Rayon d'angle", expected: "aucun", verdict: .matches)
        ])

    static let profileAvatar = BlockSpec(
        component: "ProfileAvatar",
        source: "planche 2 bloc 3a (barre) · planche 5 bloc 7f (fiche)",
        measures: [
            .init(name: "Forme", expected: "carré, aucun rayon", verdict: .matches),
            .init(name: "Côté dans la barre", expected: "26 pt (bloc 3a)", verdict: .matches),
            .init(
                name: "Police dans la barre",
                expected: "Archivo Narrow 600, 11 pt (bloc 3a)",
                verdict: .matches),
            .init(name: "Côté sur la fiche", expected: "46 pt (bloc 7f)", verdict: .matches),
            .init(
                name: "Police sur la fiche",
                expected: "Bebas Neue 400, 20 pt (bloc 7f)",
                verdict: .keptAtToken(
                    gap: 1, code: "Typo.title2, Bebas Neue 22 pt",
                    reason: """
                        Aucun rôle de Typo n'est Bebas à 20, et en ajouter un rouvrirait la \
                        porte que Typo a fermée — même motif que l'écart 8
                        """)),
            .init(
                name: "Texte sur la couleur",
                expected: "sombre (oklch 0.14), donc accent.onAccent",
                verdict: .matches)
        ])

    // MARK: I4

    static let tileRail = BlockSpec(
        component: "TileRail",
        source: "planche 1 bloc 2a · planche 3 blocs 4b · 4f · addendum 2",
        measures: [
            .init(
                name: "Gouttière de rangée",
                expected: "10 pt sur iPhone, 14 pt sur iPad et sur Mac",
                verdict: .matches),
            .init(
                name: "Marge de gauche",
                expected: "20 iPhone · 28 iPad · 44 (2a), 40 (3a), 36 (4b) sur Mac",
                verdict: .keptAtToken(
                    gap: 4, code: "Breakpoint.screenMargin = 32 sur Mac",
                    reason: """
                        Trois blocs Mac, trois valeurs : jamais contrôlée. iPhone et iPad \
                        tombent pile sur le jeton
                        """)),
            .init(
                name: "Libellé vers rangée",
                expected: "10 pt",
                verdict: .keptAtToken(
                    gap: 7, code: "Space.s3 = 12 pt",
                    reason: "10 n'est aucun cran de l'échelle de base 4")),
            .init(
                name: "Marge de droite",
                expected: "aucune : la dernière carte est coupée par le bord",
                verdict: .matches),
            .init(
                name: "Signal de défilement",
                expected: "la carte coupée, et rien d'autre : ni flèche, ni dégradé, ni compteur",
                verdict: .matches)
        ])

    static let adaptiveTileGrid = BlockSpec(
        component: "AdaptiveTileGrid",
        source: "planche 3 bloc 4a · addendum 2 bloc 13c",
        measures: [
            .init(
                name: "Colonnes",
                expected: "393 pt donnent 2 colonnes, 834 pt en donnent 4",
                verdict: .matches),
            .init(
                name: "Gouttière",
                expected: "18 pt (bloc 4a)",
                verdict: .keptAtToken(
                    gap: 6, code: "16 pt en dense",
                    reason: "18 n'est aucun cran de l'échelle de base 4")),
            .init(
                name: "Largeur de carte",
                expected: "constante : la grille prend ce qui rentre",
                verdict: .matches)
        ])

    static let tileSkeleton = BlockSpec(
        component: "TileSkeleton",
        source: "planche 7 bloc 9b",
        measures: [
            .init(
                name: "Géométrie",
                expected: "celle de la tuile remplacée, ratio réservé",
                verdict: .matches),
            .init(name: "Balayage", expected: "aucun", verdict: .matches)
        ])

    // MARK: I6

    // MARK: I10

    static let emptyState = BlockSpec(
        component: "EmptyState",
        source: "planche 7 bloc 9a",
        measures: [
            .init(name: "Titre", expected: "Bebas Neue 400, 30 pt", verdict: .matches),
            .init(
                name: "Corps",
                expected: "Archivo Narrow 300, 14 pt, largeur bornee a 400 pt",
                verdict: .matches),
            .init(
                name: "Action principale",
                expected: "aplat clair, texte sombre, Archivo Narrow 600, 12 pt",
                verdict: .matches),
            .init(
                name: "Action secondaire",
                expected: "fond translucide, Archivo Narrow 400, 12 pt",
                verdict: .matches),
            .init(name: "Indice", expected: "IBM Plex Mono, 10 pt", verdict: .matches),
            .init(
                name: "Carte fantome",
                expected: "2:3 de 70 pt, trame rayee a 45 degres (oklch 0.185 / 0.15)",
                verdict: .keptAtToken(
                    gap: 11, code: "aplat bg.surface",
                    reason: """
                        La bande claire tombe pile sur bg.surface (0,187) mais la sombre \\
                        (0,15) n'est aucun jeton : la trame demanderait d'en inventer un
                        """)),
            .init(name: "Rayon d'angle", expected: "aucun", verdict: .matches)
        ])

    static let banner = BlockSpec(
        component: "Banner",
        source: "planche 7 bloc 9c",
        measures: [
            .init(
                name: "Place",
                expected: "sous la barre, pleine largeur, le contenu reste utilisable",
                verdict: .matches),
            .init(
                name: "Pastille",
                expected: "cercle de 8 pt, a la couleur du ton",
                verdict: .matches),
            .init(
                name: "Libelle de genre",
                expected: "Archivo Narrow 600, 11 pt, +0.16em, capitales, couleur du ton",
                verdict: .keptAtToken(
                    gap: 12, code: "Typo.label, 11 pt, +0.12em",
                    reason: """
                        Meme motif que l'ecart 8 : une taille et un interlettrage par usage \\
                        rouvriraient la porte que Typo a fermee
                        """)),
            .init(
                name: "Rembourrage",
                expected: "14 pt vertical, 24 pt horizontal",
                verdict: .matches),
            .init(
                name: "Fond",
                expected: "neutre bg.fill, accent 12 %, danger 13 %, success 11 %",
                verdict: .keptAtToken(
                    gap: 13, code: "12 % pour les trois teintes",
                    reason: """
                        Trois opacites pour un meme role, sans regle qui les separe : \\
                        jamais controlees
                        """)),
            .init(name: "Rayon d'angle", expected: "aucun", verdict: .matches),
            .init(
                name: "Fermeture",
                expected: "croix a droite, cible de 44 pt",
                verdict: .matches)
        ])

    // MARK: I6

    static let stateBadge = BlockSpec(
        component: "StateBadge",
        source: "planche 3 bloc 4a · planche 7 bloc 9d",
        measures: [
            .init(
                name: "Police sur vignette",
                expected: "Archivo Narrow 600, 9 pt, interlettrage +0.18em (bloc 9d)",
                verdict: .keptAtToken(
                    gap: 8, code: "Typo.label, 11 pt, +0.12em",
                    reason: "Une taille de police par usage rouvrirait la porte que Typo a fermée")),
            .init(
                name: "Texte sur teinte pleine",
                expected: "sombre, accent.onAccent",
                verdict: .matches),
            .init(name: "Rayon d'angle", expected: "aucun", verdict: .matches)
        ])

    static let ratingBar = BlockSpec(
        component: "RatingBar",
        source: "planche 6 blocs 8a · 8c",
        measures: [
            .init(
                name: "Crans",
                expected: "cinq étoiles pleines, aucune demi-étoile",
                verdict: .matches),
            .init(
                name: "Étoile pleine",
                expected: "accent (oklch 0.8 0.14 66)",
                verdict: .matches),
            .init(
                name: "Étoile vide",
                expected: "oklch(0.34 0 0) (bloc 8a)",
                verdict: .matches),
            .init(
                name: "Tailles",
                expected: "16 pt en panneau, 20 pt en formulaire, 30 pt sur une fiche",
                verdict: .matches)
        ])

    static let progressTrack = BlockSpec(
        component: "ProgressTrack",
        source: "addendum 1 bloc 11e",
        measures: [
            .init(
                name: "Piste",
                expected: "oklch(0.28 0 0)",
                verdict: .keptAtToken(
                    gap: 9, code: "bgFill, oklch 0.29 en sombre",
                    reason: "Un centième de luminance, et le §10 dit lui-même qu'aucun jeton de piste n'existe")),
            .init(
                name: "Segments",
                expected: "success, danger, text.tertiary",
                verdict: .matches)
        ])
}

// MARK: - Previews

#Preview("Porte de bloc") {
    ScrollView {
        VStack(alignment: .leading, spacing: Space.s4) {
            BlockNote(.personTile)
            BlockNote(.tileRail)
            BlockNote(.ratingBar)
        }
        .padding(Space.s5)
    }
    .background(Color.bgCanvas)
}
