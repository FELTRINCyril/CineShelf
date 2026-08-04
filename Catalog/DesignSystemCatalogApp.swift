import DesignSystem
import SwiftUI

// MARK: - DesignSystemCatalog
//
// App de démonstration : chaque token et chaque composant, dans chaque état.
// Cible iOS · iPadOS · macOS. Aucune dépendance au modèle métier — le
// catalogue ne connaît que DesignSystem, comme n'importe quel consommateur.

@main
struct DesignSystemCatalogApp: App {
    init() { DesignSystemFonts.register() }

    var body: some Scene {
        WindowGroup {
            CatalogRootView()
        }
        #if os(macOS)
            .defaultSize(width: 1180, height: 860)
        #endif
    }
}

enum CatalogSection: String, CaseIterable, Identifiable {
    // En tête, et volontairement : sans elle, on cherche les formulaires et la console
    // de gestion dans ce catalogue sans savoir s'ils sont oubliés ou pas encore arrivés.
    case roadmap = "Où en est le design"
    // Les tokens de la direction courante.
    case palette = "Couleurs"
    case typography = "Typographie"
    case metrics = "Espacement · Densité · Rayons · Mouvement"
    case posters = "Affiches · Matrice"
    case icons = "Symboles"
    // Les composants de la direction courante, par lots. Ils remplacent les sept
    // ci-dessous, ils ne s'y ajoutent pas.
    case cardTiles = "Tuiles · I2"
    case cardSurfaces = "Surfaces · I3"
    case layout = "Rail · Grille · Squelette · I4"
    // Les sept composants du banc d'essai, ancienne direction. Ils partent avec
    // Legacy/ à V12 ; on ne les investit plus.
    case stateView = "StateView"
    case fieldRow = "FieldRow"
    case filterBar = "FilterBar · DisplayMenu"
    case thumbnail = "MediaThumbnail"
    case posterCard = "PosterCard"
    case shelfRail = "ShelfRail"
    case catalogGrid = "CatalogGrid"

    var id: String { rawValue }
}

enum SimulatedPlatform: String, CaseIterable, Identifiable {
    case iPhone, iPad, mac
    var id: String { rawValue }

    var width: CGFloat? {
        switch self {
        case .iPhone: 393
        case .iPad: 834
        case .mac: nil
        }
    }
}

struct CatalogRootView: View {
    // Optionnelle : sur iOS, `List(selection:)` n'accepte pas de liaison non
    // optionnelle. Le NavigationSplitView retombe sur la feuille d'avancement si rien
    // n'est sélectionné.
    @State private var section: CatalogSection? = .roadmap
    @State private var appearance = CatalogAppearance()
    @State private var typeSize: DynamicTypeSize = .large
    @State private var platform: SimulatedPlatform = .mac
    @State private var display = CardDisplaySetting.default

    var body: some View {
        NavigationSplitView {
            List(CatalogSection.allCases, selection: $section) { item in
                Text(item.rawValue).tag(item)
            }
            .navigationTitle("Catalogue")
        } detail: {
            ScrollView {
                content
                    .frame(maxWidth: platform.width ?? .infinity, alignment: .leading)
                    .padding(Space.xl)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(.bgCanvas)
            .environment(\.dynamicTypeSize, typeSize)
            .toolbar { toolbarContent }
        }
        .catalogAppearance(appearance)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Picker("Thème", selection: $appearance.scheme) {
                Text("Clair").tag(ColorScheme.light)
                Text("Sombre").tag(ColorScheme.dark)
            }
            .pickerStyle(.segmented)
        }
        ToolbarItem {
            Toggle(isOn: $appearance.highContrast) {
                Label("Contraste élevé", systemImage: "circle.lefthalf.filled")
            }
            .toggleStyle(.button)
            .help("Contraste élevé")
        }
        ToolbarItem {
            Picker("Taille du texte", selection: $typeSize) {
                Text("Normale").tag(DynamicTypeSize.large)
                Text("AX3").tag(DynamicTypeSize.accessibility3)
                Text("AX5").tag(DynamicTypeSize.accessibility5)
            }
        }
        ToolbarItem {
            Picker("Plateforme", selection: $platform) {
                ForEach(SimulatedPlatform.allCases) { Text($0.rawValue).tag($0) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section ?? .roadmap {
        case .roadmap: RoadmapSheet()
        case .palette: PaletteSheet()
        case .typography: TypographySheet()
        case .metrics: MetricsSheet()
        case .posters: PosterSheet()
        case .icons: IconSheet()
        case .cardTiles: CardTilesSheet()
        case .cardSurfaces: CardSurfacesSheet()
        case .layout: LayoutSheet()
        case .stateView: StateViewSheet()
        case .fieldRow: FieldRowSheet()
        case .filterBar: FilterBarSheet()
        case .thumbnail: ThumbnailSheet()
        case .posterCard: PosterCardSheet()
        case .shelfRail: ShelfRailSheet()
        case .catalogGrid: CatalogGridSheet(display: $display)
        }
    }
}

// MARK: - Planche générique

struct Sheet<Content: View>: View {
    let title: String
    let note: String?
    @ViewBuilder var content: Content

    init(_ title: String, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).font(Typo.pageTitle).foregroundStyle(.textPrimary)
                if let note { Text(note).font(Typo.body).foregroundStyle(.textSecondary) }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
