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
- **`versionIdentifier` du schéma reste à `1.0.0` pendant tout le développement.**
  Tout changement de modèle est libre, sans étape de migration : le magasin local
  est effacé si besoin. La version **gèle au prompt 20**, à l'import des vraies
  données ; à partir de là, tout changement de modèle exige un plan de migration.
  Détail dans `docs/02` §7.

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
- **Tout test de `#Predicate` SwiftData passe par le magasin** : `save()` puis
  `fetch`, ou fetch depuis un `ModelContext` neuf. Jamais sur des objets encore
  en attente. Sur du pending, SwiftData évalue le prédicat en Swift et sa
  traduction SQL n'est **pas** exercée — un test vert peut alors couvrir une app
  cassée. C'est arrivé : `searchText.contains("")` est vrai en Swift mais
  `CONTAINS ''` ne matche aucune ligne en SQL, et la grille des titres est restée
  vide en permanence derrière 42 tests verts. Quand le comportement *avant*
  sauvegarde est lui-même le sujet (dédoublonnage intra-lot d'import), le dire
  dans le nom du test et couvrir le chemin SQL ailleurs.

## Commandes
```bash
xcodegen generate   # après tout ajout de fichier : *.xcodeproj n'est pas versionné

xcodebuild -scheme CineShelf -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme CineShelf -destination 'platform=macOS' build

xcodebuild test -scheme CineShelf -destination 'platform=macOS'
xcodebuild test -scheme CineShelfUITests -destination 'platform=iOS Simulator,name=iPhone 17'
for p in CineShelfCore DesignSystem MediaKit; do (cd "Packages/$p" && swift test); done

swiftlint --strict
# swift-format n'est pas dans le PATH : il est livré avec la toolchain Xcode.
xcrun swift-format lint --recursive App Catalog Packages Tests
```

Catalogue du design system — c'est aussi le seul endroit où les tests d'assets
et de rendu tournent avec un `Colors.xcassets` compilé (`swift test` ne lance pas
`actool`) :

```bash
xcodebuild -scheme DesignSystemCatalog -destination 'platform=macOS' build
xcodebuild test -scheme DesignSystemCatalog -destination 'platform=macOS'
open ~/Library/Developer/Xcode/DerivedData/CineShelf-*/Build/Products/Debug/DesignSystemCatalog.app

python3 scripts/generate-colors.py   # après toute modif de colors.tokens.json
```

## Déroulé attendu de chaque tâche
1. Lire la section pertinente des docs.
2. **Proposer un plan avant d'écrire du code.** Attendre ma validation.
3. Écrire, compiler, corriger jusqu'à build vert sur iOS **et** macOS.
4. Lancer les tests.
5. Ajouter une ligne à `docs/journal.md`.
6. Un commit par tâche, message conventionnel.
7. Cocher la ligne du prompt dans le **tableau d'état de `docs/PROMPTS.md`**,
   avec le hash du commit. C'est le seul endroit où se suit l'avancement.
   Y reporter aussi les nouveaux écarts, dans « Écarts connus ».

> Ne rien cocher dans `docs/03-FONCTIONNALITES-NATIF.md` : ses symboles
> (✅ ♻️ 🔀 ⛔ ⏸ ➕) décrivent l'**intention** retenue pour chaque
> fonctionnalité — conservée, repensée, abandonnée — pas l'avancement. Les
> mélanger rendrait les deux illisibles.

## Ce que je ne veux pas
- De dépendance externe sans me demander.
- Du code « au cas où ».
- Des commentaires qui paraphrasent le code.
- Du texte d'interface en anglais : l'app est en français.
