<!-- ARCHIVE - NE PLUS UTILISER -->
# ARCHIVE - obsolète depuis le 3 août 2026

> **Ce document est obsolète.** Ses 24 sessions, ses prompts à copier et ses
> vérifications sont remplacés par le **tableau d'état de
> [`../PROMPTS.md`](../PROMPTS.md)** : les prompts y vivent, l'avancement s'y suit,
> et les tâches sont désormais découpées en LOGIQUE (L1, L2...) et VUES.
>
> Il décrit en outre un enchaînement « design d'abord » qui n'a plus cours : la
> direction artistique est en refonte, voir
> [`../06-BRIEF-DESIGN.md`](../06-BRIEF-DESIGN.md).
>
> Conservé pour mémoire seulement.

---

# CineShelf — Guide d'exécution

> Le déroulé complet, session par session : qui fait quoi, dans quel ordre, avec quel prompt et quelles pièces jointes.
> 24 sessions réparties en 11 phases. Une session = une tâche cohérente, 2 à 6 heures.

---

# PARTIE I — Avant d'écrire une ligne de code

## I.1 Ce que tu dois faire toi-même

Rien de tout ça n'est délégable.

| # | Tâche | Note |
|---|---|---|
| 1 | Installer **Xcode** (dernière version stable) + un simulateur iPhone | ~15–20 Go. Incontournable : ni CloudKit ni cible macOS dans Swift Playgrounds. |
| 2 | Vérifier les versions cibles réalistes selon **tes** appareils | Si ton iPhone est bloqué en iOS 17, la cible est iOS 17, pas 18. Ça change les API disponibles. |
| 3 | Créer un **nouveau dépôt** `CineShelf-app` | Ne réécris pas par-dessus l'ancien. L'app web doit rester intacte et fonctionnelle jusqu'à la phase 7. |
| 4 | Copier ce dossier dans `docs/` du nouveau dépôt | Les agents doivent pouvoir les lire depuis le dépôt, pas seulement en pièce jointe. |
| 5 | Écrire `CLAUDE.md` à la racine | Voir I.3. C'est l'artefact le plus rentable du projet. |
| 6 | Installer `swiftlint` et `swift-format` | `brew install swiftlint swift-format` |
| 7 | Décider maintenant : **quand** tu prends l'abonnement Apple Developer | Recommandation : à la fin de la phase 7, pas avant. Tu auras 6 mois de développement local devant toi. |

## I.2 Structure du dépôt

```
CineShelf-app/
├── CLAUDE.md                    ← les règles, lues à chaque session
├── docs/
│   ├── 00-AUDIT.md
│   ├── 01-DESIGN-SYSTEM-APPLE.md
│   ├── 02-MODELE-SWIFTDATA-CLOUDKIT.md
│   ├── 03-FONCTIONNALITES-NATIF.md      ← la liste de contrôle vivante
│   ├── 04-ARCHITECTURE-SWIFTUI.md
│   ├── 05-ROADMAP-NATIF.md
│   ├── GUIDE-EXECUTION.md               ← ce fichier
│   └── journal.md                       ← à créer, une ligne par session
├── CineShelf.xcodeproj
├── App/
├── Packages/
├── Tests/
└── data/                        ← le dump de l'app web (phase 0), gitignoré
```

## I.3 `CLAUDE.md` — à écrire en premier

Colle ça tel quel à la racine. Claude Code le lit automatiquement à chaque session ; c'est ce qui l'empêche de dériver.

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
- `docs/05-ROADMAP-NATIF.md` — l'ordre des lots

## Règles non négociables — modèle
- Toute propriété `@Model` a une valeur par défaut **ou** est optionnelle.
- Aucun `@Attribute(.unique)` — CloudKit l'interdit. Dédoublonnage applicatif.
- Toutes les relations sont optionnelles, avec `inverse:` déclaré d'un seul côté.
- Pas de règle de suppression `.deny`.
- Les enums sont persistées en `rawValue: String`, exposées en propriété calculée.
- `sortName` et `searchText` sont maintenus par `refreshDerived()`, appelé à **chaque** écriture.
- `CloudKitConformanceTests` doit passer avant tout commit.

## Règles non négociables — design
- Aucune couleur littérale hors du package `DesignSystem`.
- Aucune taille de police fixe : `Font.custom(_:size:relativeTo:)` ou `Font.<textStyle>`.
- `.clipShape(.rect(cornerRadius:style: .continuous))`, jamais `.cornerRadius()`.
- Matériaux (`.regularMaterial`) pour les surfaces superposées, pas d'ombres maison.
- SF Symbols uniquement, jamais d'image d'icône.
- Tout élément interactif ≥ 44 pt et accessible au clavier sur macOS.

## Règles non négociables — code
- Swift 6, concurrence stricte activée.
- Pas de force unwrap hors des tests.
- Aucune logique métier dans une `View` : repository ou service.
- Un dossier `Features/X` n'importe jamais `Features/Y`.
- `CineShelfCore` n'importe jamais SwiftUI.

## Commandes
```bash
# Build
xcodebuild -scheme CineShelf -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme CineShelf -destination 'platform=macOS' build
# Tests
xcodebuild test -scheme CineShelf -destination 'platform=iOS Simulator,name=iPhone 16'
# Qualité
swiftlint --strict
```

## Déroulé attendu de chaque tâche
1. Lire la section pertinente des docs.
2. **Proposer un plan avant d'écrire du code.** Attendre ma validation.
3. Écrire, compiler, corriger jusqu'à build vert sur iOS **et** macOS.
4. Lancer les tests.
5. Cocher les fonctionnalités traitées dans `docs/03-FONCTIONNALITES-NATIF.md`.
6. Ajouter une ligne à `docs/journal.md`.
7. Un commit par tâche, message conventionnel (`feat:`, `fix:`, `refactor:`…).

## Ce que je ne veux pas
- Des dépendances externes sans me demander. Objectif : zéro paquet tiers, sauf
  éventuellement ZIPFoundation en phase 6.
- Du code « au cas où ». On implémente ce qui est dans le contrat, rien de plus.
- Des commentaires qui paraphrasent le code.
- Du texte d'interface en anglais : l'app est en français.
````

## I.4 Comment travailler avec Claude Code

**Où** : dans un terminal, à la racine du dépôt. Xcode ouvert à côté pour le rendu visuel et l'exécution sur appareil.

**Sept habitudes qui changent tout** :

1. **Une session = une tâche.** Ne mélange pas « fais le modèle » et « fais l'UI ». Le contexte se dilue et la qualité chute.
2. **Exige un plan avant le code.** « Propose-moi ton plan, ne code pas encore. » Tu corriges les malentendus pour 200 tokens au lieu de 20 000.
3. **Laisse-le compiler.** Swift et SwiftData sont moins présents dans les données d'entraînement que React : il **fera** des erreurs d'API. La boucle qui sauve, c'est `xcodebuild` → erreur → correction. Dis-le explicitement : « compile et corrige jusqu'au vert avant de me montrer quoi que ce soit ».
4. **Commit à chaque test vert.** Pas à la fin de la session.
5. **Relis.** Tu apprends Swift ; le but n'est pas d'avoir 18 000 lignes que tu ne comprends pas. Demande-lui d'expliquer ce qu'il vient d'écrire quand quelque chose t'échappe.
6. **Ramène-le aux docs.** S'il improvise, « relis `docs/02-…` §3.3 et corrige » est plus efficace que d'expliquer à nouveau.
7. **Tiens `docs/journal.md`.** Une ligne par session : ce qui est fait, ce qui bloque, ce qui est décidé. C'est ce que tu lui donneras au début de la session suivante.

## I.5 Comment travailler avec Claude Design

Claude Design produit du visuel et itère dessus. Le circuit :

1. Tu donnes le brief + `01-DESIGN-SYSTEM-APPLE.md`.
2. Il produit le code SwiftUI du composant + une vue de démonstration.
3. Tu colles ça dans Xcode, tu lances la preview, **tu fais une capture d'écran**.
4. Tu lui renvoies la capture avec ce qui ne va pas.
5. Deux ou trois allers-retours par composant, pas plus.

Une capture vaut mieux que trois paragraphes de description. Et teste systématiquement en **clair et sombre**, à taille de texte normale **et** en `AX3`.

### Le passage de relais vers Claude Code

Les deux agents ne partagent rien : ce sont deux conversations séparées. **Le dépôt Git est le seul point de passage.**

```
Claude Design  ──▶  tu colles le code dans le dépôt  ──▶  Claude Code le lit
   (S2.1, S2.2)              (S2.2 bis)                    (S2.3 et suite)
```

Donc : tu joins `01-DESIGN-SYSTEM-APPLE.md` à **Design** ; tu ne joins jamais rien de Design à **Code** — il lit le dépôt. La session S2.2 bis ci-dessous est cette étape de transfert, et elle est facile à oublier.

Si Claude Code a besoin d'un composant qui n'existe pas (ça arrivera vers S3.2 ou S6.1) : pour quelque chose de simple, laisse-le l'écrire en respectant les tokens ; pour quelque chose de visuellement structurant, retourne voir Design avec une capture.

## I.6 Règles de session

| Règle | Pourquoi |
|---|---|
| Commence chaque session en collant les 5 dernières lignes de `docs/journal.md` | Reprend le fil sans relire tout le dépôt |
| Termine chaque session par un commit et une ligne de journal | Sinon tu perds le fil en trois jours |
| Si une session dépasse 4 h, arrête-toi et coupe la tâche en deux | La qualité chute nettement au-delà |
| Ne passe jamais à la phase suivante sans le critère de sortie | C'est ce qui évite de découvrir un problème 3 semaines trop tard |

---

# PARTIE II — Les 24 sessions

---

## PHASE 0 — Filet de sécurité

> **Dans l'ancien dépôt (app web).** Tant que ce n'est pas fait, ne touche pas à Swift.

### S0.1 — Enregistrer le comportement actuel

| | |
|---|---|
| **Agent** | Claude Code, dans le dépôt **CineShelf** (web) |
| **Pièces jointes** | `03-FONCTIONNALITES-NATIF.md` |
| **Durée** | 3–4 h |

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

**Vérification** : `npm run test:e2e` passe 5/5.
**Commit** : `test: parcours e2e de référence avant refonte native`

---

### S0.2 — Dump complet des données

| | |
|---|---|
| **Agent** | Claude Code, dépôt web |
| **Pièces jointes** | `02-MODELE-SWIFTDATA-CLOUDKIT.md` (pour la section 7, format du bundle) |
| **Durée** | 3–4 h |

```
Écris `server/scripts/export-native-bundle.mjs`. Il doit produire un dossier
autonome contenant TOUTES les données de l'app, destiné à être importé dans une
future app native.

Structure exacte attendue — voir docs/02-MODELE-SWIFTDATA-CLOUDKIT.md §7 étape 1 :

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

**Vérification** : lance le script pour de vrai. Compare les compteurs de `manifest.json` avec `SELECT COUNT(*)` sur chaque table. Ouvre 5 images au hasard.

**⚠️ Puis, à la main** : copie `CineShelfExport/` sur un **disque externe** et dans un cloud. C'est ton unique filet pour les 5 prochains mois.

---

### S0.3 — Captures de référence

| | |
|---|---|
| **Agent** | toi, seul |
| **Durée** | 1 h |

Capture chaque écran de l'app web : accueil, liste films, détail film, acteurs, détail acteur, collections, galerie, lightbox, recherche, signets, profil, compte, les 10 onglets de réglages, import, export, fusion. Range-les dans `docs/reference-web/`.

Ce n'est pas pour copier le design — c'est pour ne rien oublier quand tu diras « il manque un truc mais je ne sais plus quoi ».

---

## PHASE 1 — Fondations

> **Nouveau dépôt.** À partir d'ici, tout est en Swift.

### S1.1 — Créer le projet (toi, à la main)

| | |
|---|---|
| **Agent** | toi, dans Xcode |
| **Durée** | 1 h |

Xcode ne se pilote pas bien depuis un terminal : crée le squelette toi-même.

1. Xcode → New Project → **Multiplatform → App**
2. Nom `CineShelf`, organisation `fr.feltrin`, interface SwiftUI, langage Swift, **Storage: None** (on branchera SwiftData à la main)
3. Cibles minimum : selon tes appareils (voir I.1 #2)
4. Ajoute trois packages locaux : File → New → Package → `DesignSystem`, `CineShelfCore`, `MediaKit`, puis lie-les à la cible app
5. `git init`, premier commit, pousse
6. Copie `docs/` et `CLAUDE.md` à la racine

**Vérification** : l'app vide se lance sur simulateur iPhone **et** sur macOS.

---

### S1.2 — Le modèle de données

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `02-MODELE-SWIFTDATA-CLOUDKIT.md`, `04-ARCHITECTURE-SWIFTUI.md` |
| **Durée** | 4–6 h |

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

**Vérification** : `xcodebuild test` vert, `CloudKitConformanceTests` inclus.
**Piège fréquent** : il va peut-être écrire `var titles: [Title] = []` au lieu de `[Title]?`. Le test de conformité doit l'attraper — si ce n'est pas le cas, le test est mal écrit.

---

### S1.3 — Repositories & outillage

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `04-ARCHITECTURE-SWIFTUI.md` |
| **Durée** | 3–4 h |

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
- docs/journal.md avec les entrées des sessions précédentes

Tests unitaires sur chaque repository, avec un ModelContainer en mémoire.
```

**Critère de sortie de la phase 1** : tests verts, CI verte, tu peux insérer un catalogue factice et le relire.

---

## PHASE 2 — Design system

### S2.1 — Tokens

| | |
|---|---|
| **Agent** | **Claude Design** |
| **Pièces jointes** | `01-DESIGN-SYSTEM-APPLE.md` |
| **Durée** | 3–4 h |

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

### S2.2 — Composants primitifs

| | |
|---|---|
| **Agent** | **Claude Design** (même conversation que S2.1) |
| **Durée** | 4–6 h |

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

**Ton travail** : colle dans Xcode, lance la preview, capture, renvoie les captures avec tes remarques. Compte 2–3 allers-retours.

---

### S2.2 bis — Transférer le design dans le dépôt

| | |
|---|---|
| **Agent** | toi, puis Claude Code |
| **Durée** | 1–2 h |

**À la main** :
1. Coller les fichiers Swift de Claude Design dans `Packages/DesignSystem/Sources/DesignSystem/`
2. Coller la liste des Color Sets dans `docs/couleurs.md` — ne les crée surtout pas un par un dans Xcode (~80 jeux × 4 apparences = 300 clics)
3. Télécharger Archivo Variable dans `Resources/Fonts/`

**Puis à Claude Code** :

```
Claude Design a produit le package DesignSystem. J'ai collé ses fichiers Swift
dans Packages/DesignSystem/Sources/DesignSystem/ et la liste des couleurs dans
docs/couleurs.md.

Génère l'arborescence
Packages/DesignSystem/Sources/DesignSystem/Resources/Colors.xcassets à partir
de docs/couleurs.md :

- un dossier `<nom>.colorset` par jeu, avec son Contents.json
- 4 apparences par jeu : Any, Dark, Any + High Contrast, Dark + High Contrast
- espace colorimétrique display-p3, composantes en float 0–1
- respecte la hiérarchie de dossiers de la liste, avec les Contents.json
  intermédiaires et le Contents.json racine

Déclare la police Archivo dans le Package.swift et dans le Info.plist de la
cible app, et vérifie que le nom PostScript utilisé dans Typography.swift
correspond au fichier.

Compile le package pour iOS et macOS et corrige jusqu'au vert.
```

**Commit** : `feat(design): design system initial`

---

### S2.3 — Intégration

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | le code produit en S2.1/S2.2 (via le dépôt) |
| **Durée** | 2–3 h |

```
Claude Design a produit le package DesignSystem (voir Packages/DesignSystem).
Intègre-le proprement :

- Vérifie que ça compile sur iOS et macOS
- Active la règle SwiftLint interdisant les couleurs littérales hors du module
  et corrige les violations
- Ajoute des tests de snapshot sur PosterCard et ShelfRail : clair/sombre ×
  compact/medium/large × Dynamic Type normale/AX3
- Embarque la police Archivo Variable (fichier woff2/ttf dans Resources,
  déclaration dans le Info.plist de la cible, vérifie que le nom PostScript
  utilisé dans Typo correspond bien)
- Ajoute DesignSystemCatalog comme cible de développement
```

**Critère de sortie de la phase 2** : le catalogue de composants est lisible et correct de `xSmall` à `AX5`, en clair et en sombre, sur iPhone et sur Mac. Aucune couleur littérale hors du module.

---

## PHASE 3 — Navigation & catalogue

### S3.1 — Coquille et navigation adaptative

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `01-DESIGN-SYSTEM-APPLE.md` (partie C), `04-ARCHITECTURE-SWIFTUI.md` |
| **Durée** | 4–5 h |

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

### S3.2 — Liste et détail des titres

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `03-FONCTIONNALITES-NATIF.md` (§4) |
| **Durée** | 5–6 h |

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

### S3.3 — Recherche

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `02-MODELE-SWIFTDATA-CLOUDKIT.md` (§5) |
| **Durée** | 2–3 h |

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

**Critère de sortie de la phase 3** : le parcours 1 des tests passe sur iPhone, iPad et Mac.

---

## PHASE 4 — Médias

### S4.1 — Pipeline et cache

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `04-ARCHITECTURE-SWIFTUI.md` (§4) |
| **Durée** | 5–6 h |

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
- Brancher MediaThumbnail dessus (le stub de S2.2)
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

### S4.2 — Galerie

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `03-FONCTIONNALITES-NATIF.md` (§7) |
| **Durée** | 4–5 h |

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

**Critère de sortie de la phase 4** : le parcours 2 passe ; les chiffres de performance sont mesurés sur un **appareil réel**, pas sur le simulateur.

---

## PHASE 5 — Reste du catalogue

### S5.1 — Personnes

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `03-FONCTIONNALITES-NATIF.md` (§5) |
| **Durée** | 4–5 h |

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

### S5.2 — Collections, genres, liens

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `03-FONCTIONNALITES-NATIF.md` (§6, §8, §11) |
| **Durée** | 4–5 h |

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

## PHASE 6 — Bibliothèque, profils, transfert

### S6.1 — Console de gestion

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `03-FONCTIONNALITES-NATIF.md` (§12) |
| **Durée** | 5–6 h |

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

### S6.2 — Profils et verrouillage

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `02-MODELE-SWIFTDATA-CLOUDKIT.md` (§2.2, §9), `03-FONCTIONNALITES-NATIF.md` (§1 bis, §1 ter) |
| **Durée** | 4–5 h |

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

### S6.3 — Import / export CSV

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `03-FONCTIONNALITES-NATIF.md` (§10), `04-ARCHITECTURE-SWIFTUI.md` (§7) |
| **Durée** | 5–6 h |

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

**Critère de sortie de la phase 6** : les parcours 3, 4 et 5 passent.

---

## PHASE 7 — Migration des données réelles

### S7.1 — Importeur du bundle web

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `02-MODELE-SWIFTDATA-CLOUDKIT.md` (§7) |
| **Durée** | 5–7 h |

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

**Vérification, par toi** : lance sur le vrai dump. Les 9 assertions doivent être vertes. Puis compare 50 titres au hasard avec les captures de S0.3.

**🎯 Jalon** : à partir d'ici, **l'app web peut être éteinte.** Utilise l'app native une semaine complète avant de passer à la suite — c'est le meilleur test qui existe.

---

## PHASE 8 — CloudKit

> À partir d'ici, l'abonnement Apple Developer est nécessaire.

### S8.1 — Configuration (toi, à la main)

| | |
|---|---|
| **Agent** | toi |
| **Durée** | 2 h |

1. Souscrire au **Apple Developer Program**
2. Sur le portail développeur : créer le conteneur iCloud `iCloud.fr.feltrin.CineShelf`
3. Dans Xcode : Signing & Capabilities → **iCloud** → CloudKit → cocher le conteneur
4. Ajouter la capacité **Background Modes → Remote notifications**
5. Passer `FeatureFlags.cloudKitEnabled = true`
6. Lancer, laisser le schéma se créer, puis dans le **CloudKit Console** : déployer le schéma de Development vers Production

⚠️ **Fais d'abord une copie du magasin local**, avant le premier lancement avec CloudKit activé.

---

### S8.2 — Synchronisation

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `04-ARCHITECTURE-SWIFTUI.md` (§5), `02-MODELE-SWIFTDATA-CLOUDKIT.md` (§8) |
| **Durée** | 4–5 h |

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

**Vérification, par toi** : deux appareils. Modifie sur le Mac, vérifie l'iPhone en moins d'une minute. Puis mets les deux en mode avion, modifie les deux, reconnecte, vérifie la reconvergence.

---

## PHASE 9 — Finitions Apple

### S9.1 — Intégrations système

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `03-FONCTIONNALITES-NATIF.md` (§13) |
| **Durée** | 4–5 h |

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

### S9.2 — Accessibilité et finitions

| | |
|---|---|
| **Agent** | Claude Code |
| **Pièces jointes** | `01-DESIGN-SYSTEM-APPLE.md` (partie E) |
| **Durée** | 4–5 h |

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

## PHASE 10 — Publication

### S10.1 — Mise en ligne

| | |
|---|---|
| **Agent** | toi, avec Claude Code en appui |
| **Durée** | 3–5 h |

1. Icône d'app → **Claude Design**, en joignant `01-DESIGN-SYSTEM-APPLE.md` : « Dessine l'icône de CineShelf à partir de la direction artistique Archive de ce document. SVG, puis toutes les tailles iOS et macOS. Un seul concept fort, lisible à 16 px. »
2. Archive et envoi sur **TestFlight**, iOS et macOS
3. Fiche App Store : captures par taille d'écran, description, mots-clés
4. Étiquettes de confidentialité : simple, les données ne quittent pas iCloud
5. Notarisation de l'app Mac si distribution hors store
6. Documenter dans le README comment l'utilisateur exporte son archive

---

# PARTIE III — Récapitulatif

| Phase | Sessions | Agent principal | Durée |
|---|---|---|---|
| 0 — Filet | S0.1 · S0.2 · S0.3 | Code (dépôt web) + toi | 7–9 h |
| 1 — Fondations | S1.1 · S1.2 · S1.3 | toi + Code | 8–11 h |
| 2 — Design system | S2.1 · S2.2 · **S2.2 bis** · S2.3 | **Design** + Code | 10–15 h |
| 3 — Catalogue | S3.1 · S3.2 · S3.3 | Code | 11–14 h |
| 4 — Médias | S4.1 · S4.2 | Code | 9–11 h |
| 5 — Reste du catalogue | S5.1 · S5.2 | Code | 8–10 h |
| 6 — Gestion & profils | S6.1 · S6.2 · S6.3 | Code | 14–17 h |
| 7 — Migration | S7.1 | Code | 5–7 h |
| 8 — CloudKit | S8.1 · S8.2 | toi + Code | 6–7 h |
| 9 — Finitions | S9.1 · S9.2 | Code | 8–10 h |
| 10 — Publication | S10.1 | toi | 3–5 h |
| | **25 sessions** | | **~89–116 h** |

À 6–8 h par semaine en parallèle de l'alternance : **4 à 6 mois**. Le facteur limitant sera l'apprentissage de Swift, pas le volume de code.

---

# PARTIE IV — Quand ça dérape

| Symptôme | Réaction |
|---|---|
| Claude Code invente une API SwiftData qui n'existe pas | « Compile et corrige jusqu'au vert avant de me montrer quoi que ce soit. » C'est le réflexe le plus important : Swift est moins présent dans les données d'entraînement que React. |
| Il s'écarte du modèle du document | « Relis `docs/02-…` §3.3 et corrige. » Plutôt que de réexpliquer. |
| Le test de conformité CloudKit casse | Ne le contourne jamais. C'est le seul garde-fou entre toi et une migration douloureuse après publication. |
| Une session s'enlise depuis 2 h | Arrête, commit ce qui marche, coupe la tâche en deux, recommence à neuf. |
| Une couleur en dur apparaît dans une vue | SwiftLint doit la refuser. Si elle est passée, la règle est mal écrite : corrige la règle, pas seulement la vue. |
| Tu ne comprends pas le code produit | Demande une explication avant de commit. Tu es en train d'apprendre Swift ; du code que tu ne comprends pas est de la dette. |
| Tu doutes qu'une fonctionnalité v1 existe encore | `docs/03` est le contrat. Si la case n'est pas cochée, elle n'existe pas. |
| Tu perds le fil entre deux sessions | `docs/journal.md`. C'est pour ça qu'il existe. |

---

# PARTIE V — Les 5 règles à ne jamais enfreindre

1. **Le dump de la phase 0 est archivé hors du Mac** avant la moindre ligne de Swift.
2. **`CloudKitConformanceTests` passe** avant chaque commit, dès la session S1.2.
3. **Aucune couleur littérale, aucune taille de police fixe** hors du package DesignSystem.
4. **L'app web reste allumée** jusqu'à ce que S7.1 soit vert et que tu aies utilisé la native une semaine.
5. **Une case de `docs/03` ne se coche que quand la fonctionnalité marche**, pas quand le code est écrit.
