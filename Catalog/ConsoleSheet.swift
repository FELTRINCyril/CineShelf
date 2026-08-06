import DesignSystem
import SwiftUI

// Les trois composants de `I5`, aux deux crans de densité — c'est la fiche du lot qui l'exige,
// et c'est le seul lot dont les deux crans changent vraiment quelque chose : la console est
// dense sur Mac et ample sur iPad, et la même ligne y passe de 30 à 44 pt.
//
// Ce qu'on vient vérifier ici, et qu'aucun test ne montre :
//
// - que les colonnes du corps tombent **exactement** sous celles de l'en-tête, à un pixel
//   près, aux deux densités. C'est ce que `.tableCell(width:)` promet, et un décalage se voit
//   d'un coup d'œil là où il faudrait dix assertions pour le mesurer ;
// - qu'une ligne **sélectionnée** et une ligne **survolée** ne se ressemblent pas. Le fond est
//   le même à moitié ; seule la barre d'accent les sépare, et c'est une déduction — aucun bloc
//   ne rend une ligne sélectionnée ;
// - que le jeton actif et le jeton inactif restent distincts **sans** la différence de graisse
//   du prototype, que le système ne peut pas produire ;
// - que les compteurs restent alignés en colonne quand les nombres changent de longueur.

struct ConsoleSheet: View {

    private struct Row: Identifiable {
        let id = UUID()
        let title: String
        let year: String
        let genre: String
        let runtime: String
        let rating: String
    }

    private static let rows = [
        Row(title: "Dune", year: "2021", genre: "Science-fiction", runtime: "155 min", rating: "4,5"),
        Row(title: "Oppenheimer", year: "2023", genre: "Biographie", runtime: "181 min", rating: "4,8"),
        Row(
            title: "Everything Everywhere All at Once", year: "2022", genre: "Comédie",
            runtime: "139 min", rating: "4,2"),
        Row(title: "Nomadland", year: "2021", genre: "Drame", runtime: "108 min", rating: "3,9")
    ]

    private static let entities = [
        ("Titres", 1_284), ("Personnes", 3_902), ("Collections", 38), ("Genres", 62),
        ("Casting", 14_118), ("Images", 7_411), ("Liens", 204), ("Corbeille", 41)
    ]

    @State private var selected: UUID?
    @State private var activeChips: Set<String> = ["Titres", "Drame"]

    var body: some View {
        Sheet(
            "Ligne · Jeton · Compteur · I5",
            note: """
                Le lot de la console. Les trois composants sont rendus aux **deux** crans de \
                densité : la console est dense sur Mac et ample sur iPad, et c'est le seul lot \
                où le cran change une géométrie et non seulement un espacement.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                tables
                chips
                counters
            }
        }
    }

    // MARK: La ligne de tableau

    private var tables: some View {
        section(
            "Ligne de tableau",
            note: """
                Quatre lignes, dont une sélectionnée. Le survol se voit à la souris — c'est le \
                seul état de ce lot qu'une capture ne montre pas.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s5) {
                ForEach([Density.dense, .roomy], id: \.self) { density in
                    VStack(alignment: .leading, spacing: Space.s2) {
                        Text(
                            verbatim: """
                                \(density == .dense ? "dense" : "ample") · \
                                ligne de \(Int(ConsoleMetrics.rowHeight(density))) pt
                                """
                        )
                        .font(Typo.micro)
                        .foregroundStyle(.textTertiary)
                        table
                            .environment(\.density, density)
                            .frame(width: 620)
                            .background(.bgInset)
                    }
                }
                BlockNote(.tableRow)
            }
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            TableRow(isHeader: true) {
                Color.clear.frame(width: ConsoleMetrics.thumbnailWidth).tableCell(
                    width: ConsoleMetrics.thumbnailWidth)
                Text("Titre").tableCell()
                Text("Année").tableCell(width: 56, alignment: .trailing)
                Text("Genre").tableCell(width: 118)
                Text("Durée").tableCell(width: 66, alignment: .trailing)
                Text("Note").tableCell(width: 54, alignment: .trailing)
            }
            .font(Typo.label)
            .textCase(.uppercase)
            .foregroundStyle(.textTertiary)

            ForEach(Self.rows) { row in
                TableRow(
                    isSelected: selected == row.id, action: { selected = row.id },
                    content: {
                        thumbnail.tableCell(width: ConsoleMetrics.thumbnailWidth)
                        Text(row.title).tableCell()
                        Text(row.year).font(Typo.numeric).tableCell(width: 56, alignment: .trailing)
                        Text(row.genre).tableCell(width: 118)
                        Text(row.runtime).font(Typo.numeric).tableCell(width: 66, alignment: .trailing)
                        Text(row.rating)
                            .font(Typo.numeric)
                            .foregroundStyle(.accent)
                            .tableCell(width: 54, alignment: .trailing)
                    }
                )
                .font(Typo.callout)
                .foregroundStyle(.textPrimary)
            }
        }
    }

    /// La vignette de 16 × 24, avec une **vraie image** : c'est la leçon de `catalogue-images`,
    /// et une pastille vide ne dirait pas si l'affiche est écrasée à ce cran.
    private var thumbnail: some View {
        MediaFill(
            imageURL: SampleImageURL.url(.loaded, seed: 91),
            crop: .neutral,
            targetAspect: Ratio.poster,
            background: .bgSurface
        )
        .frame(width: ConsoleMetrics.thumbnailWidth, height: ConsoleMetrics.thumbnailHeight)
        .clipped()
    }

    // MARK: Le jeton de filtre

    private var chips: some View {
        section(
            "Jeton de filtre",
            note: """
                Actif en ambre plein, inactif en `bg.fill`. La croix n'apparaît que sur un \
                jeton **actif** qui peut être retiré : le sélecteur exclusif du bloc `7d` n'en \
                a pas, la rangée de filtres du bloc `4a` en a une.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s5) {
                ForEach([Density.dense, .roomy], id: \.self) { density in
                    VStack(alignment: .leading, spacing: Space.s3) {
                        Text(verbatim: density == .dense ? "dense" : "ample")
                            .font(Typo.micro)
                            .foregroundStyle(.textTertiary)
                        HStack(spacing: Space.s2) {
                            ForEach(["Titres", "Personnes", "Collections"], id: \.self) { name in
                                FilterChip(LocalizedStringKey(name), isOn: activeChips.contains(name)) {
                                    toggle(name)
                                }
                            }
                        }
                        HStack(spacing: Space.s2) {
                            FilterChip(
                                "Drame",
                                isOn: activeChips.contains("Drame"),
                                onRemove: { activeChips.remove("Drame") },
                                action: { toggle("Drame") })
                            FilterChip(
                                "Note ≥ 4",
                                isOn: activeChips.contains("Note ≥ 4"),
                                onRemove: { activeChips.remove("Note ≥ 4") },
                                action: { toggle("Note ≥ 4") })
                        }
                    }
                    .environment(\.density, density)
                }
                BlockNote(.filterChip)
            }
        }
    }

    private func toggle(_ name: String) {
        if activeChips.contains(name) {
            activeChips.remove(name)
        } else {
            activeChips.insert(name)
        }
    }

    // MARK: La pastille de compteur

    private var counters: some View {
        section(
            "Compteur d'entité",
            note: """
                Aucun fond, aucune pilule : le bloc `7a` ne dessine qu'un nombre en mono, \
                poussé à droite. Les huit compteurs doivent rester alignés malgré des longueurs \
                de 2 à 6 caractères.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s4) {
                VStack(spacing: 0) {
                    ForEach(Self.entities, id: \.0) { entity in
                        HStack(spacing: Space.s3) {
                            Text(entity.0).font(Typo.callout).foregroundStyle(.textSecondary)
                            Spacer(minLength: Space.s4)
                            CountBadge(entity.1)
                        }
                        .padding(.horizontal, Space.s4)
                        .frame(height: ConsoleMetrics.rowHeight(.dense))
                    }
                }
                .frame(width: 206)
                .background(.bgSurface)
                BlockNote(.countBadge)
            }
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
