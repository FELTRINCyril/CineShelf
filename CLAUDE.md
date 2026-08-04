# CineShelf — instructions projet

## Le projet
App SwiftUI multiplateforme (iOS · iPadOS · macOS) : catalogue personnel de films,
séries, personnes, collections et images. Réécriture native d'une app web
React + Express retirée. **Aucun backend.** SwiftData + CloudKit privé.

## Documents de référence — à consulter avant toute tâche
- `docs/02-MODELE-SWIFTDATA-CLOUDKIT.md` — le modèle de données **fait foi**
- `docs/03-FONCTIONNALITES-NATIF.md` — le contrat : ~130 fonctionnalités, **rien ne doit manquer**
- `docs/04-ARCHITECTURE-SWIFTUI.md` — structure, pipeline médias, tests
- `docs/06-BRIEF-DESIGN.md` — le brief de design : registre, écrans à concevoir,
  méthode. Il **remplace** `01-DESIGN-SYSTEM-APPLE.md`, archivé dans
  `docs/_archive/OBSOLETE-design-system-productivite.md` : ne plus s'y référer.
- `docs/PROMPTS.md` — le plan et l'avancement : tâches LOGIQUE (L1, L2...), tâches
  VUES, tableau d'état, écarts connus.

> `docs/_archive/` ne sert jamais de référence pour du travail neuf.

## Règles non négociables — modèle
- Toute propriété `@Model` a une valeur par défaut **ou** est optionnelle.
- Aucun `@Attribute(.unique)` — CloudKit l'interdit. Dédoublonnage applicatif.
- Toutes les relations sont optionnelles, avec `inverse:` déclaré d'un seul côté.
- Pas de règle de suppression `.deny`.
- Les enums sont persistées en `rawValue: String`, exposées en propriété calculée.
- `sortName` et `searchText` maintenus par `refreshDerived()`, appelé à **chaque** écriture.
- `CloudKitConformanceTests` doit passer avant tout commit.
- **Le schéma est FERMÉ depuis le 2026-08-03.** Dix-neuf entités. La fenêtre où
  l'on ajoutait un champ en effaçant le magasin local est close : **toute**
  modification du modèle — un champ, un renommage, une relation — exige un
  `VersionedSchema` nouveau et un `MigrationStage` qui l'atteint depuis
  `CineShelfSchemaV1`. Pas d'exception pour « ce n'est qu'un champ optionnel » :
  c'est la forme que prend la première migration oubliée.
  La passe d'inventaire qui a précédé la fermeture, les six manques qu'elle a
  trouvés et les deux non-ajouts assumés sont dans `docs/02` étape 0 bis.

## Règles non négociables — design

> **La direction artistique est en refonte complète.** Aucun travail d'interface
> nouveau sans mon accord explicite : ni écran, ni composant, ni retouche
> esthétique de l'existant. Si une tâche semble en exiger, arrête-toi et
> demande-moi. L'interface des prompts 10 et 11 reste en place comme **banc
> d'essai** pour exercer la logique : on ne la supprime pas, on ne la polit pas,
> on n'y investit plus rien.
>
> Ce qui suit reste valable : ce sont des règles d'architecture et de lint, pas des
> choix esthétiques. Elles survivront au changement de direction.

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

## Reprise de session — le dépôt existe déjà

**Avant toute autre chose, et avant même `xcodegen generate` :**

```bash
git fetch origin
git log --oneline origin/main..main   # ce que j'ai en local et qui n'est pas poussé
git log --oneline main..origin/main   # ce qui est poussé et que je n'ai pas
```

**Les deux, pas seulement le premier.** Le second est celui qu'on oublie, et c'est le
dangereux : **un dépôt en retard se travaille sans rien signaler.** Tout compile, tous
les tests passent, le tableau d'état paraît cohérent - il l'est, pour la version d'il y
a quatre jours. On rédige alors des décisions contre un plan périmé, et le seul indice
est une phrase qui sonne faux à la relecture (« `L1` reste en tête du chemin critique »
alors que `L1` à `L4` étaient faites et poussées).

Si `main..origin/main` n'est pas vide : tirer **avant** d'écrire quoi que ce soit. Si
un commit local a déjà été posé sur la base périmée, c'est `git rebase origin/main`,
pas un simple `git pull` - sans quoi la fusion masque le décalage au lieu de le
résoudre.

C'est arrivé le 2026-08-04 : treize commits de retard, dont la fermeture du schéma et
la livraison de `docs/design/`, plus un commit local posé par-dessus.

## Une garde à la compilation se prouve en cassant le build

Quand un filet est une **erreur de compilation** — une ambiguïté de nom, un `switch`
exhaustif sans `default`, un paramètre sans valeur par défaut — sa preuve d'échec ne peut
pas être un test à l'exécution : la suite cesse de compiler **avant** d'atteindre le test,
et ce qu'on observe alors est « symbole absent », pas la garde qui mord.

C'est arrivé sur les collisions `ShapeStyle` : retirer la désambiguïsation de `separator`
a bien cassé la suite, mais par symbole introuvable. Ça démontrait la détection, pas la
garde. La bonne démonstration a consisté à ajouter un token nommé `fill`, dont l'accesseur
heurte une statique de SwiftUI : la suite compilait alors, et quatre tests mordaient.

La règle : pour prouver une garde de compilation, **introduire la faute que la garde
existe pour attraper**, et constater l'erreur de compilation — pas retirer la garde.
Retirer la garde prouve seulement qu'on l'utilisait.

## Commandes
```bash
xcodegen generate   # après tout ajout de fichier : *.xcodeproj n'est pas versionné

xcodebuild -scheme CineShelf -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme CineShelf -destination 'platform=macOS' build

xcodebuild test -scheme CineShelf -destination 'platform=macOS'
xcodebuild test -scheme CineShelfUITests -destination 'platform=iOS Simulator,name=iPhone 17'
for p in CineShelfCore DesignSystem MediaKit; do (cd "Packages/$p" && swift test); done

# Un paquet qui dépend de CineShelfCore peut échouer sur « cannot find type X in
# scope » alors que CineShelfCore compile seul : son graphe de build a été mis en
# cache avant l'ajout du fichier. Ce n'est pas un défaut de code.
(cd Packages/MediaKit && rm -rf .build && swift test)

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

## Une CI rouge bloque la tâche suivante
Elle se répare **avant**, pas après. Une CI rouge que personne ne regarde est pire
qu'aucune CI : elle apprend à ignorer le signal, et le jour où elle attrape une vraie
régression, plus personne ne la croit. `gh run list` au début de session, et si c'est
rouge, c'est le sujet du jour.

Corollaire sur les seuils de performance : **ne jamais assener un budget d'expérience
utilisateur sur un runner partagé.** Les runners GitHub sont virtualisés et n'ont pas
l'accélération d'image — mesuré, sur le même code : décodage de vignette 15 ms en
local, 266 ms sur le runner. Un test de perf assène (a) des **rapports**, qui sont
indépendants de la machine et portent le sens, et (b) des plafonds absolus calés sur
l'environnement le plus lent où il tourne, qui n'attrapent qu'un ordre de grandeur.
Les budgets de `docs/04` §4 se vérifient avec Instruments sur appareil, comme ce
document le dit lui-même.

## Déroulé attendu de chaque tâche
1. Lire la section pertinente des docs.
2. **Proposer un plan avant d'écrire du code.** Attendre ma validation.
3. Écrire, compiler, corriger jusqu'à build vert sur iOS **et** macOS.
4. Lancer les tests.
5. Ajouter une ligne à `docs/journal.md`.
6. **Un commit par sujet cohérent, message conventionnel** — une tâche peut en
   produire plusieurs. Le critère est la bissectabilité : chaque commit doit
   pouvoir être compris, et le cas échéant révoqué, sans entraîner les autres.
   Une tâche qui touche trois sujets indépendants fait trois commits, et reste
   **une seule ligne** du tableau d'état.
7. Cocher la ligne du prompt dans le **tableau d'état de `docs/PROMPTS.md`**,
   avec le hash du commit. C'est le seul endroit où se suit l'avancement.
   Y reporter aussi les nouveaux écarts, dans « Écarts connus ».

   > **Le hash s'inscrit dans un commit *suivant*, jamais par `--amend`.** Amender
   > change le hash : le tableau se met alors à désigner un commit qui n'existe
   > plus dans l'historique poussé, et il n'y paraît rien — c'est arrivé sur `L2`,
   > `L3` et `L4`. Vérification en une ligne, quand un doute existe :
   > `grep -oE '\`[0-9a-f]{7}\`' docs/PROMPTS.md | tr -d '\`' | while read h; do`
   > `git merge-base --is-ancestor $h HEAD || echo "$h orphelin"; done`

> Ne rien cocher dans `docs/03-FONCTIONNALITES-NATIF.md` : ses symboles
> (✅ ♻️ 🔀 ⛔ ⏸ ➕) décrivent l'**intention** retenue pour chaque
> fonctionnalité — conservée, repensée, abandonnée — pas l'avancement. Les
> mélanger rendrait les deux illisibles.

## Ce que je ne veux pas
- De dépendance externe sans me demander.
- Du code « au cas où ».
- Des commentaires qui paraphrasent le code.
- Du texte d'interface en anglais : l'app est en français.
