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
│   ├── CineShelfCore/                @Model, repositories, services, Queries/
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
  ├─ calculer sha256 des octets SOURCE    → dédoublonnage applicatif
  ├─ calculer blurHash (4×3)              → ~30 octets, placeholder instantané
  ├─ relever pixelWidth / pixelHeight     → réserve de place, zéro saut
  └─ stocker dans MediaAsset.data (.externalStorage → CKAsset)
```

> **Le sha256 porte sur les octets source, pas sur le HEIC produit.** Décidé en
> implémentant le pipeline : l'empreinte est ainsi calculable sans décoder, et
> surtout stable d'un appareil et d'une version d'OS à l'autre. Un encodeur qui
> évolue donnerait sinon deux empreintes pour la même image, et le dédoublonnage
> tomberait dès la première synchronisation. Contrepartie assumée : la même image
> importée en JPEG puis en PNG donne deux `MediaAsset`.

> **L'encodage HEIC n'a pas de repli.** Vérifié disponible sur simulateur iOS
> comme sur macOS (Xcode 26) : un échec d'encodage est donc une vraie erreur, pas
> un cas à contourner en JPEG.

### À l'affichage

```swift
actor ThumbnailCache {
    func thumbnail(for assetID: UUID, targetSize: CGSize, scale: CGFloat) async -> CGImage?
}
```

- Vignette produite par `CGImageSourceCreateThumbnailAtIndex` avec `kCGImageSourceThumbnailMaxPixelSize` — décodage partiel, jamais l'image complète en mémoire.
- Cache disque dans `Caches/thumbnails/<assetID>-<preset>@<scale>.heic`, plus un `NSCache` mémoire borné.
- **Jamais synchronisé** : c'est reconstructible, et le quota iCloud appartient à l'utilisateur.
- Purge automatique quand `Caches/` dépasse un seuil, et sur pression mémoire.

**Les trois presets**, chiffrés en implémentant le cache. Le côté long en points,
multiplié par l'échelle de l'écran à la génération :

| Preset | Côté long | Ce qu'il couvre |
|---|---:|---|
| `thumb` | 160 pt | listes, casting, avatars — la carte portrait compacte fait 104 × 156 pt |
| `card` | 360 pt | grilles et rails — la plus grande carte de `docs/01` fait 340 pt de large |
| `hero` | 1200 pt | bandeau d'accueil et fiches |

La taille demandée par une vue est **arrondie au preset qui la couvre** : le nom
de fichier ci-dessus suppose un nombre borné d'entrées, pas une par largeur de
grille. À 3× un `hero` dépasse les 2 000 px de l'original, qui est alors rendu
tel quel — c'est voulu.

> **La purge mémoire écoute `DispatchSource.makeMemoryPressureSource`** et non
> `didReceiveMemoryWarning` : la notification est UIKit, la source de pression
> existe à l'identique sur iOS et sur macOS, et `MediaKit` reste ainsi compilable
> sans distinction de plateforme.

> **L'encodage HEIC de la vignette sort du chemin d'affichage.** Mesuré : le
> décodage-redimension coûte ~19 ms, l'encodage et l'écriture ~25 ms de plus. La
> vignette est donc rendue dès qu'elle existe, l'écriture disque est enchaînée en
> arrière-plan, et `flushPendingWrites()` permet de l'attendre avant de purger.

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
| Génération d'une vignette à froid, **hors thread principal** | < 30 ms |
| Lecture depuis le cache **disque** | < 5 ms |
| Lecture depuis le cache **mémoire** | < 1 ms |
| Recherche sur 5 000 titres | < 50 ms |

#### D'où viennent ces trois chiffres

Le budget précédent — une seule ligne, « génération d'une vignette < 20 ms » —
avait été écrit avant toute mesure, et il ne protégeait rien. À 120 Hz une image
dure **8,3 ms** : une génération à froid ne tient dans aucune image, ni à 20 ms
ni à 21,5. La conclusion n'est pas qu'il faut viser plus serré, c'est qu'une
génération à froid **ne doit jamais se produire sur le thread principal**. Ce qui
protège réellement le défilement, c'est le cache et le préchargement — pas un
seuil sur la génération.

Les trois budgets se lisent donc en fonction du chemin emprunté :

- **Génération à froid, hors thread principal : < 30 ms.** C'est le chemin qui
  n'a pas le droit d'être sur le chemin d'affichage. Le seuil sert à détecter une
  régression algorithmique (décodage complet au lieu du décodage partiel, par
  exemple), pas à garantir une fluidité : celle-ci vient de l'asynchronisme.
  30 ms couvre la mesure réelle (~19 ms de décodage-redimension, cf. plus haut)
  avec la marge d'une machine lente ou chargée.
- **Lecture depuis le cache disque : < 5 ms.** Celle-là peut arriver pendant un
  défilement. 5 ms tient dans une image à 120 Hz avec de la marge pour le reste
  du travail de rendu.
- **Lecture depuis le cache mémoire : < 1 ms.** Chemin nominal du défilement :
  doit être négligeable devant les 8,3 ms d'une image.

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

### Spotlight : la règle de confidentialité (depuis `L3`)

**Une entité privée ou à la corbeille n'est jamais dans l'index, et elle doit en
**sortir** quand elle le devient.** Les deux exigences ne se confondent pas : un titre
indexé alors qu'il était public, puis rendu privé, resterait trouvable depuis l'écran
d'accueil du système. L'app le masque partout correctement, donc rien ne signale la
fuite. Même chose pour la suppression douce.

D'où la forme de l'API : `SpotlightIndexer.sync(_:)` **décide à partir de l'état
courant** au lieu de recevoir un ordre « indexe » ou « retire ». Les repositories
l'appellent après chaque écriture, sans avoir à savoir ce qui a changé.

**`isPrivate` est porté par l'entité, pas par le profil.** Un `Title` appartient à une
`Library`, jamais à un `Profile` ; ce que le profil porte est `hidesPrivateContent`,
qui décide de l'**affichage** dans l'app. Pour Spotlight, seule `isPrivate` compte, et
`hidesPrivateContent` n'aurait aucun sens : l'index du système est unique pour
l'appareil et n'a pas de notion de profil actif. S'y fier ferait fuiter dès qu'un
profil permissif touche une entité privée.

Les entités **archivées restent indexées** : `isArchived` est un état de rangement, pas
de confidentialité. Décision, pas oubli — elle se change dans
`SpotlightIndexer.shouldIndex(isPrivate:deletedAt:)`, et nulle part ailleurs.

La réindexation complète (`reindexEverything(in:)`) est rejouable et vide l'index
avant de le reconstruire. Trois appelants prévus : la fin de la migration `L13`, un
changement de format d'identifiant, et la maintenance de `L16`.

### Le service, et son contrat (depuis `L2`)

`SearchService` (dans `CineShelfCore/Queries/`) est une fonction : « texte + portée →
résultats groupés ». Quatre points de contrat qui commandent l'interface :

- **Deux états, pas trois.** `SearchOutcome` vaut `.idle` (aucun terme saisi, espaces
  compris) ou `.results`, dont les groupes peuvent être vides. « Aucune
  correspondance » se déduit de `SearchResults.isEmpty` et n'a pas son propre cas : un
  troisième état serait une seconde source de vérité pour le même fait. Le compilateur
  force donc l'écran à traiter les deux branches — champ vide → recherches récentes,
  terme sans correspondance → « aucun résultat ».
- **La décision de `idle` appartient au service.** La règle vit à un seul endroit,
  l'écran ne peut pas l'oublier ni la contredire.
- **Chaque groupe porte sa tranche et son compte complet** (`fetchCount`, aucun objet
  matérialisé). C'est ce qui permet « 12 titres » sous une liste de cinq.
- **Aucun anti-rebond dans le service.** Il est appelable à chaque frappe ; c'est la
  vue qui décide quand l'appeler. Le rebond ici le rendrait intestable et imposerait
  un rythme aux appelants sans frappe — un App Intent de `L19`, par exemple.

La visibilité n'est pas réimplémentée : les titres passent par `TitleFilter`, les
personnes par `PersonFilter`, ceux-là mêmes que la grille et la liste utilisent. Un
second chemin finirait par diverger, et la recherche montrerait alors un contenu privé
que la grille masque. C'est la raison pour laquelle `TitleFilter` est descendu de
`App/` vers `CineShelfCore`.

Mesuré : **8 à 11 ms** en portée `.all` sur 5 000 titres — huit requêtes, deux par
type. Budget de §4 : 50 ms.

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
