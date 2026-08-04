# CineShelf

Catalogue personnel de films, séries, personnes, collections et images.
App SwiftUI multiplateforme (iOS · iPadOS · macOS), réécriture native d'une app
web React + Express retirée.

**Aucun backend, aucune dépendance externe.** SwiftData + CloudKit privé.

| | |
|---|---|
| Cibles | iOS 18.0+ · macOS 15.0+ (une seule cible multiplateforme) |
| Langage | Swift 6, concurrence stricte (`complete`) |
| Interface | français |
| Bundle ID | `fr.feltrin.CineShelf` |

---

## Démarrer

```bash
brew install xcodegen swiftlint
xcodegen generate
open CineShelf.xcodeproj
```

Ce sont les deux seuls outils à installer. `swift-format` n'est **pas** dans le
`PATH` et n'a pas besoin de l'être : il est livré avec la toolchain Xcode et
s'appelle par `xcrun swift-format`.

Rien d'autre n'est requis : aucune dépendance de paquet à résoudre, `Package.resolved`
est gitignoré parce qu'il n'y a rien à résoudre.

### Pourquoi `xcodegen generate` à chaque fois ?

`*.xcodeproj` est **gitignoré**. Le projet est intégralement décrit par
`project.yml` : c'est lui la source de vérité. Ça évite les conflits de merge
dans le `pbxproj`, qui sont pénibles à résoudre et faciles à rater.

Régénère après un `git clone`, après un `git pull` qui touche `project.yml`, et
après tout ajout de fichier hors d'Xcode :

```bash
xcodegen generate && open CineShelf.xcodeproj
```

### Reprise depuis un clone, sur une machine neuve

La séquence complète, de zéro à un build vert. Rien d'autre n'est nécessaire : tout
ce qui compte est dans Git.

```bash
# 1. Prérequis système
xcode-select --install                     # si Xcode n'est pas déjà là
brew install xcodegen swiftlint

# 2. Le dépôt
git clone https://github.com/FELTRINCyril/CineShelf.git
cd CineShelf

# 3. Le projet Xcode, qui n'est pas versionné
xcodegen generate

# 4. Le runtime du simulateur, que Xcode 26 n'embarque plus
xcodebuild -downloadPlatform iOS

# 5. Vérifier que tout est vert
xcodebuild -scheme CineShelf -destination 'platform=macOS' build
xcodebuild -scheme CineShelf -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -scheme CineShelf -destination 'platform=macOS'
for p in CineShelfCore DesignSystem MediaKit; do (cd "Packages/$p" && swift test); done
swiftlint --strict
```

Lancer Xcode une première fois avant tout, pour qu'il installe ses composants.

**Ce qui n'est pas dans Git**, et n'a pas à l'être :

| Absent | Comment le retrouver |
|---|---|
| `CineShelf.xcodeproj` | `xcodegen generate` — `project.yml` est la source de vérité |
| `.build/`, `DerivedData/` | reconstruits au premier build |
| `Package.resolved` | rien à résoudre : zéro dépendance externe |
| `.claude/settings.local.json` | autorisations locales de Claude Code, redemandées à l'usage |

Ce qui **est** versionné et qu'on pourrait croire absent : les quatre fichiers
`Archivo*.ttf` et leur licence, `colors.tokens.json`, et l'intégralité de
`Colors.xcassets` généré. Aucun asset à retélécharger.

### Prérequis simulateur iOS

Xcode 26 n'embarque plus les runtimes de simulateur. Si `xcodebuild` répond
« iOS … is not installed » :

```bash
xcodebuild -downloadPlatform iOS
```

---

## Deux arbres de travail — la chaîne `L` et la chaîne `I`

Les tâches de **logique** (`L…`, dans `Packages/CineShelfCore`, `Packages/MediaKit`,
`App/`) et les tâches d'**intégration du design** (`I…`, dans
`Packages/DesignSystem`, `Catalog/`) touchent des paquets disjoints. Elles peuvent donc
avancer dans deux arbres de travail Git parallèles, sans se marcher dessus.

```bash
# Une seule fois — depuis l'arbre principal
git worktree add ../CineShelf-design -b chain-i

# Puis, dans le nouvel arbre
cd ../CineShelf-design
xcodegen generate          # chaque arbre a son propre .xcodeproj, qui n'est pas versionné
```

| Arbre | Branche | Chaîne | Ce qu'on y ouvre |
|---|---|---|---|
| `CineShelf/` | `main` | `L…` — logique | le schéma `CineShelf` |
| `CineShelf-design/` | `chain-i` | `I…` — composants | le schéma `DesignSystemCatalog` |

### Qui possède quoi

Aucun de ces fichiers ne doit être touché par l'autre chaîne. C'est la règle qui rend
les deux arbres viables.

| Chaîne `L` seule | Chaîne `I` seule |
|---|---|
| `Packages/CineShelfCore/` | `Packages/DesignSystem/` |
| `Packages/MediaKit/` | `Catalog/` |
| `App/` (dont le banc d'essai, qu'on ne polit pas) | `scripts/generate-colors.py` |
| `Tests/` | `docs/design/` |
| `docs/02`, `docs/04` | `docs/06` |

### Les six fichiers que les deux chaînes se disputeraient

Par ordre de nuisance décroissante, avec le remède retenu :

| Fichier | Le conflit | Remède |
|---|---|---|
| **`docs/journal.md`** | Les deux **ajoutent en fin de fichier**, au même endroit, à chaque session. C'est un conflit garanti, à chaque merge, et le plus pénible parce qu'il porte sur de la prose | La chaîne `I` écrit dans **`docs/journal-design.md`**, jamais dans `docs/journal.md`. L'ordre chronologique réel se relit par `git log`, qui ne se trompe pas |
| **`docs/PROMPTS.md`** — tableau d'état | Les deux cochent une ligne avec un hash | Le tableau d'état de la chaîne `I` vit dans **sa propre section** (« Tâches INTÉGRATION DU DESIGN »), à des centaines de lignes du chemin critique. Deux zones du fichier ⇒ Git fusionne sans intervention. La chaîne `I` ne touche pas au récapitulatif du haut |
| **`docs/PROMPTS.md`** — « Écarts connus » | Les deux ajoutent une ligne au même tableau | La chaîne `I` ajoute ses écarts **en fin de tableau**, la chaîne `L` aussi : c'est le seul point où un conflit reste probable. Il se résout en gardant les deux lignes — jamais en en choisissant une |
| **`.swiftlint.yml`** | La chaîne `I` retire des entrées de la liste d'exclusions de `no_legacy_design_system` à mesure que les composants neufs remplacent les anciens ; la chaîne `L` ajoute des règles | La chaîne `I` ne touche **que** le bloc d'exclusions, la chaîne `L` **que** les règles. Blocs distincts, pas de recouvrement |
| **`project.yml`** | Les sources sont déclarées en **glob** (`- path: App`), donc ajouter un fichier ne touche pas ce fichier. Il n'est disputé que si une chaîne ajoute une **cible** ou un **schéma** | Rare. Quand ça arrive : le faire dans l'arbre principal, puis rebaser l'autre avant de continuer |
| **`.github/workflows/ci.yml`**, `docs/03` | Partagés, rarement modifiés | Prévenir avant d'y toucher depuis `chain-i` |

### Deux pièges hors de Git

1. **Le glob `CineShelf-*` de `DerivedData` devient ambigu.** Chaque arbre a son propre
   dossier `DerivedData/CineShelf-<hash>` — le hash dérive du chemin. Dès le premier
   build dans le second arbre, ils sont deux, et la commande de la section
   « Commandes » ouvre le mauvais catalogue, ou les deux. Depuis
   `CineShelf-design/`, viser explicitement :

   ```bash
   xcodebuild -scheme DesignSystemCatalog -destination 'platform=macOS' \
     -derivedDataPath .build/dd build
   open .build/dd/Build/Products/Debug/DesignSystemCatalog.app
   ```

2. **Le magasin SwiftData est commun aux deux arbres.** Le bundle ID est le même, donc
   `~/Library/Containers/fr.feltrin.CineShelf` est partagé : lancer l'app depuis les
   deux arbres écrit dans la **même** base. Sans effet aujourd'hui — la chaîne `I`
   lance le catalogue, qui n'ouvre aucun magasin — mais à savoir avant de lancer l'app
   depuis `chain-i` pour « juste voir ».

### Un seul sens de rebase

`chain-i` se rebase sur `main`, **jamais l'inverse**. `main` porte le chemin critique,
c'est la branche de référence.

```bash
# Dans CineShelf-design/, avant de reprendre le travail et avant tout merge
git fetch origin && git rebase origin/main
```

Une fois un lot `I` terminé et rebasé, il rentre en fast-forward sur `main`. Ne jamais
laisser `chain-i` diverger sur plusieurs lots : rebaser à chaque lot garde les conflits
à la taille d'un lot.

> **La vérification des deux sens de `git log` reste obligatoire dans chaque arbre.**
> Un arbre de travail en retard se travaille aussi silencieusement qu'un clone en
> retard — c'est la même heure perdue, deux fois.

---

## Structure

```
App/                  cible applicative — vues, navigation, App Intents
  Features/           un dossier par section ; aucun ne dépend d'un autre
  Navigation/         RootView, dispositions compacte et large
  Resources/          Info.plist, entitlements, Assets.xcassets
Packages/
  CineShelfCore/      modèles, repositories, services — n'importe jamais SwiftUI
  DesignSystem/       tokens et composants — seul endroit où une couleur est littérale
  MediaKit/           pipeline médias — dépend de CineShelfCore
Catalog/              app de démonstration du design system (schéma dédié)
Tests/
  CineShelfTests/     tests de logique, sans app hôte (dont CloudKitConformanceTests)
  CineShelfUITests/   tests d'interface (XCUITest) — simulateur iOS uniquement
scripts/              generate-colors.py — génère Colors.xcassets depuis colors.tokens.json
docs/                 spécifications, plan, journal — voir docs/README.md
  _archive/           documents remplacés, jamais une référence pour du travail neuf
```

Les tests unitaires des packages vivent dans les packages eux-mêmes
(`Packages/<Nom>/Tests/`), là où SwiftPM les attend.

### Trois schémas

| Schéma | Contenu | Destinations |
|---|---|---|
| `CineShelf` | l'app + `CineShelfTests` | iOS **et** macOS |
| `DesignSystemCatalog` | le catalogue du design system + les tests d'assets et de rendu | iOS et macOS |
| `CineShelfUITests` | l'app + les tests d'interface | simulateur iOS |

Le catalogue est **le seul endroit où les tests de couleurs et de rendu tournent
contre un `Colors.xcassets` compilé** : `swift test` ne lance pas `actool`, donc un
jeu de couleurs manquant y passerait inaperçu.

Les tests UI sont dans un schéma à part parce que, sur macOS, XCUITest réclame
l'autorisation d'accessibilité — impossible à accorder depuis le terminal, et
la seule présence de la cible dans le schéma principal faisait échouer
`xcodebuild test` sur Mac.

---

## Commandes

```bash
# Build
xcodebuild -scheme CineShelf -destination 'platform=macOS' build
xcodebuild -scheme CineShelf -destination 'platform=iOS Simulator,name=iPhone 17' build

# Tests unitaires des packages
for p in CineShelfCore DesignSystem MediaKit; do (cd "Packages/$p" && swift test); done

# Tests de logique
xcodebuild test -scheme CineShelf -destination 'platform=macOS'

# Tests d'interface
xcodebuild test -scheme CineShelfUITests -destination 'platform=iOS Simulator,name=iPhone 17'

# Catalogue du design system — build, tests d'assets et de rendu
xcodebuild -scheme DesignSystemCatalog -destination 'platform=macOS' build
xcodebuild test -scheme DesignSystemCatalog -destination 'platform=macOS'
open ~/Library/Developer/Xcode/DerivedData/CineShelf-*/Build/Products/Debug/DesignSystemCatalog.app

# Couleurs : régénère le .xcassets depuis la source unique
python3 scripts/generate-colors.py   # après toute modif de colors.tokens.json

# Qualité
swiftlint --strict
xcrun swift-format lint --recursive --strict App Catalog Packages Tests
xcrun swift-format format --in-place --recursive App Catalog Packages Tests
```

### Règles de lint maison

Deux règles personnalisées dans `.swiftlint.yml`, toutes deux en **erreur** :

- `no_literal_color` — interdit `Color(red:`, `Color(hex:`, `UIColor(`, `NSColor(`
  et les littéraux hexadécimaux, **partout sauf** dans `Packages/DesignSystem/`.
- `no_fixed_font_size` — interdit `.font(.system(size:` sans `relativeTo:`,
  pour que le texte suive Dynamic Type.

`force_unwrapping` est en erreur également.

---

## Intégration continue

`.github/workflows/ci.yml` — lint, tests des packages, build iOS + macOS, tests UI.

⚠️ **Les runners macOS de GitHub facturent les minutes gratuites au tarif ×10.**
Le workflow ne se déclenche donc que sur les **pull requests** et sur **main**,
jamais sur un push de branche de travail. Utilise `workflow_dispatch` pour un
lancement manuel.

---

## Activer CloudKit

Rien n'est actif aujourd'hui : le projet compile et tourne **sans** abonnement
Apple Developer. Les clés CloudKit attendent, commentées, dans
`App/Resources/CineShelf-CloudKit.entitlements`, qui n'est référencé par aucune
cible.

Le jour où tu prends l'abonnement, dans cet ordre :

1. **Équipe de développement** — renseigne `DEVELOPMENT_TEAM` dans `project.yml`
   (bloc `settings.base`), supprime les deux lignes
   `CODE_SIGN_IDENTITY[sdk=macosx*]: "-"` de la cible `CineShelf`, puis
   `xcodegen generate`.
2. **Conteneur iCloud** — crée `iCloud.fr.feltrin.CineShelf` sur
   [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list/cloudContainer),
   et active la capacité CloudKit sur l'App ID `fr.feltrin.CineShelf`.
3. **Entitlements** — copie le bloc commenté de
   `CineShelf-CloudKit.entitlements` dans `CineShelf.entitlements`, en retirant
   la clé `fr.feltrin.CineShelf.cloudkit-placeholder`. Ajoute aussi
   `com.apple.security.network.client` si tu ne l'as pas déjà (c'est le cas).
4. **Bascule applicative** — passe `FeatureFlags.cloudKitEnabled` à `true` dans
   `Packages/CineShelfCore/Sources/CineShelfCore/FeatureFlags.swift`.

C'est le prompt 21 de `docs/PROMPTS.md`.

---

## Documentation

Tout est dans `docs/` — voir `docs/README.md` pour l'index et
`docs/PROMPTS.md` pour la suite des sessions de travail.
