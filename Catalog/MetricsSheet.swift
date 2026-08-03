import DesignSystem
import SwiftUI

// Rayons, espacements, élévations. Les trois échelles se lisent mieux dessinées
// que listées : chaque valeur est rendue à sa taille réelle, avec son nom.

struct MetricsSheet: View {
    var body: some View {
        Sheet(
            "Rayons · Espacements · Élévations",
            note: "Chaque valeur est dessinée à sa taille réelle."
        ) {
            VStack(alignment: .leading, spacing: Space.section) {
                radii
                spacings
                elevations
                ratios
            }
        }
    }

    // MARK: Rayons

    private static let radii: [(String, CGFloat)] = [
        ("xs", Radius.xs), ("sm", Radius.sm), ("md", Radius.md),
        ("lg", Radius.lg), ("xl", Radius.xl)
    ]

    private var radii: some View {
        section("Rayons", note: "Toujours continus : Radius.shape(_:) ou .dsClip(_:).") {
            HStack(alignment: .top, spacing: Space.lg) {
                ForEach(Self.radii, id: \.0) { name, value in
                    VStack(spacing: Space.sm) {
                        RoundedRectangle(cornerRadius: value, style: .continuous)
                            .fill(.bgSurfaceRaised)
                            .dsBorder(.borderDefault, radius: value)
                            .frame(width: 80, height: 80)
                        caption("\(name) · \(number(value))")
                    }
                }
            }
        }
    }

    // MARK: Espacements

    private static let spacings: [(String, CGFloat)] = [
        ("xxs", Space.xxs), ("xs", Space.xs), ("sm", Space.sm), ("md", Space.md),
        ("lg", Space.lg), ("xl", Space.xl), ("xxl", Space.xxl), ("xxxl", Space.xxxl)
    ]

    private static let roles: [(String, CGFloat)] = [
        ("inlineTight", Space.inlineTight), ("inline", Space.inline),
        ("stackTight", Space.stackTight), ("stack", Space.stack),
        ("section", Space.section), ("cardPadding", Space.cardPadding),
        ("panelPadding", Space.panelPadding), ("minHitTarget", Space.minHitTarget)
    ]

    private var spacings: some View {
        section("Espacements", note: "L'échelle, puis les rôles qui s'y rattachent.") {
            VStack(alignment: .leading, spacing: Space.lg) {
                ForEach(Self.spacings, id: \.0) { name, value in
                    bar(name: name, value: value)
                }
                Divider().overlay(.borderSubtle)
                ForEach(Self.roles, id: \.0) { name, value in
                    bar(name: name, value: value)
                }
            }
        }
    }

    private func bar(name: String, value: CGFloat) -> some View {
        HStack(spacing: Space.md) {
            caption(name).frame(width: 120, alignment: .leading)
            RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                .fill(.accentSolid)
                .frame(width: value, height: 16)
            caption(number(value)).foregroundStyle(.textTertiary)
        }
    }

    // MARK: Élévations

    private var elevations: some View {
        section(
            "Élévations",
            note: "Au-delà du niveau 1, la profondeur vient d'un matériau, pas d'une ombre."
        ) {
            HStack(alignment: .top, spacing: Space.lg) {
                ForEach(Elevation.Level.allCases, id: \.rawValue) { level in
                    VStack(spacing: Space.sm) {
                        Text("\(level.rawValue)")
                            .font(Typo.dataValue)
                            .foregroundStyle(.textPrimary)
                            .frame(width: 110, height: 80)
                            .dsElevation(level)
                        caption(String(describing: level))
                    }
                }
            }
            .padding(Space.md)
            .background(.bgInset, in: .rect(cornerRadius: Radius.lg, style: .continuous))
        }
    }

    // MARK: Proportions

    private static let ratios: [(String, CGFloat)] = [
        ("poster", Ratio.poster), ("backdrop", Ratio.backdrop),
        ("landscape", Ratio.landscape), ("avatar", Ratio.avatar), ("tile", Ratio.tile)
    ]

    private var ratios: some View {
        section("Proportions", note: nil) {
            HStack(alignment: .bottom, spacing: Space.lg) {
                ForEach(Self.ratios, id: \.0) { name, value in
                    VStack(spacing: Space.sm) {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(.mediaPlaceholder)
                            .aspectRatio(value, contentMode: .fit)
                            .frame(height: 96)
                        caption(name)
                    }
                }
            }
        }
    }

    // MARK: Habillage

    private func section(
        _ title: String, note: String?, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(title).railLabelStyle()
            if let note { Text(note).font(Typo.caption).foregroundStyle(.textTertiary) }
            content()
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(Typo.cardMeta).foregroundStyle(.textSecondary)
    }

    private func number(_ value: CGFloat) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.2f", value)
    }
}
