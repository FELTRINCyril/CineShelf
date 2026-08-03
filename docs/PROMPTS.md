# CineShelf — le plan et son avancement

Ce document est le **seul** endroit où se suit l'avancement. Il contient, dans cet
ordre :

- le **récapitulatif** des prompts, fait et à faire ;
- les **écarts connus** ;
- « La bascule de direction artistique » : ce qui est obsolète, ce qui survit ;
- « Tâches LOGIQUE » (`L1`, `L2`...) — c'est là qu'on travaille aujourd'hui ;
- « Tâches VUES » (`V…`) — gelées jusqu'à la validation du nouveau design ;
- le texte des prompts historiques (numérotés `# 1` à `# 25`), conservé pour mémoire.

> `GUIDE-EXECUTION.md` et `05-ROADMAP-NATIF.md` sont archivés dans `_archive/` :
> leur contenu de suivi vit ici désormais.

---

## Récapitulatif

### Ce qui est fait

| # | Quoi | Qui | Docs à lire | État |
|---|---|---|---|---|
| 4 | Installation du projet | Code | `_archive/SETUP.md` | ✅ `03fff62` |
| 5 | Modèle de données (17 `@Model`) | Code | `02` `04` | ✅ `d5e7cb9` |
| 6 | Repositories & outillage | Code | `04` | ✅ `451f6da` |
| — | Ménage (doc, CI, journal) | Code | — | ✅ `ad95dcc` |
| 13a | Pipeline médias — **logique seule** | Code | `04 §4` | ✅ `d1810d1` |
| 7 | Tokens | **Design** | ex-`01` | ✅ livré — **direction abandonnée**, voir « La bascule de direction artistique » |
| 8 | Composants | **Design** | ex-`01 partie D` | ✅ livré — **anatomie abandonnée**, voir « La bascule de direction artistique » |
| 8bis+9 | Intégration DesignSystem + catalogue | Code | — | ✅ `ee3b88c` |
| — | Budgets perf, chasse Archivo, doc | Code | — | ✅ `0aa8d05` |
| 10 | Navigation adaptative | Code | ex-`01 partie C`, `04 §2` | ✅ `dc15a48` — **banc d'essai**, voir « La bascule de direction artistique » |
| 11 | Titres (liste + détail + éditeur) | Code | `03 §4` | ✅ `58b4b26` — **banc d'essai**, voir « La bascule de direction artistique » |
| — | Corbeille des genres, invariant `DemoCatalog` | Code | — | ✅ `c5bdb58` |
| — | Entitlements par SDK, couleurs sémantiques | Code | — | ✅ `ce3e63c` |
| — | Grille des titres vide derrière 42 tests verts | Code | — | ✅ `e0f0f0b` |
| `L1` | Requêtes interrogeables — titres et personnes | Code | `02 §3 §5`, `04 §3` | ✅ `eb05149` `e347b11` |
| — | CI réparée, invariant des relations verrouillé | Code | — | ✅ `8ae4dfb` |
| `L2` | Service de recherche | Code | `02 §5`, `04 §6` | ✅ `6ea6a8e` |
| `L3` | Indexation Spotlight | Code | `02 §5`, `04 §6`, `03 §9` | ✅ `4e696ee` |
| `L4` | Mathématiques du recadrage | Code | `02 §2.4 §3.7`, `04 §4` | ✅ `07890db` |

### Ce qui reste — chaque prompt est coupé en deux

La colonne **LOGIQUE** renvoie aux tâches `L…`, la colonne **VUES** aux tâches `V…`. On fait toute la logique d'abord ; les vues attendent le design.

| # | Quoi | LOGIQUE | VUES | État |
|---|---|---|---|---|
| 12 | Recherche + Spotlight | `L2` `L3` | `V1` | ⬜ |
| 13b | Médias — recadrage, préchargement, import d'images | `L4` `L5` | `V2` | ⬜ |
| 14 | Galerie + visionneuse | `L1 bis` (source, mélange) | `V3` | ⬜ |
| 15 | Personnes + doublons + fusion | `L8` `L9` | `V4` | ⬜ |
| 16 | Collections, genres, liens, accueil, fil | `L6` `L7` `L18` | `V5` | ⬜ |
| 17 | Console de gestion | `L10` | `V6` | ⬜ |
| 18 | Profils, bibliothèques, Face ID | `L14` `L15` | `V7` | ⬜ |
| 19 | Import/export CSV | `L11` `L12` | `V8` | ⬜ |
| 2 | **Dump de l'app web** | — (dépôt web) | — | ⬜ **dépendance dure de `L13`** |
| 20 | Migration des vraies données | `L13` | `V9` | ⬜ — **point de contrôle : geler `versionIdentifier`** (`02 §7` étape 0) |
| 21 | Config CloudKit | — (toi) | — | ⬜ abonnement requis |
| 22 | Synchronisation, maintenance, corbeille | `L16` `L17` | `V10` | ⬜ — `L17` reste ouverte jusqu'après le prompt 21 |
| 23 | Intégrations système | `L19` | `V11` | ⬜ |
| 24 | Accessibilité | — | `V12` | ⬜ contre le design final |
| 25 | Publication | — (toi) | — | ⬜ |
| 1 | Tests Playwright de référence | — (dépôt web) | — | ⬜ facultatif |
| 3 | Captures de l'app web | — (toi) | — | ⬜ facultatif |

Deux tâches logiques n'appartiennent à aucun prompt existant et se placent en tête :
`L1` (requêtes interrogeables, avant le gel du schéma) et, à la suite, tout le reste
dans l'ordre du tableau des tâches `L`. `L1 bis` en a été détachée — voir le critère
de découpage sur sa fiche.

> **Les docs ne se joignent plus** : elles sont dans `docs/` du dépôt, Claude Code les lit sur disque.
> **Suivi de l'avancement : ce document uniquement.** `docs/03` garde ses symboles (✅ ♻️ 🔀 ⛔ ⏸ ➕) — ils décrivent *l'intention* pour chaque fonctionnalité, pas l'état d'avancement. Ne pas mélanger les deux.
> À la fin de chaque tâche : cocher sa ligne, ici et dans le tableau des tâches `L`, avec le hash du commit.

> **Le handoff de design est dans le dépôt** — `docs/CineShelf design system-handoff.zip`,
> direction « 2a Plein cadre ». Ses copies de `03` et `06` sont **identiques** aux nôtres,
> vérifié : pas de seconde source de vérité pour l'instant, mais elles se figeront le
> jour où l'un des deux documents bougera. Ne jamais les lire à la place de `docs/`.
>
> **Deux erreurs à corriger dedans, au même endroit du modèle.** Son §7 « Comportements »
> écrit « **Contenu privé** : géré au niveau du **profil**, pas du titre. Un titre est
> privé parce qu'il appartient à un profil verrouillé par Face ID », et son §10 le
> répète dans les décisions arrêtées (« contenu privé au niveau du profil »). C'est faux
> dans notre modèle : `isPrivate` est porté **par l'entité**, un `Title` appartient à une
> `Library` et jamais à un `Profile`, et c'est `Profile.hidesPrivateContent` qui décide
> de l'**affichage**. La conséquence est concrète — suivre le handoff rendrait un titre
> privé visible dès qu'un profil permissif est ouvert, et le rendrait indexable dans
> Spotlight, dont l'index est unique pour l'appareil. Règle et argument dans `docs/04` §6.
>
> Ce que le handoff dit du **rendu** reste valable : géométrie exacte de l'affiche,
> aplat `private.mask`, `eye.slash` sur la vignette masquée. C'est le *déclencheur* qui
> est faux, pas l'apparence.

> **Prochaine passe transverse : la fermeture du schéma, avant `L10`.** La fenêtre de
> gratuité se referme à `L13`, et un champ manquant découvert après le gel coûte un plan
> de migration. La passe balaie tout ce qui pourrait encore réclamer une modification de
> schéma — `ActivityEntry.payload` pour `L20`, ce que `L4` a révélé sur `MediaCrop` (rien :
> un seul recadrage sert tous les ratios), le handoff de design et `docs/03` relus en
> cherchant les données supposées mais non stockées, les tâches `L` et `V` restantes lues
> avec la même question, et les champs mal typés ou mal nommés qui méritent d'être
> corrigés maintenant plutôt que jamais. **La liste se rend avant d'écrire.** On ajoute
> les champs sans la logique qui les consomme, puis `docs/02` et ce document marquent le
> schéma comme fermé.

**Écarts connus, à reprendre plus tard** (tenus à jour au fil des sessions) :

| Sujet | Où ça se règle |
|---|---|
| **L'interface des prompts 10 et 11 est un banc d'essai.** Coquille de navigation, grille des titres, fiche, éditeur, filtres : ils restent en place pour exercer la logique et voir tourner les tâches `L`, pas pour être livrés. On n'y investit plus rien — aucune retouche esthétique, aucun composant nouveau, aucun polissage — et on ne les supprime pas. Les écarts d'apparence qu'on y trouvera ne sont pas des bugs : ils seront tranchés par le nouveau design. Les écarts de **logique**, eux, restent à corriger normalement | `V1`…`V12`, après validation du design |
| **Le hero remplit toujours son cadre.** Les médias sont de formats variés (2:3, 16:9, ce qu'on veut) et un hero ne doit **jamais** laisser de bandes noires : il remplit et recadre. `MediaSlot.backdrop` et `CropContext.hero` existent pour ça. **Vérifié aujourd'hui** : `backdrop` est bien lu (`TitleFormat.backdropAsset` → `AssetURL.backdrop` → hero 16/9 de `TitleDetailView`), et `MediaThumbnail` remplit déjà par `scaledToFill` dans un cadre `aspectRatio` — donc pas de bandes. **`crop(for:)` est branché depuis `L4`** — `App/Media/CropDisplay.swift` est son appelant, et `CropContext.hero`, `.card` et `.detail` sont lus pour de vrai. Reste une réserve :  sans média `backdrop`, la fiche n'affiche **aucun** hero, au lieu de se replier sur la jaquette. À trancher avec la nouvelle direction | `V2` |
| Tous les écarts ci-dessous étiquetés d'un numéro de prompt d'interface (13b, 15, 16, 18, 24) sont **suspendus** au même titre : leur part logique passe dans une tâche `L`, leur part visible attend le design | Tâches `L` · tâches `V` |
| Édition du casting, des genres et de la collection depuis l'éditeur de titre. **`V4` et `V5` doivent passer par les mutateurs de relations de `TitleRepository` et `PersonRepository`** (`setCollection`, `setGenres`, `addCredit`, `removeCredit`, `move`, `setRoles`) — écrire dans `.genres`, `.credits`, `.collection` ou `.library` depuis une vue rendrait le filtre correspondant faux **en silence**, puisque `filterKeys` en dérive. La règle SwiftLint `no_relation_write_outside_core` le refuse à la compilation, donc le sujet ne peut plus être manqué : il ne reste qu'à brancher l'interface sur ces méthodes | `V4` · `V5` |
| `seasonCount` / `episodeCount` lus mais non éditables | 11 bis |
| Duplication d'un titre (`contextMenu` « Dupliquer » de l'ex-`docs/01` partie C, aujourd'hui archivé) | 11 bis |
| Suggestion de casting (`docs/03` §4) : aucune infrastructure | `L9` |
| `MediaSlot.portrait` (jaquette portrait alternative) jamais lu | `V2` |
| `.navigationTransition(.zoom)` : la source est déclarée par `PosterCard`, mais son `@Namespace` est privé à la grille — le chaînage vers la destination manque | `V2` |
| Pas de `fetchLimit` progressif : `@Query` tout chargé (décision actée, à revoir au-delà de ~10 000 titres). **Chiffré par `L1`** : matérialiser 5 000 titres sans filtre coûte **248 ms**, contre 5,3 ms pour une requête filtrée qui en rend 32. Ce n'est donc pas le prédicat qui coûte, c'est le nombre d'objets rendus — et c'est ce chiffre-là qu'un `fetchLimit` ferait baisser. `TitleFilterPerformanceTests` le mesure à chaque exécution. **C'est une tâche `V`, pas `L`** : la vue sans filtre est l'écran par défaut, donc ce qui reste à faire est un `fetchLimit` progressif et son déclenchement au défilement — de l'interface, pas de la logique. Rien à décider avant que le nouveau design dise comment la grille se charge | `V3` · `V6` |
| **Les prédicats de `TitleFilter` et `PersonFilter` sont construits à la main**, pas par `#Predicate` : la macro plafonne à **cinq clauses** sur un `@Model` (mesures dans `docs/02` §5). Ce n'est pas une dette, c'est la seule forme qui tienne — mais elle a un coût de lisibilité, et deux règles en découlent. **Une** : tout critère nouveau passe par `predicateClause(active:)` et rejoint un sous-arbre existant, il ne se rajoute pas à une chaîne `&&`. **Deux** : ne jamais rallonger un `#Predicate` existant sans mesurer, parce qu'un prédicat dont la compilation passe de 200 ms à 1,3 s ne se signale pas. Concerne `L2`, `L3`, `L18` et tout ce qui interroge le magasin | permanent |
| **Les items Spotlight n'ont pas encore de vignette.** `SpotlightIndexer` prend une fermeture qui les fournit, et la valeur par défaut ne rend rien : `CineShelfCore` ne peut pas importer `MediaKit`, la règle de dépendances de `04 §1` va dans l'autre sens, donc c'est à l'appelant de brancher le cache. Les items sont indexés sans image — moins joli, jamais faux. À brancher quand `L5` aura le préchargement et l'échelle d'écran, avec le preset `thumb` de `04 §4` | `L5` |
| **`TitleCollection` et `SavedLink` n'ont volontairement pas de `filterKeys`**, contrairement à `Title` et `Person`. Ce n'est pas une harmonisation en retard, c'est un arbitrage : la dénormalisation coûte un **invariant permanent** — un champ dérivé de plus à recalculer à chaque écriture, et une porte de plus à garder fermée — alors que ces deux tables comptent des dizaines de lignes, pas des milliers. La jointure `library?.id` ne se paie qu'en SQL, où elle est négligeable à cette échelle. Ce que la traversée coûtait vraiment, c'était le budget de vérification de types (7 253 ms et 7 446 ms avec `#Predicate`), et l'arbre manuel de `CollectionQuery` / `SavedLinkQuery` le règle sans rien dénormaliser. **Ne pas « harmoniser » sans mesurer d'abord** : la bonne raison d'ajouter `filterKeys` serait un critère de filtre que la jointure ne sait pas exprimer, ou un volume qui a changé d'ordre | permanent |
| **Le store de préférences d'affichage ne portera que `layout` et `size`**, alors que `02 §3.10` décrit `{layout, size, pageSize, sort, dir}`. `pageSize` est abandonné par `03` (§2 : `LazyVGrid` charge à la demande). `sort` et `dir` sont déjà portés par `TitleFilter`, que `NavigationModel` sérialise et restaure au lancement : les mettre aussi dans le store créerait deux sources de vérité, et les y mettre sans les brancher serait du code « au cas où ». **Le jour où le tri doit persister par contexte, c'est `TitleFilter` qui lira le store — jamais le store qui dupliquera `TitleFilter`.** Le sens de cette dépendance n'est pas négociable : l'inverse redonne deux vérités | `L1 bis` |
| `AppIcon.appiconset` déclare 11 emplacements sans un seul nom de fichier : `actool` ne produit rien et l'app n'a **pas d'icône**. L'icône viendra de Claude Design | avant 25 |
| `Typo.sectionTitle` inutilisé dans `App/` : **décision actée** — aucun en-tête de section n'est aujourd'hui sans style, donc rien à y brancher. Les quatre en-têtes de contenu de `TitleDetailView` gardent `railLabelStyle()` ; les promouvoir serait un changement de hiérarchie visuelle (12 → 20 pt de base sur iOS, perte des majuscules et du `tracking`), pas un branchement. À reprendre au prompt 16, qui écrit Accueil, Collections et Genres — de vrais groupes de contenu. Poser alors `sectionTitle` **une fois**, dans un `sectionTitleStyle()` sur le modèle de `railLabelStyle()`, plutôt que sur chaque appelant : ce serait un ajout aux composants, dont l'anatomie est désormais à refaire (voir la bascule) | `V5` |
| Prédicat de production sans couverture : **il n'en reste qu'un**, `Bootstrap.existingProfile`, structurellement inatteignable en test — il ne sert qu'au cas d'une relation inverse désynchronisée par CloudKit. Les six qui étaient déclarés dans des vues (`MediaEnvironment`, `TitleDetailView`, `RouteInspector`, `Sidebar`, `TitleFilterSheet`, `DemoCatalog`) sont rapatriés dans `CineShelfCore/Queries/EntityQueries.swift`, couverts par `EntityQueryTests`, et la règle `no_predicate_outside_core` interdit qu'un septième réapparaisse dans une vue | `L17` |
| `MediaRepository.asset(withID:)` : code mort, aucun appelant dans le dépôt | — |
| `ColorTokens.typedAccessor(for:)` n'a plus d'appelant de production depuis que `ProfileSession.accentColor` est un `switch` sur `ProfileAccent` : API `public` exercée par les seuls tests. La garder tant que le catalogue peut en avoir besoin, sinon la passer `internal` | — |
| **Teinte de profil : deux choix seulement** (`accent/solid`, `accent/text`). Ce sont les deux seuls jetons d'accent à alpha 1 ; `accent/soft` est un lavis de fond (alpha 0,10 à 0,22) qui rendrait l'accent invisible en `.tint`. Si le prompt 18 veut de vraies couleurs par profil, il faudra étendre la palette dans `colors.tokens.json`, pas réutiliser les rôles existants. **La palette entière étant à refaire, ce point se tranchera avec la nouvelle** | `V7` |
| Grille non navigable au clavier sur Mac (`PosterCard` ouvre par `onTapGesture`, sans `focusable()`) | `V12` |
| `MediaEnvironment.displayScale` jamais alimenté : vignettes générées en @2x quelle que soit la dalle | `L5` |
| `DemoCatalog` hors des repositories : **décision actée** — une fixture n'est pas une action utilisateur, et on ne veut pas 300 `ActivityEntry` fictives dans le fil. L'invariant `refreshDerived()` tient et `DemoCatalogTests` le vérifie. Reste factice : `MediaAsset.checksum` et `blurHash` non calculés | — |
| `Profile.requiresBiometry` affiché mais non appliqué | `L14` |
| Préchargement de l'écran suivant | `L5` |
| `MediaRepository.attach` + invariante `hasExactlyOneOwner` | `L16` |
| `Bootstrap` ne branche pas `startObservingMemoryPressure()` : le cache n'est instancié par personne tant qu'aucune vue n'affiche d'image | `L5` |
| Dédoublonnage médias : global au magasin (décision actée) | — |
| Reprise d'import par lot de 200, pas par élément | `L11` · `L13` |
| `⇧⌘I` / `⇧⌘E` présents mais grisés | `V8` |
| Avertissement à l'écran quand un profil change de bibliothèque | `V7` |
| Bloc « Bibliothèques » de la barre latérale affiché mais inerte | `V7` |
| Les 36 primitives sont générées dans le `.xcassets` alors qu'aucune vue ne doit les lire — à élaguer si le poids devient un sujet | — |
| Le pont `Binding<AppSection?>` de `Sidebar` avale la désélection : si un état « rien de sélectionné » devient nécessaire, c'est `NavigationModel.section` qu'il faudra rendre optionnelle, pas la vue | — |

---

# La bascule de direction artistique

`01-DESIGN-SYSTEM-APPLE.md` spécifiait le mauvais registre : une app de
**bureautique Apple** — barre latérale, `Table`, `Form`, inspecteur, chrome système
partout — alors que CineShelf est un catalogue de films qu'on ouvre le soir. Le bon
voisinage est l'app TV d'Apple, Plex, Infuse. Le document est archivé dans
`_archive/OBSOLETE-design-system-productivite.md` et remplacé par
[`06-BRIEF-DESIGN.md`](./06-BRIEF-DESIGN.md), qui est un **brief** et non une
spécification : la nouvelle direction part des écrans, les tokens seront déduits à la
fin (étape 8 de la méthode du §6 de ce brief).

Rien n'est supprimé du dépôt pour autant. Ce qui suit dit ce qui ne fait plus foi et
ce qui reste debout.

### Obsolète — ne plus s'y référer, ne rien y raccrocher

| Quoi | Précision |
|---|---|
| **Les valeurs de palette** | Les six primitives et leurs rampes, les rôles sémantiques et leurs valeurs. Le mécanisme reste (ci-dessous), les valeurs sautent |
| **Le choix typographique** | Archivo Variable et l'échelle de `Typo`. La règle « aucune taille fixe, `relativeTo:` partout » reste |
| **L'anatomie des 7 composants** | `StateView`, `FieldRow`, `FilterBar`, `DisplayMenu`, `MediaThumbnail`, `PosterCard`, `ShelfRail`, `CatalogGrid` : leur découpage interne, leurs marges, leurs badges, leur `ShelfRail` « signature ». Ce que fait chaque composant reste utile comme inventaire de besoins, pas comme spécification |
| **L'architecture de navigation actuelle** | `TabView` 5 onglets en compact, `NavigationSplitView` 3 colonnes en régulier, barre latérale à sections : **elle va changer**. Le brief annonce des rails et des grilles, pas une arborescence |
| **Tout chrome système appliqué par défaut** | `Form`, `List` sur fond système, `.inspector`, barres d'outils standard : à ne plus poser par réflexe. Les surfaces de gestion pourront en garder, mais c'est une décision par écran, pas un défaut |

### Conservé — c'est de l'architecture, pas de l'esthétique

| Quoi | Pourquoi ça survit |
|---|---|
| **Les 3 niveaux de tokens** (primitives → sémantiques → composants) | La nouvelle palette se coulera dedans. C'est la structure qui rend une bascule de direction possible sans toucher les vues |
| **L'Asset Catalog et ses 4 apparences** (Any, Dark, Any High Contrast, Dark High Contrast) | Le contraste élevé et le thème clair sont des contraintes du brief (§4), pas des variantes optionnelles |
| **`scripts/generate-colors.py`** et `colors.tokens.json` | Une source unique, ~80 jeux × 4 apparences générés. C'est ce qui permettra de remplacer toute la palette en une commande |
| **`ColorAssetTests`** | Il attrape les défaillances silencieuses : un jeu manquant ne casse pas la compilation, il rend juste une couleur fausse au runtime. À garder tel quel, il vaudra encore plus après la bascule |
| **La couture par modèles de présentation** | `PosterCardModel` et ses pairs : `DesignSystem` ne connaît pas `Title`, `CineShelfCore` ne connaît pas SwiftUI, et la conversion vit dans un seul fichier par feature (`App/Features/Titles/TitlePresentation.swift` en est le patron). C'est exactement ce qui rend les tâches `L` insensibles au design |
| **Les règles de lint** | Aucune couleur littérale hors de `DesignSystem`, aucune taille de police fixe. Elles valent pour n'importe quelle direction artistique |
| **La matrice `layout × size`** | `portrait \| landscape` × `compact \| medium \| large`, réglable sur 8 contextes, persistée par profil. **C'est une fonctionnalité de l'app**, pas une décoration : le nouveau design doit la rendre, pas la remplacer |
| Les budgets de perf de `04 §4` | Mesurés, indépendants de l'apparence |

### Ce qu'on ne fait plus jusqu'à nouvel ordre

Aucun travail d'interface nouveau sans accord explicite : ni écran, ni composant, ni
retouche esthétique de l'existant. Règle reportée dans `CLAUDE.md`.

---

# Tâches LOGIQUE — c'est ici qu'on travaille

**Ce que « logique » veut dire ici :** aucun `import SwiftUI`, aucune vue, aucun
token. Testable par `swift test` dans un package, ou par `Tests/CineShelfTests` quand
le type doit vivre dans `App/`. Le résultat doit rester juste quel que soit le design
qui l'affichera.

**Trois règles pour toutes les tâches `L` :**

1. **Écrire dans `Packages/`** — `CineShelfCore` pour tout ce qui touche le modèle et
   les services, `MediaKit` pour l'image. Rien dans `App/Features/`, sauf quand un
   type existant y vit déjà (`TitleFilter`, `TitlePresentation`) : on le complète là
   où il est plutôt que de créer un doublon.
2. **Tout test de `#Predicate` passe par le magasin** (`save()` puis `fetch`) — voir
   `CLAUDE.md`. C'est la règle qui a coûté 42 tests verts sur une grille vide.
3. **Toute écriture appelle `refreshDerived()`**, et `CloudKitConformanceTests` passe
   avant le commit.

### Le chemin critique — dans cet ordre

**Pourquoi cet ordre, et pas un autre.** La nouvelle direction artistique ne pourra
être jugée que sur les **vraies affiches**, pas sur des dégradés générés. Les vraies
affiches arrivent avec `L13`. Le chemin le plus court vers `L13` est donc le chemin le
plus court vers la capacité à valider le design : c'est le seul critère
d'ordonnancement qui compte aujourd'hui.

```
L1 → L2 → L3 → L4 → L10 → L11 → L12 → prompt 2 → L13
```

| # | Tâche | Objectif en une ligne | Docs à lire | Dépend de | État |
|---|---|---|---|---|---|
| 1 | `L1` | Rendre interrogeables en SQL les critères de filtre des titres **et** des personnes | `02 §3 §5`, `04 §3`, écarts ci-dessus | — | ✅ `eb05149` `e347b11` |
| 2 | `L2` | Service de recherche : portées, résultats groupés, comptes, recherches récentes | `02 §5`, `04 §6` | `L1` | ✅ `6ea6a8e` |
| 3 | `L3` | Indexation Spotlight : indexer, désindexer, réindexer, jamais le privé | `02 §5`, `04 §6`, `03 §9` | `L2` | ✅ `4e696ee` |
| 4 | `L4` | Mathématiques du recadrage : geste ↔ `MediaCrop`, bornes, rect final | `02 §2.4 §3.7`, `04 §4` | — | ✅ `07890db` |
| 5 | `L10` | Édition en masse : décrire une mutation, l'appliquer à une sélection | `03 §12` | — | ⬜ **suivant** — mais voir « fermeture du schéma » ci-dessous |
| 6 | `L11` | CSV : lire, écrire, valider, résoudre les références, appliquer par lots | `03 §10`, `04 §7` | `L10` | ⬜ |
| 7 | `L12` | Archive `.cineshelfarchive` : écriture et relecture | `04 §7`, `03 §10` | `L11` | ⬜ |
| 8 | **prompt 2** | **Dump du bundle depuis l'app web** — dans le dépôt web, pas ici | `02 §7` étape 1 | — | ⬜ **dépendance dure de `L13`** |
| 9 | `L13` | Migration des vraies données depuis le bundle web | `02 §7` | `L1` `L3` `L4` `L11` `L12` **+ prompt 2** | ⬜ |

> **Le prompt 2 n'est plus une précaution, c'est une dépendance dure.** Sans le
> bundle exporté depuis l'app web, `L13` n'a rien à importer, l'app reste peuplée de
> `DemoCatalog`, et la direction artistique reste injugeable. Il se fait dans l'autre
> dépôt, il ne coûte rien à cette base de code, et il bloque tout le reste : à faire
> dès que `L12` est passée, sinon avant.

### Tâches d'appoint — à insérer quand tu veux changer de sujet

Elles ne sont sur le chemin d'aucune autre : aucune ne retarde `L13`, et aucune n'en
dépend. Utiles quand tu veux souffler ou avancer sur un autre front.

| Tâche | Objectif en une ligne | Docs à lire | Dépend de | État |
|---|---|---|---|---|
| `L1 bis` | Filtres de galerie (source, mélange à graine stable) et store de préférences d'affichage hors des vues | `02 §3.7 §3.10`, `04 §1 §3` | — | ⬜ |
| `L20` | **Annulation de l'édition en masse et de la fusion** — journal inversable | `02 §3.9`, `03 §12` | `L8` `L10` | ⬜ **touche au schéma, voir sa fiche** |
| `L5` | Préchargement de vignettes, pression mémoire, échelle d'écran | `04 §4` | — | ⬜ |
| `L6` | Génération d'une couverture en mosaïque | `03 §6`, `04 §4` | `L4` | ⬜ |
| `L7` | Aperçu de lien : `LPMetadataProvider`, délai, repli, libellé déduit | `03 §8` | — | ⬜ |
| `L8` | Détection de doublons et exécuteur de fusion | `03 §5`, `02 §3.4` | — | ⬜ |
| `L9` | Suggestion de casting | `03 §4` (ligne « Suggestion de casting ») | `L8` | ⬜ |
| `L14` | `AppLock` : authentification, délai de grâce, portée par profil | `02 §9`, `03 §1 ter` | — | ⬜ |
| `L15` | Transfert entre bibliothèques, clôture des dépendances, fusion des genres en double | `02 §2.2`, `03 §1`, `04 §5` | `L8` | ⬜ |
| `L16` | Maintenance et corbeille : orphelins, non référencés, purge à 30 jours | `04 §5`, `03 §3` | — | ⬜ |
| `L17` | État de synchronisation : machine d'états, les 6 cas, espace occupé | `04 §5` | — | ⬜ **jamais vérifiable avant le prompt 21**, voir sa fiche |
| `L18` | Sélections éditoriales (hero, rayons, ma liste, **fil d'activité**) et statistiques | `03 §11`, `06 §5.2` | `L1` | ⬜ |
| `L19` | App Intents, Handoff, partage entrant, données du widget | `03 §13`, `04 §12` | `L2` `L7` `L18` | ⬜ |

Parmi elles, `L1 bis` `L5` `L7` `L8` `L14` `L16` `L17` ne dépendent de rien du tout.

> **`L20` est la seule tâche d'appoint qui touche au schéma.** Elle a donc la même
> contrainte de fenêtre que `L1` : gratuite tant que `versionIdentifier` vaut `1.0.0`,
> plan de migration après le prompt 20. Si elle n'est pas faite avant, elle le devient.

Les fiches détaillées qui suivent sont rangées par **numéro** (`L1` à `L19`), pas dans
l'ordre d'exécution : c'est l'ordre où l'on retrouve une tâche quand on la cherche.
L'ordre de travail, c'est celui des deux tableaux ci-dessus.

`L1` reste première du chemin critique pour une seconde raison, indépendante du
design : elle touche le schéma, et doit donc passer **avant** le gel de
`versionIdentifier` que `L13` déclenche.

---

### `L1` — Requêtes interrogeables

**Objectif.** Sortir du filtrage en mémoire, pour les titres et pour les personnes.

**Pourquoi cette tâche s'arrête là où elle s'arrête.** Le découpage entre `L1` et
`L1 bis` suit un seul critère : **est-ce que ça touche au schéma ?** Ce qui le touche
appartient à `L1`, parce que le schéma est modifiable gratuitement aujourd'hui
(`versionIdentifier` à `1.0.0`, magasin effaçable) et coûtera un plan de migration
après le prompt 20. Ce qui ne le touche pas n'a aucune raison d'occuper la fenêtre de
gratuité, et part dans `L1 bis`, insérable n'importe quand. C'est le critère qui
justifiait la priorité de `L1` ; c'est donc lui qui doit la délimiter.

- Dénormaliser dans `Title` les identifiants aujourd'hui filtrés en Swift
  (bibliothèque, collection, genres, personnes créditées) en champs interrogeables, sur
  le modèle de `searchText`. Objectif chiffré : les cinq critères de l'écart connu
  passent dans le `#Predicate`, sur 5 000 titres, sous les 50 ms de `04 §4`.
- Maintenir ces champs dans `refreshDerived()`, et couvrir le cas qui les invalide
  sans passer par le titre : ajouter un crédit, renommer un genre, déplacer une
  collection.
- Filtres de personnes : tranches d'âge (jeune < 35, moyen 35–55, senior > 55), rôle,
  genre — mêmes bornes que la v1 (`04 §12`). Rôles et genres dénormalisés comme pour
  les titres ; l'âge **non**, voir sa fiche de raisonnement dans le code.
- Mesure du prédicat complet sur 5 000 titres, et l'écart « cinq critères filtrés en
  mémoire » rayé.

**Ce qui n'en fait pas partie :** les filtres de galerie et le store de préférences
d'affichage. Aucun des deux ne modifie le schéma → `L1 bis`.

**Terminé quand :** le catalogue n'est plus rapatrié en entier pour filtrer, un test
mesure le prédicat complet sur 5 000 titres, et l'écart « cinq critères filtrés en
mémoire » est rayé.

---

### `L1 bis` — Galerie et préférences d'affichage

**Objectif.** Ce que `L1` a laissé de côté parce que **ça ne touche pas au schéma** :
détaché pour ne pas occuper la fenêtre de gratuité du modèle, insérable n'importe
quand, y compris après le gel du prompt 20.

- Filtres de galerie : par source (titre / personne / collection / orphelin), et
  mélange à **graine stable** (le même ordre tant qu'on ne rafraîchit pas).
- Déplacer le store de préférences d'affichage de `App/Features/Titles/TitlesView.swift`
  vers `CineShelfCore` : clé `(profil, contexte)`, les 8 contextes, valeurs par
  défaut. Les prompts 14 à 17 le réutiliseront, il ne peut pas rester dans une vue.
  Charge utile `layout` + `size` seulement — voir l'écart correspondant.

**Deux pièges relevés à l'avance, à vérifier avant de construire dessus.**

1. **« Orphelin » écrit `asset.attachments?.isEmpty ?? true` est exactement la
   traversée de relation optionnelle qui fait sauter le budget de vérification de
   types** — c'est la découverte de `L1` : ce qui sature `#Predicate`, ce n'est pas le
   nombre de clauses, ce sont les traversées de relation optionnelle. À mesurer avant
   d'en faire la base du filtre de source. Les deux issues connues : interroger
   `MediaAttachment` plutôt que `MediaAsset` (le propriétaire y est une colonne, et
   « orphelin » devient une absence de ligne), ou dénormaliser sur `MediaAsset` — ce
   qui **retomberait dans le schéma** et ramènerait la tâche dans `L1`. Trancher par la
   mesure, pas par le goût.
2. **Les énumérations en double entre `CineShelfCore` et `DesignSystem`** (`layout`,
   `size`, les 8 contextes) sont acceptables — la règle de dépendances de `04 §1`
   interdit à l'un de connaître l'autre — mais elles deviennent un bug le jour où
   quelqu'un ajoute un cas d'un seul côté. **Écrire un test qui affirme que les deux
   jeux de `rawValue` sont identiques**, sans quoi la divergence sera silencieuse : un
   contexte présent d'un seul côté ne casse aucune compilation, il perd juste sa
   préférence au runtime.

---

### `L20` — Annulation de l'édition en masse et de la fusion

**Objectif.** Rendre défaisables les deux seules opérations qui touchent des dizaines
d'enregistrements d'un coup et qu'aucune main ne peut refaire à l'envers.

**Pourquoi ça manque, et pourquoi ce n'est pas la corbeille.** La suppression est déjà
réversible : `deletedAt` la met en corbeille, `restore` la ramène. C'est une opération
sur **une** entité, et elle a son filet. L'édition en masse (`L10`) et la fusion
(`L8`) n'en ont aucun : elles écrasent des champs et déplacent des relations sur toute
une sélection, et une erreur de sélection ne se rattrape pas — il faudrait retrouver à
la main la valeur d'avant de chaque enregistrement touché. C'est le point soulevé par
le design, et il est juste.

**Correction à la prémisse : `ActivityEntry.payload` n'existe pas.** Le modèle porte
aujourd'hui `id`, `actionRaw`, `entityTypeRaw`, `entityID`, `summary`, `createdAt` —
et rien d'autre. Il n'y a donc **pas** de base à réutiliser : le champ est à créer,
c'est un changement de schéma, et c'est ce qui donne à cette tâche sa fenêtre.

- Ajouter à `ActivityEntry` de quoi porter un diff inversable, et **une seule fois** :
  un `Data` encodé (JSON), pas une colonne par cas. Le contenu est un enregistrement
  par entité touchée : identifiant, type, et pour chaque champ modifié l'avant et
  l'après. Pour les relations, ce qui a été rattaché et détaché.
- Une entrée par **lot**, pas par ligne — sinon le fil devient illisible, ce que
  `L10` note déjà. C'est donc le lot qui s'annule, pas une ligne du lot.
- L'exécuteur d'annulation : rejouer un diff à l'envers, en vérifiant que les entités
  visées existent toujours et n'ont pas changé depuis. **Refuser plutôt qu'écraser** si
  elles ont changé : une annulation qui détruit une modification postérieure est pire
  que pas d'annulation du tout. Le refus doit dire ce qui a bougé.
- Bornes : ce qui est annulable, et jusqu'à quand. Un diff a un coût de stockage, et il
  est synchronisé. Décider d'une fenêtre (par nombre d'entrées ou par âge) et purger
  au-delà, dans la passe de maintenance de `L16`.
- La fusion (`L8`) rend déjà un plan inspectable : son diff inverse est ce plan lu à
  l'envers, plus le rétablissement du perdant marqué supprimé. Les deux opérations
  doivent produire le même format de diff, sinon il y aura deux exécuteurs
  d'annulation.

**Terminé quand :** un lot d'édition en masse et une fusion s'annulent tous les deux
par le même chemin, un test vérifie qu'une annulation refuse de s'appliquer sur une
entité modifiée entre-temps, et la purge des diffs anciens est rejouable.

> **`V6` (console de gestion, édition en masse) n'est pas utilisable pour de vrai
> tant que `L20` n'est pas faite.** Livrer une édition en masse sans annulation, c'est
> livrer un outil qui peut détruire une heure de saisie sur une sélection mal cliquée,
> avec pour seul recours de tout ressaisir. Le lien est noté des deux côtés.

---

### `L2` — Service de recherche

**Objectif.** Une fonction pure « texte + portée → résultats groupés », sans
`.searchable`.

- Portées : tous, titres, personnes, collections, signets. Prédicats sur `searchText`
  déjà replié (sans accents, minuscules).
- Résultats groupés par type, avec un compte par groupe et une limite par groupe.
- Recherches récentes : stockage local, borné, dédoublonné, jamais synchronisé.
- Exclure ce que le profil courant ne doit pas voir (`hidesPrivateContent`).
- Vérifications à écrire : « ame » trouve « Âme », « downey » trouve
  « Robert Downey Jr. », la chaîne vide ne renvoie pas zéro résultat (l'erreur de
  `e0f0f0b`).

**Terminé quand :** les tests passent par le magasin, et la recherche sur 5 000
titres tient sous 50 ms.

---

### `L3` — Indexation Spotlight

**Objectif.** Le pont vers `CoreSpotlight`, sans écran.

- Indexer titres, personnes, collections : `CSSearchableItemAttributeSet` avec
  vignette (preset `thumb` de `04 §4`) et `NSUserActivity` pour l'ouverture directe.
- **Ne jamais indexer une entité `isPrivate`**, et désindexer celle qui le devient.
- Désindexer à la suppression douce, réindexer à la restauration.
- Réindexation complète rejouable, appelée par `L13` à la fin de la migration.
- Encodage/décodage de l'identifiant d'un item vers une route de l'app : c'est un
  type de `CineShelfCore`, pas une vue.

**Dépend de `L2`** pour partager la normalisation et la notion de portée.

---

### `L4` — Mathématiques du recadrage

**Objectif.** Toute l'arithmétique de `MediaCrop`, sans un seul geste SwiftUI.

- Conversion dans les deux sens : un déplacement et un facteur de zoom (ce qu'un
  geste produira) ↔ le triplet `(x, y, zoom)` en pourcentages de la v1.
- Bornes : un recadrage ne doit jamais laisser de vide dans le cadre, quel que soit le
  ratio cible. La correction se fait dans la logique, pas dans la vue.
- Le rect source à afficher pour un ratio cible donné, à partir d'un recadrage — c'est
  ce que la vue consommera, et ce que `L6` réutilisera pour ses tuiles.
- La résolution contexte → standard → `(50, 50, 100)` existe déjà (`MediaAsset.crop(for:)`) :
  la couvrir pour les contextes ajoutés depuis.

**Terminé quand :** les cas limites sont testés (image plus étroite que le cadre,
zoom minimal, ratio extrême) et qu'aucune correction de bornes ne vit dans une vue.

---

### `L5` — Préchargement de vignettes et pression mémoire

**Objectif.** Ce qui protège réellement le défilement, d'après `04 §4` : le cache et
le préchargement, pas un seuil sur la génération.

- File de préchargement : une fenêtre autour de la position courante, annulable,
  priorité inférieure à l'affichage, jamais deux fois le même travail.
- Brancher `startObservingMemoryPressure()` — personne ne l'appelle aujourd'hui
  (écart connu), donc le cache n'est instancié qu'à la première image affichée.
- Alimenter `displayScale` : les vignettes sortent en @2x quelle que soit la dalle
  (écart connu). L'échelle est une donnée d'environnement, mais son transport jusqu'au
  cache est de la logique.
- Préchargement de l'écran suivant (écart connu) : l'API côté logique, l'appel côté vue
  plus tard.

**Terminé quand :** un test montre que le préchargement se fait hors du chemin
d'affichage, que l'annulation fonctionne, et que la purge sous pression mémoire libère
sans perdre d'écriture en cours (`flushPendingWrites()`).

---

### `L6` — Mosaïque de couverture

**Objectif.** Composer une image de couverture depuis les jaquettes des titres d'une
collection, dans `MediaKit`.

- Choix des tuiles déterministe (même collection, même mosaïque), nombre de tuiles
  selon ce qui est disponible, repli propre à 1, 2, 3 jaquettes.
- Chaque tuile respecte son propre recadrage : c'est pour ça que ça dépend de `L4`.
- Sortie : un `MediaAssetDraft` comme n'importe quelle image importée — donc sha256,
  blurhash et dimensions, et le dédoublonnage s'applique.
- Régénérable : la mosaïque d'hier ne doit pas empêcher celle de demain.

---

### `L7` — Aperçu de lien

**Objectif.** Un service qui prend une URL et rend un titre, une icône et une
vignette, ou rien.

- `LPMetadataProvider` du framework `LinkPresentation`, délai de 3 s, une seule
  requête par URL, annulable.
- L'échec ne bloque rien et ne remplit rien : le libellé se déduit alors de l'URL
  (hôte, dernier segment, décodage des `%`).
- La vignette récupérée entre dans le pipeline médias normal (`MediaIngestor`), elle
  n'est pas un cas à part.
- Aucune sortie réseau dans les tests : la frontière est un protocole, le test fournit
  un fournisseur factice.

---

### `L8` — Doublons et fusion

**Objectif.** Détecter, proposer, et exécuter — trois choses séparées.

- Détection : `sortName` proche (distance de Levenshtein, seuil à justifier par des
  cas réels) **et** date de naissance identique. Aucune fusion automatique : un score
  et une liste de candidats.
- Plan de fusion : pour chaque champ, la valeur retenue ; pour chaque relation, ce qui
  sera transféré (crédits, médias, liens, genres, flags, comptes sociaux). Le plan est
  une valeur inspectable, c'est lui que l'écran de fusion affichera.
- Exécution : applique un plan, transfère les relations sans créer d'orphelin, marque
  le perdant supprimé, journalise un `.merge`. Réutilisée par `L15` pour les genres.
- Rappel : il n'y a plus de fusion acteur ↔ profil social, c'est la même entité avec
  deux rôles. Seuls les vrais doublons subsistent.

---

### `L9` — Suggestion de casting

**Objectif.** Ce qu'aucune infrastructure ne couvre aujourd'hui (écart connu) :
suggérer des personnes à créditer sur un titre.

- Personnes fréquemment co-créditées avec celles déjà au casting.
- Correspondance de nom dans le synopsis, sur `searchText` replié.
- Sortie ordonnée avec une raison par suggestion (« déjà 4 films avec X », « nommé
  dans le synopsis »), sans laquelle l'écran ne pourra rien afficher d'honnête.
- Coût borné : la suggestion ne parcourt pas le catalogue entier à chaque frappe.

---

### `L10` — Édition en masse

**Objectif.** Décrire une mutation indépendamment de l'entité, et l'appliquer à une
sélection.

- Un descripteur par champ modifiable, par entité : remplacer, vider, ajouter à une
  relation, retirer d'une relation.
- Application transactionnelle sur une sélection : tout passe ou rien, avec le compte
  de ce qui a changé et de ce qui a été refusé.
- Validation avant application, avec un message par refus.
- Journalisation : une entrée d'activité pour le lot, pas une par ligne — sinon le fil
  devient illisible.
- Sert deux écrans : la console de gestion (`V6`) et l'aperçu d'import (`V8`).

---

### `L11` — CSV

**Objectif.** Tout l'import/export, moins les écrans.

- Lecture : `TabularData`, séparateurs et encodages, colonnes typées.
- Écriture : sérialiseur maison, UTF-8 **avec BOM**, séparateur `;`, échappement
  RFC 4180. Un gabarit vierge par entité.
- Schéma de colonnes par entité, et sélection de champs — la liste des champs
  exportables est une donnée, pas une vue.
- Validation ligne à ligne avec statut (nouveau / mise à jour / conflit / erreur) et un
  message explicite. Revalidation après correction, sans reparser le fichier.
- Résolution des références : un genre ou une personne cité par son nom est retrouvé
  (`GenreRepository.findOrCreate`) ou créé.
- Application dans `ImportActor`, par lots de 200, avec progression et annulation.
  Reprise **par élément** et non par lot (écart connu).
- Profil de mappage « Movix » préconfiguré, et enregistrement de mappages personnels.
- Fixtures : fichiers malformés, accents, colonnes manquantes, doublons intra-lot.

**Dépend de `L10`** pour la correction en masse dans l'aperçu.

---

### `L12` — Archive `.cineshelfarchive`

**Objectif.** Un aller-retour complet, données et médias.

- Écriture : `manifest.json` (version, date, comptes), un JSON par entité, `media/`.
- Relecture : la même archive se réimporte et redonne les mêmes comptes. C'est le test
  qui compte, pas le format.
- `Transferable` pour le partage système — la conformité est de la logique, le bouton
  viendra avec `V8`.

---

### `L13` — Migration des vraies données

**Objectif.** Importer le bundle produit par l'app web, une fois, sans perte.

- L'ordre exact des 12 étapes de `02 §7`, dont le point critique : un
  `social_profile` avec un `actor_id` non nul alimente la **même** `Person` que cet
  acteur, avec le rôle `.social` en plus.
- Recadrages reconstruits depuis les 21 colonnes de la v1 (`L4`).
- Checksum, blurhash et dimensions calculés à l'import (le bundle ne les fournit pas).
- Rapport de vérification : les 9 assertions de `02 §7` étape 3, chacune avec son
  écart chiffré.
- D'abord un bundle factice réduit et son test. Les vraies données ensuite.

**Point de contrôle.** Après cette tâche, `versionIdentifier` gèle et tout changement
de modèle exige un plan de migration. Tout ce qui touche au schéma doit être passé
avant : c'est la raison d'être de l'ordre de ce document.

---

### `L14` — `AppLock`

**Objectif.** Le verrou d'interface de `02 §9`, sans écran.

- `LocalAuthentication` avec `.deviceOwnerAuthentication` — **pas**
  `...WithBiometrics` : on veut le repli automatique sur le code de l'appareil.
- Machine d'états : verrouillé, déverrouillé, délai de grâce (immédiat / 1 / 5 /
  15 min), reverrouillage sur passage à `.inactive`.
- Portée par profil : `requiresBiometry` est affiché mais jamais appliqué aujourd'hui
  (écart connu). Et `hidesPrivateContent` : un filtre que toutes les requêtes doivent
  respecter, pas un masque posé par les vues.
- Cas à traiter explicitement : biométrie indisponible, aucun code configuré,
  verrouillage après échecs répétés.
- Frontière testable : l'authentification passe par un protocole, le test fournit un
  évaluateur factice qui accepte, refuse, ou n'est pas disponible.

---

### `L15` — Transfert entre bibliothèques

**Objectif.** Déplacer des entités d'une bibliothèque à l'autre en emportant ce
qu'il faut, et pas plus.

- Clôture transitive des dépendances : transférer un titre emporte ses médias, ses
  crédits, ses liens, ses recadrages. Le calcul rend une liste inspectable — c'est
  l'aperçu que l'écran affichera.
- Décider, cas par cas, de ce qui est **copié** et de ce qui est **déplacé** : un genre
  partagé par 200 titres ne suit pas un titre.
- Exécution en lots, avec journalisation.
- Fusion des doublons de genres sur `nameKey` (`04 §5`) : deux appareils hors ligne
  créent le même genre. Réutilise l'exécuteur de `L8`.
- Vider une bibliothèque (l'ancien bac à sable) et supprimer une bibliothèque, sans
  toucher aux profils qui pointaient dessus autrement qu'en les reroutant.

---

### `L16` — Maintenance et corbeille

**Objectif.** Les tâches d'entretien qui n'ont pas d'écran propre.

- `MediaAttachment` orphelins, et l'invariante `hasExactlyOneOwner` posée à
  l'attachement (`MediaRepository.attach`, écart connu).
- Médias non référencés.
- Corbeille : lister les entités `deletedAt`, restaurer, purger à 30 jours. La
  restauration réindexe (`L3`).
- Passe rejouable et idempotente, appelable au démarrage comme à la demande.

---

### `L17` — État de synchronisation

**Objectif.** La machine d'états de `04 §5`, testable sans CloudKit.

- `SyncState` : `upToDate`, `syncing(Double?)`, `offline`, `needsAccount`,
  `failed(String)`, alimenté par les notifications du coordinateur CloudKit.
- Les 6 cas du tableau de `04 §5`, chacun avec son message en voix d'interface (en
  français) et son action concrète. Les textes sont de la donnée, pas de la vue.
- Calcul de l'espace occupé par CineShelf.
- Testable en injectant des événements : la vraie synchronisation attend le prompt 21,
  la machine n'a pas à l'attendre.

> **Cette tâche ne sera jamais « terminée » avant le prompt 21.** Elle peut être
> écrite et testée à fond dès maintenant — la machine d'états, les six messages, le
> calcul d'espace — mais **rien n'aura tourné contre un vrai conteneur CloudKit** : ni
> les notifications réelles du coordinateur, ni leur charge utile, ni leur ordre
> d'arrivée, ni les cas de compte et de quota, qu'aucun test local ne peut produire.
> Quand elle passera au vert, elle vaudra donc « écrite et couverte en simulation »,
> pas « vérifiée ». Elle reste ouverte jusqu'à une repasse après l'activation de
> CloudKit, et son état dans le tableau ci-dessus doit le dire.

---

### `L18` — Sélections éditoriales, fil d'activité et statistiques

**Objectif.** Tout ce qui répond à « qu'est-ce qu'on montre, et dans quel ordre ».

- Le hero de l'accueil : la règle de choix, stable dans la journée, jamais un titre
  archivé ni privé si le profil les masque.
- Les rayons : collections manuelles + rayons par genre, avec leur ordre, leur seuil
  minimal de titres et leur compte.
- « Ma liste » : watchlist, favoris, vus du profil courant, depuis les flags.
- « Prochain à voir » : un titre de la watchlist, la même règle servant au widget et à
  l'App Intent de `L19`.
- **Le fil d'activité** : lecture chronologique d'`ActivityEntry`, décroissante,
  fenêtrée (le fil ne charge pas dix ans d'un coup), regroupée par jour, avec le
  libellé de chaque entrée construit depuis `ActivityDescribing` et non dans la vue.
  Filtrage par action et par entité. Les entrées dont la cible a disparu doivent
  rester lisibles : `ActivityEntry` garde un libellé figé, c'est fait pour.
  **Vérifié : rien ne lit `ActivityEntry` aujourd'hui.** `ActivityRecorder` écrit,
  personne ne relit — cette puce est le seul endroit du plan qui couvre la lecture.
- Statistiques : répartition par genre, par décennie, par note, durée totale. Les
  agrégations rendent des séries ; `Swift Charts` viendra avec `V11`.

---

### `L19` — App Intents, Handoff, partage entrant

**Objectif.** Les intégrations système, moins leurs surfaces.

- Trois App Intents : ajouter un film, chercher dans CineShelf, « qu'est-ce que je
  dois regarder ? ». Ils appellent `L2` et `L18`, ils ne réimplémentent rien.
- Handoff : encodage et décodage d'une route en `NSUserActivity`, aller et retour
  testés.
- Partage entrant depuis Safari : une URL devient un `SavedLink`, ou pré-remplit un
  titre si elle est reconnue. La reconnaissance et l'aperçu viennent de `L7`.
- Fournisseur de données du widget : entrées de timeline calculées, sans vue.

---

# Tâches VUES — gelées

**Gelées.** Aucune ne démarre avant que la direction artistique de
[`06-BRIEF-DESIGN.md`](./06-BRIEF-DESIGN.md) soit produite et validée, et chacune
s'écrit **une seule fois**, contre le design final. L'interface des prompts 10 et 11
sert de banc d'essai en attendant.

| Tâche | Écrans | Prompt d'origine | S'appuie sur |
|---|---|---|---|
| `V1` | Recherche : champ, portées, suggestions, résultats groupés. **L'anti-rebond de la saisie est affaire de vue, pas du service** : `SearchService` est une fonction pure, appelable à chaque frappe, et c'est la vue qui décide quand l'appeler. Le mettre dans le service le rendrait intestable et imposerait un rythme à des appelants qui n'ont pas de frappe à amortir — l'App Intent de `L19`, par exemple. Deux branches obligatoires, et le compilateur les impose : `SearchOutcome.idle` (champ vide → recherches récentes) et `.results` dont les groupes peuvent être vides (→ « aucun résultat ») | 12 | `L2` `L3` |
| `V2` | Médias : `PhotosPicker`, import de fichier, glisser-déposer, collage, `CropEditor`, branchement de `MediaThumbnail` | 13b | `L4` `L5` |
| `V3` | Galerie : masonry, matrice `layout × size` rendue, visionneuse, immersif | 14 | `L1 bis` `L4` `L5` |
| `V4` | Personnes : grille, fiche, éditeur, écran de fusion champ par champ | 15 | `L8` `L9` |
| `V5` | Collections, genres, liens et signets, accueil, fil | 16 | `L6` `L7` `L18` |
| `V6` | Console de gestion : tableau par entité, édition inline, édition en masse. **Ne pas livrer sans `L20`** : une édition en masse sans annulation peut détruire une heure de saisie sur une sélection mal cliquée, sans autre recours que de tout ressaisir | 17 | `L10` · **`L20`** |
| `V7` | Profils, bibliothèques, transfert, verrouillage, écran de confidentialité | 18 | `L14` `L15` |
| `V8` | Import et export : sélecteur de champs, aperçu ligne à ligne, correction, progression | 19 | `L11` `L12` |
| `V9` | Migration : commande cachée et rapport de vérification | 20 | `L13` |
| `V10` | Synchronisation : indicateur, messages d'erreur, corbeille, espace occupé | 22 | `L16` `L17` |
| `V11` | Widget, extension de partage, écrans de statistiques | 23 | `L18` `L19` |
| `V12` | Passe d'accessibilité complète sur les écrans définitifs | 24 | tout |

Le chrome, l'identité et les 7 composants ne figurent pas ici : ils appartiennent aux
étapes 1 à 10 de la méthode du `06 §6`, qui se déroulent avant `V1`.

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

---

---

## Comment circulent les fichiers entre les deux agents

Claude Design et Claude Code ne partagent **rien** : ce sont deux conversations
séparées, aucune ne voit l'autre. Le dépôt Git est le seul point de passage.

- Ce qu'on joint désormais à **Claude Design** : [`06-BRIEF-DESIGN.md`](./06-BRIEF-DESIGN.md).
  Plus jamais l'ancien `01`, archivé et faux de registre.
- Claude Design rend d'abord des **rendus visuels** (méthode du `06 §6`, étapes 1 à 8).
  Le code SwiftUI ne vient qu'à l'étape 9, après validation. C'est là que la première
  tentative a échoué : 2 120 lignes livrées avant que quiconque ait vu à quoi ça
  ressemblait.
- Tu poses ce qu'il rend dans le dépôt et tu commit ; **Claude Code lit tout depuis le
  dépôt**, on ne lui joint rien.
- Si Claude Code a besoin d'un composant qui n'existe pas : il s'arrête et demande.
  Voir la règle d'interface de `CLAUDE.md` — plus rien de visuel ne s'écrit sans accord.

---

## Le fichier `CLAUDE.md`

Il vit à la racine du dépôt et **fait foi**. Il n'est plus recopié ici : deux copies
divergent toujours, et c'est celle du dépôt que Claude Code lit à chaque session.

Ce qu'il porte aujourd'hui, en plus des règles d'origine : la règle de gel de
`versionIdentifier`, la règle « tout test de `#Predicate` passe par le magasin », les
références de documents à jour (le `06` remplace le `01`), et la règle d'interface
— aucun travail visuel nouveau sans accord explicite.

---

# Les prompts d'origine, conservés pour mémoire

Ce qui suit est le texte des 25 prompts tels qu'ils ont été écrits au départ. À lire
avec deux réserves :

- **Les prompts 7, 8, 10, 24 et 25 joignent `01-DESIGN-SYSTEM-APPLE.md`**, qui est
  archivé et faux de registre. Ne pas les rejouer tels quels : voir « La bascule de
  direction artistique » plus haut, et le `06`.
- **Les prompts 12 à 24 sont remplacés** par le découpage LOGIQUE / VUES. Leur texte
  reste utile comme inventaire de ce qu'il faut couvrir ; l'ordre et le périmètre, non.

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
