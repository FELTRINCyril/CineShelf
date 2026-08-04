import SwiftUI

// MARK: - I6 · L'indicateur de progression
//
// Relevé sur l'addendum 1, bloc `11e` — la barre de l'aperçu d'import :
//
//     <span style="flex:1;height:6px;background:oklch(0.28 0 0);display:flex;
//                  overflow:hidden">
//       <span style="width:60%;background:oklch(0.78 0.15 150)"></span>
//       <span style="width:32.5%;background:oklch(0.68 0.19 25)"></span>
//       <span style="width:7.5%;background:oklch(0.6 0 0)"></span>
//     </span>
//
// **Ce composant applique une convention que le design a explicitement laissée ouverte.**
// Le §10 du handoff, « Ouvert par les addenda », point 4 :
//
// > **Piste de progression.** Aucun token de piste ni de remplissage. La barre
// > 771 / 417 / 96 utilise `bg.fill` en piste et `success`, `danger`, `text.tertiary` en
// > segments. Ça fonctionne, mais toute future barre devra reprendre cette convention
// > sans qu'elle soit écrite dans la planche 8.
//
// « Toute future barre devra reprendre cette convention » est exactement ce qu'un
// composant sait garantir et qu'une note ne garantit pas. C'est la raison d'être de ce
// fichier : la convention n'existe qu'ici, et une barre qui la reprendrait à la main dans
// un écran serait le défaut que `I6` existe pour empêcher.
//
// **Aucun jeton n'est inventé pour autant.** Piste `bg.fill`, segments `success`,
// `danger`, `text.tertiary` — les quatre existent. Si un `warning` ou un jeton de piste
// arrive un jour dans la planche 8, c'est ce fichier qui change, et lui seul.

/// Une part de la piste : un compte et sa teinte.
public struct ProgressSegment: Identifiable, Sendable, Hashable {
    public let id: String
    /// Le compte de cette part. Nomme `value` et non `count` : ce n'est pas la taille
    /// d'une collection mais un nombre de lignes, et `empty_count` a raison de le
    /// signaler — 771 lignes pretes n'est pas `segments.count`.
    public let value: Int
    public let role: ProgressRole

    public init(id: String, value: Int, role: ProgressRole) {
        self.id = id
        self.value = value
        self.role = role
    }
}

/// Les quatre rôles relevés. Ce sont des jetons existants, pas des couleurs neuves.
public enum ProgressRole: Sendable, CaseIterable {
    case done, failed, neutral, inProgress

    var color: Color {
        switch self {
        case .done: Color.success
        case .failed: Color.danger
        case .neutral: Color.textTertiary
        case .inProgress: Color.accent
        }
    }
}

// MARK: - L'arithmétique, hors de la vue
//
// **Séparée de `ProgressTrack` pour la même raison que `GridMetrics` l'est de
// `AdaptiveTileGrid`, plus une seconde qui n'est apparue qu'à l'exécution.** `View` est
// `@MainActor`, donc tout ce qui vit sur la vue l'est aussi — et une clôture qui capture
// `self` déclenche un contrôle d'isolation qui **fait sauter le processus de test**
// (`_swift_task_checkIsolatedSwift`, `SIGTRAP`), pas un échec d'assertion. Une
// arithmétique pure n'a aucune raison d'être isolée : elle sort, et elle se teste.

public enum ProgressMetrics {

    /// Les largeurs des segments dans une piste d'une largeur donnée.
    ///
    /// C'est la seule arithmétique du composant, et c'est là que se logent les divisions
    /// par zéro et les débordements.
    public static func widths(
        of segments: [ProgressSegment],
        total: Int,
        in available: CGFloat
    ) -> [CGFloat] {
        segments.map { segment in
            guard total > 0, available > 0, segment.value > 0 else { return 0 }
            // Plafonnée : un compte supérieur à son total déborderait la piste, et un
            // appelant qui se trompe de dénominateur ne doit pas produire une barre plus
            // large que son cadre.
            return min(available, available * CGFloat(segment.value) / CGFloat(total))
        }
    }
}

/// Une piste de progression, en un ou plusieurs segments.
public struct ProgressTrack: View {
    private let segments: [ProgressSegment]
    private let total: Int

    /// La hauteur du prototype. Pas un cran d'espacement : c'est l'épaisseur d'une piste,
    /// et la rattacher à `Space` ferait croire qu'elle suit la densité.
    public static let thickness: CGFloat = 6

    /// - Parameters:
    ///   - segments: les parts, dans l'ordre où elles se posent de gauche à droite.
    ///   - total: le dénominateur. Quand il dépasse la somme des segments, le reste de la
    ///     piste reste vide — c'est ce qui distingue « 312 sur 1 284 » d'un partage.
    public init(segments: [ProgressSegment], total: Int) {
        self.segments = segments
        self.total = total
    }

    /// Une piste à un seul segment : le cas d'une progression ordinaire.
    public init(value: Int, total: Int, role: ProgressRole = .inProgress) {
        self.init(
            segments: [ProgressSegment(id: "value", value: value, role: role)], total: total)
    }

    public var body: some View {
        GeometryReader { proxy in
            let widths = ProgressMetrics.widths(
                of: segments, total: total, in: proxy.size.width)
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    segment.role.color
                        .frame(width: widths[index])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: Self.thickness)
        .background(Color.bgFill)
        .clipped()
        .accessibilityElement()
        .accessibilityLabel("Progression")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let counted = segments.reduce(0) { $0 + $1.value }
        return "\(counted) sur \(total)"
    }
}

// MARK: - Previews

#Preview("Progression · segmentée et simple") {
    VStack(alignment: .leading, spacing: Space.s5) {
        // La barre de l'aperçu d'import : 1 284 lignes, 771 prêtes, 417 en erreur,
        // 96 doublons.
        ProgressTrack(
            segments: [
                ProgressSegment(id: "ok", value: 771, role: .done),
                ProgressSegment(id: "ko", value: 417, role: .failed),
                ProgressSegment(id: "dup", value: 96, role: .neutral)
            ],
            total: 1284)
        // La synchronisation du bloc 9d : « 312 sur 1 284 ». Le reste est vide.
        ProgressTrack(value: 312, total: 1284)
        ProgressTrack(value: 0, total: 100)
        ProgressTrack(value: 100, total: 100, role: .done)
    }
    .frame(width: 420)
    .padding(Space.s5)
    .background(Color.bgCanvas)
}
