<!-- ARCHIVE - INSTALLATION FAITE -->
# ARCHIVE - l'installation est faite

> Ce prompt d'installation a été exécuté (prompt 4, commit `03fff62`). Le dépôt, le
> projet XcodeGen, les trois packages, `CLAUDE.md`, le lint et la CI sont en place.
> Le document est conservé comme trace de la configuration initiale ; il n'est plus
> à rejouer, et il a divergé de l'état réel du dépôt depuis.

---

# Rayon — Prompt d'installation

Un seul prompt qui met tout en place : dépôt, projet Xcode, packages, `CLAUDE.md`, lint, CI.
Remplace l'ancienne étape manuelle « créer le projet Xcode ».

---

## Avant de lancer

Trois choses que Claude Code ne peut pas faire à ta place :

1. **Xcode installé** depuis l'App Store, puis lancé une fois pour accepter la licence.
2. **Homebrew installé** — `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
3. **Les 9 fichiers `.md`** de ce dossier posés quelque part que tu sais retrouver (le prompt gère le déplacement).

Puis :

```bash
mkdir ~/Developer/Rayon && cd ~/Developer/Rayon
claude
```

Et tu colles le prompt ci-dessous.

> **Changer de nom ?** Modifie les deux premières lignes du prompt (`Nom` et `Bundle ID`). Tout le reste s'adapte.

---

## Le prompt

````
Tu vas initialiser de zéro un nouveau projet. Voici les paramètres :

- Nom de l'app : Rayon
- Bundle ID : fr.feltrin.Rayon
- Organisation : Cyril Feltrin
- Langue de l'interface : français
- Cibles : iOS 18.0+ et macOS 15.0+, une seule cible multiplateforme
- Swift 6, concurrence stricte
- Zéro dépendance externe

C'est la réécriture native d'une app web (React + Express) : un catalogue
personnel de films, séries, personnes, collections et images. SwiftData +
CloudKit privé, aucun backend.

## Étape 0 — Vérifications et outils

Vérifie et installe si besoin :
- xcode-select -p pointe bien vers Xcode.app (pas les Command Line Tools seules)
- xcodebuild -version
- brew install xcodegen swiftlint swift-format

Si l'un de ces points bloque, arrête-toi et dis-moi quoi faire.

## Étape 1 — Documentation

Les 9 fichiers de documentation du projet (README.md, 00-AUDIT.md,
01-DESIGN-SYSTEM-APPLE.md, 02-MODELE-SWIFTDATA-CLOUDKIT.md,
03-FONCTIONNALITES-NATIF.md, 04-ARCHITECTURE-SWIFTUI.md, 05-ROADMAP-NATIF.md,
GUIDE-EXECUTION.md, PROMPTS.md) sont soit dans ce dossier, soit dans
~/Downloads, soit dans un sous-dossier. Trouve-les et déplace-les dans docs/.
S'il y a un dossier _archive-web/, déplace-le aussi dans docs/.

Si tu n'en trouves aucun, arrête-toi et demande-moi où ils sont.

## Étape 2 — Arborescence

Crée exactement :

Rayon/
├── CLAUDE.md
├── README.md
├── .gitignore
├── .swiftlint.yml
├── .swift-format
├── project.yml
├── .github/workflows/ci.yml
├── docs/
│   └── journal.md
├── App/
│   ├── RayonApp.swift
│   ├── RootView.swift
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   ├── Info.plist
│   │   └── Rayon.entitlements
│   ├── Navigation/
│   ├── Features/
│   │   ├── Home/  Titles/  People/  Collections/  Gallery/
│   │   ├── SavedLinks/  Search/  MyList/  LibraryAdmin/
│   │   ├── Transfer/  Settings/
│   └── Intents/
├── Packages/
│   ├── DesignSystem/
│   ├── RayonCore/
│   └── MediaKit/
└── Tests/
    ├── RayonCoreTests/  DesignSystemTests/  MediaKitTests/
    └── RayonUITests/

Mets un .gitkeep dans les dossiers encore vides.

## Étape 3 — Les trois packages locaux

Un Package.swift par package, platforms iOS 18 / macOS 15, swift-tools-version
adaptée à ta version de Swift, Swift 6 language mode.

- DesignSystem : aucune dépendance. Contiendra tokens et composants.
  Prévois dès maintenant la déclaration `resources: [.process("Resources")]`.
- RayonCore : aucune dépendance, et surtout **n'importe jamais SwiftUI**.
  Contiendra les @Model, les repositories, les services.
- MediaKit : dépend de RayonCore.

Dans chacun, un fichier source minimal pour que ça compile, et une cible de test.

## Étape 4 — project.yml (XcodeGen)

Écris un project.yml qui produit une cible **multiplateforme unique** nommée
Rayon, supportant iOS et macOS.

Attention : la syntaxe des cibles multiplateformes a évolué selon les versions
de XcodeGen. Consulte la doc de la version que tu viens d'installer
(`xcodegen --version`, puis son README). Si `supportedDestinations` n'est pas
disponible, replie-toi sur deux cibles partageant les mêmes sources et dis-le
moi explicitement.

Le project.yml doit inclure :
- les trois packages locaux en dépendances
- le chemin des sources App/
- Info.plist et entitlements depuis App/Resources/
- les cibles de test
- SWIFT_STRICT_CONCURRENCY = complete
- SWIFT_VERSION = 6.0
- DEVELOPMENT_TEAM laissé vide (je le remplirai quand j'aurai l'abonnement)
- CODE_SIGN_STYLE = Automatic

Puis lance `xcodegen generate`.

Ajoute `*.xcodeproj` au .gitignore : le projet est reproductible depuis
project.yml, ça évite les conflits Git. Documente-le dans le README.

## Étape 5 — Info.plist et entitlements

Info.plist :
- CFBundleDisplayName : Rayon
- Langue par défaut : fr
- UIUserInterfaceStyle absent (on suit le système)
- NSFaceIDUsageDescription : "Rayon utilise Face ID pour protéger l'accès à ta bibliothèque."
- NSPhotoLibraryUsageDescription : "Rayon a besoin d'accéder à tes photos pour ajouter des images à ton catalogue."
- UIAppFonts prévu pour Archivo (commenté pour l'instant, la police arrivera plus tard)

Rayon.entitlements : crée le fichier avec les clés CloudKit
(com.apple.developer.icloud-services, icloud-container-identifiers avec
iCloud.fr.feltrin.Rayon, aps-environment) mais **commentées ou dans un fichier
Rayon-CloudKit.entitlements séparé et non référencé**. Je n'ai pas encore
l'abonnement Apple Developer : le projet doit compiler et tourner sans.
Documente dans le README la manipulation exacte pour les activer plus tard.

## Étape 6 — CLAUDE.md

Crée CLAUDE.md à la racine, avec exactement le contenu de la section
« Avant tout — CLAUDE.md » de docs/PROMPTS.md, en remplaçant partout
« CineShelf » par « Rayon » et « CineShelfCore » par « RayonCore ».

## Étape 7 — Qualité

.swiftlint.yml, en mode strict, avec :
- les règles opt-in utiles (empty_count, first_where, force_unwrapping,
  implicitly_unwrapped_optional, redundant_nil_coalescing, toggle_bool,
  unused_import…)
- force_unwrapping en erreur, sauf dans Tests/
- une **règle personnalisée `no_literal_color`** : interdit
  `Color(red:`, `Color(hex:`, `UIColor(`, `NSColor(` et les littéraux
  hexadécimaux de couleur, partout SAUF dans Packages/DesignSystem/
- une **règle personnalisée `no_fixed_font_size`** : interdit
  `.font(.system(size:` sans `relativeTo:`
- line_length à 120, warning seulement

.swift-format avec une configuration cohérente (indentation 4 espaces).

## Étape 8 — CI

.github/workflows/ci.yml : sur push et pull request, sur macos-latest —
swiftlint --strict, build iOS Simulator, build macOS, tests.

⚠️ Les runners macOS de GitHub consomment les minutes gratuites au tarif ×10.
Configure le workflow pour ne tourner que sur les pull requests et sur main,
pas sur chaque push de branche. Note-le dans le README.

## Étape 9 — Code minimal

- RayonApp.swift : @main, WindowGroup, scène Settings sur macOS,
  commandes de barre de menus vides mais en place
- RootView.swift : bascule @Environment(\.horizontalSizeClass), avec
  CompactRootView (TabView) et RegularRootView (NavigationSplitView),
  chacune avec des écrans vides « À venir »
- Un test bidon dans chaque cible de test, qui passe

Pas de SwiftData pour l'instant : le modèle viendra au prompt suivant.

## Étape 10 — Git

git init, branche main, .gitignore complet (macOS, Xcode, SPM, DerivedData,
*.xcodeproj, .DS_Store, xcuserdata, /data), puis premier commit
« chore: initialisation du projet Rayon ».

Crée docs/journal.md avec une première entrée datée.

## Étape 11 — Vérification

Compile pour iOS Simulator ET pour macOS. Lance les tests. Lance swiftlint.
Corrige jusqu'à ce que tout soit vert.

Puis affiche-moi :
- l'arborescence finale (2 niveaux)
- le résultat des deux builds et des tests
- ce que je dois faire à la main, s'il reste quoi que ce soit
- la commande pour ouvrir le projet

Ne me montre pas le contenu de chaque fichier créé, juste le récapitulatif.
````

---

## Après ce prompt

Tu enchaînes directement sur le **prompt 5** de `PROMPTS.md` (le modèle de données). Les prompts 3 et 4 de l'ancienne numérotation sont couverts : les captures d'écran restent à faire par toi, le projet Xcode est désormais automatisé.

## Régénérer le projet

Comme `*.xcodeproj` est gitignoré, après un `git clone` ou un changement dans `project.yml` :

```bash
xcodegen generate && open Rayon.xcodeproj
```

## Le jour où tu prends l'abonnement Apple Developer

Le prompt a laissé la place. Tu auras à faire, dans l'ordre :

1. Renseigner `DEVELOPMENT_TEAM` dans `project.yml`, puis `xcodegen generate`
2. Créer le conteneur `iCloud.fr.feltrin.Rayon` sur le portail développeur
3. Activer les clés CloudKit dans `Rayon.entitlements`
4. Passer `FeatureFlags.cloudKitEnabled = true`

C'est le prompt 21 de `PROMPTS.md`.
