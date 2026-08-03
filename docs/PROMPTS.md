# CineShelf — Tous les prompts, dans l'ordre

Rien d'autre : ce qu'il faut coller, à qui, avec quoi.
Version détaillée (vérifications, critères de sortie, dépannage) → `GUIDE-EXECUTION.md`.

---

## Récapitulatif

| # | Quoi | Qui | Docs à lire | État |
|---|---|---|---|---|
| 4 | Installation du projet | Code | `SETUP.md` | ✅ `03fff62` |
| 5 | Modèle de données (17 `@Model`) | Code | `02` `04` | ✅ `d5e7cb9` |
| 6 | Repositories & outillage | Code | `04` | ✅ `451f6da` |
| — | Ménage (doc, CI, journal) | Code | — | ✅ `ad95dcc` |
| 13a | Pipeline médias — **logique seule** | Code | `04 §4` | ✅ `d1810d1` |
| 7 | Tokens | **Design** | `01` | ✅ livré |
| 8 | Composants | **Design** | `01 partie D` | ✅ livré |
| 8bis+9 | Intégration DesignSystem + catalogue | Code | — | ✅ `ee3b88c` |
| — | Budgets perf, chasse Archivo, doc | Code | — | ✅ `0aa8d05` |
| 10 | Navigation adaptative | Code | `01 partie C`, `04 §2` | ✅ `dc15a48` |
| **11** | **Titres (liste + détail + éditeur)** | Code | `03 §4` | 🔜 **suivant** |
| 12 | Recherche + Spotlight | Code | `02 §5` | ⬜ |
| 13b | Médias — **UI** : PhotosPicker, import fichier, glisser-déposer, `CropEditor`, branchement `MediaThumbnail`, `attach` + invariante, préchargement | Code | `04 §4` | ⬜ |
| 14 | Galerie + visionneuse | Code | `03 §7` | ⬜ |
| 15 | Personnes + doublons + fusion | Code | `03 §5` | ⬜ |
| 16 | Collections, genres, liens, accueil, fil | Code | `03 §6 §8 §11` | ⬜ |
| 17 | Console de gestion (`Table`) | Code | `03 §12` | ⬜ |
| 18 | Profils, bibliothèques, Face ID | Code | `02 §2.2 §9` | ⬜ |
| 19 | Import/export CSV | Code | `03 §10`, `04 §7` | ⬜ |
| 2 | **Dump de l'app web** | Code (dépôt web) | `02 §7` | ⬜ avant le 20 |
| 20 | Migration des vraies données | Code | `02 §7` | ⬜ |
| 21 | Config CloudKit | toi | — | ⬜ abonnement requis |
| 22 | Synchronisation | Code | `04 §5` | ⬜ |
| 23 | Intégrations système | Code | `03 §13` | ⬜ |
| 24 | Accessibilité | Code | `01 partie E` | ⬜ |
| 25 | Publication | toi | — | ⬜ |
| 1 | Tests Playwright de référence | Code (dépôt web) | `03` | ⬜ facultatif |
| 3 | Captures de l'app web | toi | — | ⬜ facultatif |

> **Les docs ne se joignent plus** : elles sont dans `docs/` du dépôt, Claude Code les lit sur disque.
> **Suivi de l'avancement : ce tableau uniquement.** `docs/03` garde ses symboles (✅ ♻️ 🔀 ⛔ ⏸ ➕) — ils décrivent *l'intention* pour chaque fonctionnalité, pas l'état d'avancement. Ne pas mélanger les deux.
> À la fin de chaque prompt : cocher la ligne ici avec le hash du commit.

**Écarts connus, à reprendre plus tard** (tenus à jour au fil des sessions) :

| Sujet | Où ça se règle |
|---|---|
| Barre d'outils de la colonne « Liste » | 11 |
| `⌥↑` / `⌥↓` câblés mais inactifs (aucune collection peuplée) | 11 |
| `MediaThumbnail` non relié à `ThumbnailCache` | 11 |
| `⌘N` « Nouveau titre » présent mais grisé | 11 |
| `Profile.requiresBiometry` affiché mais non appliqué | 18 |
| Préchargement de l'écran suivant | 13b |
| `MediaRepository.attach` + invariante `hasExactlyOneOwner` | 13b |
| `Bootstrap` ne branche pas `startObservingMemoryPressure()` : le cache n'est instancié par personne tant qu'aucune vue n'affiche d'image | 13b |
| Dédoublonnage médias : global au magasin (décision actée) | — |
| Reprise d'import par lot de 200, pas par élément | 19 · 20 |
| `⇧⌘I` / `⇧⌘E` présents mais grisés | 19 |
| Avertissement à l'écran quand un profil change de bibliothèque | 18 |
| Bloc « Bibliothèques » de la barre latérale affiché mais inerte | 18 |
| Les 36 primitives sont générées dans le `.xcassets` alors qu'aucune vue ne doit les lire — à élaguer si le poids devient un sujet | — |
| Le pont `Binding<AppSection?>` de `Sidebar` avale la désélection : si un état « rien de sélectionné » devient nécessaire, c'est `NavigationModel.section` qu'il faudra rendre optionnelle, pas la vue | — |

---

## Structure de travail à mettre dans chaque prompt

À coller en tête de tout prompt à partir du 10. Économise le contexte et évite la compaction.

```
Répartition du travail :
- Toi, agent principal : les décisions d'architecture, le code structurant,
  l'intégration. Tu gardes la vue d'ensemble et tu ne délègues pas ça.
- Sous-agent « reco », AVANT d'écrire : lit les sections de docs concernées et
  le code existant, et me rend une synthèse — ce qui existe déjà, les
  contraintes, les pièges. Rien d'autre.
- Sous-agent « build » : la boucle compiler → erreur → corriger, sur iOS et
  macOS. Il ne me rend que le résultat final et la liste des corrections.
- Sous-agent « revue », À LA FIN : relit ton travail contre les docs citées et
  CLAUDE.md, et liste les écarts. Il ne corrige rien, il constate.

Termine par un commit et une mise à jour de docs/journal.md et du tableau
d'état de docs/PROMPTS.md, avec le hash.
```

---|---|---|---|
| 1 | Tests de référence | **Code** (dépôt web) | `03-FONCTIONNALITES-NATIF.md` |
| 2 | Dump des données | **Code** (dépôt web) | `02-MODELE-SWIFTDATA-CLOUDKIT.md` |
| 3 | Captures d'écran | toi | — |
| 4 | **Installation complète du projet** | **Code** | voir `SETUP.md` |
| 5 | Modèle de données | **Code** | `02` + `04` |
| 6 | Repositories & outillage | **Code** | `04` |
| 7 | Tokens | **Design** | `01-DESIGN-SYSTEM-APPLE.md` |
| 8 | Composants | **Design** | (même conversation que 7) |
| **8 bis** | **Passer le design à Claude Code** | toi + **Code** | — |
| 9 | Intégration du DesignSystem | **Code** | — |
| 10 | Navigation | **Code** | `01` + `04` |
| 11 | Titres | **Code** | `03` |
| 12 | Recherche | **Code** | `02` |
| 13 | Pipeline médias | **Code** | `04` |
| 14 | Galerie | **Code** | `03` |
| 15 | Personnes | **Code** | `03` |
| 16 | Collections, genres, liens | **Code** | `03` |
| 17 | Console de gestion | **Code** | `03` |
| 18 | Profils & Face ID | **Code** | `02` + `03` |
| 19 | Import/export CSV | **Code** | `03` + `04` |
| 20 | Migration des vraies données | **Code** | `02` |
| 21 | Config CloudKit | toi | — |
| 22 | Synchronisation | **Code** | `04` + `02` |
| 23 | Intégrations système | **Code** | `03` |
| 24 | Accessibilité | **Code** | `01` |
| 25 | Publication | toi | — |

---

## Comment circulent les fichiers entre les deux agents

Claude Design et Claude Code ne partagent **rien** : ce sont deux conversations séparées, aucune ne voit l'autre. Le dépôt Git est le seul point de passage.

```
Claude Design  ──▶  tu colles le code dans le dépôt  ──▶  Claude Code le lit
   (sessions 7-8)            (session 8 bis)              (sessions 9 et suivantes)
```

Conséquences pratiques :

- **Aux sessions 7 et 8**, tu joins `01-DESIGN-SYSTEM-APPLE.md` à Claude Design. Il te rend du code dans la conversation.
- **À la session 8 bis**, tu mets ce code dans `Packages/DesignSystem/` et tu commit.
- **À partir de la session 9**, Claude Code lit tout depuis le dépôt. Tu n'as **plus jamais** besoin de lui joindre quoi que ce soit venant de Claude Design.
- **Si Claude Code a besoin d'un composant qui n'existe pas** (ça arrivera vers les sessions 11 ou 17), deux options : soit tu le laisses l'écrire en respectant les tokens existants, soit tu retournes voir Claude Design avec une capture de l'écran concerné. Pour un composant simple, laisse Claude Code faire ; pour quelque chose de visuellement structurant, repasse par Design.

---

## Le fichier `CLAUDE.md`

**Tu n'as pas à le créer** : le prompt 4 (`SETUP.md`) le génère à partir de cette section. Il est reproduit ici pour que tu puisses vérifier ce qui a été produit, et le corriger si tu changes d'avis en cours de route.

Claude Code le lit automatiquement à chaque session : c'est lui qui l'empêche de dériver.

````markdown
# CineShelf — instructions projet

## Le projet
App SwiftUI multiplateforme (iOS · iPadOS · macOS) : catalogue personnel de films,
séries, personnes, collections et images. Réécriture native d'une app web
React + Express retirée. **Aucun backend.** SwiftData + CloudKit privé.

## Documents de référence — à consulter avant toute tâche
- `docs/02-MODELE-SWIFTDATA-CLOUDKIT.md` — le modèle de données **fait foi**
- `docs/03-FONCTIONNALITES-NATIF.md` — le contrat : ~130 fonctionnalités, **rien ne doit manquer**
- `docs/04-ARCHITECTURE-SWIFTUI.md` — structure, pipeline médias, tests
- `docs/01-DESIGN-SYSTEM-APPLE.md` — tokens et composants

## Règles non négociables — modèle
- Toute propriété `@Model` a une valeur par défaut **ou** est optionnelle.
- Aucun `@Attribute(.unique)` — CloudKit l'interdit. Dédoublonnage applicatif.
- Toutes les relations sont optionnelles, avec `inverse:` déclaré d'un seul côté.
- Pas de règle de suppression `.deny`.
- Les enums sont persistées en `rawValue: String`, exposées en propriété calculée.
- `sortName` et `searchText` maintenus par `refreshDerived()`, appelé à **chaque** écriture.
- `CloudKitConformanceTests` doit passer avant tout commit.

## Règles non négociables — design
- Aucune couleur littérale hors du package `DesignSystem`.
- Aucune taille de police fixe : `Font.custom(_:size:relativeTo:)` ou `Font.<textStyle>`.
- `.clipShape(.rect(cornerRadius:style: .continuous))`, jamais `.cornerRadius()`.
- Matériaux (`.regularMaterial`) pour les surfaces superposées, pas d'ombres maison.
- SF Symbols uniquement.
- Tout élément interactif ≥ 44 pt et accessible au clavier sur macOS.

## Règles non négociables — code
- Swift 6, concurrence stricte.
- Pas de force unwrap hors des tests.
- Aucune logique métier dans une `View` : repository ou service.
- Un dossier `Features/X` n'importe jamais `Features/Y`.
- `CineShelfCore` n'importe jamais SwiftUI.

## Commandes
```bash
xcodebuild -scheme CineShelf -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme CineShelf -destination 'platform=macOS' build
xcodebuild test -scheme CineShelf -destination 'platform=iOS Simulator,name=iPhone 16'
swiftlint --strict
```

## Déroulé attendu de chaque tâche
1. Lire la section pertinente des docs.
2. **Proposer un plan avant d'écrire du code.** Attendre ma validation.
3. Écrire, compiler, corriger jusqu'à build vert sur iOS **et** macOS.
4. Lancer les tests.
5. Cocher les fonctionnalités traitées dans `docs/03-FONCTIONNALITES-NATIF.md`.
6. Ajouter une ligne à `docs/journal.md`.
7. Un commit par tâche, message conventionnel.

## Ce que je ne veux pas
- De dépendance externe sans me demander.
- Du code « au cas où ».
- Des commentaires qui paraphrasent le code.
- Du texte d'interface en anglais : l'app est en français.
````

---

# 1 — Tests de référence

**Qui :** Claude Code, dans le dépôt **CineShelf (web)**
**Joindre :** `03-FONCTIONNALITES-NATIF.md`

```
Je vais réécrire cette app web en natif Apple. Avant ça, j'ai besoin d'un oracle
du comportement actuel.

Installe Playwright dans ce dépôt et écris 5 tests end-to-end contre l'app qui
tourne en local (npm run dev:full, front sur :3103, API sur :4003) :

1. Connexion → accueil → liste films → ouvrir un détail → retour, en vérifiant
   que la position de scroll est restaurée
2. Créer un film → lui ajouter une jaquette → recadrer → ajouter un acteur au
   casting → mettre en favori → supprimer
3. Réglages → onglet films → sélection multiple → édition en masse → recharger
   la page et vérifier la persistance
4. Import d'un fichier Excel → aperçu → corriger une ligne → revalider →
   appliquer → vérifier les compteurs du catalogue
5. Bascule vers un profil lié → vérifier l'isolation des données → revenir

Utilise les comptes seed (admin@cineshelf.local / admin123).
Chaque test doit assert sur des valeurs concrètes, pas seulement sur la présence
d'éléments. Ajoute un script npm `test:e2e`.

Ces tests ne servent pas à valider l'app web : ils documentent ce que la version
native devra reproduire. Commente-les dans ce sens.
```

---

# 2 — Dump des données

**Qui :** Claude Code, dépôt **web**
**Joindre :** `02-MODELE-SWIFTDATA-CLOUDKIT.md`

```
Écris `server/scripts/export-native-bundle.mjs`. Il doit produire un dossier
autonome contenant TOUTES les données de l'app, destiné à être importé dans une
future app native.

Structure exacte attendue — voir 02-MODELE-SWIFTDATA-CLOUDKIT.md §7 étape 1 :

CineShelfExport/
├── manifest.json      { schemaVersion: 1, exportedAt, counts: {...} }
├── titles.json        tous les champs de `movies`, y compris les 9 colonnes de recadrage
├── people.json        `actors` ET `social_profiles`, en conservant social_profiles.actor_id
├── collections.json   avec les 6 colonnes cover_*
├── genres.json
├── credits.json       depuis movie_actor
├── links.json  saved_links.json
├── flags.json         watchlist + les 3 tables de favoris, à plat
└── media/
    ├── index.json     { id, ownerType, ownerId, isMain, type, crops:{x,y,zoom}, sha256, file }
    └── files/<id>.<ext>

Points critiques :
- Résoudre les 3 formes de `medias.url` : data-URL (décoder), /api/medias/:id/file
  (lire sur disque), http(s):// (télécharger, avec retry et timeout).
- Calculer le sha256 de chaque fichier et le mettre dans index.json.
- Ne rien filtrer : inclure les entités privées, cachées, et tous les profils liés.
- Le manifest doit contenir le compte exact de chaque entité, pour vérification.
- Le script doit être rejouable et supporter --dry-run.
- Afficher une progression, et un récapitulatif final avec les compteurs.
```

---

# 3 — Captures d'écran

**Qui :** toi. Pas de prompt.

Capture chaque écran de l'app web (accueil, films, détail, acteurs, collections, galerie, lightbox, recherche, signets, profil, compte, les 10 onglets de réglages, import, export, fusion) dans `docs/reference-web/`.

**Puis : copie `CineShelfExport/` sur un disque externe et dans un cloud.**

---

# 4 — Installation complète du projet

**Qui :** Claude Code, dans un dossier vide
**Joindre :** rien (le prompt gère tout)

Le prompt complet est dans **`SETUP.md`** — il est long, je ne le duplique pas ici.

Il crée en une fois : le dépôt Git, le projet Xcode via XcodeGen, les trois
packages locaux, `CLAUDE.md`, l'Info.plist, les entitlements CloudKit prêts mais
désactivés, SwiftLint avec les règles maison, la CI, et le code minimal qui
compile sur iOS et macOS.

Prérequis, à faire avant : Xcode installé et lancé une fois, Homebrew installé,
les 9 fichiers `.md` posés quelque part.

```bash
mkdir ~/Developer/Rayon && cd ~/Developer/Rayon
claude
```

Puis colle le prompt de `SETUP.md`.

---

# 5 — Modèle de données

**Qui :** Claude Code (nouveau dépôt)
**Joindre :** `02-MODELE-SWIFTDATA-CLOUDKIT.md` + `04-ARCHITECTURE-SWIFTUI.md`

```
Lis docs/02-MODELE-SWIFTDATA-CLOUDKIT.md en entier avant de commencer.

Implémente dans le package CineShelfCore les 17 @Model décrits en section 3 :
Library, Profile, TitleFlag, PersonFlag, MediaFlag, Title, Person, SocialHandle,
TitleCollection, Genre, Credit, MediaAsset, MediaAttachment, MediaCrop,
ResourceLink, SavedLink, ActivityEntry.

Reprends le code du document tel quel quand il est fourni : il est écrit sous
les contraintes CloudKit et je ne veux pas qu'on s'en écarte.

Ajoute :
- Les énumérations de la section 3.1, persistées en rawValue String avec
  propriété calculée exposée.
- `Persistence.makeContainer(cloudKit:)` (section 4) et un `FeatureFlags`
  avec `cloudKitEnabled = false` pour l'instant.
- Un `VersionedSchema` + `SchemaMigrationPlan`, même vide.
- `refreshDerived()` sur Title, Person, TitleCollection, SavedLink.

AVANT tout le reste, écris `CloudKitConformanceTests` (docs/04 §9) : il
instancie un ModelContainer configuré CloudKit en mémoire et échoue si le
schéma est invalide. Il doit passer.

Puis les tests unitaires :
- refreshDerived() produit bien un sortName sans accents ni casse
- MediaAsset.crop(for:) applique la résolution contexte → standard → (50,50,100)
- MediaAttachment.hasExactlyOneOwner
- Un TitleFlag repassé à isEmpty est bien supprimé par FlagRepository

Compile pour iOS et macOS, lance les tests, corrige jusqu'au vert. Montre-moi
seulement le résultat final.
```

---

# 6 — Repositories & outillage

**Qui :** Claude Code
**Joindre :** `04-ARCHITECTURE-SWIFTUI.md`

```
Dans CineShelfCore, implémente la couche d'accès décrite dans docs/04 §3 :

- TitleRepository, PersonRepository, CollectionRepository, MediaRepository
  (create / update / softDelete / restore), chacun appelant refreshDerived()
- GenreRepository avec findOrCreate(name:target:in:) qui cherche sur nameKey
  avant d'insérer — c'est notre remplacement de la contrainte d'unicité
- FlagRepository (docs/02 §3.2 ter) avec suppression des flags vides
- ProfileRepository : créer, renommer, supprimer, changer de bibliothèque
- ActivityRecorder qui journalise create/update/delete/merge/import
- Un ImportActor (@ModelActor) vide pour l'instant, avec le patron de
  sauvegarde par lots de 200

Ajoute aussi :
- .swiftlint.yml strict, avec une règle personnalisée interdisant
  Color(red:green:blue:), Color(hex:) et UIColor/NSColor hors de DesignSystem
- .swift-format
- .github/workflows/ci.yml : build iOS + macOS + tests + swiftlint
- docs/journal.md

Tests unitaires sur chaque repository, avec un ModelContainer en mémoire.
```

---

# 7 — Tokens

**Qui :** **Claude Design**
**Joindre :** `01-DESIGN-SYSTEM-APPLE.md`

```
Voici le design system de CineShelf, une app SwiftUI multiplateforme
(iOS · iPadOS · macOS) : catalogue personnel de films et séries.

Le document contient la direction artistique et l'intégralité des tokens.
Suis-le exactement — ne réinvente ni la palette, ni l'échelle typographique,
ni les rôles. Si quelque chose te paraît manquer, demande-moi.

Produis le contenu du package Swift `DesignSystem` :

1. `Resources/Colors.xcassets` — les primitives (Graphite, Ember, Jade, Amber,
   Crimson, Azure) et les sémantiques de la partie B.1, chacune avec les
   apparences Any, Dark, Any High Contrast, Dark High Contrast, en Display P3.
   Donne-moi la liste complète des Color Sets à créer avec leurs valeurs par
   apparence, sous une forme que je peux reproduire dans Xcode.
2. `Colors.swift` — les extensions `ShapeStyle where Self == Color` typées.
3. `Typography.swift` — l'enum Typo de la partie B.2. Dynamic Type obligatoire :
   `Font.custom(_:size:relativeTo:)` partout, jamais de taille fixe.
4. `Metrics.swift` — Space, Radius, Elevation, Motion, Ratio.
5. `CardMetrics.swift` — la matrice layout × size de la partie B.7.
6. `Icons.swift` — la correspondance SF Symbols de la partie B.8, en constantes
   typées plutôt qu'en chaînes dispersées.

Contraintes : aucune couleur littérale hors de Colors.swift, rayons continus
(`.rect(cornerRadius:style:.continuous)`), matériaux plutôt qu'ombres pour les
surfaces superposées.
```

---

# 8 — Composants

**Qui :** **Claude Design**, même conversation que 7
**Joindre :** rien de plus

```
Maintenant les composants, partie D du document. Dans cet ordre :

1. StateView (vide / chargement / erreur) — trois cas, un seul composant
2. FieldRow (LabeledContent + validation)
3. FilterBar, DisplayMenu
4. MediaThumbnail — blurhash → vignette → image, sans saut de mise en page.
   Prends en paramètre une closure asynchrone de chargement : le vrai cache
   viendra plus tard, mets un stub.
5. PosterCard — image + recadrage + badges (favori, watchlist, privé, archivé)
   + titre + méta. Survol sur macOS, contextMenu, matchedTransitionSource.
6. ShelfRail — l'élément signature de la partie A.4. Libellé, filet, compteur
   monospace, barre de progression en accent, flèches au survol sur Mac.
7. CatalogGrid — LazyVGrid piloté par CardMetrics, avec bascule automatique en
   liste au-delà de dynamicTypeSize .accessibility1.

Puis une app de démonstration `DesignSystemCatalog` montrant chaque composant
dans chaque état, avec des sélecteurs pour le thème (clair/sombre), la taille
de texte (normale / AX3 / AX5) et la plateforme.

Rappels : Dynamic Type partout, cibles ≥ 44 pt, accessibilityReduceMotion
respecté, `.accessibilityLabel` sur chaque élément non textuel.
```

> Ensuite : colle dans Xcode, lance la preview, **fais une capture**, renvoie-la avec tes remarques. 2–3 allers-retours.

---

# 8 bis — Passer le design à Claude Code

**Qui :** toi, puis Claude Code
**Joindre :** rien

### a) Ce que tu fais à la main

1. Colle les fichiers Swift rendus par Claude Design dans
   `Packages/DesignSystem/Sources/DesignSystem/` :
   `Colors.swift`, `Typography.swift`, `Metrics.swift`, `CardMetrics.swift`, `Icons.swift`,
   puis `Components/` (StateView, FieldRow, FilterBar, DisplayMenu, MediaThumbnail,
   PosterCard, ShelfRail, CatalogGrid) et l'app `DesignSystemCatalog`.
2. Colle la **liste des Color Sets** (celle que Claude Design t'a donnée en session 7)
   dans un fichier `docs/couleurs.md`. Ne les crée pas à la main dans Xcode : ~80 jeux
   × 4 apparences, c'est 300 clics. Le prompt ci-dessous les génère.
3. Télécharge **Archivo Variable** (Google Fonts) dans
   `Packages/DesignSystem/Sources/DesignSystem/Resources/Fonts/`.

### b) Le prompt à donner à Claude Code

```
Claude Design a produit le package DesignSystem. J'ai collé ses fichiers Swift
dans Packages/DesignSystem/Sources/DesignSystem/ et la liste des couleurs dans
docs/couleurs.md.

Génère l'arborescence
Packages/DesignSystem/Sources/DesignSystem/Resources/Colors.xcassets à partir
de docs/couleurs.md :

- un dossier `<nom>.colorset` par jeu, avec son Contents.json
- 4 apparences par jeu : Any, Dark, Any + High Contrast, Dark + High Contrast
  (appearances luminosity: light/dark et contrast: high)
- espace colorimétrique display-p3, composantes en float 0–1
- respecte la hiérarchie de dossiers de la liste (Graphite/, Ember/, bg/, text/,
  border/, accent/, status/, media/, state/) avec les Contents.json intermédiaires
- le Contents.json racine

Déclare ensuite la police Archivo dans le Package.swift (resources) et dans le
Info.plist de la cible app, et vérifie que le nom PostScript utilisé dans
Typography.swift correspond bien au fichier.

Puis compile le package pour iOS et macOS et corrige jusqu'au vert.
```

### c) Commit

`git add . && git commit -m "feat(design): design system initial"`

---

# 9 — Intégration du DesignSystem

**Qui :** Claude Code
**Joindre :** rien (le code est dans le dépôt)

```
Claude Design a produit le package DesignSystem (voir Packages/DesignSystem).
Intègre-le proprement :

- Vérifie que ça compile sur iOS et macOS
- Active la règle SwiftLint interdisant les couleurs littérales hors du module
  et corrige les violations
- Ajoute des tests de snapshot sur PosterCard et ShelfRail : clair/sombre ×
  compact/medium/large × Dynamic Type normale/AX3
- Embarque la police Archivo Variable (fichier dans Resources, déclaration dans
  le Info.plist, vérifie que le nom PostScript utilisé dans Typo correspond)
- Ajoute DesignSystemCatalog comme cible de développement
```

---

# 10 — Navigation

**Qui :** Claude Code
**Joindre :** `01-DESIGN-SYSTEM-APPLE.md` + `04-ARCHITECTURE-SWIFTUI.md`

```
Implémente la coquille de l'app, docs/01 partie C et docs/04 §2.

- CineShelfApp : scènes, ModelContainer, commandes de barre de menus,
  scène Settings sur macOS
- RootView adaptative : CompactRootView (TabView 5 onglets) et RegularRootView
  (NavigationSplitView 3 colonnes)
- NavigationModel @Observable : route courante, collection de navigation
  (pour le précédent/suivant dans le détail), restauration au lancement
- Barre latérale : sections, genres épinglés, menu de profil
- Sélecteur de profil au lancement (affiché si > 1 profil, avec option
  « ouvrir directement le dernier profil »)
- Bascule de profil par ⌃⌘1…9 sur Mac
- Écrans vides pour toutes les routes, avec StateView

Pas encore de données réelles : des placeholders. Ce que je veux valider à ce
stade, c'est que la navigation est correcte sur iPhone, iPad et Mac.
```

---

# 11 — Titres

**Qui :** Claude Code
**Joindre :** `03-FONCTIONNALITES-NATIF.md`

```
Implémente Features/Titles, en couvrant TOUTES les lignes du §4 de
docs/03-FONCTIONNALITES-NATIF.md.

Liste :
- CatalogGrid avec @Query, tri (ajout, titre, note, sortie, durée × asc/desc)
- Filtres : recherche, collection, genre, personne, durée min/max, note min/max
- Tranches de durée pré-réglées (court < 90, moyen 90–120, long > 120)
- Bascule d'affichage (layout × taille), par contexte, persistée par profil
- Bascule « afficher les archivés »

Détail :
- Hero 16/9, jaquette 2/3, métadonnées, casting, galerie, liens
- Boutons favori / watchlist / vu, qui écrivent dans TitleFlag du profil courant
- Navigation précédent/suivant respectant les filtres de la liste
  (⌥↑ / ⌥↓ sur Mac, balayage sur iOS)
- .navigationTransition(.zoom) depuis la carte

Édition : feuille sur iOS, .inspector sur Mac et iPad.

L'état des filtres vit dans NavigationModel et est restauré au lancement.
```

---

# 12 — Recherche

**Qui :** Claude Code
**Joindre :** `02-MODELE-SWIFTDATA-CLOUDKIT.md`

```
Implémente la recherche, docs/02 §5 niveaux 1 et 2.

- .searchable + .searchScopes (Tous / Titres / Personnes / Collections / Signets)
- Prédicats sur le champ searchText déjà replié (sans accents, minuscules)
- Résultats groupés par type, avec compteur par groupe
- .searchSuggestions avec les recherches récentes (stockées localement)
- Indexation CoreSpotlight des titres, personnes et collections, avec vignette
  et NSUserActivity pour l'ouverture directe
- Ne PAS indexer les entités isPrivate

Vérifie que « ame » trouve « Âme », et que « downey » trouve « Robert Downey Jr. ».
```

---

# 13 — Pipeline médias

**Qui :** Claude Code
**Joindre :** `04-ARCHITECTURE-SWIFTUI.md`

```
Implémente le package MediaKit, docs/04 §4.

Import :
- PhotosPicker, .fileImporter, glisser-déposer, collage
- Pipeline : redimension à 2000 px max, ré-encodage HEIC qualité 0.8,
  sha256, blurhash 4×3, relevé de pixelWidth/pixelHeight
- Déduplication : si le sha256 existe déjà pour ce propriétaire, réutiliser
  le MediaAsset au lieu d'en créer un

Affichage :
- ThumbnailCache (actor) : CGImageSourceCreateThumbnailAtIndex avec
  kCGImageSourceThumbnailMaxPixelSize, cache disque dans Caches/thumbnails/,
  NSCache mémoire borné, purge au-delà d'un seuil et sur alerte mémoire
- Brancher MediaThumbnail dessus (le stub de la session 8)
- Séquence : blurhash → cache → générée, sans jamais de saut de mise en page

Recadrage :
- CropEditor : MagnifyGesture + DragGesture, aperçu par contexte,
  écrit dans MediaCrop

Les vignettes ne doivent JAMAIS entrer dans le modèle SwiftData : elles sont
reconstructibles et le quota iCloud appartient à l'utilisateur.

Mesure : je veux pouvoir défiler une grille de 2000 jaquettes à fréquence
pleine et sous 250 Mo. Écris un test de performance et dis-moi les chiffres.
```

---

# 14 — Galerie

**Qui :** Claude Code
**Joindre :** `03-FONCTIONNALITES-NATIF.md`

```
Implémente Features/Gallery, §7 de docs/03.

- Masonry en colonnes, nombre de colonnes selon la largeur
- Filtre par source (titre / personne / collection / orphelin)
- Mélange avec graine stable (le même mélange tant qu'on ne rafraîchit pas)
- Favoris de galerie, écrits dans MediaFlag du profil courant
- Visionneuse plein écran : zoom, balayage entre médias, partage système,
  .navigationTransition(.zoom) depuis la vignette
- Scroll immersif
- Quick Look sur les médias

Sur Mac : glisser-déposer depuis le Finder pour ajouter, et depuis l'app vers
le Finder pour exporter.
```

---

# 15 — Personnes

**Qui :** Claude Code
**Joindre :** `03-FONCTIONNALITES-NATIF.md`

```
Implémente Features/People, §5 de docs/03.

- Liste avec filtres (rôle acteur/social, genre, tranche d'âge jeune < 35 /
  moyen 35–55 / senior > 55)
- Fiche : portrait, biographie, âge calculé, filmographie, comptes sociaux
- Éditeur, rôles multiples (une personne peut être acteur ET profil social)
- Détection de doublons locale : sortName proche (Levenshtein) + date de
  naissance identique. Pas de fusion automatique, une suggestion.
- Écran de fusion champ par champ, avec aperçu de ce qui sera transféré
  (crédits, médias, liens, genres, flags)

Rappelle-toi : il n'y a plus de fusion acteur ↔ profil social, c'est la même
entité. Seule la déduplication de vraies personnes en double subsiste.
```

---

# 16 — Collections, genres, liens

**Qui :** Claude Code
**Joindre :** `03-FONCTIONNALITES-NATIF.md`

```
Implémente, §6, §8 et §11 de docs/03 :

Collections : liste, fiche, compteur de titres, couverture + recadrage,
génération d'une couverture en mosaïque depuis les jaquettes des titres.

Genres : CRUD, cibles multiples (titre / personne / signet / collection),
création à la volée depuis un sélecteur, épinglage vers la barre latérale,
jeton de couleur (pas de hex libre).

Liens : liens attachés aux entités, et signets autonomes avec notes et genre.
L'aperçu de lien utilise LPMetadataProvider (framework LinkPresentation) :
titre, favicon, vignette. Timeout de 3 s, gestion de l'échec sans bloquer l'UI.

Accueil : hero avec sélection de titres, sections par genre en ShelfRail,
« rayons » = collections manuelles + rayons par genre.

Ma liste : watchlist + favoris du profil courant, alimenté par les flags.

Fil : liste chronologique depuis ActivityEntry.
```

---

# 17 — Console de gestion

**Qui :** Claude Code
**Joindre :** `03-FONCTIONNALITES-NATIF.md`

```
Implémente Features/LibraryAdmin, §12 de docs/03.

C'est le remplaçant des 10 onglets de « Réglages » de l'app web — une console
de gestion de données, pas des préférences.

- Sur Mac : une fenêtre dédiée (Window scene, ⇧⌘L) avec barre latérale
  d'entités et une Table SwiftUI : colonnes triables, redimensionnables,
  personnalisables (TableColumnCustomization), sélection multiple
- Sur iOS : onglet Bibliothèque → liste par entité → détail
- Édition inline dans la Table
- Édition en masse de la sélection, via .inspector
- Densité de ligne (compacte / standard / confortable) pilotée par token
- Entités couvertes : titres, personnes, collections, genres, médias, signets,
  liens, crédits

L'ancien onglet « users » n'existe plus. L'ancien onglet « relations » devient
un inspecteur de crédits.
```

---

# 18 — Profils & Face ID

**Qui :** Claude Code
**Joindre :** `02-MODELE-SWIFTDATA-CLOUDKIT.md` + `03-FONCTIONNALITES-NATIF.md`

```
Implémente la gestion des profils et le verrouillage, docs/02 §2.2 et §9.

Profils :
- Écran de gestion : créer, renommer, avatar (SF Symbol ou emoji), couleur
  d'accent (jeton), supprimer
- Supprimer un profil efface ses flags, PAS le catalogue
- Rattacher un profil à une bibliothèque (même bibliothèque = modèle Netflix,
  bibliothèque dédiée = isolation)
- Gestion des bibliothèques : créer, renommer, vider, supprimer
- Transfert d'entités entre bibliothèques, avec aperçu des dépendances
  entraînées (transférer un titre entraîne ses médias, ses crédits, ses liens)

Verrouillage (docs/02 §9) :
- AppLock avec LocalAuthentication, en utilisant .deviceOwnerAuthentication
  (et NON ...WithBiometrics) pour avoir le repli automatique sur le code
- Réglage « verrouiller l'app » + délai de grâce (immédiat / 1 / 5 / 15 min)
- Écran de confidentialité dès scenePhase == .inactive
- Profile.requiresBiometry : un profil peut exiger une authentification
- Profile.hidesPrivateContent : un profil ne voit jamais les entités isPrivate
- Contenu privé flouté tant que non déverrouillé, même dans un profil ouvert
- NSFaceIDUsageDescription dans l'Info.plist
- Gérer proprement : biométrie indisponible, verrouillage après échecs,
  aucun code configuré sur l'appareil

Teste que deux profils sur la MÊME bibliothèque ont bien des watchlists
distinctes. C'est le point que je veux voir vérifié.
```

---

# 19 — Import/export CSV

**Qui :** Claude Code
**Joindre :** `03-FONCTIONNALITES-NATIF.md` + `04-ARCHITECTURE-SWIFTUI.md`

```
Implémente Features/Transfer, §10 de docs/03 et §7 de docs/04.

Export :
- CSV par entité, avec sélecteur de champs et aperçu
- UTF-8 AVEC BOM, séparateur ';', échappement RFC 4180
- Archive complète .cineshelfarchive (package : manifest.json + JSON par
  entité + media/), exposée via Transferable et .fileExporter

Import :
- Lecture CSV avec le framework TabularData
- Aperçu en Table éditable, avec statut par ligne
  (nouveau / mise à jour / conflit / erreur) et message d'erreur explicite
- Correction inline + édition en masse de la sélection
- Revalidation après correction
- Résolution des références : un genre ou une personne cité par son nom est
  retrouvé (via GenreRepository.findOrCreate) ou créé
- Application dans l'ImportActor, par lots de 200, avec progression et
  possibilité d'annuler
- Profil de mappage « Movix » préconfiguré, et sauvegarde de mappages perso

Le XLSX est hors périmètre pour l'instant — on le fera plus tard.
```

---

# 20 — Migration des vraies données

**Qui :** Claude Code
**Joindre :** `02-MODELE-SWIFTDATA-CLOUDKIT.md`

```
Implémente l'importeur du bundle produit par l'app web, docs/02 §7 étape 2.

Une commande cachée (⇧⌘⌥I) ouvre un .fileImporter sur le dossier
CineShelfExport/. L'import se fait dans l'ImportActor, par lots, avec
progression et reprise possible.

Ordre exact, docs/02 §7 :
1. Library par défaut + Profile par défaut pointant dessus
2. Genres, dédoublonnés sur nameKey
3. Collections
4. Titles (kind déduit de duration_kind)
5. People — LE POINT CRITIQUE : si un social_profile a un actor_id non nul,
   il alimente la MÊME Person que cet acteur, en ajoutant le rôle .social.
   Sinon, nouvelle Person. C'est ici que la fusion se fait automatiquement.
6. SocialHandle
7. Credits depuis movie_actor (role = .cast, characterName = ancien role)
8. Relations genres
9. MediaAsset (checksum, blurhash, dimensions calculés à l'import),
   puis MediaAttachment (slot = .primary si is_main), puis MediaCrop depuis
   les 21 colonnes de recadrage
10. ResourceLink, SavedLink
11. Flags → TitleFlag / PersonFlag / MediaFlag, rattachés au profil par défaut
12. Réindexation CoreSpotlight

Puis un rapport de vérification qui affiche les 9 assertions de docs/02 §7
étape 3, en vert ou en rouge, avec les écarts.

Écris d'abord un test avec un bundle factice réduit. Ne lance sur les vraies
données qu'une fois le test vert.
```

> Après cette session : utilise l'app native **une semaine** avant d'éteindre l'app web.

---

# 21 — Config CloudKit

**Qui :** toi. Pas de prompt. **Nécessite l'abonnement Apple Developer.**

1. Souscrire au Apple Developer Program
2. Portail développeur → créer le conteneur `iCloud.fr.feltrin.CineShelf`
3. Xcode → Signing & Capabilities → **iCloud** → CloudKit → cocher le conteneur
4. Ajouter **Background Modes → Remote notifications**
5. **Copier le magasin local avant de lancer**, puis passer `FeatureFlags.cloudKitEnabled = true`
6. Lancer, puis dans CloudKit Console : déployer le schéma Development → Production

---

# 22 — Synchronisation

**Qui :** Claude Code
**Joindre :** `04-ARCHITECTURE-SWIFTUI.md` + `02-MODELE-SWIFTDATA-CLOUDKIT.md`

```
CloudKit est maintenant activé. Implémente la couche de synchronisation
visible, docs/04 §5.

- SyncState (upToDate / syncing / offline / needsAccount / failed) observé
  depuis les notifications du coordinateur CloudKit
- SyncStatusBadge dans la barre latérale (Mac) et l'écran Bibliothèque (iOS)
- Les 6 cas d'erreur du tableau de docs/04 §5, chacun avec un message en voix
  d'interface et une action concrète (pas de message technique brut)
- Affichage de l'espace iCloud occupé par CineShelf, dans les réglages
- Passe de fusion des doublons de genres sur nameKey, au démarrage
  (deux appareils hors ligne peuvent créer le même genre)
- Tâche de maintenance : MediaAttachment orphelins, médias non référencés
- Corbeille : liste des entités deletedAt, restauration, purge à 30 jours
```

---

# 23 — Intégrations système

**Qui :** Claude Code
**Joindre :** `03-FONCTIONNALITES-NATIF.md`

```
Implémente les intégrations système, §13 de docs/03 :

- Handoff Mac ↔ iPhone via NSUserActivity (reprendre une fiche en cours)
- Extension de partage « Ajouter à CineShelf » depuis Safari : crée un
  SavedLink, ou pré-remplit un titre si l'URL est reconnue
- App Intents : « Ajouter un film à CineShelf », « Chercher dans CineShelf »,
  « Qu'est-ce que je dois regarder ? » (renvoie la watchlist)
- Widget « Prochain à voir » : un titre de la watchlist, avec sa jaquette
- Statistiques en Swift Charts : répartition par genre, par décennie, par note,
  durée totale visionnée
- Glisser-déposer Finder ↔ app sur macOS
```

---

# 24 — Accessibilité

**Qui :** Claude Code
**Joindre :** `01-DESIGN-SYSTEM-APPLE.md`

```
Audit complet et corrections, contre la partie E de docs/01 :

- VoiceOver sur chaque écran : chaque carte annonce titre + année + état ;
  chaque bouton a un label ; les changements asynchrones (tri, filtre) sont
  annoncés
- Dynamic Type de xSmall à AX5 sur chaque écran : aucune troncature,
  bascule en liste au-delà de .accessibility1
- Contraste vérifié en clair, sombre et contraste élevé
- accessibilityReduceMotion et accessibilityReduceTransparency respectés
- Navigation clavier complète sur macOS, ordre de focus cohérent
- Localisation française complète, aucune chaîne en dur dans le code
- Étendre XCUITest de 5 à 12 parcours

Liste-moi ce que tu as corrigé, et ce que tu n'as pas pu corriger.
```

---

# 25 — Publication

**Qui :** toi, avec Claude Code en appui. Pas de prompt fixe.

1. Icône d'app → **Claude Design**, en joignant `01-DESIGN-SYSTEM-APPLE.md` (partie A) : « Dessine l'icône de CineShelf à partir de la direction artistique Archive de ce document. Format SVG, puis toutes les tailles iOS et macOS. Un seul concept fort, lisible à 16 px. »
2. Archive → **TestFlight**, iOS et macOS
3. Fiche App Store : captures par taille, description, mots-clés
4. Étiquettes de confidentialité
5. Notarisation Mac si distribution hors store
