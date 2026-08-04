import SwiftUI

// MARK: - I4 · Le squelette de chargement
//
// Relevé sur la planche 7 bloc `9b`. Le rail en cours de chargement y est un rail
// **vide à la géométrie finale** — même cran, même ratio, même gouttière :
//
//     <div style="display:flex;gap:14px;padding-left:36px">
//       <span style="flex:none;width:160px;aspect-ratio:2/3;background:oklch(0.165 0 0)"></span>
//     </div>
//
// C'est pour ça que ce composant n'apporte **aucun conteneur à lui**. Le rail et la
// grille étant génériques, un chargement s'écrit avec eux :
//
//     TileRail("Ajoutés cette semaine") {
//         ForEach(0..<8, id: \.self) { _ in TileSkeleton(scale: .l) }
//     }
//
// Un `SkeletonRail` et un `SkeletonGrid` séparés auraient eu leur propre marge et leur
// propre gouttière, donc leur propre façon de dériver — et le saut de mise en page que
// le squelette existe pour empêcher serait revenu par la porte du squelette lui-même.
//
// **Deux points du design qui ne se devinent pas.**
//
// 1. *Aucun balayage.* Le §6 est explicite : « squelettes à la géométrie finale exacte —
//    ratio réservé, aucun saut de mise en page, aucune animation de balayage ». La
//    légende du bloc `9b` — « aucune animation si Reduce Motion est actif : les blocs
//    restent fixes » — n'aurait cependant aucun objet si rien ne bougeait jamais. D'où
//    une **pulsation d'opacité** en `dur.slow`, qui n'est pas un balayage, et que Reduce
//    Motion arrête net.
// 2. *La couleur dominante n'est pas de ce lot.* Le §6 demande de « remplacer la trame
//    rayée par la couleur dominante de l'image ». Elle se déduit de la première
//    composante du `blurHash` — c'est un décodeur, pas un champ, et le schéma fermé n'a
//    donc rien à recevoir. **Le producteur appartient à `L5`** (préchargement de
//    vignettes), et `TileSkeleton` gagnera un paramètre de couleur quand il existera.
//    En attendant, l'aplat est `bg.surface`, comme le fond de tuile de `I2`.

/// Une tuile en attente, à la géométrie exacte de celle qui la remplacera.
public struct TileSkeleton: View {
    private let layout: CardLayout
    private let scale: PosterScale

    @State private var isDimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(layout: CardLayout = .portrait, scale: PosterScale = .m) {
        self.layout = layout
        self.scale = scale
    }

    public var body: some View {
        let size = scale.size(layout)
        SkeletonFill(isDimmed: isDimmed)
            .frame(width: size.width, height: size.height)
            .task {
                guard !reduceMotion else { return }
                isDimmed = true
            }
            // Décoratif : une grille de vingt cases en attente annoncerait vingt fois
            // « image » sans rien apprendre. C'est l'écran qui dit qu'il charge.
            .accessibilityHidden(true)
    }
}

/// Une barre de texte en attente — le titre, la ligne de méta, un bouton.
///
/// Le bloc `9b` en pose neuf autour du hero, à des largeurs qui imitent celles du texte
/// final. La hauteur par défaut est celle de ses barres de métadonnées.
public struct SkeletonBar: View {
    private let width: CGFloat
    private let height: CGFloat

    @State private var isDimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(width: CGFloat, height: CGFloat = Space.s3) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        SkeletonFill(isDimmed: isDimmed)
            .frame(width: width, height: height)
            .task {
                guard !reduceMotion else { return }
                isDimmed = true
            }
            .accessibilityHidden(true)
    }
}

// MARK: - L'aplat commun

/// Le remplissage des deux formes, et le seul endroit où la pulsation est décrite.
private struct SkeletonFill: View {
    let isDimmed: Bool

    var body: some View {
        Color.bgSurface
            .opacity(isDimmed ? 0.55 : 1)
            .dsAnimation(Motion.slow.repeatForever(autoreverses: true), value: isDimmed)
    }
}

// MARK: - Previews

#Preview("Squelette · rail et grille, géométrie finale") {
    VStack(alignment: .leading, spacing: Space.s6) {
        TileRail("Ajoutés cette semaine") {
            ForEach(0..<8, id: \.self) { _ in
                TileSkeleton(scale: .l)
            }
        }
        VStack(alignment: .leading, spacing: Space.s3) {
            SkeletonBar(width: 180, height: Space.s3)
            SkeletonBar(width: 430, height: Space.s8 + Space.s7)
            HStack(spacing: Space.s3) {
                SkeletonBar(width: 54)
                SkeletonBar(width: 64)
                SkeletonBar(width: 110)
            }
        }
        .padding(.horizontal, Breakpoint.macStandard.screenMargin)
    }
    .padding(.vertical, Space.s6)
    .frame(width: 720, alignment: .leading)
    .background(Color.bgCanvas)
}
