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
- `docs/design/README.md` — le paquet de design livré, et **son §0 « Comment lire les
  planches » avant d'ouvrir un seul `.dc.html`**. Six propositions de direction y
  coexistent, **une seule est retenue** (`2a` Plein cadre), et rien dans les fichiers ne
  distingue un bloc abandonné d'un bloc final. Les blocs `1a` `1b` `1c` `2b` `2c` sont
  morts ; tout ce qui porte un numéro `3` ou plus est dans la direction retenue. Le piège
  a mordu sur `I2`.
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

> **La nouvelle direction artistique est produite et son catalogue de tokens validé**
> (2026-08-04). Le travail d'interface est donc **ouvert**, mais seulement le long des
> chaînes prévues : les **composants** par les lots `I2`…`I10`, les **écrans** par les
> tâches `V`, chacune après les lots `I` qui la fournissent. L'ordre est dans
> `docs/PROMPTS.md`.
>
> Reste interdit, et c'est ce qui n'a pas changé : **retoucher l'esthétique de
> l'interface des prompts 10 et 11.** Elle reste un **banc d'essai** — on ne la
> supprime pas, on ne la polit pas, on n'y investit rien. Elle sera *remplacée* par les
> `V`, pas amendée. Toute retouche esthétique hors d'un lot `I` ou d'une tâche `V`
> demande mon accord explicite.
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

## Les documents de design contraignent le rendu, jamais le modèle

`docs/design/` et les planches décrivent ce que l'utilisateur **voit**. `docs/02` décrit ce
qui est **stocké**. Quand un document de design paraît contraindre le modèle, c'est une
erreur de catégorie : le **signaler**, pas l'appliquer.

Deux incidents, la même erreur :

- « Cinq étoiles pleines, pas de demi-étoile » (planche 6) a été appliqué à
  `Title.rating`, borné à `0...5` avec refus des décimales. Or `docs/02` §3.3 dit 0–10, et
  `TitleFormat.fiveStarRating` divise déjà par deux depuis le prompt 11. La planche décrit
  le rendu. En l'état, l'import aurait refusé **la moitié de l'échelle**.
- « Contenu privé géré au niveau du profil » (handoff §7) décrivait aussi un comportement
  d'affichage. Dans le modèle, `isPrivate` appartient à l'entité, et l'appliquer au profil
  aurait rendu un titre privé **indexable dans Spotlight**, dont l'index est unique pour
  l'appareil. C'est la fuite que `L3` a fermée.

Le test : « est-ce que ça change ce qui est **écrit en base**, ou ce qui est **montré** ? »
Si c'est la base, la source est `docs/02`, et le document de design est à amender.

### Le corollaire, pour les tests

**Citer la source de chaque assertion non évidente.** Un seuil, une borne, un format : dire
d'où il vient, fichier et section.

Et si la source citée est un document de design alors que le sujet est le modèle, c'est un
**signal d'alarme**. C'est exactement comment « une demi-étoile est refusée » a verrouillé
le bug au lieu de l'attraper : le test citait la planche 6, ce qui le rendait crédible, et
il a fallu un arbitrage sur l'import pour découvrir qu'il testait une règle d'affichage
appliquée au mauvais niveau.

Un test qui encode une intention fausse est pire qu'un test absent : il transforme le bug
en comportement attendu, et il faut le remplacer par son contraire. C'est arrivé deux fois.

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

### Une preuve d'échec vérifie d'abord que la faute est bien là

Constater l'échec ne suffit pas : il faut constater que **l'injection de faute a
réellement eu lieu**. Une preuve se lit en deux temps — la faute est présente, *puis* le
filet mord — et le premier temps s'oublie, parce qu'un rouge attendu ressemble à un
succès. Trois fois que ça mord :

- un `sed` d'injection qui n'avait **rien remplacé** (la forme réelle du code était
  `.foldedForMatching` seul sur sa ligne) : le rouge observé venait d'ailleurs ;
- un test de couleurs qui **passait malgré** la faute de frappe injectée ;
- une garde de compilation dont la démonstration prouvait la détection du symbole absent,
  pas la garde (le cas ci-dessus).

En pratique : après toute injection, **relire le fichier modifié** (ou vérifier le compte
de substitutions), et seulement ensuite lancer la vérification.

### Une propriété invisible depuis l'environnement de test n'est protégée que par le lint

Quand la faute ne se manifeste **pas** sur ma machine, un test ne protège rien : il est
vert avec le bug. Ma machine est française, donc les deux chemins de repliage y donnent la
même réponse — les tests d'invariance de locale passent même si un modèle contourne
`TextFolding`. Seule une **règle de lint** attrape ça, parce qu'elle regarde le code et
non son comportement.

C'est la quatrième fois, et c'est désormais un motif établi : `no_literal_color`,
`no_predicate_outside_core`, la règle sur les mutateurs de relation, et
`no_folding_outside_text_folding`. Le réflexe : quand la propriété à garantir est
« ce code passe par tel unique point d'entrée » plutôt que « ce code produit telle
valeur », écrire la règle de lint en plus du test, et la prouver en injectant la faute.

## L'arithmétique ne vit jamais dans une `View`

**`View` est `@MainActor`**, donc tout membre d'une vue l'est aussi. Une clôture qui
capture `self` — un `segments.map { width(of: $0, …) }`, par exemple — déclenche alors un
contrôle d'isolation depuis un test non isolé, et ce contrôle **tue le processus de test**
(`SIGTRAP`, `_swift_task_checkIsolatedSwift`) au lieu d'échouer proprement.

Ce qu'on observe est bien pire qu'un test rouge : `swift test` sort en « exited with
unexpected signal code 5 », **la suite entière ne rend aucun résultat**, et le message ne
nomme aucun test. C'est vrai même avec un `--filter` qui ne sélectionne rien, ce qui oriente
vers un problème de chargement de bundle alors que le défaut est dans un corps de fonction.

La règle : **tout calcul pur sort de la vue**, dans un type nonisolé, et c'est lui qu'on
teste. Trois fois que le motif se répète — `GridMetrics` hors de `AdaptiveTileGrid`,
`ProgressMetrics` hors de `ProgressTrack`, et avant eux la géométrie de recadrage. Le
bénéfice n'est pas seulement l'isolation : un calcul extrait est le seul qu'on puisse
assener sur des entrées dégénérées (division par zéro, compte négatif, débordement) sans
monter un rendu.

Quand il n'y a rien à extraire — comparer deux jetons de couleur portés par un `enum`
imbriqué dans une vue —, la sortie est `@MainActor` sur le test, pas une extraction
artificielle.

### Une suite qui meurt sans nommer de test se diagnostique par le rapport système

**Avant de bissecter :** `ls -t ~/Library/Logs/DiagnosticReports/*.ips | head`, et lire la
pile du thread déclencheur. Elle nomme la fonction fautive directement.

```bash
python3 -c "
import sys,json; raw=open(sys.argv[1]).read(); d=json.loads(raw.split('\n',1)[1])
print(d['exception'])
for t in d['threads']:
    if t.get('triggered'):
        for f in t['frames'][:12]: print(' ', d['usedImages'][f['imageIndex']]['name'], f.get('symbol'))
" ~/Library/Logs/DiagnosticReports/<le-fichier>.ips
```

Mesuré le 2026-08-04 : six bissections à l'aveugle pour arriver là où la pile menait en une
commande. La bissection reste bonne quand un test **échoue** ; elle est le mauvais outil
quand le processus **meurt**.

## Deux crans de rigueur, réglés sur l'irréversibilité — pas sur la couche

Le classement fait foi dans `docs/PROMPTS.md`, section « La rigueur se règle sur
l'irréversibilité ». **À lire avant de commencer une tâche**, parce qu'il décide de la
méthode et de la longueur du rapport.

Le critère : **si cette tâche a un défaut et que personne ne le voit pendant trois
semaines, est-ce que la donnée est récupérable ?** Non → maximale. Oui → légère. Deux
crans, pas trois. Une seconde porte compte autant sans être de l'irréversibilité :
exposer un contenu marqué privé ne se répare pas.

- **Maximale** — sonde hors dépôt, preuve d'échec avec injection vérifiée, sous-agent de
  revue, rapport détaillé. `L8` `L11a` `L11b` `L12` `L13` `L15` `L16` `L20`.
- **Légère** — compile, teste normalement, avance. `L1 bis` `L5` `L6` `L7` `L9` `L17`
  `L18`, et **toute la chaîne `I`**.

**La longueur du rapport suit le même cran.** Sur une tâche légère : **cinq lignes** — ce
qui est fait, ce qui est vert, ce qui reste. Les rapports détaillés, les tableaux de
mesures et les récits d'arbitrage restent pour les tâches à rigueur maximale, où ils ont
servi. Sur une tâche légère, en produire un n'est pas du zèle, c'est une erreur de
méthode.

## Le paquet sonde : méthode attendue sur les tâches critiques de données

**Une suite de tests écrite par l'auteur du code partage ses angles morts.** Elle
n'interroge que les entrées auxquelles il a pensé, et c'est précisément là qu'il n'y a rien
à trouver. `L11a` l'a démontré : 320 tests verts, `swiftlint --strict` à zéro, et **trois
défauts muets** dans le lecteur d'octets — un guillemet de pouce dans un titre coûtait huit
lignes valides, un synopsis multiligne pourtant conforme corrompait la fin du fichier, un
fichier à fins de ligne `CR` devenait un en-tête de quatre colonnes. Aucun test ne les
voyait, et le rapport annonçait « 7 lignes analysées » sur 15 sans un mot sur les huit
autres.

Ce qui les a trouvés est une **sonde hors dépôt** : un paquet SwiftPM jetable, qui dépend de
`CineShelfCore` par chemin local, et dont le `main.swift` n'assène rien mais **imprime**.

```swift
// Package.swift : dependencies: [.package(path: "…/Packages/CineShelfCore")]
let d = CSVReader().read(fichierAdverse)
print("15 lignes fournies -> rows=\(d.rows.count) saines=\(d.wellFormedRows.count)")
```

Pourquoi ça marche là où un test échoue :

- **Elle imprime au lieu d'assener.** Un test dit « conforme à mon attente » ; la sonde dit
  ce qui s'est *réellement* passé. `rows=7` sur quinze lignes fournies saute aux yeux — et
  aucune assertion ne l'aurait demandé, puisque personne ne soupçonnait la perte.
- **Elle est jetable, donc les entrées peuvent être franchement hostiles** sans qu'on
  s'inquiète du temps de la suite ni de sa lisibilité.
- **Elle mesure avant de corriger, puis remesure après.** Les tableaux « avant / après » du
  journal viennent tous de là, et c'est ce qui a montré que ma première correction du seuil
  de resynchronisation **aggravait** le pire cas — 24 lignes perdues au lieu de 8. Sans
  mesure, je l'aurais livrée en la croyant meilleure.

**Attendue sur les tâches à rigueur maximale, et sur elles seules** : ce sont celles où une
donnée fausse s'écrit en base et ne se voit plus. La liste fait foi dans `docs/PROMPTS.md`,
section « La rigueur se règle sur l'irréversibilité, pas sur la couche » — au 2026-08-04 :
`L8`, `L11a`, `L11b`, `L12`, `L13`, `L15`, `L16`, `L20`. La sonde y précède les tests, et
chaque défaut qu'elle trouve devient un test de non-régression — c'est le test qui reste,
pas la sonde.

**Sur une tâche à rigueur légère, ne pas la construire.** Pas de sonde, pas de preuve
d'échec, pas de sous-agent de revue : compile, teste normalement, avance.

Les entrées à essayer sont celles qu'un auteur ne choisit pas spontanément : la valeur qui
contient le séparateur, celle qui contient le caractère d'échappement, la ligne trop courte,
la ligne trop longue, l'encodage étranger, la fin de ligne d'un autre système, la collection
vide, le doublon intra-lot, l'annulation au pire moment, et la même opération jouée deux
fois. Les scripts de sonde vont dans le répertoire de travail temporaire de la session, pas
dans le dépôt.

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

## Un tableau de vérification ne porte que des commandes réellement passées

**C'est la règle la plus importante du fichier, parce que c'est le seul risque que tu ne
peux pas rattraper.** Tu n'as aucun moyen de savoir ce qui a tourné, sinon ce que mes
rapports affirment. Un tableau vert sur une commande que je n'ai pas lancée n'est pas une
approximation : c'est une information fausse, et elle est indétectable.

- Une commande non lancée s'écrit **« non lancée »**, jamais ✅, jamais « devrait passer ».
- Une commande lancée sur un **sous-ensemble** le dit : « `swift test --filter Archive`,
  36 tests » et non « `swift test` ».
- Un chiffre reporté d'une session précédente est marqué comme tel, pas réaffirmé au
  présent.
- Aucune inférence : que le build passe ne dit rien des tests, et qu'un paquet passe ne
  dit rien des trois autres.

### La même règle vaut pour le code, pas seulement pour les commandes

**Une affirmation sur du code que je n'ai pas encore confronté à sa source est du même
ordre qu'un ✅ sur une commande non lancée.** Dans les deux cas j'énonce un résultat que je
n'ai pas constaté, et dans les deux cas tu n'as aucun moyen de le savoir.

Trois occurrences, la même faute sous trois habits :

- **« Les builds passent »** sans avoir lancé les tests. L'inférence est nommée plus haut.
- **Le contre-test de `P0`**, qui lisait `DEVELOPMENT_TEAM` au lieu de jouer le geste du
  `README`.
- **« `NavigationModelTests` restera vert sans que j'y touche »**, annoncé en fin de `I6`.
  Il n'a pas compilé : le design donne cinq onglets là où la coquille en avait cinq autres.
  La prédiction portait sur du code que je connaissais — mais elle affirmait son accord
  avec une **planche que je n'avais pas encore ouverte**.

Ce que ça change en pratique : avant d'écrire qu'un fichier, un test ou une décision
« tient » face au design, **ouvrir la planche qui en décide**. Tant que ce n'est pas fait,
la formulation honnête est « je n'ai pas encore confronté X à la planche Y », pas une
prédiction. Une prédiction explicitement marquée comme telle reste utile — elle se vérifie,
et son échec apprend quelque chose ; c'est l'affirmation *déguisée en constat* qui trompe.

### Une preuve doit exercer le geste, pas seulement la valeur

Corollaire de `P0`, et le défaut était réel. Le contre-test vérifiait
`xcodebuild -showBuildSettings | grep DEVELOPMENT_TEAM`, donc **la lecture de la valeur**.
Or le bug était dans le **geste que le `README` recommande** — copier
`Local.xcconfig.example` — et il cassait `xcodebuild test` sur une cible de test sans
rapport avec la signature. Trois mesures vertes, et le défaut passait entre elles.

La question à se poser : **quelle est la suite de gestes qu'un lecteur de ma documentation
va réellement faire ?** C'est celle-là qu'il faut jouer, en entier, avant d'écrire qu'elle
fonctionne. Lire une valeur n'est pas exécuter un chemin.

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
   >
   > **Un seul faux positif attendu : `56ed7a7`.** C'est le commit de l'app **web**, cité
   > sur la fiche du prompt 2 ; il vit dans `CineShelf_old`, pas ici, et il sera donc
   > toujours signalé « orphelin » par cette commande. Tout autre hash signalé est un vrai
   > problème.

> Ne rien cocher dans `docs/03-FONCTIONNALITES-NATIF.md` : ses symboles
> (✅ ♻️ 🔀 ⛔ ⏸ ➕) décrivent l'**intention** retenue pour chaque
> fonctionnalité — conservée, repensée, abandonnée — pas l'avancement. Les
> mélanger rendrait les deux illisibles.

## Ce que je ne veux pas
- De dépendance externe sans me demander.
- Du code « au cas où ».
- Des commentaires qui paraphrasent le code.
- Du texte d'interface en anglais : l'app est en français.
