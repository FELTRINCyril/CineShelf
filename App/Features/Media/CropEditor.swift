import CineShelfCore
import DesignSystem
import SwiftUI

// MARK: - V2 bis · L'éditeur de recadrage
//
// **Il ne calcule rien.** Toute la géométrie est dans `CropGeometry`, livrée par `L4` :
// `crop(after:magnifying:from:source:frame:)` prend un déplacement et un pincement et rend un
// `CropValues` déjà borné. Cet écran ne fait que trois choses — montrer, transmettre le geste,
// enregistrer.
//
// C'est la règle « l'arithmétique ne vit jamais dans une `View` », et ici elle était déjà
// respectée avant l'écran : le calcul a été écrit et testé six tâches plus tôt, sans rendu.
//
// **Deux ratios, et ce sont ceux du modèle, pas deux réglages libres.** `CropContext` compte
// **neuf** cas héritées de la v1, mais ils se ramènent à trois formes : portrait 2:3, paysage
// 16:9, carré. Un média n'est recadré que dans les cadres où il apparaît vraiment — un
// backdrop en 16:9 (`hero`), une jaquette en 2:3 (`card`). L'éditeur montre donc **les cadres
// du média qu'on lui donne**, deux au plus, et enregistre une ligne `MediaCrop` par contexte.
//
// Les neuf cas sont couverts sans `default`, et le compilateur l'a exigé : j'en avais écrit
// quatre. C'est la garde qui a mordu — un contexte oublié aurait pris le ratio du `default` et
// produit un recadrage qu'aucun écran ne sait afficher.
//
// **Pourquoi les deux à la fois, et pas un onglet par cadre.** La même image sert aux deux, et
// un réglage qui va bien en 2:3 coupe souvent mal en 16:9 : les voir côte à côte est la seule
// façon de s'en apercevoir. C'est aussi ce que `docs/02` §3.9 implique en stockant un
// recadrage **par contexte** plutôt qu'un seul par média.
//
// MARK: - Ce que cet écran ne fait pas
//
// Il ne pivote pas, ne retouche pas, ne réencode pas. `MediaCrop` est une **vue** sur l'image
// source : quatre nombres, aucun pixel réécrit. C'est ce qui rend un recadrage réversible et
// synchronisable pour trente octets — et c'est la décision de `docs/02`, pas la mienne.

struct CropEditor: View {
    let asset: MediaAsset
    /// Les cadres à régler. Deux au plus, dans l'ordre d'affichage.
    let contexts: [CropContext]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Le recadrage en cours d'édition, par contexte. Chargé des lignes existantes, ou du
    /// neutre si le média n'en a pas encore.
    @State private var drafts: [CropContext: CropValues] = [:]
    /// Le contexte que le geste pilote. Pointer dans un cadre le sélectionne : sans ça, un
    /// glissement modifierait les deux à la fois, ce qui n'a aucun sens — ils n'ont ni le
    /// même jeu ni le même cadrage.
    @State private var active: CropContext?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            header
            frames
            controls
            actions
        }
        .padding(Space.s6)
        .frame(minWidth: 720, minHeight: 620)
        .background(Color.bgCanvas)
        .task { loadDrafts() }
    }

    // MARK: L'en-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Recadrage")
                .font(Typo.title1(.large))
                .foregroundStyle(Color.textPrimary)
            Text(
                """
                Fais glisser pour déplacer, pince ou utilise le curseur pour agrandir. \
                L'image n'est jamais modifiée : seuls quatre nombres sont enregistrés.
                """
            )
            .font(Typo.body)
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: 460, alignment: .leading)
        }
    }

    // MARK: Les cadres

    private var frames: some View {
        HStack(alignment: .top, spacing: Space.s5) {
            ForEach(contexts, id: \.rawValue) { cropContext in
                frame(for: cropContext)
            }
        }
    }

    private func frame(for cropContext: CropContext) -> some View {
        let aspect = Self.aspect(of: cropContext)
        let isActive = active == cropContext || (active == nil && cropContext == contexts.first)

        return VStack(alignment: .leading, spacing: Space.s2) {
            CropCanvas(
                asset: asset,
                crop: drafts[cropContext] ?? .neutral,
                aspect: aspect,
                onGesture: { start, translation, magnification, size in
                    apply(start, translation, magnification, in: cropContext, frame: size)
                }
            )
            .frame(width: Self.frameWidth, height: Self.frameWidth / aspect)
            .overlay {
                // Le cadre actif porte un liseré d'accent. C'est le seul indicateur, et il
                // n'existe que parce que deux cadres coexistent — un éditeur à un seul cadre
                // n'en aurait pas besoin.
                if isActive {
                    Rectangle().strokeBorder(Color.accent, lineWidth: 2).allowsHitTesting(false)
                }
            }
            .onTapGesture { active = cropContext }

            Text(Self.label(of: cropContext))
                .labelStyle()
                .foregroundStyle(isActive ? Color.textPrimary : Color.textTertiary)
            Text(Self.ratioLabel(of: cropContext))
                .font(Typo.micro)
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: Le curseur de zoom

    /// Un curseur **en plus** du pincement, pas à sa place.
    ///
    /// Le pincement n'existe pas sur un Mac sans trackpad, et il est imprécis partout. Le
    /// curseur porte la plage de stockage de la v1 — 50 à 400 % — que `CropGeometry` borne de
    /// son côté : la vue n'invente aucune limite.
    private var controls: some View {
        let target = active ?? contexts.first ?? .standard
        let current = drafts[target] ?? .neutral

        return VStack(alignment: .leading, spacing: Space.s2) {
            HStack {
                Text("Agrandissement").labelStyle().foregroundStyle(Color.textTertiary)
                Spacer()
                Text(verbatim: "\(Int(current.zoom.rounded())) %")
                    .font(Typo.numeric)
                    .foregroundStyle(Color.textSecondary)
            }
            Slider(
                value: Binding(
                    get: { current.zoom },
                    set: { newValue in
                        drafts[target] = CropGeometry.clamped(
                            CropValues(x: current.x, y: current.y, zoom: newValue))
                    }
                ),
                in: CropGeometry.storableZoom
            )
            .frame(maxWidth: Self.frameWidth * 2 + Space.s5)
        }
    }

    // MARK: Les actions

    private var actions: some View {
        HStack(spacing: Space.s3) {
            Button("Enregistrer") { save() }
                .buttonStyle(ActionButtonStyle(rank: .primary))
            Button("Recentrer") { recenterActive() }
                .buttonStyle(ActionButtonStyle(rank: .secondary))
            Spacer()
            Button("Annuler") { dismiss() }
                .buttonStyle(.plain)
                .actionStyle()
                .foregroundStyle(Color.textSecondary)
                .frame(minHeight: Space.minHitTarget)
        }
    }

    // MARK: Le travail

    /// Charge les lignes existantes, ou le neutre.
    ///
    /// **Le neutre et non « rien »** : un contexte sans ligne doit s'éditer comme un recadrage
    /// centré à 100 %, et enregistrer alors une ligne réelle. Sans ça, l'utilisateur règlerait
    /// un cadre et rien ne serait écrit tant qu'il n'a pas bougé les deux.
    private func loadDrafts() {
        for cropContext in contexts {
            let existing = asset.crops?.first { $0.context == cropContext }
            drafts[cropContext] =
                existing.map { CropValues(x: $0.positionX, y: $0.positionY, zoom: $0.zoom) }
                ?? .neutral
        }
        active = contexts.first
    }

    /// Applique un geste, **depuis son point de départ**.
    ///
    /// `from: start` et non `from: drafts[cropContext]` : les deux gestes rendent des valeurs
    /// cumulées depuis le début, donc repartir du recadrage courant composerait le mouvement à
    /// chaque événement.
    private func apply(
        _ start: CropValues,
        _ translation: CGSize,
        _ magnification: Double,
        in cropContext: CropContext,
        frame: CGSize
    ) {
        active = cropContext
        drafts[cropContext] = CropGeometry.crop(
            after: translation,
            magnifying: magnification,
            from: start,
            source: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
            frame: frame
        )
    }

    private func recenterActive() {
        guard let target = active ?? contexts.first else { return }
        drafts[target] = .neutral
    }

    /// Écrit une ligne par contexte réglé, puis referme.
    ///
    /// `MediaRepository.setCrop` cherche avant d'insérer, donc rejouer un enregistrement met à
    /// jour au lieu de dupliquer — deux lignes pour le même couple rendraient le recadrage
    /// indéterminé.
    private func save() {
        let repository = MediaRepository(context: modelContext)
        for (cropContext, values) in drafts {
            repository.setCrop(values, on: asset, in: cropContext)
        }
        try? modelContext.save()
        dismiss()
    }

    // MARK: Les libellés et les ratios

    /// Le ratio du cadre, tiré du contexte.
    ///
    /// **Il n'est pas un réglage** : `card` est une jaquette, donc 2:3 ; `hero` est un bandeau,
    /// donc 16:9 ; `avatar` est carré. Laisser l'utilisateur choisir un ratio libre produirait
    /// des recadrages qu'aucun écran ne sait afficher.
    /// **Les neuf cas sont couverts, et le compilateur l'a exigé.** J'en avais écrit quatre :
    /// `CropContext` en a neuf, héritage de la v1, et un `switch` exhaustif sans `default` a
    /// refusé de compiler. C'est la garde qui a mordu — sans elle, un contexte oublié aurait
    /// pris le ratio du `default` et produit un recadrage qu'aucun écran ne sait afficher.
    ///
    /// Trois familles seulement : portrait 2:3, paysage 16:9, carré. Aucun ratio libre.
    static func aspect(of cropContext: CropContext) -> CGFloat {
        switch cropContext {
        case .standard, .card, .list, .side, .detail, .coverCard:
            CardLayout.portrait.aspectRatio
        case .hero, .coverHero:
            CardLayout.landscape.aspectRatio
        case .avatar:
            1
        }
    }

    static func label(of cropContext: CropContext) -> LocalizedStringKey {
        switch cropContext {
        case .standard: "Par défaut"
        case .card: "Carte"
        case .list: "Ligne"
        case .hero: "Bandeau"
        case .side: "Panneau"
        case .detail: "Fiche"
        case .coverCard: "Couverture · carte"
        case .coverHero: "Couverture · bandeau"
        case .avatar: "Avatar"
        }
    }

    static func ratioLabel(of cropContext: CropContext) -> String {
        switch aspect(of: cropContext) {
        case CardLayout.landscape.aspectRatio: "16:9 · accueil et fiche"
        case 1: "1:1 · pastille"
        default: "2:3 · grilles et rails"
        }
    }

    /// 300 pt : deux cadres côte à côte tiennent dans une feuille de 720, avec le 16:9 qui est
    /// le plus large.
    static let frameWidth: CGFloat = 300
}

// MARK: - La toile

/// L'image, son recadrage courant, et les deux gestes.
///
/// Séparée de l'éditeur pour une raison précise : elle a besoin de sa **propre** taille pour
/// convertir un déplacement en pixels source, et un `GeometryReader` autour de tout l'éditeur
/// aurait donné la taille de la feuille, pas celle du cadre.
private struct CropCanvas: View {
    let asset: MediaAsset
    let crop: CropValues
    let aspect: CGFloat
    /// Appelée avec le recadrage **du début du geste**, la translation totale, le facteur de
    /// pincement et la taille du cadre.
    let onGesture: (CropValues, CGSize, Double, CGSize) -> Void

    /// Le recadrage figé au premier événement du geste.
    ///
    /// **Sans lui, un glissement accélère.** `DragGesture` rend une translation **totale**
    /// depuis le début du geste, alors que `CropGeometry.crop(after:…)` attend un déplacement à
    /// appliquer à un recadrage de départ. Appliquer la translation totale au recadrage
    /// **déjà déplacé** compose le mouvement à chaque événement : le doigt avance de 10 pt et
    /// l'image de 10, puis 30, puis 60. Le défaut était écrit dans la première version de cet
    /// écran — le champ existait et n'était pas lu.
    @State private var gestureStart: CropValues?

    var body: some View {
        GeometryReader { proxy in
            MediaFill(
                imageURL: AssetURL.url(for: asset.id, preset: .hero),
                blurHash: asset.blurHash,
                crop: CropDisplay.display(of: crop, sourceAspect: sourceAspect),
                targetAspect: aspect,
                background: Color.bgSurface
            )
            .contentShape(.rect)
            .gesture(drag(in: proxy.size))
            .gesture(magnify(in: proxy.size))
        }
    }

    private var sourceAspect: Double? {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return nil }
        return Double(asset.pixelWidth) / Double(asset.pixelHeight)
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = gestureStart ?? crop
                gestureStart = start
                onGesture(start, value.translation, 1, size)
            }
            .onEnded { _ in gestureStart = nil }
    }

    /// Même raison pour le pincement : `MagnifyGesture` rend un facteur **cumulé** depuis le
    /// début du geste, pas un incrément.
    private func magnify(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = gestureStart ?? crop
                gestureStart = start
                onGesture(start, .zero, value.magnification, size)
            }
            .onEnded { _ in gestureStart = nil }
    }
}
