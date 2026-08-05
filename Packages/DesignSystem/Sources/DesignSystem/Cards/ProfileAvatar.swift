import SwiftUI

// MARK: - I3 · L'avatar de profil
//
// Relevé sur la **planche 5, bloc `7f`** — « Profils et bibliothèques » :
//
//     <span style="width:46px;height:46px;background:{{ p.color }};color:oklch(0.14 0 0);
//                  font:400 20px/46px 'Bebas Neue',sans-serif;text-align:center">{{ p.i }}</span>
//
// **C'est un carré, pas un rond.** Le relevé mérite d'être souligné parce que le bloc `1a`
// — direction **abandonnée** « Salle obscure » — montre un avatar circulaire de 28 px en
// Archivo, et que c'est celui qu'on dessine spontanément. La direction retenue n'a aucun
// rayon nulle part : ni sur la tuile d'affiche, ni sur les jetons, ni ici. Un rond aurait
// été le seul arrondi de toute l'interface.
//
// Trois autres relevés :
//
// - **L'initiale est en Bebas Neue sur le carré de 46**, pas dans la police de texte :
//   c'est la police d'affichage du système (`Typo.title2`), et elle donne la lettre
//   condensée qu'on voit dans le prototype. Dans la barre, en revanche, le bloc `3a` pose
//   Archivo Narrow 600 à 11 pt — voir `Size.font`, qui porte le relevé des deux blocs.
// - **Le texte est sombre sur le fond de couleur** (`oklch(0.14 0 0)`), donc
//   `accent.onAccent` — jamais du blanc, qui ne passerait pas sur l'ambre.
// - **Le fond est la couleur du profil**, pas un token fixe. `ProfileAccent` vit dans
//   `CineShelfCore`, dont `DesignSystem` ne dépend pas : le composant reçoit donc une
//   `Color`, et c'est l'app qui la résout. Même couture que `MediaCropDisplay`.

/// L'avatar carré d'un profil : son initiale sur sa couleur.
public struct ProfileAvatar: View {
    /// Les tailles où l'avatar apparaît réellement, plutôt qu'un `CGFloat` libre.
    ///
    /// Un nombre libre inviterait chaque appelant à choisir la sienne, et l'avatar du
    /// chrome finirait par ne plus faire la même taille d'un écran à l'autre. Les deux
    /// valeurs viennent du prototype : 46 pt dans l'écran des profils, et un cran petit
    /// pour la barre d'outils, où la cible tactile de 44 pt est portée par le bouton qui
    /// l'entoure et non par l'avatar lui-même.
    public enum Size: Sendable, CaseIterable {
        case toolbar, card

        public var side: CGFloat {
            switch self {
            case .toolbar: 26
            case .card: 46
            }
        }

        /// La police de l'initiale, et **elle change avec la taille** — ce n'est pas une
        /// mise à l'échelle.
        ///
        /// Le prototype pose deux choses différentes : `font:400 20px/46px 'Bebas Neue'`
        /// sur le carré de 46 (bloc `7f`) et `font:600 11px/26px 'Archivo Narrow'` sur
        /// celui de la barre (bloc `3a`). Bebas est une capitale étroite qui tient un
        /// grand carré ; à 11 pt elle devient un trait. Les deux blocs sont d'accord
        /// chacun sur le sien, donc les rendus font foi.
        ///
        /// C'est l'écart 1 de la revue du 2026-08-04 : une valeur relevée sur un bloc
        /// avait été généralisée à l'autre, comme la forme de `PersonTile` avant elle.
        var font: Font {
            switch self {
            // Archivo Narrow 600 à 11 pt : exactement le bloc `3a`.
            case .toolbar: Typo.label
            // Bebas Neue, à 22 pt et non 20 : aucun rôle de `Typo` n'est Bebas à 20, et
            // en ajouter un rouvrirait la porte que `Typo` a fermée — même motif que
            // l'écart 8. Les 2 pt sont inscrits aux écarts connus.
            case .card: Typo.title2(.large)
            }
        }
    }

    private let initials: String
    private let tint: Color
    private let size: Size
    private let isLocked: Bool

    public init(
        initials: String,
        tint: Color = .accent,
        size: Size = .card,
        isLocked: Bool = false
    ) {
        self.initials = initials
        self.tint = tint
        self.size = size
        self.isLocked = isLocked
    }

    /// À partir d'un nom affiché — réutilise la règle d'initiales de `PersonTile`, pour que
    /// « Jean de La Fontaine » donne « JF » ici comme là-bas.
    public init(
        name: String,
        tint: Color = .accent,
        size: Size = .card,
        isLocked: Bool = false
    ) {
        self.init(
            initials: PersonTile.initials(of: name), tint: tint, size: size, isLocked: isLocked)
    }

    public var body: some View {
        tint
            .frame(width: size.side, height: size.side)
            .overlay {
                Text(initials)
                    .font(size.font)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
                    .foregroundStyle(Color.accentOnAccent)
            }
            .overlay(alignment: .bottomTrailing) { lock }
            .accessibilityLabel(accessibilityLabel)
    }

    /// Le cadenas d'un profil qui demande Face ID.
    ///
    /// En bas à droite et **hors** du carré de couleur, sur un fond sombre : posé dessus, il
    /// se perdrait sur l'ambre. C'est la seule information qu'un avatar doit porter en plus
    /// de son initiale — un profil verrouillé qu'on ne distingue pas se clique par erreur.
    @ViewBuilder private var lock: some View {
        if isLocked {
            Image(systemName: Icon.lockFallback)
                .font(.system(size: size.side * 0.26))
                .foregroundStyle(Color.textPrimary)
                .padding(2)
                .background(Color.bgCanvas)
        }
    }

    private var accessibilityLabel: String {
        isLocked ? "\(initials), profil verrouillé" : initials
    }
}

#Preview("Deux tailles, verrouillé ou non") {
    VStack(alignment: .leading, spacing: Space.s5) {
        ForEach(ProfileAvatar.Size.allCases, id: \.side) { size in
            HStack(spacing: Space.s4) {
                ProfileAvatar(name: "Cyril Feltrin", size: size)
                ProfileAvatar(name: "Invité", tint: .textSecondary, size: size)
                ProfileAvatar(name: "Archives", size: size, isLocked: true)
                ProfileAvatar(initials: "JF", size: size)
            }
        }
    }
    .padding(Space.s5)
    .background(Color.bgCanvas)
}
