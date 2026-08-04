import SwiftUI

// MARK: - I2 · La tuile de personne
//
// Une personne n'est pas un titre, et deux différences le rendent visible :
//
// 1. **Le nom est toujours affiché.** Une affiche se reconnaît, un visage rarement — la
//    tuile nue de `PosterTile` marcherait pour un acteur célèbre et pour personne d'autre.
//    Le handoff le dit de son côté (§11) : « Portraits de personnes : aucun. Les fiches
//    personne utilisent une affiche recadrée. »
// 2. **Le repli n'est pas un aplat, ce sont les initiales.** Un pavé vide répété sur une
//    grille de deux cents personnes ne donne aucune prise ; les initiales, si.
//
// Les crans restent ceux du système : `PosterContext.people` donne `s / m / xl`, et
// `homePeople` donne `s / m / l`. C'est pour ça que cette tuile ne définit aucune taille à
// elle — elle reçoit un `PosterScale` comme les autres.

/// Une personne : portrait ou initiales, avec son nom et son rôle.
public struct PersonTile: View {
    private let model: PosterCardModel
    private let scale: PosterScale
    private let action: (() -> Void)?

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ model: PosterCardModel,
        scale: PosterScale = .s,
        action: (() -> Void)? = nil
    ) {
        self.model = model
        self.scale = scale
        self.action = action
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: Space.s2) {
                portrait
                caption
            }
            .frame(width: scale.width, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering && action != nil ? 1.06 : 1)
        .animation(reduceMotion ? Motion.instant : Motion.fast, value: isHovering)
        .onHover { isHovering = $0 }
        .focusable(action != nil)
        .accessibilityLabel(model.accessibilityDescription)
        .accessibilityAddTraits(action == nil ? [] : .isButton)
    }

    /// Toujours en portrait : une personne en 16:9 est un plan de coupe, pas un portrait.
    /// La tuile ignore donc `CardLayout`, et c'est délibéré — l'exposer serait offrir un
    /// réglage qui n'a pas de bonne valeur.
    private var portrait: some View {
        Group {
            if model.isPrivate {
                Color.privateMask.overlay {
                    Image(systemName: Icon.isPrivate)
                        .font(.system(size: min(scale.width * 0.22, 28)))
                        .foregroundStyle(Color.textTertiary)
                }
            } else if model.imageURL == nil {
                initials
            } else {
                MediaFill(
                    imageURL: model.imageURL,
                    crop: model.crop,
                    targetAspect: CardLayout.portrait.aspectRatio,
                    background: Color.bgSurface
                )
            }
        }
        .frame(
            width: scale.width,
            height: scale.width / CardLayout.portrait.aspectRatio
        )
        .clipped()
    }

    /// Deux lettres au plus, sur le fond de surface — pas d'accent : deux cents pavés
    /// ambre feraient une grille clignotante.
    private var initials: some View {
        Color.bgSurface.overlay {
            Text(Self.initials(of: model.title))
                .font(Typo.title2(.large))
                .foregroundStyle(Color.textTertiary)
        }
    }

    /// Le nom, puis le rôle ou l'information secondaire.
    ///
    /// Les deux lignes sont réservées même quand la seconde est vide : sans ça, une rangée
    /// où une seule personne porte un rôle voit toutes ses tuiles se désaligner.
    private var caption: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.title)
                .font(Typo.callout)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Text(model.meta ?? " ")
                .font(Typo.label)
                .tracking(Typo.Tracking.label)
                .textCase(.uppercase)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
        }
    }

    /// Les initiales d'un nom affiché.
    ///
    /// Prend la première lettre du premier et du dernier mot — « Marlon Brando » → « MB »,
    /// « Bong Joon-ho » → « BJ ». Un nom d'un seul mot rend une seule lettre. Les mots vides
    /// sont écartés parce qu'un nom composé (« Jean de La Fontaine ») donnerait sinon
    /// « JL » au lieu de « JF ».
    static func initials(of displayName: String) -> String {
        let particles: Set<String> = ["de", "du", "des", "la", "le", "van", "von", "di", "da"]
        let words =
            displayName
            .split(whereSeparator: { $0 == " " || $0 == "-" })
            .map(String.init)
            .filter { !particles.contains($0.lowercased()) }
        guard let first = words.first else { return "" }
        let letters = [first, words.count > 1 ? words[words.count - 1] : ""]
            .compactMap { $0.first }
            .map { String($0).uppercased() }
        return letters.joined()
    }
}

#Preview("Personnes, quatre crans") {
    HStack(alignment: .top, spacing: Space.s4) {
        ForEach([PosterScale.s, .m, .l, .xl]) { scale in
            PersonTile(.person, scale: scale) {}
        }
    }
    .padding(Space.s5)
    .background(Color.bgCanvas)
}

#Preview("Repli sur les initiales") {
    HStack(alignment: .top, spacing: Space.s3) {
        ForEach(PosterCardModel.people) { person in
            PersonTile(person, scale: .m) {}
        }
    }
    .padding(Space.s5)
    .background(Color.bgCanvas)
}

// MARK: - Échantillons

extension PosterCardModel {
    /// Une personne, pour les previews et le catalogue.
    public static let person = PosterCardModel(
        id: "p1", title: "Marlon Brando", kind: .person, meta: "Acteur")

    /// De quoi éprouver le repli sur initiales : un nom composé, un nom à particule, un
    /// nom d'un seul mot, un nom privé.
    public static let people: [PosterCardModel] = [
        .init(id: "p1", title: "Marlon Brando", kind: .person, meta: "Acteur"),
        .init(id: "p2", title: "Bong Joon-ho", kind: .person, meta: "Réalisateur"),
        .init(id: "p3", title: "Jean de La Fontaine", kind: .person, meta: "Scénariste"),
        .init(id: "p4", title: "Cher", kind: .person),
        .init(id: "p5", title: "Anonyme", kind: .person, isPrivate: true)
    ]
}
