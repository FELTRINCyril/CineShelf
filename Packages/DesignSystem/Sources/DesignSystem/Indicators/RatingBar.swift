import SwiftUI

// MARK: - I6 · La barre de notation
//
// Relevée sur la planche 6, blocs `8a` (le champ « Note » d'un formulaire dense) et `8c`
// (« Ma note » sur une fiche) :
//
//     <span style="display:flex;gap:5px;font:400 20px/1 'Archivo Narrow';
//                  color:oklch(0.8 0.14 66)">★ ★ ★ ★ <span
//                  style="color:oklch(0.34 0 0)">★</span>
//                  <span …>effacer</span></span>
//
// **Cinq étoiles pleines, aucune demi-étoile — et c'est une règle de RENDU.**
//
// > Le modèle note **sur 10** (`docs/02` §3.3), `CatalogBounds.ratings` vaut `0...10`, et
// > `TitleFormat.fiveStarRating` divise par deux depuis le prompt 11.
//
// C'est le piège qui a déjà mordu : « pas de demi-étoile » a été appliqué une fois au
// modèle, bornant `Title.rating` à `0...5` et refusant les décimales — l'import aurait
// alors rejeté **la moitié de l'échelle**. Ce composant vit donc entièrement dans
// l'espace d'affichage : il reçoit une note **déjà convertie sur 5**, comme
// `PosterCardModel.rating`, et il ne décide rien de ce qui s'écrit en base.
//
// **Ce que la version éditable émet, et pourquoi c'est sans perte.** Elle ne propose que
// des crans entiers, comme le design le demande — l'appelant remultiplie par deux, donc
// écrit 0, 2, 4, 6, 8 ou 10. Une note impaire déjà en base (9/10, venue d'un import) n'est
// **pas** réécrite en ouvrant l'éditeur : la barre n'émet que sur un geste. C'est la
// distinction qui rend la règle du design applicable sans amputer l'échelle.
//
// **Et une note fractionnaire, alors ?** Elle s'affiche « ★ 4,5 » — un glyphe et le
// nombre — sur la ligne de métadonnées de la **fiche titre** (planche 3 bloc `4b`). Cette
// barre-ci arrondit au cran le plus proche pour choisir son nombre d'étoiles : elle n'est
// pas l'affichage de référence d'une note fractionnaire.
//
// MARK: - LACUNE DE DESIGN — la barre seule perd de l'information, en silence
//
// **Arrondir n'est pas le problème ; c'est que le design ne montre jamais la valeur à
// côté de la barre.** 8,4 sur 10 donne quatre étoiles, et 8,0 aussi. Partout où la barre
// paraît seule, les deux notes sont indistinguables, et rien ne signale qu'un chiffre a
// été perdu.
//
// Relevé au 2026-08-04 — **huit occurrences dans la direction retenue montrent la barre
// sans valeur** :
//
// | Écran | Bloc |
// |---|---|
// | Accueil, ligne de méta du hero | planche 1 `2a` |
// | Fiche titre, rangée d'actions | planche 3 `4b` |
// | Champ « Note » d'un formulaire | planche 6 `8a` (barre + « effacer », aucun nombre) |
// | Fiche et panneau, « Ma note » | planche 6 `8c`, `8e` |
// | Accueil et fiche, iPhone et iPad | addendum 2, quatre écrans |
//
// Les deux seuls endroits qui portent le nombre — `★ 4,5` sur la carte (planche 3 `4a`)
// et `★ 4` dans le filtre (planche 6) — sont ceux où la barre n'est **pas** utilisée. Le
// design ne les associe jamais.
//
// **C'est dans l'éditeur que ça a des conséquences, pas sur le hero.** Un titre noté 8,4
// s'y présente comme quatre étoiles pleines ; toucher une étoile écrit une valeur entière,
// donc la décimale disparaît — et l'utilisateur n'a jamais vu qu'il en avait une. Sur le
// hero, la même approximation n'est qu'un affichage.
//
// **Ce que ce composant ne fait pas, et pourquoi.** Il n'invente pas de demi-étoile : la
// direction l'exclut explicitement. Il ne colle pas non plus le nombre d'autorité — ce
// serait ajouter au design un élément qu'aucune planche ne montre, exactement le genre de
// comblement qui a déjà mal tourné ici. La question part au design ; d'ici là, l'appelant
// qui affiche une note **modifiable** doit poser la valeur à côté (`TitleFormat.ratingText`
// rend « 8,4 / 10 »). Inscrit aux écarts connus de `docs/PROMPTS.md`.

/// Cinq étoiles, en lecture ou en saisie.
public struct RatingBar: View {
    private let rating: Double?
    private let scale: Scale
    private let onChange: ((Int) -> Void)?

    /// Le facteur de Dynamic Type, mesuré une fois.
    ///
    /// Une étoile est un SF Symbol, et `Font.system(size:)` ne prend pas de `relativeTo:`
    /// — la règle « aucune taille de police fixe » resterait donc contournée par un
    /// nombre en dur. `@ScaledMetric` donne le facteur du cran courant, dont on multiplie
    /// les trois tailles du design. C'est ce qui fait qu'une note reste lisible à AX5.
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    /// Le nombre d'étoiles. Cinq, et ce n'est pas un réglage — c'est la règle du design.
    public static let starCount = 5

    /// Les trois tailles relevées : 16 pt en panneau, 20 pt en formulaire, 30 pt sur une
    /// fiche.
    public enum Scale: Sendable, CaseIterable {
        case compact, form, detail

        var size: CGFloat {
            switch self {
            case .compact: 16
            case .form: 20
            case .detail: 30
            }
        }

        var spacing: CGFloat {
            switch self {
            case .compact: Space.s1
            case .form: Space.s1 + 1
            case .detail: Space.s2 + 2
            }
        }
    }

    /// - Parameters:
    ///   - rating: la note **sur 5**, déjà convertie depuis l'échelle 0–10 du modèle.
    ///     `nil` quand le titre n'est pas noté : les cinq étoiles sont alors vides.
    ///   - scale: la taille du cran, selon le contexte.
    ///   - onChange: `nil` rend la barre inerte, donc en lecture. Sinon elle reçoit le
    ///     nombre d'étoiles choisi, de 0 à 5 — et 0 signifie « effacer ».
    public init(
        _ rating: Double?,
        scale: Scale = .form,
        onChange: ((Int) -> Void)? = nil
    ) {
        self.rating = rating
        self.scale = scale
        self.onChange = onChange
    }

    public var body: some View {
        HStack(spacing: scale.spacing) {
            ForEach(1...Self.starCount, id: \.self) { position in
                star(position)
            }
            if onChange != nil, filledCount > 0 {
                clearButton
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Note")
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction(adjust)
    }

    /// Le nombre d'étoiles pleines : la note arrondie au cran le plus proche.
    ///
    /// **Elle borne l'affichage, elle ne valide rien.** Une note hors échelle rend cinq
    /// étoiles ou zéro, jamais six ni moins que rien — mais elle n'est pas refusée : ce
    /// composant ne décide pas de ce qui s'écrit en base.
    static func filledCount(for rating: Double?) -> Int {
        guard let rating, rating.isFinite else { return 0 }
        return min(starCount, max(0, Int(rating.rounded())))
    }

    private var filledCount: Int { Self.filledCount(for: rating) }

    @ViewBuilder private func star(_ position: Int) -> some View {
        let isFilled = position <= filledCount
        let image = Image(systemName: Icon.ratingStar)
            .symbolVariant(isFilled ? .fill : .none)
            .font(.system(size: scale.size * typeScale))
            .foregroundStyle(isFilled ? Color.accent : Color.bgFill)

        if let onChange {
            Button {
                // Toucher l'étoile déjà atteinte efface la note : c'est le geste
                // qu'attend quiconque a déjà noté, et « effacer » reste là pour le
                // clavier et pour VoiceOver.
                onChange(position == filledCount ? 0 : position)
            } label: {
                image
                    .frame(minWidth: Space.minHitTarget, minHeight: Space.minHitTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        } else {
            image
        }
    }

    private var clearButton: some View {
        Button("Effacer") { onChange?(0) }
            .buttonStyle(.plain)
            .actionStyle()
            .foregroundStyle(Color.textTertiary)
            .frame(minHeight: Space.minHitTarget)
            .accessibilityHidden(true)
    }

    private var accessibilityValue: String {
        filledCount == 0 ? "non notée" : "\(filledCount) sur \(Self.starCount)"
    }

    /// VoiceOver et le clavier passent par là plutôt que par cinq boutons annoncés un à
    /// un : « 3 étoiles sur 5 », qu'on ajuste, se parcourt en un geste au lieu de cinq.
    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        guard let onChange else { return }
        switch direction {
        case .increment: onChange(min(Self.starCount, filledCount + 1))
        case .decrement: onChange(max(0, filledCount - 1))
        @unknown default: break
        }
    }
}

// MARK: - Previews

#Preview("Notation · lecture et saisie") {
    @Previewable @State var rating: Double? = 4

    VStack(alignment: .leading, spacing: Space.s5) {
        ForEach(RatingBar.Scale.allCases, id: \.self) { scale in
            RatingBar(4, scale: scale)
        }
        RatingBar(nil, scale: .form)
        RatingBar(rating, scale: .detail) { rating = Double($0) }
        // Une note impaire du modèle : 9/10 arrive ici en 4,5.
        RatingBar(4.5, scale: .form)
    }
    .padding(Space.s5)
    .background(Color.bgCanvas)
}
