# CineShelf — Design System Apple (iOS · iPadOS · macOS)

> **Destinataire : Claude Design.** Remplace `01-DESIGN-SYSTEM.md` (version web). Cible unique multiplateforme SwiftUI.

---

## PARTIE A — Direction

### A.1 Le sujet

CineShelf est une **étagère personnelle** : un catalogue privé de films, séries, personnes, collections et images, que son propriétaire range, annote, recadre et fait grossir année après année. Pas un service de streaming, pas une app sociale. Un **archiviste** face à sa collection.

Trois conséquences :

1. **Le contenu est l'unique source de couleur.** Les jaquettes et les photos sont l'objet. L'interface est en niveaux de gris ; l'accent est rationné à un seul rôle.
2. **La densité vient de la grille, pas de la petitesse du texte.** On ne descend jamais sous la taille système. Sur iOS, ça veut dire **Dynamic Type obligatoire** : c'est la différence entre « userfriendly » et « joli sur ta capture d'écran ».
3. **Les métadonnées sont le sujet.** Année, durée, note, épisodes, position dans la collection. Elles ont leur propre traitement (chiffres tabulaires monospace), pas « du petit texte gris ».

### A.2 Natif d'abord, pas un portage

La règle la plus importante de ce document : **on ne porte pas une interface web.** Une app Mac/iOS sobre et professionnelle se reconnaît à ce qu'elle utilise les affordances de la plateforme :

| Au lieu de… | On utilise |
|---|---|
| Une navbar horizontale | `NavigationSplitView` (Mac, iPad) · `TabView` (iPhone) |
| Un overlay « Réglages » maison | `.inspector` (Mac/iPad) · scène `Settings` (Mac) |
| Des `<table>` faits main | `Table` SwiftUI, triable, colonnes redimensionnables |
| Des menus déroulants maison | `Menu`, `contextMenu`, `.toolbar`, commandes de barre de menus |
| Des ombres CSS | `Material` (`.regularMaterial`, `.thinMaterial`) |
| Une police web chargée | SF Pro, déjà là, avec Dynamic Type gratuit |
| Une lightbox maison | Plein écran + `Zoomable` + gestes système |
| Des icônes bitmap | SF Symbols, avec variantes de poids et de rendu |

Ce que ça achète : accessibilité VoiceOver, Dynamic Type, Reduce Motion, contraste élevé, navigation clavier, Handoff, Spotlight — **gratuitement**, ou presque.

### A.3 Palette — 5 valeurs

| Rôle | Nom | Hex (sRGB) | Usage |
|---|---|---|---|
| Fond | Graphite 950 | `#0D0F12` | Le canevas. Presque noir, légèrement froid (teinte 216°). |
| Surface | Graphite 900 | `#14171B` | Cartes, panneaux, listes. |
| Trait | Graphite 700 | `#3A4048` | Filets, séparateurs, bords. |
| Texte | Graphite 100 | `#EDEFF2` | Blanc cassé, jamais `#FFF` pur. |
| Accent | Ember 500 | `#E8395B` | Sélection, action principale, état actif. **Rien d'autre.** |

Le gris est **froid** volontairement : un gris chaud décale la perception des couleurs des affiches vers le vert. Le noir pur `#000` de la version web est abandonné — il fait disparaître le bord des jaquettes sombres et supprime toute possibilité d'élévation.

L'accent conserve la famille rouge de CineShelf mais désaturé par rapport au `#e11d48` actuel (rose Tailwind brut, trop néon en aplat).

> Les écrans Apple sont en **Display P3**. Définis les Color Sets en `Display P3` dans le catalogue d'assets ; les hex sRGB ci-dessus sont la référence, Xcode fait la conversion.

### A.4 L'élément signature : le **rail d'étagère**

Chaque rangée horizontale de jaquettes (accueil, sections par genre, filmographie, casting) repose sur un filet de 1 pt, interrompu à gauche par un libellé et à droite par un compteur monospace :

```
ACTION · 24 titres ─────────────────────────────  01–08 / 24  ‹ ›
┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐
│    │ │    │ │    │ │    │ │    │ │    │ │    │ │    │
└────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘
──────────────────────────────────────────────────────────
```

Le compteur encode **où on en est dans la collection** — une information réelle, pas une décoration. Sous le filet, un segment plein en Ember matérialise la portion visible : c'est le seul endroit de l'app où l'accent apparaît en aplat sans être une action.

Implémentation : `ScrollView(.horizontal)` + `.scrollPosition` (ou `onScrollGeometryChange`) pour la plage visible, `.scrollTargetBehavior(.viewAligned)` pour l'accrochage. Sur Mac, les flèches n'apparaissent qu'au survol.

**Règle de retenue** : le rail est la seule audace. Tout le reste est délibérément silencieux.

### A.5 Typographie — une seule police custom

| Rôle | Famille | Justification |
|---|---|---|
| UI + corps | **SF Pro** (système) | Dynamic Type, optical sizing, toutes les graisses, zéro octet à embarquer, familier |
| Display | **Archivo** (embarquée) | Grotesque d'archive, en deux chasses : normale et SemiExpanded. Réservée au hero, aux titres de section et aux libellés de rail. |
| Données | **SF Mono** (système) | Années, durées, notes, compteurs. Ou SF Pro + `.monospacedDigit()` — souvent suffisant et plus léger visuellement. |

On abandonne DM Sans, Lora et IBM Plex Mono. **Une seule police embarquée**, employée avec parcimonie : c'est ce qui rend l'identité perceptible sans casser l'impression native.

Embarquée en fichiers **statiques**, pas en police variable : `Font.custom`
n'expose aucun axe de variation, et y accéder par `CTFont` ferait perdre Dynamic
Type. Détail des chasses et des noms PostScript en §B.2.

---

## PARTIE B — Tokens

### Architecture

```
Niveau 1 — PRIMITIVES    Colors.xcassets (Graphite/900, Ember/500…)   jamais lues directement
       ↓
Niveau 2 — SÉMANTIQUES   Color.bgSurface, Color.textPrimary            ce que les vues utilisent
       ↓
Niveau 3 — COMPOSANTS    CardMetrics.portrait(.medium)                 métriques locales
```

**Règle** : une vue ne référence jamais un niveau 1. Les thèmes clair / sombre / contraste élevé sont gérés par les **variantes d'apparence** du catalogue d'assets — pas par du code conditionnel.

### B.1 Catalogue de couleurs

Créer `DesignSystem/Resources/Colors.xcassets` avec, pour chaque jeu, les apparences **Any**, **Dark**, **Any (High Contrast)**, **Dark (High Contrast)**.

#### Primitives

```
Graphite/0 …/50 /100 /200 /300 /400 /500 /600 /700 /800 /850 /900 /950 /1000
  #FFFFFF #F7F8F9 #EDEFF2 #DCDFE4 #BFC4CC #949BA5 #6E757F
  #515861 #3A4048 #262B31 #1C2026 #14171B #0D0F12 #07080A

Ember/50 …/900
  #FFF1F3 #FFE0E5 #FFC5CE #FF9BAB #F76A84 #E8395B #CE2148 #A9173A #7E1330 #4E0C1E

Jade/400 #4FD99A   Jade/500 #34C97E   Jade/600 #22A566
Amber/400 #F0B849  Amber/500 #E0A32E  Amber/600 #BF861A
Crimson/400 #FF8A73 Crimson/500 #F4664B Crimson/600 #D6462C
Azure/400 #6FB0EE  Azure/500 #4E9BE8  Azure/600 #2F7BC9
```

#### Sémantiques

| Jeu | Sombre | Clair |
|---|---|---|
| `bg/canvas` | Graphite 950 | Graphite 50 |
| `bg/surface` | Graphite 900 | Graphite 0 |
| `bg/surfaceRaised` | Graphite 850 | Graphite 0 |
| `bg/inset` | Graphite 800 | Graphite 50 |
| `bg/selected` | Ember 500 @ 12 % | Ember 600 @ 10 % |
| `text/primary` | Graphite 100 | Graphite 950 |
| `text/secondary` | Graphite 300 | Graphite 600 |
| `text/tertiary` | Graphite 400 | Graphite 500 |
| `text/onAccent` | Graphite 0 | Graphite 0 |
| `border/subtle` | blanc @ 8 % | noir @ 8 % |
| `border/default` | Graphite 700 | Graphite 200 |
| `border/strong` | Graphite 600 | Graphite 300 |
| `accent/text` | Ember 500 | Ember 700 |
| `accent/solid` | Ember 600 | Ember 600 |
| `accent/soft` | Ember 500 @ 14 % | Ember 600 @ 10 % |
| `status/success` | Jade 400 | Jade 600 |
| `status/warning` | Amber 400 | Amber 600 |
| `status/danger` | Crimson 400 | Crimson 600 |
| `status/info` | Azure 400 | Azure 600 |
| `media/placeholder` | Graphite 800 | Graphite 200 |
| `media/ring` | blanc @ 8 % | noir @ 10 % |
| `state/private` | Amber 400 | Amber 600 |
| `state/archived` | Graphite 400 | Graphite 500 |

> ⚠️ **Accent ≠ danger.** Aujourd'hui, « sélectionné » et « supprimer » sont la même couleur. Le danger passe en **Crimson** (orangé, teinte 12°), nettement séparé d'Ember (teinte 348°). Et une action destructive n'est **jamais** un bouton plein : `.buttonStyle(.bordered)` + `role: .destructive` + confirmation. La couleur seule ne porte jamais une action irréversible.

En variante **High Contrast**, remonter `text/secondary` et `text/tertiary` d'un cran, et passer `border/subtle` à Graphite 600.

#### Accès typé

```swift
public extension ShapeStyle where Self == Color {
    static var bgCanvas: Color        { .ds("bg/canvas") }
    static var bgSurface: Color       { .ds("bg/surface") }
    static var bgSurfaceRaised: Color { .ds("bg/surfaceRaised") }
    static var bgInset: Color         { .ds("bg/inset") }
    static var bgSelected: Color      { .ds("bg/selected") }
    static var textPrimary: Color     { .ds("text/primary") }
    static var textSecondary: Color   { .ds("text/secondary") }
    static var textTertiary: Color    { .ds("text/tertiary") }
    static var borderSubtle: Color    { .ds("border/subtle") }
    static var borderDefault: Color   { .ds("border/default") }
    static var accentText: Color      { .ds("accent/text") }
    static var accentSolid: Color     { .ds("accent/solid") }
    static var accentSoft: Color      { .ds("accent/soft") }
    static var statusDanger: Color    { .ds("status/danger") }
    // …
}

private extension Color {
    static func ds(_ name: String) -> Color { Color(name, bundle: .designSystem) }
}
```

Une règle SwiftLint interdit `Color(red:green:blue:)` et `Color(hex:)` hors du module DesignSystem.

### B.2 Typographie — Dynamic Type

Chaque rôle est déclaré **relativement à un `Font.TextStyle`**, jamais en taille fixe. C'est ce qui fait respecter les réglages d'accessibilité de l'utilisateur.

| Rôle | TextStyle | Base iOS | Base macOS | Police | Graisse |
|---|---|---:|---:|---|---|
| `heroTitle` | `.largeTitle` | 34 | 26 | Archivo SemiExpanded | 800 |
| `pageTitle` | `.title` | 28 | 22 | Archivo | 700 |
| `sectionTitle` | `.title3` | 20 | 15 | Archivo | 600 |
| `railLabel` | `.caption` | 12 | 10 | Archivo SemiExpanded, majuscules, `tracking` 0.08em | 600 |
| `cardTitle` | `.subheadline` | 15 | 11 | SF Pro | 500 |
| `cardMeta` | `.caption2` | 11 | 10 | SF Mono | 400 |
| `body` | `.body` | 17 | 13 | SF Pro | 400 |
| `bodyEmphasis` | `.body` | 17 | 13 | SF Pro | 600 |
| `fieldLabel` | `.footnote` | 13 | 10 | SF Pro | 500 |
| `dataValue` | `.callout` | 16 | 12 | SF Mono | 400 |
| `caption` | `.caption` | 12 | 10 | SF Pro | 400 |

#### L'axe de chasse ne concerne que les rôles en Archivo

`wdth` est un axe de la police Archivo. Il n'a **aucun sens pour les rôles en SF
Pro ou SF Mono** — `cardTitle`, `body`, `cardMeta` et les autres n'ont pas de
chasse à régler, et une largeur ne s'y applique pas.

Trois rôles seulement sont en Archivo à chasse normale (`pageTitle`,
`sectionTitle`) ou élargie (`heroTitle`, `railLabel`).

**Chasse élargie = SemiExpanded, pas Expanded.** L'axe `wdth` d'Archivo a six
crans : 62, 75, 87,5, 100, **112,5**, 125. La valeur 112 visée pour `heroTitle`
et `railLabel` est donc le cran 112,5, dont le nom de famille est **« Archivo
SemiExpanded »**. « Archivo Expanded » est le cran 125 — nettement plus large que
l'intention.

`Font.custom` n'adresse une police que par son nom PostScript et n'expose aucun
axe de variation : les deux chasses sont embarquées comme **deux familles
statiques distinctes**, et non comme un réglage de la police variable. Passer par
`CTFont` pour régler l'axe ferait perdre `relativeTo:`, donc Dynamic Type.

```swift
public enum Typo {
    // Noms PostScript réels, relevés sur les fichiers embarqués —
    // « Archivo » tout court n'en est pas un.
    public static let heroTitle    = Font.custom("ArchivoSemiExpanded-ExtraBold", size: 34, relativeTo: .largeTitle)
    public static let pageTitle    = Font.custom("Archivo-Bold", size: 28, relativeTo: .title)
    public static let sectionTitle = Font.custom("Archivo-SemiBold", size: 20, relativeTo: .title3)
    public static let railLabel    = Font.custom("ArchivoSemiExpanded-SemiBold", size: 12, relativeTo: .caption)

    // SF Pro et SF Mono : ni police custom, ni chasse.
    public static let cardTitle    = Font.subheadline.weight(.medium)
    public static let body         = Font.body
    public static let fieldLabel   = Font.footnote.weight(.medium)
    public static let caption      = Font.caption

    public static let cardMeta     = Font.system(.caption2, design: .monospaced)
    public static let dataValue    = Font.system(.callout, design: .monospaced)
}
```

**Règles** :
- Chiffres tabulaires partout où des nombres s'empilent : `.monospacedDigit()`.
- Tester à `AX5` (la plus grande taille d'accessibilité) : aucune troncature de titre, aucun bouton illisible.
- Au-delà de `.accessibility1`, les grilles de cartes passent en **liste** (`@Environment(\.dynamicTypeSize)` → `if size.isAccessibilitySize`). C'est le vrai test « userfriendly ».

### B.3 Espacement

```swift
public enum Space {
    public static let xxs: CGFloat = 2
    public static let xs:  CGFloat = 4
    public static let sm:  CGFloat = 8
    public static let md:  CGFloat = 12
    public static let lg:  CGFloat = 16
    public static let xl:  CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48

    // Sémantiques
    public static let inlineTight = xs
    public static let inline      = sm
    public static let stackTight  = sm
    public static let stack       = lg
    public static let section     = xxl
    public static let cardPadding = md
    public static let panelPadding = xl
}
```

Marges de page adaptatives (`horizontalSizeClass`) : compact 16 · regular 24 · Mac 20. Sur Mac, préférer `.scenePadding()` quand c'est possible — ça respecte les métriques système.

### B.4 Rayons

```swift
public enum Radius {
    public static let xs: CGFloat = 4    // badges, cases à cocher
    public static let sm: CGFloat = 6    // champs, petits contrôles
    public static let md: CGFloat = 10   // boutons, cartes de liste
    public static let lg: CGFloat = 14   // jaquettes, panneaux
    public static let xl: CGFloat = 20   // feuilles, blocs hero
}
```

Toujours `.clipShape(.rect(cornerRadius: Radius.lg, style: .continuous))` — le rayon continu (squircle) est la signature Apple ; un rayon circulaire fait « web porté ».

### B.5 Élévation — matériaux, pas ombres

| Niveau | Traitement |
|---|---|
| 0 | `Color.bgCanvas` |
| 1 | `Color.bgSurface` + trait `borderSubtle` |
| 2 | `.background(.regularMaterial)` — popovers, menus |
| 3 | `.background(.thickMaterial)` + ombre légère — feuilles, dialogues |
| 4 | fond opaque `bgCanvas` — plein écran, visionneuse |

```swift
public enum Elevation {
    public static let card   = ShadowSpec(radius: 2,  y: 1,  opacity: 0.28)
    public static let media  = ShadowSpec(radius: 12, y: 6,  opacity: 0.45)   // jaquette survolée (Mac)
    public static let sheet  = ShadowSpec(radius: 32, y: 12, opacity: 0.50)
}
```

Sur iOS, laisser les feuilles et popovers système gérer leur propre élévation. N'ajouter une ombre que pour les jaquettes au survol sur Mac.

### B.6 Mouvement

```swift
public enum Motion {
    public static let quick   = Animation.snappy(duration: 0.16)
    public static let base    = Animation.smooth(duration: 0.24)
    public static let sheet   = Animation.smooth(duration: 0.32)
    public static let emphasis = Animation.bouncy(duration: 0.4, extraBounce: 0.08)
}
```

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
// …
.animation(reduceMotion ? nil : Motion.base, value: state)
```

Transitions de navigation : utiliser `NavigationTransition.zoom(sourceID:in:)` entre une jaquette et sa fiche — c'est l'effet le plus « produit fini » disponible gratuitement, et il est désactivé automatiquement sous Reduce Motion.

### B.7 Métriques de cartes — la matrice `layout × size`

> Fonctionnalité **existante à conserver** : 2 dispositions × 3 tailles, réglables indépendamment sur 8 contextes.

```swift
public enum CardLayout: String, Codable, CaseIterable { case portrait, landscape }
public enum CardSize: String, Codable, CaseIterable { case compact, medium, large }

public struct CardMetrics {
    public let width: CGFloat
    public let aspect: CGFloat
    public let spacing: CGFloat
    public let radius: CGFloat
    public let showsMeta: Bool
    public let titleLineLimit: Int

    public static func metrics(_ layout: CardLayout, _ size: CardSize) -> CardMetrics {
        switch (layout, size) {
        case (.portrait, .compact):  .init(width: 104, aspect: 2/3, spacing: 8,  radius: Radius.md, showsMeta: false, titleLineLimit: 1)
        case (.portrait, .medium):   .init(width: 148, aspect: 2/3, spacing: 12, radius: Radius.lg, showsMeta: true,  titleLineLimit: 2)
        case (.portrait, .large):    .init(width: 196, aspect: 2/3, spacing: 16, radius: Radius.lg, showsMeta: true,  titleLineLimit: 2)
        case (.landscape, .compact): .init(width: 200, aspect: 3/2, spacing: 10, radius: Radius.md, showsMeta: true,  titleLineLimit: 1)
        case (.landscape, .medium):  .init(width: 264, aspect: 3/2, spacing: 14, radius: Radius.lg, showsMeta: true,  titleLineLimit: 2)
        case (.landscape, .large):   .init(width: 340, aspect: 3/2, spacing: 18, radius: Radius.lg, showsMeta: true,  titleLineLimit: 2)
        }
    }
}
```

Grille :

```swift
LazyVGrid(
    columns: [GridItem(.adaptive(minimum: m.width), spacing: m.spacing)],
    spacing: m.spacing
) { … }
```

`LazyVGrid` virtualise nativement : `VirtualizedCatalogGrid`, `useVirtualGrid`, `useListGridColumns` et `listGrid.ts` (≈ 600 lignes) disparaissent.

Proportions :

```swift
public enum Ratio {
    public static let poster: CGFloat    = 2/3
    public static let backdrop: CGFloat  = 16/9
    public static let landscape: CGFloat = 3/2
    public static let avatar: CGFloat    = 1
    public static let tile: CGFloat      = 4/5
}
```

### B.8 Icônes — correspondance SF Symbols

Remplace `lucide-react` (0 octet embarqué, poids et rendus variables, VoiceOver correct) :

| Usage | SF Symbol |
|---|---|
| Films / titres | `film.stack` |
| Série | `tv` |
| Personnes | `person.2` |
| Collections | `square.stack` |
| Genres | `tag` |
| Galerie | `photo.on.rectangle.angled` |
| Signets | `bookmark` |
| Recherche | `magnifyingglass` |
| Favori | `heart` / `heart.fill` |
| Watchlist | `bookmark.circle` / `.fill` |
| Vu | `checkmark.circle` / `.fill` |
| Note | `star` / `star.leadinghalf.filled` |
| Privé | `lock` |
| Archivé | `archivebox` |
| Recadrer | `crop` |
| Importer | `square.and.arrow.down` |
| Exporter | `square.and.arrow.up` |
| Fusionner | `arrow.triangle.merge` |
| Bibliothèque | `books.vertical` |
| Réglages | `gearshape` |
| Affichage | `square.grid.2x2` / `rectangle.grid.1x2` |
| Trier | `arrow.up.arrow.down` |
| Filtrer | `line.3.horizontal.decrease.circle` |
| Sync | `arrow.triangle.2.circlepath` |

Toujours `.symbolRenderingMode(.hierarchical)` par défaut, `.palette` pour les états à deux couleurs. Animer les changements d'état avec `.contentTransition(.symbolEffect(.replace))`.

---

## PARTIE C — Navigation adaptative

### iPhone (compact)

```
TabView
├─ Accueil     hero + rails par genre
├─ Catalogue   segmenté : Titres · Personnes · Collections
├─ Galerie     masonry + plein écran
├─ Recherche   champ + résultats groupés
└─ Bibliothèque profil, flags, réglages, import/export
```

Détails en `NavigationStack` empilé. Édition en `.sheet` avec `.presentationDetents`.

### iPad & Mac (regular)

```
NavigationSplitView (3 colonnes)
├─ Sidebar          Accueil · Titres · Personnes · Collections · Galerie · Signets
│                   ── Genres épinglés ──
│                   ── Bibliothèques ──
├─ Liste            grille ou Table, barre d'outils (tri, filtres, affichage)
└─ Détail           fiche + .inspector pour l'édition
```

L'`.inspector` remplace l'overlay « Réglages » de la version web : un panneau latéral qui édite l'élément sélectionné sans quitter le contexte. C'est le patron natif exact de ce que tu avais construit à la main.

### Spécificités Mac

- Barre de menus : `CommandGroup` pour Nouveau titre (`⌘N`), Importer (`⇧⌘I`), Exporter (`⇧⌘E`), Recherche (`⌘F`), Afficher/Masquer l'inspecteur (`⌥⌘I`).
- Survol : révèle les actions rapides sur les jaquettes, les flèches du rail.
- `contextMenu` sur chaque carte : Favori, Watchlist, Modifier, Recadrer, Dupliquer, Archiver, Supprimer.
- `Table` pour la gestion de base : colonnes triables, redimensionnables, sélection multiple, `⌘`-clic.
- Scène `Settings` séparée pour les préférences (≠ la gestion de données).
- Glisser-déposer : une image depuis le Finder sur une jaquette la remplace.

---

## PARTIE D — Composants à produire

| Composant | Points clés |
|---|---|
| `PosterCard` | image + recadrage + badges (favori, watchlist, privé, archivé) + titre + méta. Survol Mac, `contextMenu`, `matchedTransitionSource` |
| `ShelfRail` | libellé, filet, compteur, progression, flèches Mac. `accessibilityLabel` = « {genre}, {n} titres » |
| `CatalogGrid` | `LazyVGrid` piloté par `CardMetrics`, bascule en liste aux tailles d'accessibilité |
| `MediaThumbnail` | placeholder blurhash → vignette locale → image, sans saut de mise en page |
| `CropEditor` | `MagnifyGesture` + `DragGesture`, aperçu par contexte, remplace `ImageTransformModal` |
| `MediaViewer` | plein écran, zoom, balayage, partage, `.navigationTransition(.zoom)` |
| `MasonryGallery` | colonnes calculées, `LazyVStack` par colonne |
| `FilterBar` | `Menu` de tri, filtres en `Picker`, jetons actifs supprimables |
| `DisplayMenu` | disposition × taille × densité, par contexte |
| `EntityTable` | `Table` générique pour la gestion de base (Mac/iPad) |
| `BulkEditSheet` | édition en masse de la sélection |
| `FieldRow` | libellé + valeur + validation, en `LabeledContent` |
| `StateView` | vide / chargement / erreur, un seul composant, trois cas |
| `SyncStatusBadge` | état CloudKit : à jour, en cours, hors ligne, erreur |

### États vides, chargement, erreur

- **Vide** — SF Symbol 32 pt en `textTertiary`, titre, une phrase, **et un bouton**. « Aucun film pour l'instant. » + `[Ajouter un film]`.
- **Chargement** — squelettes de la géométrie finale, `.redacted(reason: .placeholder)`. Jamais un spinner centré.
- **Erreur** — ce qui s'est passé et comment le réparer, en voix d'interface. « Impossible de synchroniser. Vérifie ta connexion iCloud. » + `[Réessayer]`. Jamais d'excuse, jamais de message technique.

---

## PARTIE E — Plancher de qualité

- [ ] Dynamic Type de `xSmall` à `AX5` sans troncature ni chevauchement
- [ ] VoiceOver : chaque carte annonce titre + année + état ; chaque action a un label
- [ ] Contraste ≥ 4,5:1 (texte) et 3:1 (contrôles), en clair, sombre, et contraste élevé
- [ ] `accessibilityReduceMotion` et `accessibilityReduceTransparency` respectés
- [ ] Navigation clavier complète sur Mac, `focusable()` là où il faut
- [ ] Cibles tactiles ≥ 44×44 pt
- [ ] Aucune couleur en dur hors du module DesignSystem
- [ ] Aucune taille de police fixe hors `relativeTo:`
- [ ] Fonctionne en mode hors ligne, avec un état de synchronisation lisible
- [ ] iPhone SE → iPad Pro 13" → Mac plein écran 6K
