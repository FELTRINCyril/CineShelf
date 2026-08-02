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
brew install xcodegen swiftlint swift-format
xcodegen generate
open CineShelf.xcodeproj
```

### Pourquoi `xcodegen generate` à chaque fois ?

`*.xcodeproj` est **gitignoré**. Le projet est intégralement décrit par
`project.yml` : c'est lui la source de vérité. Ça évite les conflits de merge
dans le `pbxproj`, qui sont pénibles à résoudre et faciles à rater.

Régénère après un `git clone`, après un `git pull` qui touche `project.yml`, et
après tout ajout de fichier hors d'Xcode :

```bash
xcodegen generate && open CineShelf.xcodeproj
```

### Prérequis simulateur iOS

Xcode 26 n'embarque plus les runtimes de simulateur. Si `xcodebuild` répond
« iOS … is not installed » :

```bash
xcodebuild -downloadPlatform iOS
```

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
Tests/
  CineShelfTests/     tests de logique, sans app hôte (futurs CloudKitConformanceTests)
  CineShelfUITests/   tests d'interface (XCUITest) — simulateur iOS uniquement
docs/                 spécifications, roadmap, prompts, journal
```

Les tests unitaires des packages vivent dans les packages eux-mêmes
(`Packages/<Nom>/Tests/`), là où SwiftPM les attend.

### Deux schémas

| Schéma | Contenu | Destinations |
|---|---|---|
| `CineShelf` | l'app + `CineShelfTests` | iOS **et** macOS |
| `CineShelfUITests` | l'app + les tests d'interface | simulateur iOS |

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

# Qualité
swiftlint --strict
swift-format lint --recursive --strict App Packages Tests
swift-format format --in-place --recursive App Packages Tests
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
