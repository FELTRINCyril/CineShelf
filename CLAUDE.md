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

## Reprise de session — le dépôt existe déjà, et il est en retard

**Avant toute autre chose, et avant même `xcodegen generate` :**

```bash
git fetch origin
git log --oneline origin/main..main   # ce que j'ai en local et qui n'est pas poussé
git log --oneline main..origin/main   # ce qui est poussé et que je n'ai pas
git pull --ff-only                    # puis tirer : c'est la normale, pas un cas
```

**Le `pull` fait partie de l'ouverture, ce n'est pas une précaution.** J'alterne entre
deux machines, donc **le cas normal est un dépôt local en retard** : 13 commits le
2026-08-04, 34 le 2026-08-05, et une fois avant. Trois fois sur trois, la question
n'était pas « faut-il tirer ? » mais « de combien étais-je en retard ? ». Le `pull` se
lance donc systématiquement, et ce qui mérite un commentaire est le cas où il ne ramène
rien.

Si `--ff-only` échoue, c'est qu'un commit local a été posé sur la base périmée : c'est
`git rebase origin/main`, pas un `git pull` simple - sans quoi la fusion masque le
décalage au lieu de le résoudre.

**Les deux, pas seulement le premier.** Le second est celui qu'on oublie, et c'est le
dangereux : **un dépôt en retard se travaille sans rien signaler.** Tout compile, tous
les tests passent, le tableau d'état paraît cohérent - il l'est, pour la version d'il y
a quatre jours. On rédige alors des décisions contre un plan périmé, et le seul indice
est une phrase qui sonne faux à la relecture (« `L1` reste en tête du chemin critique »
alors que `L1` à `L4` étaient faites et poussées).

C'est arrivé le 2026-08-04 : treize commits de retard, dont la fermeture du schéma et
la livraison de `docs/design/`, plus un commit local posé par-dessus. Et le 2026-08-05 :
trente-quatre, dont la revue visuelle du catalogue et l'arbitrage de ses dix écarts.

### Et une session se termine par un `git push`, sans que j'aie à le demander

**Symétrique de la règle d'ouverture, et pour la même raison : je change de machine.** Un
dépôt local en avance n'est pas un état, c'est un risque - le travail n'existe que sur
une machine, et la CI ne l'a jamais vu. La session suivante rouvre alors le dépôt sur
l'autre machine et se croit à jour.

**C'est arrivé quatre fois.** À chaque fois les commits étaient propres, les tests verts,
et le rapport annonçait honnêtement « non poussés » - ce qui ne les rendait pas moins
absents du dépôt distant.

En pratique, après le commit qui coche le tableau d'état : `git push origin main`. Pas de
question préalable ; le push fait partie de la livraison, comme le journal et le tableau.
Ce qui se demande, c'est l'inverse : **si une raison existe de ne *pas* pousser, la dire
et attendre.** Et comme une CI rouge bloque la tâche suivante (voir plus bas), le push
est aussi ce qui donne le droit de commencer la suivante.

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

## Le composant possède la forme, l'écran possède le texte

**Même famille que la règle précédente : une erreur de couche.** Là, c'était le rendu
confondu avec le modèle ; ici, c'est la copie confondue avec le composant. Et le symptôme
se ressemble : ça compile, ça s'affiche, et c'est faux à un endroit qu'on ne regarde pas.

`DesignSystem` possède la **géométrie, la typographie, les états, le comportement**. L'écran
possède **les mots**. Un composant qui porte sa propre copie a l'air plus pratique - un
appel plus court, rien à passer - et il devient faux dès le deuxième appelant.

**Le cas mesuré, à `I10`.** `StateView` prenait un `case` par situation : `noTitles`,
`noResults`, `syncFailed`. Le texte vivait donc dans le package. Or la grille des titres a
**deux** états vides qui demandent deux messages différents - « Ta collection est vide,
importe un CSV » quand il n'y a rien, « Les filtres ne laissent rien passer » quand 1 284
titres existent. Le second message est impossible à écrire dans `DesignSystem` : le package
ne sait pas qu'un filtre est actif, ni lequel, ni combien de titres il masque. Avec
l'énumération fermée, l'un des deux écrans mentait forcément.

`EmptyState` prend donc `title`, `message`, deux actions et un indice - **des paramètres,
pas des cas**. Le même composant sert les six écrans du bloc `9a` et les deux états de la
grille, sans qu'aucun texte n'entre dans le package.

Le test, en une question : **est-ce que deux appelants pourraient légitimement vouloir des
mots différents ?** Si oui, les mots sont un paramètre. Trois indices qu'on a franchi la
frontière :

- un `enum` de cas dans `DesignSystem` dont chaque cas correspond à **une situation
  métier** plutôt qu'à une variante de dessin (`noTitles` est une situation, `.compact` est
  une variante) ;
- un composant qui a besoin de savoir **pourquoi** on l'affiche, pas seulement quoi
  afficher ;
- une chaîne de caractères en français dans `Packages/`, hors d'une preview ou d'une
  planche du catalogue.

**Le corollaire, et il coupe dans l'autre sens.** L'écran ne possède pas la forme : il ne
choisit pas un rembourrage, une taille de police ni une couleur. `PosterCardModel` est la
frontière correcte - l'écran remplit des champs nommés, le composant décide de tout le
reste. Un écran qui passe une `CGFloat` de marge à un composant a franchi la même frontière
dans le sens inverse, et c'est ainsi qu'on obtient deux écrans qui ne s'alignent plus.

## Deux états qui rendent la même chose rendent toute porte aveugle

**Une porte d'acceptation ne voit que ce que ses entrées font varier.** Si l'absence et
l'échec produisent le même pixel, la porte est aveugle sur les deux - et elle continue de
passer au vert, ce qui est pire que de ne pas exister : on la croit.

**Mesuré, et le coût était de quatre sessions.** Les échantillons du catalogue avaient
`imageURL: nil`. Une tuile **sans** image et une tuile dont le chargement **échoue**
rendaient donc exactement le même aplat de fond. Pendant ce temps `MediaFill` chargeait par
`AsyncImage`, incapable de résoudre le schéma interne `cineshelf-asset://` — donc **aucune
affiche ne s'est affichée depuis `I2`**, sur la grille, les rails, le hero, la fiche et la
recherche. Le catalogue validait la forme d'une tuile vide et le journal notait « lancement
réel sur Mac, processus vivant » : les deux étaient vrais, aucun ne prouvait quoi que ce
soit.

**La règle : tout échantillon exerce le chemin réel, jamais le cas nul.** Un `nil`, une
chaîne vide, un tableau vide, une closure qui ne fait rien - ce sont des cas à couvrir *en
plus*, jamais le cas par défaut d'un échantillon. Le cas nul court-circuite précisément le
code qu'on cherche à valider.

Le corollaire, quand on ajoute un état : **compter les apparences, pas les états.** Trois
états qui donnent deux apparences valent deux états pour une porte visuelle. `MediaFill` a
donc gagné un rendu d'échec - un symbole discret - parce que sans lui « en cours » et « en
échec » étaient indistinguables, et la porte serait restée à moitié aveugle après
correction.

Trois questions avant de déclarer une porte utile :

- **qu'est-ce que cet échantillon ne peut pas révéler ?** Si la réponse est « le chargement »
  sur un composant d'image, la porte ne sert à rien ;
- **deux états différents donnent-ils deux apparences différentes ?** Sinon en ajouter une ;
- **le chemin réel est-il emprunté ?** Un `ImageLoader` injecté qui n'est jamais appelé
  parce qu'aucune URL n'existe est un chemin mort qui a l'air branché.

C'est la même famille que « une propriété invisible depuis l'environnement de test n'est
protégée que par le lint » : dans les deux cas, la vérification passe au vert sans avoir
exercé ce qu'elle prétend couvrir.

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

### Une entrée de test se prend quelconque, jamais remarquable

**Minuit, zéro, la chaîne vide et le premier élément sont les valeurs qui masquent les
défauts.** Ce sont aussi celles qu'on tape spontanément — et un test qui les prend passe au
vert en laissant le bug intact.

**Mesuré le 2026-08-06, sur le hero du jour.** La propriété à tenir était « stable dans la
journée ». Le code ramenait l'instant à un jour par `timeIntervalSince1970 / 86 400`,
c'est-à-dire à un jour **UTC**. Un test posé sur minuit local aurait passé sur ma machine ; le
test posé sur un instant quelconque — 22 h 13 UTC — a rendu deux heros pour deux instants du
même jour, et il a fallu écrire la bonne règle. Ce que la valeur remarquable cachait n'était
pas une erreur de calcul mais **une mauvaise définition du jour**.

Le motif est le même partout : une valeur remarquable est celle où plusieurs implémentations
coïncident. À minuit, « jour UTC » et « jour local » donnent la même réponse ; à zéro, une
somme et un produit aussi ; sur une chaîne vide, `contains` et `hasPrefix` sont d'accord. Le
test ne distingue alors plus les implémentations qu'il est censé départager.

En pratique, pour chaque entrée d'un test :

- **une date** : un instant au milieu de la journée, dans un fuseau qui n'est pas UTC, et un
  jour qui n'est ni le 1er ni le dernier du mois ;
- **un nombre** : ni 0, ni 1, ni la borne — et si la borne compte, elle s'ajoute *en plus* ;
- **une chaîne** : ni vide, ni ASCII pur, ni de la longueur du tampon ;
- **un index** : ni le premier, ni le dernier ;
- **une collection** : ni vide, ni à un élément.

Les cas dégénérés restent à couvrir — ils ont leurs propres tests, et ce fichier en réclame
ailleurs. Ce qu'ils ne peuvent pas faire, c'est servir de **cas nominal** : là, ils ne
départagent rien. C'est la même famille que « tout échantillon exerce le chemin réel, jamais le
cas nul », transposée des données de démonstration aux entrées de test.

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

## Les rendus gagnent quand ils s'accordent ; le jeton gagne quand ils se contredisent

**C'est la règle qui tranche entre « le prototype dit 44 » et « le système dit 32 ».** Elle
s'applique chaque fois qu'une valeur relevée dans un `.dc.html` diffère d'un jeton de
`DesignSystem`, et elle évite les deux erreurs symétriques : recopier aveuglément un pixel
de maquette, ou se réfugier derrière un jeton pour ne pas regarder.

- **Les rendus concordent → ils font foi**, et le code se corrige. Plusieurs écrans dessinés
  qui donnent la même valeur, c'est une intention contrôlée.
- **Les rendus divergent entre eux → le jeton fait foi**, et l'écart s'inscrit. Une mesure
  qui change d'un bloc à l'autre n'a jamais été contrôlée : elle est un accident de mise en
  page, et le jeton est la seule source stable.

Trois applications, mesurées :

- **Barre latérale.** Douze écrans rendus n'en montrent aucune, et le bloc `3b` l'écrit ;
  seule la table de synthèse du §4.6 en annonce une. Les rendus concordent → `Sidebar.swift`
  supprimée, la table est l'intruse.
- **Gouttière de rail.** iPhone 10, iPad 14, Mac 14 — trois formats d'accord, et *aucun* ne
  suit la densité. Les rendus concordent → c'est une mesure par point de rupture, et le code
  se corrige.
- **Marge de rail.** 44, 40, 36 selon le bloc Mac. Jamais contrôlée → le jeton
  `Breakpoint.screenMargin` gagne, et l'écart s'inscrit. Confirmation utile : les deux seuls
  formats rendus pour de vrai, iPhone et iPad, tombent **exactement** sur le jeton (20, 28).

Le corollaire pratique : avant de trancher, **compter les blocs**. Une valeur vue une seule
fois n'est ni l'un ni l'autre — c'est une observation, et il faut aller en chercher une
deuxième avant de décider. L'arbitrage complet des dix écarts relevés au 2026-08-04 est dans
`docs/PROMPTS.md`, section « Arbitrage de la revue visuelle du catalogue ».

## Une règle de doctrine énonce sa raison, pas seulement sa conséquence

**Une règle qui a raison par accident est pire qu'aucune règle** : elle gagne une confiance
qu'elle ne mérite pas, et elle finit par être appliquée au cas où le motif ne tient plus.
Le test : **si je ne sais pas écrire *pourquoi*, c'est probablement une observation
généralisée à tort**, pas une règle.

Deux fois que ça se produit ici, et les deux fois la conséquence était juste :

- **« La chaîne `L` demande une rigueur maximale. »** Vrai pour `L8`, `L11a`, `L12`… et
  faux dès `L5` ou `L9`. Le motif réel n'est pas la **couche** mais **l'irréversibilité** :
  si un défaut passe inaperçu trois semaines, la donnée est-elle récupérable ? La règle
  corrigée est la section suivante — et elle classe correctement les tâches `V`, ce que la
  version « par couche » ne savait pas faire.
- **« La direction `2a` n'a aucun rayon, nulle part. »** Elle a donné la bonne réponse sur
  l'avatar de profil (carré, bloc `7f`, contre le rond de `1a`), et j'en ai conclu qu'elle
  était la règle. Elle est fausse : les personnes sont des **cercles** en 1:1 dans les blocs
  `4b`, `4c` et `4d`. Le motif réel est **« rien de photographique et rectangulaire n'a de
  coin arrondi »** — affiches, jaquettes, images. Une personne n'est pas une affiche ; un
  avatar de profil n'est pas un portrait mais une pastille de couleur qui désigne un compte.
  Formulée trop largement, la règle a livré `PersonTile` en rectangle 2:3 pendant trois lots.

Ce qu'il faut en faire : quand une règle se dégage d'un ou deux cas, **écrire le motif
avant la conséquence**, et vérifier que le motif explique aussi les cas qu'on n'a pas
regardés. Une règle dont la justification se résume à « c'est ce que j'ai vu jusqu'ici » se
note comme observation, pas comme doctrine.

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

# Sondes de rendu d'ecran — la SEULE suite qui charge l'app (TEST_HOST), donc la seule
# qui puisse instancier une vue de `App/`. C'est la porte de non-vacuite des taches `V`.
# macOS uniquement : la question qu'elle pose ne depend pas de la plateforme.
xcodebuild test -scheme CineShelfScreenTests -destination 'platform=macOS'

# Biometrie simulee — pour exercer LocalAuthenticationEvaluator contre le vrai systeme.
# Mesure du 2026-08-06 : `canEvaluate`, `biometryKind` et les chemins d'echec sont
# atteignables depuis un bundle de test SANS app hote ; un SUCCES ne l'est pas — le
# dialogue attend indefiniment. Il faudra une app au premier plan (V7).
xcrun simctl boot <udid>
xcrun simctl spawn <udid> notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
xcrun simctl spawn <udid> notifyutil -p com.apple.BiometricKit.enrollmentChanged
# puis, pendant l'evaluation, depuis l'hote :
xcrun simctl spawn <udid> notifyutil -p com.apple.BiometricKit_Sim.pearl.match     # Face ID
xcrun simctl spawn <udid> notifyutil -p com.apple.BiometricKit_Sim.fingerTouch.nomatch
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
# La CI teste le catalogue sur les DEUX plateformes (job `catalog`, matrice iOS +
# macOS). Le lancer seulement sur macOS en local laisse passer un échec propre à
# la destination iOS, que rien ne signale avant le push. **`OS=latest` fait partie
# du geste** : c'est le spécificateur exact de la CI, et une commande locale qui
# l'omet ne joue pas le même chemin de résolution de destination.
xcodebuild test -scheme DesignSystemCatalog \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
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

**Et la mesure s'imprime à côté du plafond.** Un plafond calé sur le pire environnement ne
dit plus rien du confort réel : il ne reste que le chiffre imprimé pour le dire, et c'est lui
qu'on compare d'une session à l'autre. Un test de perf sans `print` ne mesure plus rien, il
surveille seulement l'effondrement.

## Une tâche `V` se termine par un rendu assené, jamais par « non vu »

**`ImageRenderer` ne demande aucune permission**, parce que rendre une vue dans un bitmap ne
passe par aucune API de capture d'écran. Il est dans le dépôt depuis `I2`. Pendant ce temps,
cinq vérifications visuelles ont été reportées faute de `screencapture`, et quatre sessions
d'affiches invisibles sont passées : **l'outil était là, la question ne lui était pas posée.**

Ce que je ne peux pas faire reste vrai — juger si c'est beau, c'est ton travail. Ce que je peux
faire et que je dois faire : **prouver que ce n'est pas vide.**

- **Une image attendue rend de la variance ; un aplat n'en a aucune.** C'est l'assertion qui
  aurait attrapé `MediaFill`. Mesuré à l'injection de la faute : la tuile fautive rend **deux**
  couleurs et non une — le symbole d'échec en dessine une seconde — donc « uniforme » seul ne
  mord pas. Le seuil utile est un compte de couleurs distinctes, pas un booléen.
- **Deux états qui doivent se distinguer se comparent deux à deux**, jamais en bloc : c'est la
  paire « en cours » / « en échec » qui était aveugle, et une assertion d'ensemble n'aurait pas
  dit laquelle.
- **`ImageRenderer` rend de façon synchrone**, donc un `.task` n'a pas tourné : sans attente,
  tous les états de chargement rendent le placeholder et la porte est aveugle **à nouveau**. La
  parade est de lire `cgImage` une première fois, laisser tourner la boucle, puis relire — voir
  `renderStats(_:settling:)`.
- La sonde a son **contrôle négatif** : un aplat doit être vu comme uniforme, sinon elle ne
  mesure rien.

En pratique, à la fin d'une tâche `V` ou `I` : au moins une assertion de non-vacuité sur ce que
la tâche dessine. Le tableau de vérification porte alors une ligne verte au lieu d'un « non
vu », et le « non vu » qui reste ne concerne plus que l'esthétique.

## Une étiquette ne dit rien de ce qui dépend de quoi

**Réordonner un plan d'après une étiquette — rigueur, priorité, taille — ignore le seul
classement qui ne se discute pas : les dépendances.** Une étiquette décrit une tâche ; une
dépendance décrit un ordre. Les confondre produit un plan qui a l'air bien rangé et qu'on ne
peut pas exécuter.

**Mesuré le 2026-08-06**, sur la compression du palier 3. « Les quatre tâches à rigueur
maximale passent en fin de palier » est une consigne raisonnable — et elle envoyait `L20` et
`L14` **après** `V6` et `V7`, qui ne se livrent pas sans elles. Le tableau se serait lu comme
cohérent jusqu'à la première tâche impossible à commencer.

Trois autres erreurs de la même passe ont la même forme — **une propriété affirmée sans être
vérifiée contre la source** :

- « `V8` est un doublon de `V3` » : `V3` est la galerie, `V8` l'import et l'export. La retirer
  laissait trois tâches faites sans écran, dont deux à rigueur maximale ;
- « `L15` est à rigueur maximale dans le palier 3 » : elle est reportée en v1.1, donc absente ;
- « `L14` est à rigueur maximale » : le classement dit « légère **sauf** la portée du
  déverrouillage ».

C'est le même motif que **comparer des nombres hors contexte** — 3 colonnes contre 2 sans
vérifier que les deux blocs rendent la même largeur. Dans les deux cas, une valeur est lue
correctement et rapprochée d'une autre qui ne parle pas de la même chose.

**Le geste, avant tout réordonnancement : relire la colonne « Ce qu'elle débloque » et les
« Ne pas livrer sans », pas la colonne « Rigueur ».** Et avant de retirer une ligne : chercher
ce qui pointe vers elle. `grep -n 'V8' docs/PROMPTS.md` répondait en une seconde — sept écarts
inscrits y menaient.

Corollaire, et il vaut pour moi : **quand une consigne repose sur une propriété du plan, la
vérifier avant de l'appliquer, et dire ce qu'on a trouvé.** Appliquer en silence une prémisse
fausse produit un document faux qui porte une signature de validation.

## Un défaut trouvé se rapporte avec son âge

**Un défaut trouvé dans du code écrit dans la même session ne prouve pas la même chose qu'un
défaut trouvé dans du code déjà là.** Le premier dit que je me relis ; le second dit que la
passe de rigueur sert. Les confondre fait croire qu'une sonde a travaillé alors qu'elle n'a
rattrapé que sa propre écriture.

**Mesuré le 2026-08-06, sur `L20`.** Ma sonde avait trouvé deux défauts, et je les avais
rapportés comme un résultat. Ils étaient tous les deux dans du code écrit **dix minutes plus
tôt**. À la même rigueur, `L11b` en avait trouvé cinq, `L12` neuf, `L10` un bug de notation,
`L1` trois hypothèses fausses — tous dans du code antérieur. La question « `L20` était-elle
simple ou sous-exercée ? » n'a pu être posée que parce que le rapport ne faisait pas la
distinction. Elle était sous-exercée : la fusion était **entièrement inannulable**, et aucun
test d'édition en masse ne pouvait le montrer.

En pratique, dans le rapport et le journal : **dire pour chaque défaut s'il est de la session
ou antérieur.** Et quand tous les défauts d'une tâche à rigueur maximale sont de la session,
le dire aussi — c'est le signal qu'il faut chercher ailleurs, pas la preuve que le code était
sain.

Le corollaire, qui découle du même incident : **une tâche dont la moitié du domaine n'est
exercée par aucun test peut être déclarée finie sans que rien ne proteste.** `L20` couvrait
l'édition en masse par quatorze tests et la fusion par zéro, alors que sa fiche exige que les
deux « s'annulent par le même chemin ». Avant de déclarer finie une tâche à rigueur maximale,
relire sa fiche **phrase par phrase** et pointer le test qui couvre chacune.

## Une capacité lue et jamais écrite est un écran qui ment

**Une propriété que le code sait *afficher* mais que rien ne sait *écrire* produit une
interface cohérente et inerte.** Rien ne casse, rien ne prévient : l'écran rend simplement la
valeur par défaut, pour toujours. C'est indétectable à la relecture du code d'affichage, qui
est correct.

**Mesuré à `V4`/`V5b` : cinq occurrences dans une seule tâche**, ce qui en fait une classe de
défaut et non cinq oublis.

- `Genre.isPinned` et `pinIndex` étaient posés à la fermeture du schéma et **lus par `HomeView`
  depuis `V5a`** — l'accueil affichait donc une configuration que l'utilisateur ne pouvait pas
  faire, et aucun test ne pouvait le voir puisque le rail *fonctionne* quand la donnée existe ;
- `PersonFilter` n'avait pas de tri, alors que le bloc `4c` pose un menu « Trier » ;
- `SavedLink` n'avait ni repository ni conformité à `ActivityDescribing` : le cas
  `ActivityEntityType.savedLink` existait **sans habitant**, lisible avant d'être écrivable ;
- `PrecisionDateRow`, `TokenFieldRow` et `ValidationSummary` n'avaient **aucun appelant de
  production**, donc la conversion `PrecisionDate` ↔ `Date` n'existait pas ;
- `PosterCardModel(_ person:)` ne passait aucune `imageURL` — un portrait attaché ne
  s'affichait nulle part.

**Le geste, avant de livrer un écran : pour chaque propriété que l'écran lit, chercher qui
l'écrit.** C'est un `grep` sur le nom du symbole, pas une relecture — s'il n'apparaît qu'en
lecture et dans le modèle, la chaîne est ouverte.

```bash
grep -rn "isPinned" App/ Packages/*/Sources | grep -v "Tests"
# lectures seules + déclaration = personne ne l'écrit
```

**Le corollaire, et il est symétrique** : une capacité **écrite et jamais lue** est le même
défaut vu de l'autre bout. `ActivityEntry` a été écrit pendant quinze prompts avant que quoi
que ce soit le relise — une piste d'audit qu'on ne lit jamais est une piste d'audit qu'on n'a
pas. Les deux se cherchent avec le même `grep` ; ce qui change est la colonne qui manque.

## Infirmer une contrainte documentée demande la même rigueur que l'établir

**Retirer une limitation écrite est une écriture, pas une lecture.** On l'aborde pourtant avec
l'humeur inverse : établir une contrainte se fait en la mesurant, l'infirmer se fait souvent sur
un indice — et l'indice suffit à donner l'autorisation qu'on cherchait.

**Mesuré le 2026-08-06, et c'est moi qui l'ai commis.** `project.yml` disait « iOS uniquement :
sur macOS les tests UI réclament l'autorisation d'accessibilité ». J'ai lancé la suite sur Mac,
vu `testAppLaunches` passer, et écrit « mesuré, elle y tourne, le commentaire était faux ». Le
test passait parce que `wait(for: .runningForeground)` lit un **état de processus** et non l'arbre
d'accessibilité : sans l'autorisation, la suite est **verte sur ce qu'elle n'exerce pas et vide
sur le reste** — donc pire que si elle ne tournait pas. Le commentaire avait raison ; il était
seulement imprécis sur la conséquence.

**L'ironie est le vrai enseignement** : je croyais appliquer la règle sur la fausse dette — « une
contrainte écrite mais jamais éprouvée coûte le temps d'une vraie ». Elle vaut, et son symétrique
aussi : **une contrainte déclarée périmée sur une preuve trop faible coûte davantage**, parce
qu'elle transforme un obstacle connu en défaut mystérieux.

En pratique, avant d'écrire qu'une limitation documentée ne tient plus :

- **nommer ce que la mesure a réellement exercé**, et ce qu'elle n'a pas pu exercer. « Le test
  passe » n'est pas « la contrainte est levée » ;
- **chercher le chemin par lequel la contrainte se manifesterait**, et vérifier qu'il a été
  emprunté. Ici : lire un élément de l'arbre, pas seulement l'état du processus ;
- **si la contrainte prescrit sa propre vérification, la jouer en entier.** Le commentaire sur le
  bug XcodeGen demandait « relancer la reproduction, *puis* retirer les réglages et vérifier les
  deux builds ». La reproduction ne reproduit plus ; le second temps n'a pas été joué, donc la
  contrainte reste en place **avec son audit inscrit** plutôt que retirée à moitié.

C'est la même famille que « un tableau de vérification ne porte que des commandes réellement
passées », appliquée aux contraintes plutôt qu'aux résultats.

## Une règle qui entre ici se propage à ce qui existait avant elle

**Une règle écrite mais jamais propagée ne protège que le code écrit après elle**, et c'est la
même famille que la fausse dette : dans les deux cas le document dit vrai, et le dépôt dit
autre chose. La différence est qu'ici personne ne le découvre avant que ça casse.

**Mesuré, deux fois, sur la même règle.** Le corollaire ci-dessus est né le 2026-08-04 d'un
test qui échouait — les 200 vignettes, 15 ms en local contre 266 ms sur le runner. Il a été
écrit, et **il n'a été appliqué qu'au test qui l'avait provoqué**. Deux seuils calés sur une
mesure locale sont restés en place :

- `SearchPerformanceTests`, plafond à 40 ms — « quatre fois la mesure haute », locale. Il a
  rougi la CI le 2026-08-05, à 80,5 ms ;
- `TitleFilterPerformanceTests`, plafond à 25 ms — « cinq fois la mesure », locale aussi.
  Trouvé par l'audit du 2026-08-06, **avant** qu'il rougisse. Il devait rendre ~40 ms sur le
  runner, donc il aurait rougi.

Le second est le plus instructif : il était vert, donc rien ne le signalait, et il l'était par
chance. Un test vert n'est pas une preuve de conformité à une règle qu'il enfreint.

**Ce que ça ajoute à la routine, en une ligne : quand une règle entre dans ce fichier, chercher
ce qui l'enfreint déjà, et le dire — même sans le corriger.** Le geste est un `grep` sur le
motif que la règle interdit, pas une relecture. Pour les seuils de performance, c'était :

```bash
grep -rn "#expect(.*\(duration\|elapsed\|milliseconds\|seconds\)" Packages/*/Tests Tests
```

Corriger tout de suite n'est pas obligatoire — inscrire l'écart suffit, et c'est mieux que de
rouvrir trois fichiers au milieu d'une autre tâche. **Ce qui n'est pas acceptable est de ne pas
regarder** : la règle s'écrit alors comme une intention, et la prochaine occurrence coûtera une
CI rouge et une session de diagnostic.

Le même geste vaut pour les règles de lint : une règle neuve se lance sur tout le dépôt avant
d'être ajoutée, jamais seulement sur le fichier qui l'a motivée.

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
8. **`git push origin main`.** Sans le demander - voir la règle d'ouverture et de
   clôture de session plus haut.

## Le tableau des écarts se relit à chaque fin de palier

**Un écart résolu qu'on n'a pas rayé coûte exactement le temps d'un vrai.** Il envoie
chercher un défaut qui n'existe pas, et le jour où on s'en aperçoit il fait douter de tout
le reste du tableau - qui n'a pourtant rien fait de mal. C'est le pire des deux mondes :
le travail est perdu *et* la confiance aussi.

Mesuré le 2026-08-05, à la première relecture complète des « Écarts connus » de
`docs/PROMPTS.md` : sur **86 lignes**, deux étaient déjà réglées sans être rayées, trois
étaient devenues sans objet, et quatre pointaient vers une tâche **qui n'existe pas** ou
qui est close. Neuf lignes sur 86, soit une sur dix, ne disaient plus la vérité. Le
déclencheur avait été une trouvaille fortuite pendant `L5`.

La relecture se fait **à chaque fin de palier**, jamais « plus tard ». Trois verdicts par
ligne, et le troisième est celui qu'on oublie :

- **résolue** → la rayer avec `~~…~~`, en nommant **ce qui** l'a résolue (commit ou tâche).
  Ne pas la supprimer : une ligne rayée dit qu'on y a regardé, une ligne absente ne dit
  rien ;
- **toujours valable** → la garder, et **vérifier sa destination**. Une colonne
  « Où ça se règle » qui nomme un numéro de prompt abandonné ou une tâche déjà close est
  aussi trompeuse qu'un écart périmé ;
- **devenue sans objet** → la retirer, mais **écrire pourquoi** dans le bloc de relecture
  sous le tableau. Un retrait sans trace se relit comme un oubli, et quelqu'un la
  réintroduira.

Le piège de méthode : les lignes qui rouillent sont celles qui **nomment un symbole** -
`startObservingMemoryPressure()`, `Typo.sectionTitle`, `Sidebar.swift`, `PosterCard`. Une
ligne de doctrine (« les prédicats sont construits à la main, et voici pourquoi ») ne
rouille pas. Commencer la relecture par un `grep` de chaque symbole cité est donc plus
efficace que de relire dans l'ordre.

   > **Le hash s'inscrit dans un commit *suivant*, jamais par `--amend`.** Amender
   > change le hash : le tableau se met alors à désigner un commit qui n'existe
   > plus dans l'historique poussé, et il n'y paraît rien — c'est arrivé sur `L2`,
   > `L3` et `L4`. Vérification en une ligne, quand un doute existe :
   > `grep -oE '\`[0-9a-f]{7}\`' docs/PROMPTS.md | tr -d '\`' | while read h; do`
   > `git merge-base --is-ancestor $h HEAD || echo "$h orphelin"; done`
   >
   > **Amender après avoir inscrit le hash impose de réécrire le tableau.** C'est arrivé
   > le 2026-08-05 : un `--amend` sur le commit de l'écart 5 (pour recompacter un JSON
   > reformaté par mégarde) a fait de `d8acdda` un orphelin, et c'est la commande de
   > vérification ci-dessus qui l'a attrapé - pas moi.
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
