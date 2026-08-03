import SwiftUI

// MARK: - Modèles de présentation de filtrage

public struct SortOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let symbol: String

    public init(id: String, label: String, symbol: String = Icon.sort) {
        self.id = id
        self.label = label
        self.symbol = symbol
    }

    public static let samples: [SortOption] = [
        .init(id: "added", label: "Ajout récent"),
        .init(id: "title", label: "Titre"),
        .init(id: "year", label: "Année"),
        .init(id: "rating", label: "Note")
    ]
}

/// Jeton de filtre actif, supprimable.
public struct FilterToken: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let symbol: String?

    public init(id: String, label: String, symbol: String? = nil) {
        self.id = id
        self.label = label
        self.symbol = symbol
    }

    public static let samples: [FilterToken] = [
        .init(id: "g-action", label: "Action", symbol: Icon.genres),
        .init(id: "fav", label: "Favoris", symbol: Icon.favorite.on),
        .init(id: "y-90", label: "1990–1999")
    ]
}

public struct FilterGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let options: [FilterToken]

    public init(id: String, label: String, options: [FilterToken]) {
        self.id = id
        self.label = label
        self.options = options
    }
}

// MARK: - FilterBar

public struct FilterBar: View {
    @Binding private var sort: SortOption
    @Binding private var ascending: Bool
    @Binding private var tokens: [FilterToken]
    private let sortOptions: [SortOption]
    private let groups: [FilterGroup]

    public init(
        sort: Binding<SortOption>,
        ascending: Binding<Bool>,
        tokens: Binding<[FilterToken]>,
        sortOptions: [SortOption] = SortOption.samples,
        groups: [FilterGroup] = []
    ) {
        _sort = sort
        _ascending = ascending
        _tokens = tokens
        self.sortOptions = sortOptions
        self.groups = groups
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                sortMenu
                filterMenu
                Spacer(minLength: Space.sm)
                if !tokens.isEmpty {
                    Button("Tout effacer") { tokens.removeAll() }
                        .font(Typo.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.accentText)
                        .frame(minHeight: Space.minHitTarget)
                }
            }

            if !tokens.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: Space.sm) {
                        ForEach(tokens) { token in
                            TokenChip(token: token) { remove(token) }
                        }
                    }
                    .padding(.bottom, Space.xxs)
                }
                .scrollIndicators(.hidden)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .dsAnimation(Motion.base, value: tokens)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Trier par", selection: $sort) {
                ForEach(sortOptions) { option in
                    Text(option.label).tag(option)
                }
            }
            Divider()
            Picker("Ordre", selection: $ascending) {
                Text("Croissant").tag(true)
                Text("Décroissant").tag(false)
            }
        } label: {
            MenuLabel(symbol: Icon.sort, text: sort.label)
        }
        .accessibilityLabel("Trier, actuellement \(sort.label), \(ascending ? "croissant" : "décroissant")")
    }

    private var filterMenu: some View {
        Menu {
            if groups.isEmpty {
                Text("Aucun filtre disponible")
            }
            ForEach(groups) { group in
                Section(group.label) {
                    ForEach(group.options) { option in
                        Button {
                            toggle(option)
                        } label: {
                            Label(
                                option.label,
                                systemImage: tokens.contains(option) ? "checkmark" : (option.symbol ?? Icon.genres))
                        }
                    }
                }
            }
        } label: {
            MenuLabel(
                symbol: Icon.filter,
                text: tokens.isEmpty ? "Filtrer" : "\(tokens.count) filtre\(tokens.count > 1 ? "s" : "")",
                isActive: !tokens.isEmpty)
        }
        .accessibilityLabel("Filtrer, \(tokens.count) filtre actif")
    }

    private func toggle(_ token: FilterToken) {
        if let index = tokens.firstIndex(of: token) { tokens.remove(at: index) } else { tokens.append(token) }
    }

    private func remove(_ token: FilterToken) {
        tokens.removeAll { $0 == token }
    }
}

struct MenuLabel: View {
    let symbol: String
    let text: String
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: symbol).symbolRenderingMode(.hierarchical)
            Text(text).font(Typo.fieldLabel)
        }
        .foregroundStyle(isActive ? Color.accentText : .textSecondary)
        .padding(.horizontal, Space.md)
        .frame(minHeight: Space.minHitTarget)
        .background(isActive ? Color.accentSoft : .bgSurface, in: .rect(cornerRadius: Radius.sm, style: .continuous))
        .dsBorder(isActive ? .accentText.opacity(0.4) : .borderSubtle, radius: Radius.sm)
    }
}

struct TokenChip: View {
    let token: FilterToken
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Space.xs) {
            if let symbol = token.symbol {
                Image(systemName: symbol).symbolRenderingMode(.hierarchical).accessibilityHidden(true)
            }
            Text(token.label).font(Typo.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(.caption2, weight: .bold))
                    .padding(Space.xs)
            }
            .buttonStyle(.plain)
            .contentShape(.rect)
            .accessibilityLabel("Retirer le filtre \(token.label)")
        }
        .foregroundStyle(.textPrimary)
        .padding(.leading, Space.md)
        .padding(.trailing, Space.xs)
        .frame(minHeight: 32)
        .background(.bgSelected, in: .capsule)
        .overlay(Capsule().strokeBorder(.borderSubtle, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - DisplayMenu — disposition × taille, par contexte

public struct DisplayMenu: View {
    @Binding private var setting: CardDisplaySetting
    private let context: CardDisplayContext

    public init(setting: Binding<CardDisplaySetting>, context: CardDisplayContext = .titles) {
        _setting = setting
        self.context = context
    }

    public var body: some View {
        Menu {
            Picker("Disposition", selection: $setting.layout) {
                ForEach(CardLayout.allCases) { layout in
                    Label(layout.label, systemImage: layout.symbol).tag(layout)
                }
            }
            .pickerStyle(.inline)

            Picker("Taille", selection: $setting.size) {
                ForEach(CardSize.allCases) { size in
                    Text(size.label).tag(size)
                }
            }
            .pickerStyle(.inline)
        } label: {
            MenuLabel(symbol: setting.layout.symbol, text: "Affichage")
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Affichage : \(setting.layout.rawValue), \(setting.size.rawValue)")
    }
}

#Preview("FilterBar") {
    @Previewable @State var sort = SortOption.samples[0]
    @Previewable @State var ascending = false
    @Previewable @State var tokens = FilterToken.samples
    @Previewable @State var display = CardDisplaySetting.default

    VStack(alignment: .leading, spacing: Space.lg) {
        FilterBar(
            sort: $sort, ascending: $ascending, tokens: $tokens,
            groups: [.init(id: "genres", label: "Genres", options: FilterToken.samples)])
        DisplayMenu(setting: $display)
    }
    .padding()
    .background(.bgCanvas)
}
