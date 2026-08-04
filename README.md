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
| `Configuration/Local.xcconfig` | ton identifiant d'équipe Apple — voir « Signer pour un appareil ». Sans lui, le dépôt compile pour le simulateur et macOS |

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

## Signer pour un appareil

Sans configuration, le dépôt compile pour le **simulateur** et pour **macOS**, pas pour
un iPhone. Un build appareil échoue alors ainsi, et c'est le comportement attendu :

```
error: Signing for "CineShelf" requires a development team.
```

**Un Apple ID gratuit suffit.** Il donne une « Personal Team », des profils de 7 jours
renouvelables par un simple rebuild, et l'installation sur ses propres appareils.
L'abonnement payant ne sert qu'à CloudKit, aux widgets et aux App Intents.

```bash
# 1. Une seule fois, dans Xcode (interactif, rien à automatiser) :
#    Settings › Accounts › + › Apple ID

# 2. Relever l'identifiant d'équipe — entre parenthèses en fin de nom d'identité
security find-identity -v -p codesigning

# 3. Le poser dans un fichier local, jamais dans le dépôt
cp Configuration/Local.xcconfig.example Configuration/Local.xcconfig
$EDITOR Configuration/Local.xcconfig      # DEVELOPMENT_TEAM = A1B2C3D4E5

# 4. Vérifier qu'il est bien pris en compte
xcodebuild -scheme CineShelf -showBuildSettings | grep DEVELOPMENT_TEAM

# 5. Construire pour un appareil
xcodebuild -scheme CineShelf -destination 'generic/platform=iOS' build
```

Aucun `xcodegen generate` n'est nécessaire après l'étape 3 : le `.xcodeproj` référence le
`xcconfig`, pas sa valeur.

### Pourquoi un `xcconfig` et pas `project.yml`

| | |
|---|---|
| `Configuration/Signing.xcconfig` | **versionné.** Pose `DEVELOPMENT_TEAM` vide, puis `#include? "Local.xcconfig"` |
| `Configuration/Local.xcconfig` | **gitignoré.** Porte ton identifiant |
| `Configuration/Local.xcconfig.example` | versionné, le modèle |

Deux raisons, et une conséquence à connaître :

1. **Le dépôt est public.** Un identifiant d'équipe n'est pas un secret critique, mais
   c'est un identifiant personnel, et un historique public ne se rétracte pas.
2. **`xcodegen generate` réécrit le `.xcodeproj`** à chaque ajout de fichier : une équipe
   choisie dans l'interface d'Xcode serait perdue à la régénération suivante. Un
   `xcconfig` survit.

Le `#include?` est **optionnel** — le point d'interrogation compte. Sans lui, un clone
neuf et la CI échoueraient sur un fichier absent.

> ⚠️ **Ne jamais remettre `DEVELOPMENT_TEAM` dans `project.yml`.** Un build setting du
> projet **écrase** un `xcconfig`, et sans rien signaler : `Local.xcconfig` deviendrait
> inopérant alors qu'il est là et correctement rempli. Vérifié par la mesure — avec
> `DEVELOPMENT_TEAM: ""` réintroduit, `-showBuildSettings` rend une valeur vide malgré un
> `Local.xcconfig` renseigné. C'est aussi le premier endroit à regarder si l'étape 4
> ci-dessus ne rend rien.

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
Configuration/        xcconfig de signature — Local.xcconfig est gitignoré
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

1. **Équipe de développement** — voir « Signer pour un appareil » ci-dessus : elle vit
   dans `Configuration/Local.xcconfig`, **pas** dans `project.yml`. Ne reste ici que la
   partie propre à l'abonnement : supprimer les deux lignes
   `CODE_SIGN_IDENTITY[sdk=macosx*]: "-"` de la cible `CineShelf`, puis
   `xcodegen generate`. Tant qu'il n'y a pas d'abonnement, ces deux lignes restent —
   elles ne gênent pas iOS, et les retirer casserait le build macOS local.
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
