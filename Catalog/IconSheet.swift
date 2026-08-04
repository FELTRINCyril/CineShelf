import DesignSystem
import SwiftUI

// Les SF Symbols de la correspondance, section 8 du handoff.
//
// Un nom de symbole faux ne casse pas la compilation : il rend un carré vide. Cette
// planche est donc la vérification visuelle qui va avec `IconTests`, et elle affiche
// le nom sous chaque symbole pour qu'un carré vide soit immédiatement attribuable.

struct IconSheet: View {
    var body: some View {
        Sheet(
            "Symboles",
            note: """
                \(Icon.all.count) symboles. Rendu .regular partout, hierarchical avec du \
                texte, monochrome dans les barres. Un seul symbole prend l'ambre : celui \
                de l'élément actif.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                group(
                    "Navigation",
                    [
                        ("home", Icon.home), ("titles", Icon.titles), ("people", Icon.people),
                        ("collections", Icon.collections), ("gallery", Icon.gallery),
                        ("search", Icon.search), ("myList", Icon.myList),
                        ("bookmarks", Icon.bookmarks), ("feed", Icon.feed)
                    ])
                group(
                    "Actions",
                    [
                        ("addTitle", Icon.addTitle), ("edit", Icon.edit),
                        ("delete", Icon.delete), ("importItem", Icon.importItem),
                        ("exportItem", Icon.exportItem), ("merge", Icon.merge),
                        ("crop", Icon.crop), ("replaceImage", Icon.replaceImage)
                    ])
                group(
                    "Affichage",
                    [
                        ("sort", Icon.sort), ("filter", Icon.filter),
                        ("layoutPortrait", Icon.layoutPortrait),
                        ("layoutLandscape", Icon.layoutLandscape),
                        ("thumbnailSize", Icon.thumbnailSize)
                    ])
                group(
                    "États d'une fiche",
                    [
                        ("ratingStar", Icon.ratingStar), ("watchedMark", Icon.watchedMark),
                        ("isPrivate", Icon.isPrivate)
                    ])
                group(
                    "Profils et système",
                    [
                        ("lockedProfile", Icon.lockedProfile),
                        ("lockFallback", Icon.lockFallback),
                        ("settings", Icon.settings), ("profiles", Icon.profiles)
                    ])
                group(
                    "Bandeaux d'interruption",
                    [
                        ("offline", Icon.offline), ("sync", Icon.sync),
                        ("diskSpace", Icon.diskSpace), ("error", Icon.error)
                    ])
                group(
                    "Chrome",
                    [
                        ("close", Icon.close), ("moreActions", Icon.moreActions),
                        ("navigateForward", Icon.navigateForward),
                        ("fullScreen", Icon.fullScreen)
                    ])
            }
        }
    }

    private func group(_ title: String, _ symbols: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(title).labelStyle()
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: Space.s3)],
                spacing: Space.s4
            ) {
                ForEach(symbols, id: \.0) { name, symbol in
                    VStack(spacing: Space.s2) {
                        Image(systemName: symbol)
                            .symbolRenderingMode(.monochrome)
                            .font(.title2)
                            .foregroundStyle(.textPrimary)
                            .frame(height: 28)
                        Text(name).metaStyle().foregroundStyle(.textSecondary)
                        Text(symbol).microStyle().foregroundStyle(.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(name), \(symbol)")
                }
            }
        }
    }
}
