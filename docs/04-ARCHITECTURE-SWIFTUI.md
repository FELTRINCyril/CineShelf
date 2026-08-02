# CineShelf — Architecture SwiftUI multiplateforme

> **Destinataire : Claude Code.** Remplace `04-ARCHITECTURE.md`. Cible unique : une app SwiftUI multiplateforme iOS · iPadOS · macOS, sans backend.

---

## 1. Forme du projet

Une **cible unique multiplateforme**, trois packages locaux. Pas de modularisation à outrance : c'est un projet solo, la friction se paie tous les jours.

```
CineShelf/
├── CineShelf.xcodeproj
├── App/                              cible unique (iOS · iPadOS · macOS)
│   ├── CineShelfApp.swift            @main, scènes, ModelContainer
│   ├── Navigation/                   AppRoute, NavigationModel, adaptation compact/regular
│   ├── Features/
│   │   ├── Home/                     hero + rails
│   │   ├── Titles/                   liste, détail, éditeur, filtres
│   │   ├── People/                   liste, détail, doublons, fusion
│   │   ├── Collections/
│   │   ├── Gallery/                  masonry, visionneuse, immersif
│   │   ├── SavedLinks/
│   │   ├── Search/
│   │   ├── MyList/                   watchlist + favoris
│   │   ├── LibraryAdmin/             ex-« Réglages », Table + inspecteur
│   │   ├── Transfer/                 import / export CSV + archive
│   │   └── Settings/                 vraies préférences
│   ├── Intents/                      App Intents, Raccourcis
│   └── Resources/                    Assets.xcassets, Archivo.ttf, Localizable
├── Packages/
│   ├── DesignSystem/                 tokens, composants, PosterCard, ShelfRail
│   ├── CineShelfCore/                @Model, repositories, services
│   └── MediaKit/                     vignettes, blurhash, recadrage, import d'images
├── Tests/
│   ├── CoreTests/  DesignSystemTests/  MediaKitTests/
└── UITests/                          5 parcours critiques
```

### Pourquoi une cible unique

Une seule cible avec `#if os(macOS)` là où c'est nécessaire, plutôt que deux cibles partageant un framework. SwiftUI adapte déjà `NavigationSplitView`, `Table`, `Menu`, `.searchable` et les feuilles selon la plateforme. Les divergences réelles sont peu nombreuses (barre de menus, survol, glisser-déposer Finder, scène `Settings`) et se traitent par `#if` ou par des vues dédiées.

### Règle de dépendances

```
App ──▶ DesignSystem ──▶ (rien)
 │  ──▶ CineShelfCore ──▶ (rien)
 └─ ──▶ MediaKit ──────▶ CineShelfCore
```

`CineShelfCore` ne connaît **pas** SwiftUI. Un `Feature` ne connaît pas un autre `Feature` : la coordination passe par `NavigationModel`.

---

## 2. Scènes et cycle de vie

```swift
@main
struct CineShelfApp: App {
    @State private var container: ModelContainer
    @State private var navigation = NavigationModel()

    init() {
        do {
            container = try Persistence.makeContainer(cloudKit: FeatureFlags.cloudKitEnabled)
        } catch {
            fatalError("Impossible d'ouvrir le magasin : \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(navigation)
                .tint(.accentText)
        }
        .modelContainer(container)
        .commands { CineShelfCommands() }

        #if os(macOS)
        Settings { SettingsScene() }
        Window("Bibliothèque", id: "library-admin") { LibraryAdminScene() }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        #endif
    }
}
```

`FeatureFlags.cloudKitEnabled` est un booléen unique : `false` tant que tu n'as pas l'abonnement Apple Developer, `true` après. Rien d'autre ne change dans le code.

### Racine adaptative

```swift
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .compact {
            CompactRootView()      // TabView
        } else {
            RegularRootView()      // NavigationSplitView 3 colonnes
        }
    }
}
```

---

## 3. Données : couche d'accès

### Requêtes déclaratives dans les vues

Pour les listes simples, `@Query` suffit et gère la réactivité :

```swift
struct TitlesGrid: View {
    @Query private var titles: [Title]

    init(filter: TitleFilter, sort: TitleSort) {
        _titles = Query(filter: filter.predicate, sort: sort.descriptors)
    }
    // …
}
```

### Repositories pour tout le reste

Les opérations non triviales (création avec dérivés, fusion, dédoublonnage, import) passent par des repositories testables, sans SwiftUI :

```swift
@MainActor
public struct TitleRepository {
    let context: ModelContext

    public func create(name: String, kind: TitleKind, in library: Library) -> Title {
        let t = Title(name: name, kind: kind)
        t.library = library
        t.refreshDerived()
        context.insert(t)
        ActivityRecorder(context: context).record(.create, t)
        return t
    }

    public func update(_ t: Title, _ mutate: (Title) -> Void) {
        mutate(t)
        t.refreshDerived()                 // sortName, searchText, updatedAt
        SpotlightIndexer.shared.index(t)
    }

    public func softDelete(_ t: Title) {
        t.deletedAt = .now
        t.updatedAt = .now
        SpotlightIndexer.shared.remove(t)
    }
}
```

**Invariant central** : aucune écriture ne contourne `refreshDerived()`. C'est ce qui garantit que `sortName` et `searchText` restent cohérents — ils remplacent les colonnes générées et l'index FTS que CloudKit ne permet pas.

### Écritures lourdes hors du thread principal

Import, migration, régénération de vignettes : `ModelActor` dédié.

```swift
@ModelActor
actor ImportActor {
    func importBundle(at url: URL, progress: @Sendable (Double) -> Void) async throws { … }
}
```

Sauvegarde par lots de ~200 objets, sinon la mémoire explose et l'UI se fige.

---

## 4. Médias — le pipeline

Le point de performance n°1 de la version web (une grille de 48 jaquettes téléchargeait 8,6 Mo) se résout différemment ici : **rien ne se télécharge**, tout est local. Le risque devient la mémoire et le décodage.

### À l'import

```
Fichier choisi
  ├─ redimensionner à 2 000 px max        (une jaquette n'a pas besoin de plus)
  ├─ ré-encoder en HEIC qualité 0.8       (~3× plus petit que le JPEG source)
  ├─ calculer sha256                      → dédoublonnage applicatif
  ├─ calculer blurHash (4×3)              → ~30 octets, placeholder instantané
  ├─ relever pixelWidth / pixelHeight     → réserve de place, zéro saut
  └─ stocker dans MediaAsset.data (.externalStorage → CKAsset)
```

### À l'affichage

```swift
actor ThumbnailCache {
    func thumbnail(for assetID: UUID, targetSize: CGSize, scale: CGFloat) async -> CGImage?
}
```

- Vignette produite par `CGImageSourceCreateThumbnailAtIndex` avec `kCGImageSourceThumbnailMaxPixelSize` — décodage partiel, jamais l'image complète en mémoire.
- Cache disque dans `Caches/thumbnails/<assetID>-<preset>@<scale>.heic`, plus un `NSCache` mémoire borné.
- **Jamais synchronisé** : c'est reconstructible, et le quota iCloud appartient à l'utilisateur.
- Purge automatique quand `Caches/` dépasse un seuil, et sur `didReceiveMemoryWarning`.

### Affichage sans saut de mise en page

```swift
MediaThumbnail(asset: asset, context: .card)
    .aspectRatio(Ratio.poster, contentMode: .fill)
```

Séquence : `blurHash` (immédiat) → vignette cache (quelques ms) → vignette générée. La place est réservée dès le premier frame par `aspectRatio` + `pixelWidth/Height`.

Le recadrage applique la sémantique v1 :

```swift
let c = asset.crop(for: .card)
image
    .scaleEffect(c.zoom / 100)
    .offset(x: (50 - c.x) / 100 * width, y: (50 - c.y) / 100 * height)
    .clipped()
```

### Budget

| Métrique | Cible |
|---|---|
| Lancement à froid → premier écran utile | < 800 ms |
| Défilement d'une grille de 2 000 jaquettes | 120 fps constants (ProMotion) |
| Mémoire, grille pleine | < 250 Mo |
| Génération d'une vignette | < 20 ms |
| Recherche sur 5 000 titres | < 50 ms |

Mesurer avec Instruments (Time Profiler, Allocations, SwiftUI, Hangs) sur le **plus vieil appareil visé**, pas sur ton Mac.

---

## 5. Synchronisation

### État visible

CloudKit est asynchrone et parfois lent. L'utilisateur doit toujours savoir où il en est :

```swift
enum SyncState { case upToDate, syncing(Double?), offline, needsAccount, failed(String) }
```

`SyncStatusBadge` dans la barre latérale (Mac) ou l'écran Bibliothèque (iOS). Observer `NSPersistentCloudKitContainer.eventChangedNotification` — accessible même via SwiftData en écoutant les notifications du coordinateur sous-jacent.

Cas à traiter explicitement, chacun avec un message et une action :

| Cas | Message |
|---|---|
| Pas de compte iCloud | « Connecte-toi à iCloud pour synchroniser tes bibliothèques. » + `[Ouvrir Réglages]` |
| iCloud Drive désactivé | idem |
| Quota dépassé | « Ton stockage iCloud est plein. » + taille occupée par CineShelf + `[Gérer]` |
| Hors ligne | « Modifications enregistrées localement. Synchronisation à la reconnexion. » |
| Premier envoi long | barre de progression honnête, Wi-Fi recommandé |
| Premier téléchargement | l'app reste utilisable à moitié peuplée |

### Conflits & doublons

CloudKit résout les conflits en « dernier écrivain gagne » par champ. Deux points à gérer :

1. **Doublons de genres** créés hors ligne sur deux appareils → passe de fusion sur `nameKey` au démarrage.
2. **`MediaAttachment` orphelins** si un parent est supprimé pendant qu'un autre appareil y attache un média → tâche de maintenance.

---

## 6. Recherche

Trois couches, décrites en détail dans `02-MODELE-SWIFTDATA-CLOUDKIT.md` §5 :

1. `searchText` dénormalisé et replié (sans accents, minuscules) + `#Predicate.contains` — c'est ce qui remplace `unicode61 remove_diacritics 2`.
2. `CoreSpotlight` : indexer titres, personnes et collections → trouvables depuis l'écran d'accueil iOS et Spotlight macOS. `CSSearchableItemAttributeSet` avec vignette, et un `NSUserActivity` pour l'ouverture directe.
3. Index FTS local en base annexe **non synchronisée**, uniquement si la mesure le justifie (> ~20 000 entrées).

L'UI utilise `.searchable(text:placement:)` + `.searchScopes` pour filtrer par type, et `.searchSuggestions` pour les recherches récentes.

---

## 7. Import / export

- **Lecture CSV** : framework `TabularData` (`DataFrame(contentsOfCSVFile:)`), colonnes typées, gestion des séparateurs et encodages.
- **Écriture CSV** : sérialiseur maison, UTF-8 **avec BOM** (sinon Excel massacre les accents), séparateur `;` en locale française, échappement RFC 4180.
- **Archive complète** : un dossier `.cineshelfarchive` (package) contenant `manifest.json`, les JSON par entité et `media/`. Exposé via `Transferable` + `.fileExporter`, donc partageable par AirDrop.
- **Aperçu d'import** : `Table` éditable avec statut par ligne (nouveau / mise à jour / conflit / erreur), édition en masse de la sélection, revalidation, puis application dans un `ModelActor` avec progression.
- **Profils de mappage** : un profil « Movix » préconfiguré (reprise de `import-movix-csv.mjs`), et la possibilité d'enregistrer ses propres correspondances colonne → champ.

Le XLSX est reporté ; voir `03-FONCTIONNALITES-NATIF.md` §10 pour les trois options quand tu y reviendras.

---

## 8. Tests

| Niveau | Outil | Contenu |
|---|---|---|
| Modèle | Swift Testing + `ModelContainer(inMemory)` | dérivés (`sortName`, `searchText`), invariante d'exclusivité des `MediaAttachment`, résolution de recadrage, fusion de personnes, dédoublonnage de genres |
| Conformité CloudKit | test dédié | **échoue si** une propriété perd sa valeur par défaut, si une relation devient non optionnelle, ou si un `@Attribute(.unique)` apparaît |
| Médias | MediaKitTests | vignettes, blurhash, checksum, HEIC |
| Import | fixtures CSV réelles | y compris fichiers malformés et accents |
| Migration | dump réel anonymisé | les 8 assertions de comptage |
| Interface | XCUITest | 5 parcours |
| Snapshots | — | `PosterCard` et `ShelfRail` en clair/sombre × 3 tailles × Dynamic Type AX3 |

### Les 5 parcours XCUITest

1. Lancer → accueil → rail Action → fiche film → retour, position de scroll conservée
2. Créer un titre → ajouter une jaquette → recadrer → ajouter au casting → mettre en favori → supprimer
3. Bibliothèque → `Table` des titres → sélection multiple → édition en masse → vérifier la persistance
4. Importer un CSV → corriger une ligne dans l'aperçu → appliquer → vérifier les compteurs
5. Créer une seconde bibliothèque → basculer → vérifier l'isolation → transférer un titre

> **À faire avant tout** : enregistrer les équivalents contre l'app web actuelle (Playwright), pour disposer d'un oracle du comportement attendu.

---

## 9. Le test de conformité CloudKit

Le plus rentable de tous. À écrire au premier jour :

```swift
@Test func modelStaysCloudKitCompatible() throws {
    // Un conteneur configuré CloudKit lève à l'init si le schéma est invalide.
    let schema = Schema([Library.self, Title.self, Person.self, /* … */])
    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .private("iCloud.fr.feltrin.CineShelf")
    )
    #expect(throws: Never.self) {
        _ = try ModelContainer(for: schema, configurations: [config])
    }
}
```

Il attrape immédiatement la propriété non optionnelle sans défaut ou la relation obligatoire ajoutée par distraction — les deux erreurs les plus fréquentes, et celles qui coûtent le plus cher à découvrir après publication.

---

## 10. Ce qui remplace chaque brique web

| Web | Natif |
|---|---|
| Express + Cloudflare Worker (23 000 l.) | ⛔ rien |
| SQLite / Turso | SwiftData |
| R2 | `CKAsset` via `.externalStorage` |
| JWT, sessions, bcrypt, CORS, rate limiting | ⛔ compte iCloud |
| TanStack Query (cache, invalidation) | `@Query` + réactivité SwiftData |
| React Router | `NavigationStack` / `NavigationSplitView` |
| Tailwind + shadcn/ui (58 composants) | DesignSystem + composants natifs |
| lucide-react | SF Symbols |
| framer-motion | animations SwiftUI + `.navigationTransition` |
| `@tanstack/react-virtual` | `LazyVGrid`, `List`, `Table` |
| FTS5 | `searchText` + prédicat + CoreSpotlight |
| exceljs / xlsx | `TabularData` (CSV) |
| sharp | `ImageIO` |
| Vite, PostCSS, ESLint, Prettier | Xcode, SwiftLint, swift-format |
| Playwright | XCUITest |
| GitHub Actions | Xcode Cloud ou GitHub Actions + `xcodebuild` |
| Cloudflare Pages | TestFlight, App Store, Mac App Store |

---

## 11. Distribution & coûts

| Poste | Détail |
|---|---|
| **Apple Developer Program** | Obligatoire pour CloudKit — le provisioning gratuit d'un Apple ID **n'accorde pas** l'entitlement iCloud. Également requis pour TestFlight, l'App Store et la notarisation d'une app Mac distribuée hors store. ~99 $/an. |
| **CloudKit** | Base privée : consomme le quota iCloud de **l'utilisateur**, rien pour toi. Pas de coût serveur. |
| **Xcode** | Indispensable. Swift Playgrounds ne gère ni les entitlements CloudKit ni une cible macOS. Compter ~15–20 Go avec un simulateur. |
| **Matériel** | Un Mac suffit. Tester sur un iPhone physique avant publication (les performances de décodage d'images diffèrent nettement du simulateur). |
| **Signature** | Développement local possible sans abonnement, mais **sans CloudKit** — d'où la stratégie en deux temps de la roadmap. |

---

## 12. Ce qu'il faut reprendre de l'app web

Des choses bien pensées qu'il serait dommage de perdre en changeant de plateforme :

| Idée v1 | Transposition |
|---|---|
| Navigation précédent/suivant dans le détail, respectant les filtres de la liste | `NavigationModel` conserve la collection courante ; `⌥↑`/`⌥↓` sur Mac, balayage sur iOS |
| Restauration de scroll par écran | `.scrollPosition(id:)` + `SceneStorage` |
| Filtres persistés et partageables | état `@Observable` restauré au lancement + `NSUserActivity` pour Handoff |
| Recadrage indépendant par contexte d'affichage | `MediaCrop` — concept conservé tel quel, c'est une bonne idée |
| Rayons = collections + genres sur l'accueil | structure de l'accueil, inchangée |
| Aperçu → revalidation → application, à l'import | même flux, en `Table` native |
| Épinglage de genres | barre latérale |
| Tranches de durée et d'âge pré-réglées | mêmes bornes |
| `docs/performance/` en lots avec critères de sortie | même méthode pour cette refonte |
