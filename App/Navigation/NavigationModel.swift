import Foundation
import Observation
import SwiftUI

/// L'état de navigation de l'app.
///
/// C'est le point de coordination entre les `Features` : `docs/04` §1 interdit
/// qu'une feature en connaisse une autre, donc tout passage de l'une à l'autre
/// se fait en écrivant ici. Une vue de feature ne connaît que ce modèle.
///
/// Une pile par section plutôt qu'une pile unique : en compact chaque onglet a
/// son `NavigationStack`, et revenir sur un onglet doit retrouver sa pile. En
/// large, seule la pile de la section sélectionnée est visible.
@MainActor
@Observable
final class NavigationModel {

    // MARK: État

    /// La section affichée. En compact, elle suit l'onglet et le segment.
    var section: AppSection = .home {
        didSet { alignCompactSelection(with: section, from: oldValue) }
    }

    var compactTab: CompactTab = .home {
        didSet { alignSection(with: compactTab, from: oldValue) }
    }

    var catalogueSegment: CatalogueSegment = .titles {
        didSet {
            guard compactTab == .catalogue else { return }
            section = catalogueSegment.section
        }
    }

    /// Une pile par destination empilable. Absente du dictionnaire = pile vide.
    ///
    /// Clé dédiée plutôt que `AppSection` : l'onglet « Plus » est une liste, pas
    /// une section, et il lui faut malgré tout sa propre pile. Le lier à la
    /// section courante ferait partager un même `NavigationStack` entre
    /// plusieurs onglets vivants — `TabView` évalue le corps de tous.
    var paths: [StackID: [AppRoute]] = [:]

    /// Panneau d'édition latéral — ⌥⌘I. `docs/01` partie C en fait le
    /// remplaçant de l'overlay « Réglages » de la version web.
    var isInspectorPresented = false

    /// Ce que ⌥↑ et ⌥↓ parcourent depuis un détail : la liste dans laquelle
    /// l'élément affiché a été ouvert. Renseignée par la vue de liste au moment
    /// où elle pousse une route, vide tant qu'on n'a ouvert aucun détail.
    private(set) var collection: [AppRoute] = []

    // MARK: Piles

    /// Ce qui identifie une pile de navigation.
    enum StackID: Hashable, Codable, Sendable {
        case section(AppSection)
        /// L'onglet « Plus » : une liste de sections, pas une section.
        case more

        var storageKey: String {
            switch self {
            case .section(let section): section.rawValue
            case .more: "+more"
            }
        }

        init?(storageKey: String) {
            if storageKey == "+more" {
                self = .more
            } else if let section = AppSection(rawValue: storageKey) {
                self = .section(section)
            } else {
                return nil
            }
        }
    }

    func path(for section: AppSection) -> [AppRoute] {
        path(for: .section(section))
    }

    func path(for id: StackID) -> [AppRoute] {
        paths[id] ?? []
    }

    func pathBinding(for id: StackID) -> Binding<[AppRoute]> {
        Binding(
            get: { self.paths[id] ?? [] },
            set: { self.paths[id] = $0 }
        )
    }

    /// Ouvre une route dans la section courante, en mémorisant la liste d'où
    /// elle vient pour que ⌥↑ / ⌥↓ sachent quoi parcourir.
    func open(_ route: AppRoute, within collection: [AppRoute] = []) {
        self.collection = collection
        paths[.section(section), default: []].append(route)
    }

    /// Remplace le détail affiché sans empiler : c'est ce que font ⌥↑ et ⌥↓,
    /// qui se déplacent *dans* une liste plutôt que de s'y enfoncer.
    private func replaceTopOfStack(with route: AppRoute) {
        let current = path(for: section)
        guard !current.isEmpty else { return }
        paths[.section(section), default: []][current.count - 1] = route
    }

    // MARK: Précédent / suivant dans la collection

    var canGoToPrevious: Bool { neighbour(offset: -1) != nil }
    var canGoToNext: Bool { neighbour(offset: +1) != nil }

    func goToPrevious() {
        guard let route = neighbour(offset: -1) else { return }
        replaceTopOfStack(with: route)
    }

    func goToNext() {
        guard let route = neighbour(offset: +1) else { return }
        replaceTopOfStack(with: route)
    }

    private func neighbour(offset: Int) -> AppRoute? {
        guard let current = path(for: section).last,
            let index = collection.firstIndex(of: current)
        else { return nil }

        let target = index + offset
        guard collection.indices.contains(target) else { return nil }
        return collection[target]
    }

    // MARK: Cohérence compact / large

    /// Aligne onglet et segment quand la section change (sélection dans la
    /// barre latérale, raccourci clavier, restauration).
    private func alignCompactSelection(with section: AppSection, from previous: AppSection) {
        guard section != previous else { return }
        compactTab = CompactTab.containing(section)
        if let segment = CatalogueSegment.matching(section) {
            catalogueSegment = segment
        }
    }

    /// Aligne la section quand l'onglet change. « Plus » n'a pas de section
    /// propre : c'est une liste, la section ne bouge qu'à la sélection d'une
    /// de ses entrées.
    private func alignSection(with tab: CompactTab, from previous: CompactTab) {
        guard tab != previous else { return }
        switch tab {
        case .catalogue: section = catalogueSegment.section
        case .more: break
        default:
            if let target = tab.section { section = target }
        }
    }
}

// MARK: - Restauration

extension NavigationModel {

    /// Ce qui traverse un redémarrage. Pas les filtres ni la largeur des
    /// colonnes : les premiers n'existent pas encore, la seconde est déjà
    /// restaurée par le système.
    private struct Snapshot: Codable {
        var section: AppSection
        var catalogueSegment: CatalogueSegment
        var paths: [String: [AppRoute]]
        var isInspectorPresented: Bool
    }

    /// La restauration est **par profil** : deux profils sur le même Mac n'ont
    /// pas de raison de rouvrir sur le même écran.
    private static func storageKey(profileID: UUID) -> String {
        "navigation.\(profileID.uuidString)"
    }

    func save(profileID: UUID, to defaults: UserDefaults = .standard) {
        let snapshot = Snapshot(
            section: section,
            catalogueSegment: catalogueSegment,
            paths: Dictionary(uniqueKeysWithValues: paths.map { ($0.key.storageKey, $0.value) }),
            isInspectorPresented: isInspectorPresented
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.storageKey(profileID: profileID))
    }

    /// Recharge l'état du profil, ou repart de zéro s'il n'en a pas.
    ///
    /// Le repli explicite n'est pas cosmétique : `restore` est appelée à chaque
    /// bascule de profil sur la **même** instance. Sans lui, un profil sans état
    /// enregistré hériterait de la section, des piles et de l'inspecteur du
    /// profil précédent — puis les réenregistrerait sous son propre identifiant.
    func restore(profileID: UUID, from defaults: UserDefaults = .standard) {
        collection = []

        guard let data = defaults.data(forKey: Self.storageKey(profileID: profileID)),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            reset()
            return
        }

        catalogueSegment = snapshot.catalogueSegment
        section = snapshot.section
        paths = Dictionary(
            uniqueKeysWithValues: snapshot.paths.compactMap { key, value in
                StackID(storageKey: key).map { ($0, value) }
            }
        )
        isInspectorPresented = snapshot.isInspectorPresented
    }

    private func reset() {
        catalogueSegment = .titles
        section = .home
        paths = [:]
        isInspectorPresented = false
    }
}
