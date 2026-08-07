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

## Les trois chaînes de tâches, et ce que chacune apporte

Il y a **trois** séries de tâches, et elles ne font pas la même chose. La confusion est
facile — elle s'est produite : en ouvrant le catalogue du design system, on y cherche les
formulaires et la console de gestion, on ne les trouve pas, et rien ne dit s'ils sont
oubliés ou simplement pas encore arrivés.

| Chaîne | Ce qu'elle apporte | Où ça se voit |
|---|---|---|
| **`L1`…`L20`** — logique | Le comportement, sans interface : requêtes, services, mathématiques, import, annulation. Insensible au design | Nulle part à l'écran. Uniquement dans les tests |
| **`I1`…`In`** — intégration du design | `I1` les **tokens** (couleur, typographie, espacement, densité, rayons, traits, mouvement, plans, ruptures, tailles d'affiche, symboles). `I2` et suivantes les **composants, un par un** | Le catalogue `DesignSystemCatalog`, planche par planche |
| **`V1`…`V12`** — écrans | Les écrans assemblés, écrits **une seule fois** contre le design final | L'app elle-même, jamais le catalogue |

**Le cas des formulaires, parce que c'est le piège.** « Les formulaires » ne sont pas une
étape : ils se répartissent sur les deux chaînes visuelles.

- Les **champs** — texte, nombre, bascule, date à précision variable, notation,
  multi-sélecteur, jeton de couleur, et les quatre marques d'erreur de l'addendum 1 — sont
  des **composants**. Ils arrivent dans la chaîne `I`, et se voient dans le catalogue.
- L'**écran d'import** et ses quatre étapes — correspondance des colonnes, aperçu,
  corrections en masse, import — est un **écran**. Il appartient à `V8`, ne se verra jamais
  dans le catalogue, et ne peut pas commencer avant que ses champs existent.

Même découpage pour la console de gestion : la ligne de tableau et le jeton de filtre sont
des composants (`I`), la console est un écran (`V6`).

État au 2026-08-04 (2) : **`I1` intégrée et le catalogue de tokens validé**. `I2` est
donc la suivante de la chaîne, et les `V` ne sont **plus gelées** — chacune démarre quand
les lots `I` qui la fournissent sont passés. Le catalogue porte la même explication sur sa
première planche. La chaîne `I` n'était pas inventoriée — elle l'est ci-dessous, en **neuf
lots de trois composants**.

---

## La rigueur se règle sur l'irréversibilité, pas sur la couche

Décidé le 2026-08-04. `L11b` avait mérité ses deux heures : sa clé de doublon
fabriquait **quatre fiches à partir de deux lignes identiques**, en silence. `L5`, `L6`,
`L7` et `L9` ne les méritent pas, et c'est là que le temps se perdait.

**« Chaîne `L` = rigueur maximale » était faux.** Ce qui décide n'est pas la couche,
c'est ce qu'un défaut muet coûte. Une tâche qui écrit ou supprime des données qu'aucun
geste ne refait n'a pas droit au même régime qu'un service de lecture dont l'erreur se
voit à l'écran et disparaît au rechargement.

### Le critère, en une question

> **Si cette tâche a un défaut et que personne ne le voit pendant trois semaines,
> est-ce que la donnée est récupérable ?**

Non → **rigueur maximale**. Oui → **rigueur légère**. Deux crans, pas trois.

Une seconde porte, qui n'est pas de l'irréversibilité mais coûte autant : **exposer un
contenu marqué privé ne se répare pas** — l'index Spotlight est unique pour l'appareil,
c'est la fuite que `L3` a fermée, et c'est la raison de la monotonie du privé à
l'import. Une tâche dont un défaut peut montrer du privé passe en maximale **sur ce
point nommé**, le reste en légère.

### Ce que chaque cran engage

| | Rigueur maximale | Rigueur légère |
|---|---|---|
| Sonde hors dépôt (`CLAUDE.md` § « Le paquet sonde ») | **oui**, avant les tests | non |
| Preuve d'échec par injection, la faute vérifiée présente avant de conclure | **oui**, pour chaque correction | non |
| Sous-agent de revue | **oui** | non |
| Tests | la suite, plus un test de non-régression par défaut trouvé | normaux |
| Rapport de fin | détaillé — mesures, arbitrages, tableaux avant/après | **cinq lignes** : ce qui est fait, ce qui est vert, ce qui reste |
| Entrée au journal | complète | trois lignes |

Sur une tâche légère : **compile, teste, avance.** Pas de sonde, pas de preuve d'échec,
pas de revue, pas de rapport détaillé. C'est tout ce qui est demandé, et en demander
plus est une erreur, pas un excès de zèle.

### Le classement

| Cran | Tâches | Ce qu'un défaut muet coûte |
|---|---|---|
| **Maximale** | `L8` `L11a` `L11b` `L12` `L13` `L15` `L16` `L20` | Des enregistrements écrasés, fusionnés ou purgés sans trace, ou une sauvegarde qui ne se relit pas |
| **Légère** | `L1 bis` `L5` `L6` `L7` `L9` `L17` `L18` · **toute la chaîne `I`** | Un affichage faux, une image à régénérer, un cache à vider |
| **Légère, sauf un point** | `L14` | La logique du verrou est légère ; **la portée du déverrouillage et le délai de grâce** sont maximaux — ils décident qui voit le privé |

Justification tâche par tâche, pour les cas qui ne sont pas évidents :

- **`L8` (doublons et fusion) est maximale**, et c'est la correction la plus importante
  de ce classement. La fusion transfère des relations et marque le perdant supprimé, et
  **rien ne l'annule avant `L20`** : c'est l'opération destructive, `L20` n'est que son
  filet. Classer le filet en maximale et l'opération en défaut serait exactement à
  l'envers.
- **`L15` (transfert entre bibliothèques, fusion des genres) est maximale** : elle
  rejoue l'exécuteur de `L8` et déplace des entités d'une bibliothèque à l'autre. Même
  nature, même absence de retour.
- **`L16` (maintenance et corbeille) est maximale** : c'est la seule tâche qui
  **supprime définitivement** — orphelins, non référencés, purge à 30 jours. Une règle
  d'orphelin trop large efface des médias que rien ne récupère, et après le prompt 21
  la suppression se propage à tous les appareils.
- **`L5` reste légère** malgré `flushPendingWrites()` : ce qui se perd sous pression
  mémoire est un cache de vignettes, régénérable au prochain affichage.
- **`L6` reste légère** bien qu'elle écrive un `MediaAsset` : une mosaïque fausse se
  voit au premier coup d'œil, et la fiche exige qu'elle soit régénérable.
- **`L17` est légère pour une raison de plus** : sa propre fiche dit qu'elle ne sera
  jamais « vérifiée » avant le prompt 21. Investir en rigueur là où la vérification est
  structurellement impossible ne rend rien.
- **`L18` est légère avec deux points nommés** : le filtre « jamais un titre archivé ni
  privé si le profil les masque » se teste (c'est la porte du privé), et tout prédicat
  nouveau se mesure (écart « le plafond de `#Predicate` »). Rien d'autre.
- **Les tâches `V` se classeront à leur démarrage**, avec le même critère. Deux sont
  maximales d'avance parce qu'elles déclenchent des écritures de masse : `V6` (édition
  en masse) et `V8` (import).

---

## Reporté en v1.1 — inscrit, pas supprimé

Décidé le 2026-08-04, pour raccourcir le chemin jusqu'à une app utilisable. **Rien
n'est abandonné** : ce qui suit sort du périmètre de la v1 et reste ici, avec ce qui
reste en v1 à sa place.

| Reporté | Ce qui reste en v1 |
|---|---|
| **`L19`** — App Intents, Handoff, données du widget, partage entrant depuis Safari. Et `V11` (widget, extension de partage) avec elle | Ajouter un lien à la main, dans les signets (`V5`). Ça couvre le même besoin que le partage entrant, sans extension d'app ni provisioning. Les écrans de **statistiques** de `V11` restent à trancher : leur logique est dans `L18`, qui n'est pas reportée |
| **`L6`** — génération d'une couverture en mosaïque | La couverture **choisie à la main** : `MediaAttachment` porte déjà l'emplacement, rien à écrire. Et un repli calculé à l'affichage — les premières jaquettes en grille — qui n'écrit **aucun** `MediaAsset`. Ce qui part est la génération d'un asset, pas l'apparence d'une collection sans couverture |
| **`L9`** — suggestion de casting | L'ajout d'un crédit **par recherche de nom** : `PersonRepository.addCredit` existe, `L2` fournit la recherche. La suggestion est du confort, pas un chemin |
| **`L8`** — détection de doublons et exécuteur de fusion. Et l'écran de fusion de `V4` avec elle | Le dédoublonnage **à l'entrée** : `L11b` refuse déjà de créer un doublon à l'import, `GenreRepository.findOrCreate` fait de même pour les genres. Donc les doublons ne s'**accumulent** pas en v1 ; ce qui manque est le nettoyage de ceux déjà là |
| **`V6` au-delà d'une `Table` brute** — colonnes réordonnables, édition inline, mise en forme | Une `Table` SwiftUI par entité, tri par colonne, sélection multiple. **L'édition en masse n'y est livrée que si `L20` est faite** — sinon une sélection mal cliquée détruit une heure de saisie sans recours, et c'est déjà noté des deux côtés du plan |

**Trois conséquences du report de `L8`, à ne pas découvrir plus tard :**

1. **`L20` perd la moitié de son objet mais garde tout son format.** Sa fiche exige que
   l'édition en masse et la fusion s'annulent « par le même chemin ». En v1, `L20`
   n'annule que `L10` — mais le diff doit **rester capable de porter une fusion**, sinon
   `L8` en v1.1 devra faire évoluer `BulkEditDiff.currentVersion`, et un `payload` déjà
   en base ne se relit pas autrement.
2. **`L15` se réduit au transfert entre bibliothèques.** Sa troisième puce, la fusion
   des genres en double, dépend de l'exécuteur de `L8` : elle part en v1.1 avec lui.
3. **`L13` importera les doublons du bundle web s'il y en a**, et rien en v1 ne les
   fusionnera. Le rapport de vérification doit donc les **compter et les nommer** — il
   le peut, `LegacyRecord` le lui permet — même sans savoir les résoudre. Un doublon
   signalé et non résolu est acceptable ; un doublon silencieux ne l'est pas.

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
| `I1` | *(la chaîne `I` se suit désormais dans sa propre section, « Tâches INTÉGRATION DU DESIGN » — cette ligne reste pour l'historique)* **Tokens de la nouvelle direction** — couleur, typographie, 5 polices, espacement, densité, rayons, traits, mouvement, plans, ruptures, 6 tailles d'affiche et matrice, 37 SF Symbols. Ancienne direction isolée dans `Legacy/` | Code | `design/README.md` §4, planche 8 | ✅ `9b4b64e` |
| `L1` | Requêtes interrogeables — titres et personnes | Code | `02 §3 §5`, `04 §3` | ✅ `eb05149` `e347b11` |
| — | CI réparée, invariant des relations verrouillé | Code | — | ✅ `8ae4dfb` |
| `L2` | Service de recherche | Code | `02 §5`, `04 §6` | ✅ `6ea6a8e` |
| `L3` | Indexation Spotlight | Code | `02 §5`, `04 §6`, `03 §9` | ✅ `4e696ee` |
| `L4` | Mathématiques du recadrage | Code | `02 §2.4 §3.7`, `04 §4` | ✅ `07890db` |
| `L10` | Édition en masse | Code | `03 §12` | ✅ `68688b2` |
| `L11a` | CSV — format et analyse | Code | `03 §10`, `04 §7` | ✅ `902bfb1` … `4a42907` + revue |
| `L11b` | CSV — application au magasin | Code | idem | ✅ `8f68345` + revue `c393ed9` |
| `L12` | **Archive `.cineshelfarchive`** — paquet de dossier, aller-retour, fusion par identifiant, `Transferable` | Code | `04 §7`, `03 §10` | ✅ `e7e2915` `7a10b52` + revue `47ceb35` |

### Ce qui reste — chaque prompt est coupé en deux

La colonne **LOGIQUE** renvoie aux tâches `L…`, la colonne **VUES** aux tâches `V…`. On fait toute la logique d'abord ; les vues attendent le design.

| # | Quoi | LOGIQUE | VUES | État |
|---|---|---|---|---|
| 12 | Recherche + Spotlight | `L2` `L3` | `V1` | 🔶 **écran fait** · la vignette Spotlight reste à brancher |
| 13b | Médias — recadrage, préchargement, import d'images | `L4` `L5` | `V2` | 🔶 import, recadrage et éditeur faits · **le préchargement reste**, voir son écart |
| 14 | Galerie + visionneuse | `L1 bis` (source, mélange) | `V3` | ✅ **`3a6df7f` → `489148f`** — maçonnerie, visionneuse, immersif, sélection. **Le rendu n'est pas vérifié à l'œil** |
| 15 | Personnes + doublons + fusion | `L8` `L9` | `V4` | ✅ `63bf776` — **sans la fusion ni la suggestion** : `L8` et `L9` sont reportées en v1.1 |
| 16 | Collections, genres, liens, accueil, fil | `L6` `L7` `L18` | `V5` | ✅ `25d25b0` (`V5a`) · `5c065d3` (`V5b`) |
| 17 | Console de gestion | `L10` ✅ | `V6` | ⬜ |
| 18 | Profils, bibliothèques, Face ID | `L14` `L15` | `V7` | ⬜ |
| 19 | Import/export CSV | `L11a` ✅ `L11b` ✅ `L12` ✅ | `V8` | ⬜ — toute la logique est faite, il ne reste que les écrans |
| 2 | **Dump de l'app web** | — (dépôt web) | — | ⬜ dépendance immédiate de `L13`, **hors du chemin critique depuis le 2026-08-04 (2)** |
| 20 | Migration des vraies données | `L13` | `V9` | ⬜ — **dernière étape avant CloudKit.** Point de contrôle : geler `versionIdentifier` (`02 §7` étape 0) |
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

> **Le handoff de design est dans le dépôt, extrait en fichiers** — [`docs/design/`](./design/),
> direction « 2a Plein cadre ». L'archive `.zip` a été retirée : un binaire ne se diffe
> pas, chaque livraison en laisserait un dans l'historique pour toujours, et le README du
> paquet **est la spécification**, donc il doit rester lisible et corrigeable sur place.
> La règle pour les livraisons suivantes est dans [`docs/README.md`](./README.md).
>
> **Deux corrections y ont été appliquées, signalées à l'endroit où elles portent :**
>
> 1. **Le contenu privé, au §7 et au §10.** Le paquet livré écrivait « géré au niveau du
>    **profil**, pas du titre » — faux dans notre modèle. `isPrivate` est porté par
>    l'entité, un `Title` appartient à une `Library` et jamais à un `Profile`, et c'est
>    `Profile.hidesPrivateContent` qui décide de l'**affichage**. Suivre la formulation
>    d'origine rendrait un titre privé visible dès qu'un profil permissif est ouvert, et
>    indexable dans Spotlight, dont l'index est unique pour l'appareil — la fuite fermée
>    par `L3`. Corriger le §7 seul n'aurait pas suffi : le §10 fait autorité, c'est la
>    liste des décisions arrêtées. Ce que le paquet dit du **rendu** reste valable —
>    géométrie exacte de l'affiche, aplat `private.mask`, `eye.slash` sur la vignette
>    masquée. C'est le déclencheur qui était faux, pas l'apparence.
> 2. **Les copies de `03` et `06` que le paquet embarquait sont retirées**, remplacées
>    par des renvois vers `docs/`. Elles étaient identiques aux nôtres à la livraison et
>    auraient cessé de l'être au premier changement : une seconde source de vérité ne se
>    surveille pas, elle s'élimine.

> ## ✅ Le schéma est fermé — 2026-08-03
>
> **Dix-neuf entités. Toute modification ultérieure exige un plan de migration
> versionné** : un `VersionedSchema` nouveau et un `MigrationStage` qui l'atteint depuis
> `CineShelfSchemaV1`. La fenêtre où l'on ajoutait un champ en effaçant le magasin est
> close, et il n'y a pas d'exception pour « ce n'est qu'un champ optionnel ».
>
> Six manques trouvés par la passe d'inventaire et ajoutés avant fermeture :
> `ActivityEntry.payload` et `.undoneAt` (`L20`), `ActivityEntityType` (`L18` `L20`),
> `MediaAsset.isGenerated` (`L6`), `ImportMapping` (`L11`), `LegacyRecord` (`L13`).
> **Les champs sont posés, aucune logique ne les consomme** — c'est le travail des
> fiches citées. Détail et raisons dans `docs/02` étape 0 bis.
>
> Deux décisions de non-ajout, assumées : les « champs libres » à l'import sont écartés
> (contrepartie : le rapport nomme les colonnes ignorées), et `Genre.colorToken` reste
> une chaîne libre en attendant une réponse du design.

---

> **~~Prochaine passe transverse : la fermeture du schéma, avant `L10`.~~ Faite.** La fenêtre de
> gratuité se referme à `L13`, et un champ manquant découvert après le gel coûte un plan
> de migration. La passe balaie tout ce qui pourrait encore réclamer une modification de
> schéma — `ActivityEntry.payload` pour `L20`, ce que `L4` a révélé sur `MediaCrop` (rien :
> un seul recadrage sert tous les ratios), le handoff de design et `docs/03` relus en
> cherchant les données supposées mais non stockées, les tâches `L` et `V` restantes lues
> avec la même question, et les champs mal typés ou mal nommés qui méritent d'être
> corrigés maintenant plutôt que jamais. **La liste se rend avant d'écrire.** On ajoute
> les champs sans la logique qui les consomme, puis `docs/02` et ce document marquent le
> schéma comme fermé.

> ### En attente de Claude Design — inventaire au 2026-08-03
>
> **Les trois addenda sont livrés**, pas attendus : états d'erreur de champ et parcours
> de récupération à l'import (addendum 1), quatre écrans en iPhone et iPad (addendum 2),
> icône de l'app (addendum 3). Ils sont dans [`docs/design/`](./design/), et le §10 du
> handoff marque les deux points qu'ils comblaient comme traités. L'icône est livrée en
> SVG.
>
> Ce qui reste réellement ouvert, du §10 du handoff et de la fermeture du schéma :
>
> | Question | Pourquoi elle bloque |
> |---|---|
> | **`Genre.colorToken`** | Des pastilles de genre colorées ont-elles un sens sous une direction à un seul accent ambre ? Addition postérieure à la v1, jamais une fonctionnalité reprise. Détail à l'écart correspondant |
> | **Trois décisions sur l'icône** | Variante de dessin sous 32 px, fond sur écran d'accueil sombre, ton assourdi de la tranche |
>
> Aucune n'empêche les tâches `L` d'avancer. Toutes empêchent les tâches `V`.
>
> **Trois questions de cette liste sont tranchées** et ont quitté le tableau : la portée
> de l'apparence claire, la passe sur les réglages, et les quatre valeurs manquantes du
> système de couleur. Voir « Arbitrages tranchés », en tête de la bascule de direction
> artistique. Aucune ne bloque plus `I1`.

**Écarts connus, à reprendre plus tard** (tenus à jour au fil des sessions) :

| Sujet | Où ça se règle |
|---|---|
| **L'interface des prompts 10 et 11 est un banc d'essai.** Coquille de navigation, grille des titres, fiche, éditeur, filtres : ils restent en place pour exercer la logique et voir tourner les tâches `L`, pas pour être livrés. On n'y investit plus rien — aucune retouche esthétique, aucun composant nouveau, aucun polissage — et on ne les supprime pas. Les écarts d'apparence qu'on y trouvera ne sont pas des bugs : ils seront tranchés par le nouveau design. Les écarts de **logique**, eux, restent à corriger normalement | `V1`…`V12`, après validation du design |
| ~~**Le hero remplit toujours son cadre.**~~ **Réglé par `V0 bis`** — la réserve était « sans média `backdrop`, la fiche n'affiche **aucun** hero, au lieu de se replier sur la jaquette ». Le design tranche : le prototype du bloc `4b` pose la **même source** en fond flouté et en affiche nette, et le §11 dit qu'aucune image large n'existe encore. `TitleDetailView` prend donc `backdrop` s'il existe, la jaquette sinon. **Ce qui reste vrai** : `MediaFill` remplit et recadre, jamais de bandes noires | ✅ `8ad3342` |
| Tous les écarts ci-dessous étiquetés d'un numéro de prompt d'interface (13b, 15, 16, 18, 24) sont **suspendus** au même titre : leur part logique passe dans une tâche `L`, leur part visible attend le design | Tâches `L` · tâches `V` |
| Édition du casting, des genres et de la collection depuis l'éditeur de titre. **`V4` et `V5` doivent passer par les mutateurs de relations de `TitleRepository` et `PersonRepository`** (`setCollection`, `setGenres`, `addCredit`, `removeCredit`, `move`, `setRoles`) — écrire dans `.genres`, `.credits`, `.collection` ou `.library` depuis une vue rendrait le filtre correspondant faux **en silence**, puisque `filterKeys` en dérive. La règle SwiftLint `no_relation_write_outside_core` le refuse à la compilation, donc le sujet ne peut plus être manqué : il ne reste qu'à brancher l'interface sur ces méthodes | `V4` · `V5` |
| `seasonCount` / `episodeCount` lus mais non éditables. **Destination corrigée le 2026-08-05** : « 11 bis » n'existe nulle part dans le plan — le découpage par numéro de prompt a été remplacé par les tâches `V`, et cette ligne pointait donc vers rien | `V0 bis` — l'éditeur de titre |
| Duplication d'un titre (`contextMenu` « Dupliquer » de l'ex-`docs/01` partie C, aujourd'hui archivé). **Destination corrigée le 2026-08-05**, même motif que la ligne précédente | `V0 bis` |
| Suggestion de casting (`docs/03` §4) : aucune infrastructure | `L9` |
| `MediaSlot.portrait` (jaquette portrait alternative) jamais lu. **Vérifié le 2026-08-05 : toujours vrai.** `MediaImportService` sait l'écrire — `slot.isSingle` le traite comme `.primary` et `.backdrop` — mais aucune vue ne le propose et aucune ne le lit. Ce n'est plus une absence d'infrastructure, c'est une absence de geste | `V6`, avec la console |
| `.navigationTransition(.zoom)` : la source est déclarée par `PosterCard`, mais son `@Namespace` est privé à la grille — le chaînage vers la destination manque | `V2` |
| Pas de `fetchLimit` progressif : `@Query` tout chargé (décision actée, à revoir au-delà de ~10 000 titres). **Chiffré par `L1`** : matérialiser 5 000 titres sans filtre coûte **248 ms**, contre 5,3 ms pour une requête filtrée qui en rend 32. Ce n'est donc pas le prédicat qui coûte, c'est le nombre d'objets rendus — et c'est ce chiffre-là qu'un `fetchLimit` ferait baisser. `TitleFilterPerformanceTests` le mesure à chaque exécution. **C'est une tâche `V`, pas `L`** : la vue sans filtre est l'écran par défaut, donc ce qui reste à faire est un `fetchLimit` progressif et son déclenchement au défilement — de l'interface, pas de la logique. Rien à décider avant que le nouveau design dise comment la grille se charge | `V3` · `V6` |
| **Les prédicats de `TitleFilter` et `PersonFilter` sont construits à la main**, pas par `#Predicate` : la macro plafonne à **cinq clauses** sur un `@Model` (mesures dans `docs/02` §5). Ce n'est pas une dette, c'est la seule forme qui tienne — mais elle a un coût de lisibilité, et deux règles en découlent. **Une** : tout critère nouveau passe par `predicateClause(active:)` et rejoint un sous-arbre existant, il ne se rajoute pas à une chaîne `&&`. **Deux** : ne jamais rallonger un `#Predicate` existant sans mesurer, parce qu'un prédicat dont la compilation passe de 200 ms à 1,3 s ne se signale pas. Concerne `L2`, `L3`, `L18` et tout ce qui interroge le magasin | permanent |
| **Les items Spotlight n'ont pas encore de vignette.** `SpotlightIndexer` prend une fermeture qui les fournit, et la valeur par défaut ne rend rien : `CineShelfCore` ne peut pas importer `MediaKit`, la règle de dépendances de `04 §1` va dans l'autre sens, donc c'est à l'appelant de brancher le cache. Les items sont indexés sans image — moins joli, jamais faux. À brancher quand `L5` aura le préchargement et l'échelle d'écran, avec le preset `thumb` de `04 §4`. **Le déclencheur a sauté le 2026-08-05 : `L5` est faite**, `MediaEnvironment` porte l'échelle et le cache sait précharger. Rien ne bloque plus le branchement, et personne ne l'a fait — c'est désormais une dette prête, pas une dépendance | prêt à brancher · `V1` au plus tard |
| **`Genre.colorToken` est une chaîne libre que rien ne valide** — exactement le défaut que `ProfileAccent` a corrigé (« un jeton invalide doit être impossible à écrire, pas avalé à la lecture »). Il n'a **pas** été typé à la fermeture du schéma, pour deux raisons : la palette de la nouvelle direction n'est pas intégrée, donc la liste fermée n'est pas connue ; et la question est d'abord de savoir si des pastilles de genre colorées ont encore un sens sous une direction à **un seul accent ambre** — c'est une addition postérieure à la v1, pas une fonctionnalité reprise. **La question part chez Claude Design.** En attendant, la précaution qui compte est déjà tenue : aucun repository ne l'expose à l'écriture, donc le défaut de `ProfileAccent` ne peut pas se reproduire par une vue. Le typer plus tard exigera un plan de migration | `V5` · question ouverte au design |
| **`TitleCollection` et `SavedLink` n'ont volontairement pas de `filterKeys`**, contrairement à `Title` et `Person`. Ce n'est pas une harmonisation en retard, c'est un arbitrage : la dénormalisation coûte un **invariant permanent** — un champ dérivé de plus à recalculer à chaque écriture, et une porte de plus à garder fermée — alors que ces deux tables comptent des dizaines de lignes, pas des milliers. La jointure `library?.id` ne se paie qu'en SQL, où elle est négligeable à cette échelle. Ce que la traversée coûtait vraiment, c'était le budget de vérification de types (7 253 ms et 7 446 ms avec `#Predicate`), et l'arbre manuel de `CollectionQuery` / `SavedLinkQuery` le règle sans rien dénormaliser. **Ne pas « harmoniser » sans mesurer d'abord** : la bonne raison d'ajouter `filterKeys` serait un critère de filtre que la jointure ne sait pas exprimer, ou un volume qui a changé d'ordre | permanent |
| **La barre de notation seule perd une décimale, en silence — lacune de design, question ouverte.** 8,4 sur 10 donne quatre étoiles, et 8,0 aussi ; le design ne montre **jamais** la valeur numérique à côté de la barre. Relevé au 2026-08-04 : huit occurrences dans la direction retenue affichent la barre nue — hero de l'accueil (planche 1 `2a`), fiche titre (planche 3 `4b`), champ « Note » (planche 6 `8a`), « Ma note » (planche 6 `8c` `8e`), et les quatre écrans iPhone/iPad de l'addendum 2. Les deux seuls endroits qui portent le nombre (`★ 4,5` sur la carte, `★ 4` dans le filtre) sont ceux où la barre n'est pas utilisée. **La conséquence est dans l'éditeur** : un titre noté 8,4 s'y présente en quatre étoiles pleines, et toucher une étoile écrit un entier — la décimale disparaît sans que l'utilisateur l'ait vue. `RatingBar` **n'invente ni demi-étoile** (exclue par la direction) **ni nombre d'autorité** (aucune planche ne le montre). En attendant l'arbitrage : tout appelant qui rend une note **modifiable** pose la valeur à côté, via `TitleFormat.ratingText` | question ouverte au design · `V0 bis` pour l'éditeur |
| **`HomeSelection` n'a aucun test, et c'est une dette, pas une décision.** La règle du hero — « stable dans la journée » — est exactement ce qui se teste : même jour, même titre ; jour suivant, titre différent ; jamais un archivé ; jamais un privé quand le profil les masque. Les quatre s'écrivent en quelques lignes, et la structure est déjà pure et hors de la vue pour cette raison. `V5a` l'a livrée sans. À reprendre avec `L18`, qui reprendra de toute façon le choix du hero | `L18` |
| **`PosterTileDetail` a été supprimé, et sa suppression est réversible par l'historique.** Recherche faite le 2026-08-04 dans les onze planches : le seul rendu d'une carte « affiche + métadonnées » hors du premier bloc ambigu de `4a` est dans le bloc **`2b`**, direction abandonnée. Recherche, Ma liste et le Fil montrent des affiches **nues** ; le Fil et la console utilisent des **lignes**, qui sont `I5`. Le composant n'avait donc aucun foyer, et un composant orphelin finit branché par quelqu'un qui croit corriger un oubli. **Si le design confirme un jour le survol enrichi du bloc `4a`, il se reprend du commit `8262878`** plutôt que d'être réécrit | supprimé `8ad3342` |
| ~~**`CropContext.hero` n'est exercé par aucune donnée de démonstration.**~~ **Réglé par `V2`.** `DemoCatalog` crée désormais un `backdrop` sur un titre sur quatre — assez pour exercer le chemin `hero`, pas assez pour effacer le repli sur jaquette, qui reste majoritaire et doit continuer d'être vu — et **des lignes `MediaCrop` réelles** pour les contextes `card` et `hero`. Aucune n'est neutre (`50/50/100` serait indistinguable du repli, donc ne prouverait rien), et `DemoCropCoverageTests` refuse que l'un des deux chemins redevienne mort. Texte d'origine : Mesuré au 2026-08-04 : `DemoCatalog` ne crée que des pièces jointes `.primary` (aucun `backdrop`) et **aucune** ligne `MediaCrop`. Le hero de la fiche emprunte donc le repli — jaquette 600 × 900 (2:3 exact), contexte `.card`, recadrage `.neutral` — et `MediaFill` la fait remplir une bande 16:9, ce qui lui coûte le haut et le bas. Invisible sous un flou de 22 pt et un agrandissement de 1,28, mais **le chemin `hero` du recadrage reste non exercé en pratique** : il le sera à `V2`, quand on pourra attacher une vraie image large | `V2` |
| **Le bloc `4a` montre deux survols différents pour la même grille, et je n'ai pas tranché.** Ses cartes en `sc-for` portent `style-hover="transform:scale(1.06)"` — la règle arrêtée du §7 — mais la **première** carte y est dessinée agrandie à 1,1 **avec** titre, méta et trois actions, c'est-à-dire un `PosterTileDetail`. Soit c'est la façon du prototype de montrer un état de survol enrichi (façon service de streaming), soit c'est une carte « mise en avant » propre à cette capture. `V0 bis` a implémenté **le survol arrêté** (1,06, rien sous l'affiche), parce que c'est la règle écrite du §7 et du §10 ; l'échange vers la carte détaillée serait un comportement qu'aucune phrase ne décrit. `PosterTileDetail`, livré par `I2`, s'est retrouvé **sans appelant** — et a été **supprimé** plutôt que laissé orphelin (ligne ci-dessus) | question ouverte au design |
| **La rangée de filtres actifs est en lecture seule tant que `I5` n'est pas fait.** Le bloc `4a` montre des jetons cliquables avec une croix — « Drame ✕ », « Note ≥ 4 ✕ » — et un « ＋ Filtrer ». C'est le **jeton de filtre de `I5`**, palier 3. `V0 bis` affiche donc l'état des filtres avec un `StateBadge` (`I6`) et un « Tout effacer », et le retrait fin passe par la feuille : moins direct que le prototype, et volontairement pas une seconde implémentation du composant | `I5` |
| ~~**L'état vide de la grille utilise encore `StateView`.**~~ **Réglé par `I10`.** `TitlesGrid` pose désormais deux `EmptyState` distincts — « aucun titre » et « aucun titre ne correspond » — parce que « Importe un CSV » n'a aucun sens quand 1 284 titres existent mais qu'aucun ne passe le filtre. C'est exactement ce qu'un composant à `case` fermés ne savait pas exprimer. Texte d'origine : La vue vide paramétrée est `I10`, palier 2. Elle n'est pas dans la liste d'exclusion `no_legacy_design_system` — la règle ne vise pas ce symbole — mais c'est bien un reste de l'ancienne direction, et il se remplace à `I10` | `I10` |
| **La barre d'onglets iPhone ne couvre que cinq sections sur onze, et le design ne dit pas où on atteint les autres.** Le bloc `3c` donne **Accueil · Titres · Recherche · Ma liste · Gérer**. Personnes, Collections, Galerie et Signets n'ont donc aucun onglet, et le handoff n'en parle pas : son §6 ne traite que la *mise en page* des huit écrans non dessinés, pas leur **accessibilité**. `V0` les liste derrière « Gérer » — l'onglet fourre-tout du prototype — plutôt que de les rendre inatteignables ; c'est un défaut de mieux, pas une lecture du design. `NavigationModelTests` verrouille l'invariant : toute section a un onglet propre **ou** figure dans `CompactTab.managed`. À confirmer au design, en même temps que la question des genres épinglés — les deux portent sur la même chose, ce que devient une entrée de navigation qui n'a plus de place | `V5b` — question ouverte |
| **Le §4.6 annonce une barre latérale que la direction retenue n'a pas. Ne pas « corriger » le code vers le tableau.** La colonne « Ce qui change » du tableau des points de rupture écrit « barre latérale en superposition », « barre latérale permanente », « barre latérale + inspecteur simultanés » à quatre crans sur six. **Aucun écran rendu n'en montre une**, et le bloc `3b` le dit dans sa propre légende : « même navigation régulière, **sans barre latérale** ». La navigation régulière est une **barre horizontale en haut** sur Mac comme sur iPad — `CINESHELF · Accueil · Titres · Personnes · Collections · Galerie · Ma liste`, puis `Rechercher ⌘K`, l'indicateur de sync et l'avatar. Douze écrans dessinés contre quatre mots d'une table de synthèse : c'est le même résidu que la colonne « Colonnes ». `App/Navigation/Sidebar.swift` est **supprimée** par `V0`. **L'inspecteur, lui, reste** : il est bien rendu, en colonne à droite au-dessus de 1024 pt, et `Breakpoint.showsInspectorAsColumn` reste juste | permanent |
| ~~**Les genres épinglés n'ont plus aucun point d'accès.**~~ **Réglé par `V5a`, et la piste était la bonne.** Le bloc `3a` défilé montre l'accueil avec un rail « **Mes genres · Drame** » entre « Ajoutés cette semaine » et « Ma liste · à voir ». Les genres épinglés ne sont donc **pas** une entrée de navigation : ils sont la **configuration de l'accueil** — quels rails, dans quel ordre. `HomeSelection` en fait un rail par genre épinglé, dans l'ordre de `pinIndex`. Ce qui reste ouvert, et c'est autre chose : **où on épingle un genre**, qui appartient à `V5b` | ✅ `25d25b0` · épinglage à `V5b` |
| **Le changement de bibliothèque n'est pas dans le menu de profil.** Vérifié contre les planches au 2026-08-04, parce que l'hypothèse naturelle est fausse : un `Profile` pointe bien vers une `Library`, mais le design met le sujet à deux endroits, et aucun n'est le menu de profil de la barre — un menu **`Bibliothèque`** dans la barre de menus Mac (planche 2, bloc `3a`), et l'écran de gestion **« Profils et bibliothèques »** (planche 5, bloc `7f`, donc `V7`). Le menu de profil de la barre ne porte que le changement de **profil** (`Profil suivant ⌃⌘1…9`). La liste « Bibliothèques » que portait `Sidebar.swift` part donc vers `V7`, pas vers le chrome | `V7` |
| **Le compte de colonnes du §4.6 diverge du calcul à 1280 pt, et c'est le calcul qui gagne.** Le tableau des points de rupture de `docs/design/README.md` donne une colonne « Colonnes » — 6 pour `macStandard` — alors que la règle arrêtée par l'addendum 2 bloc `13c` (largeur de carte fixe, la grille prend ce qui rentre) en donne 7 à `poster.l`. C'est le seul écart réel : à 1680 la table dit « 7+ », que le calcul satisfait, et aux deux largeurs que l'addendum a **rendues pour de vrai** — 393 et 834 — les deux coïncident exactement. `Breakpoint.columns` a donc été **supprimée** par `I4` plutôt qu'annotée : une constante morte qui contredit le code vivant finit par se faire « respecter » par quelqu'un qui croit corriger un oubli. Le compte n'existe plus qu'en un endroit, `GridMetrics.columnCount`. **Ne pas la réintroduire** ; si le design veut vraiment 6 colonnes à 1280, ce qui change est la largeur de carte de la grille des titres, pas le compte | permanent |
| **La densité a deux crans, pas trois.** `docs/03` §2 annonçait « compacte / standard / confortable » ; le handoff livre `.dense | .roomy`, et ce sont des écrans dessinés. `docs/03` est corrigé. Le cran est posé une fois par plateforme dans l'environnement — ample par défaut sur iPad, dense au pointeur — et c'est la seule valeur dynamique du système de design | `V5` |
| ~~**Le store de préférences d'affichage ne portera que `layout` et `size`**~~ **Fait par `L1 bis`**, et la décision tient telle quelle : `DisplayPreference` porte `layout` + `size`, rien d'autre. Texte d'origine :, alors que `02 §3.10` décrit `{layout, size, pageSize, sort, dir}`. `pageSize` est abandonné par `03` (§2 : `LazyVGrid` charge à la demande). `sort` et `dir` sont déjà portés par `TitleFilter`, que `NavigationModel` sérialise et restaure au lancement : les mettre aussi dans le store créerait deux sources de vérité, et les y mettre sans les brancher serait du code « au cas où ». **Le jour où le tri doit persister par contexte, c'est `TitleFilter` qui lira le store — jamais le store qui dupliquera `TitleFilter`.** Le sens de cette dépendance n'est pas négociable : l'inverse redonne deux vérités | `L1 bis` |
| **La différence d'ensembles des orphelins charge tous les identifiants de médias, et ce n'est mesuré que sur des centaines.** `GalleryQuery.assetIDs` fait, pour « orphelin », deux `fetch` complets : toutes les pièces jointes et tous les médias. C'est **correct** — la soustraction doit porter sur *toutes* les pièces jointes, sinon décocher « titre » ferait passer ses médias pour des orphelins — mais c'est linéaire et non indexé. Mesuré juste sur quelques centaines de lignes par `GalleryFilterTests`, **pas** sur des dizaines de milliers. La route alternative connue serait de dénormaliser un `hasOwner` sur `MediaAsset`, ce qui **retomberait dans le schéma fermé** et exigerait une migration : à ne pas faire sans une mesure qui la justifie. **Mesuré par `V3`** (`b437687` `29644e1`) : **39,0 ms** pour 12 orphelins sur 205 médias et 193 pièces jointes, contre 25,1 ms pour la branche « titre ». Toujours linéaire, donc toujours vrai à grande échelle — mais **l'écran par défaut ne le paie plus** : un filtre inactif ne déclenche aucun `fetch`, et le coût ne se paie que sur demande explicite d'une source. La dénormalisation reste non justifiée | ~~`V3`~~ — à remesurer sur des dizaines de milliers, si ça arrive |
| **Le prédicat par traversée de relation à plusieurs tue le processus, et rien avant le `fetch` ne le voit.** Mesuré le 2026-08-05 : `#Predicate<MediaAsset> { $0.attachments?.isEmpty ?? true }` **compile**, se vérifie en moins de 200 ms, et fait abandonner Core Data au premier `fetch` — `Keypath containing KVC aggregate where there shouldn't be one; failed to handle attachments.@count`, signal 6, non rattrapable par un `do/catch`. **Ne pas réintroduire ce motif**, nulle part : la traversée d'une relation *à plusieurs* optionnelle dans un `#Predicate` n'est pas traduisible en SQL. C'est le cas le plus dur de la règle « tout `#Predicate` passe par le magasin », et le seul de ce dépôt où la preuve d'un défaut **ne peut pas** devenir un test — un test qui poserait ce prédicat tuerait la suite entière au lieu d'échouer | permanent |
| **La planche de recherche montre six portées, le modèle n'en sert que cinq.** Le bloc `5b` rend « Images · 21 » à côté des titres, personnes, collections et signets. `SearchScope` n'a pas ce cas, et ce n'est pas un oubli de `L2` : **`MediaAsset` n'a ni nom ni `searchText`** — un checksum, un blurhash, des dimensions, rien qu'un terme puisse matcher. Deux issues, toutes deux hors de `V1` : une légende sur `MediaAsset`, qui **touche le schéma fermé** et exige une migration ; ou chercher dans le nom de l'entité propriétaire, ce qui rendrait les images d'un titre que le terme trouve déjà. `V1` livre cinq portées. **Ne pas ajouter une portée qui rendrait toujours zéro** | question ouverte au design · `docs/02` |
| **Les signets n'ont pas de tuile, et la recherche les rend en texte.** `V1` liste leurs libellés — nom, ou URL à défaut — parce que la ligne de tableau est `I5`, palier 3. Ce n'est pas une seconde implémentation d'un composant : c'est l'absence assumée d'un composant que la direction n'a pas encore dessiné pour ce contexte | `I5` |
| **L'anti-rebond de la recherche est à 250 ms, choisis et non mesurés.** Assez pour qu'une frappe continue ne déclenche rien, assez court pour que la pause entre deux mots rende déjà des résultats — mais c'est un raisonnement, pas un relevé. **À confirmer sur appareil**, où la latence de saisie et le coût des huit requêtes de la portée `.all` sont réels ; le simulateur donnerait un chiffre rassurant qui ne dit rien (écart connu sur les budgets de `docs/04` §4) | `V12`, avec la passe de perception |
| **Le bandeau de `I10` n'est posé sur aucun écran.** `Banner` existe, il se valide au catalogue au-dessus d'une vraie grille, et **aucune vue de l'app ne l'affiche** : les quatre cas du bloc `9c` sont hors ligne, synchronisation, quota iCloud et fin d'import — soit `V10` pour les trois premiers et `V8` pour le dernier. Un composant sans appelant finit branché par quelqu'un qui croit corriger un oubli : la note est ici pour dire que ce n'en est pas un | `V8` · `V10` |
| **Aucune affiche ne s'est jamais affichée dans la nouvelle direction, et ça a duré quatre sessions.** `MediaFill` — le point de passage des sept composants d'image — chargeait par `AsyncImage(url:)`, donc par `URLSession`, alors que `AssetURL` fabrique des URL au schéma interne `cineshelf-asset://`. Sonde du 2026-08-05 : `URLSession` rend **« unsupported URL »**, `phase.image` restait donc toujours `nil`, et tout rendait un aplat. **Corrigé par `V2`** : `MediaFill` lit `\.imageLoader` comme `MediaThumbnail` le faisait depuis le prompt 11, et la séquence blurhash → cache → générée est en place. `AssetURLResolutionTests` verrouille la propriété — pas le composant — pour que le chemin ne puisse pas se reperdre | ✅ `V2` |
| ~~**Le catalogue ne pouvait pas révéler ce défaut.**~~ **Réglé par `catalogue-images`.** Les échantillons portent désormais de vraies images, **dessinées par code** — aucun binaire au dépôt — et le catalogue injecte un `ImageLoader` qui les sert. Les quatre cas sont côte à côte sur la planche `I2` : chargée, en cours, en échec, sans image. La correction a demandé d'ajouter un **rendu d'échec** à `MediaFill`, sans quoi « en cours » et « en échec » restaient indistinguables et la porte serait restée à moitié aveugle. Texte d'origine : Ses échantillons ont `imageURL: nil` : une tuile **sans** image y rend exactement le même aplat qu'une tuile dont le chargement **échoue**. Deux causes, une apparence — la planche validait la forme d'une tuile vide et ne disait rien du chargement. **Ce qu'il faudrait pour que la porte morde** : au moins un échantillon portant une URL réellement résoluble depuis le catalogue, ce qui suppose d'y injecter un `ImageLoader` de démonstration. À faire quand un lot `I` touchera de nouveau à l'image | méthode · ~~`V3`~~ **repris par `V3`** (`862431f`) : la planche de maçonnerie porte de vraies images, et le chargeur du catalogue sait les dessiner **au ratio de la tuile** — sans quoi on validait un remplissage de 2:3 recadrés, pas une maçonnerie |
| ~~**`PrefetchWindow` demande une tranche visible que rien ne sait lui donner.**~~ **Réglé par `V3`** (`3a6df7f`) : la signature devient `indices(from frontier:count:)` et l'ancienne est **supprimée**, pas doublée. La variante `onAppear` est retenue, `ScrollPosition` écartée — elle ne rend qu'un identifiant d'ancrage pour toute la vue de défilement, donc rien des autres colonnes d'une maçonnerie, et rien du tout au repos. `PrefetchScheduler` porte la frontière (le **maximum** des index apparus, testé sur le cas des colonnes désaccordées) et le cran d'émission. **La cause inscrite ici trois sessions de suite était fausse** : ce n'était pas « il manque un écran », c'était une signature qu'aucun appelant ne pouvait remplir. Texte d'origine : Vérifié le 2026-08-05 en cherchant son foyer : `prefetch` n'a **toujours aucun appelant de vue**, et ce n'est pas `V2` qui le lui donnera — un import est une image immédiate, et la galerie d'un titre compte une poignée d'entrées, sous n'importe quelle fenêtre. Le défaut est plus profond : l'API prend `visible: Range<Int>`, et **aucun conteneur paresseux de SwiftUI ne rapporte cette tranche** — `LazyVGrid` ne notifie qu'élément par élément, par `onAppear`. Soit `V3` ajoute une variante pilotée par `onAppear`, soit elle calcule la tranche depuis un `ScrollPosition`. À trancher là, avec un vrai défilement sous les yeux | `V3` |
| ~~**`CropEditor` n'est pas livré.**~~ **Livré par `V2 bis`.** Il ne calcule rien : toute la géométrie est `CropGeometry`, écrite et testée par `L4` six tâches plus tôt. Deux cadres côte à côte — 16:9 et 2:3 — parce que la même image sert aux deux et qu'un réglage qui va bien dans l'un coupe souvent mal dans l'autre ; c'est aussi pourquoi `MediaCrop` est stocké **par contexte**. Les neuf cas de `CropContext` sont couverts sans `default`, et le compilateur l'a exigé : j'en avais écrit quatre. Texte d'origine : L'écriture des `MediaCrop` existe et est testée (`MediaRepository.setCrop`, une ligne par contexte, mise à jour et non dupliquée), les données de démonstration en portent, et la fiche les applique. Ce qui manque est **le geste** : l'écran qui laisse déplacer et agrandir une image dans son cadre. Il demande un rendu interactif de l'image source, deux ratios de cadre (2:3 et 16:9), et le report du `zoom`/`focus` vers `CropValues` — soit un écran à lui seul, que je n'ai pas voulu bâcler à la fin d'une tâche déjà large | `V2 bis` — à replanifier |
| **`MediaFill` a un rendu d'échec qu'aucun bloc ne dessine.** Un symbole discret en `text.tertiary` sur l'aplat, ajouté par `catalogue-images` parce que sans lui un chargement raté est indistinguable d'un chargement en cours **et** d'une absence d'image — trois causes, une apparence. La planche 7 traite l'erreur de chargement **par rangée** (bloc `9c`, « cette rangée n'a pas pu se charger », avec un « Réessayer »), jamais par tuile. Le précédent repris est `MediaThumbnail`, de l'ancienne direction, qui posait déjà un symbole de repli. **À confirmer au design** : c'est le seul rendu de la nouvelle direction qui n'est adossé à aucun bloc | question ouverte au design |
| **La CI a un second mode d'échec intermittent : le lancement de l'app expire dans les tests d'interface.** Relevé le 2026-08-05 sur le run `31013846388`, job `Tests interface (iOS)` : « Timed out while launching application via Xcode » après 81 s, précédé de « IDELaunchParametersSnapshot ... DebuggerLLDB.DebuggerVersionStore.StoreError error 0 ». **Ce n'est pas une assertion qui échoue, c'est le lanceur.** Cause écartée par vérification : `DemoCatalog.populate` — qui génère plus d'images depuis `V2` — n'est appelé que depuis les réglages, **jamais au lancement**, donc l'alourdissement du lancement est hors de cause. Quatre exécutions locales le même jour : 13, 23, 28 et 65 s, toutes vertes — la variance du lancement est déjà énorme en local, et un runner virtualisé la dépasse. **Distinct du flake de simulateur absent**, déjà réparé : celui-là ne se corrige pas par un spécificateur. Le remède serait une reprise du job ou un délai de lancement plus long, et c'est une modification du workflow que je n'ai pas faite sans deuxième occurrence — le seuil que je me suis fixé la première fois | à surveiller, deuxième occurrence = réparer |
| **`CropEditor` n'est atteignable que depuis la fiche titre, et sur une seule image.** ~~Les images de galerie ne sont pas recadrables.~~ **Réglé pour la galerie par `V3`** (`29644e1`) : la visionneuse porte « Recadrer », donc toute image de galerie est recadrable — depuis l'écran de galerie **et** depuis le rail de la fiche titre, qui montre désormais toutes ses images au lieu de cinq. Reste vrai pour les personnes et les collections, faute de fiche. Le bouton « Recadrer » règle l'image d'en-tête — backdrop s'il existe, jaquette sinon, le même choix que le hero pour ne pas recadrer autre chose que ce qu'on voit. Les images de **galerie** ne sont donc pas recadrables, faute d'écran qui les liste : c'est `V3`. Et les personnes et collections non plus, faute de fiche : `V4` et `V5b` | `V3` · `V4` · `V5b` |
| **`CropEditor` n'a pas été essayé au doigt ni à la souris.** Son calcul est celui de `CropGeometry`, écrit et testé par `L4`, et `CropGestureTests` vérifie qu'un geste part bien de son point de départ — le défaut inverse, un mouvement qui s'accélère, était présent dans ma première version et se voit à l'œil en une seconde. Mais **la sensation** — la latence, la vitesse, le fait qu'un pincement au trackpad soit utilisable — n'est vérifiée par rien : `screencapture` est refusé sur cette machine et je n'ai ni déplacé ni pincé une image. À essayer avant de considérer l'écran acquis | à essayer |
| **L'avatar de la fiche profil garde Bebas à 22 pt là où le bloc `7f` pose 20.** Écart neuf, ouvert en corrigeant l'écart 1 : la correction a bien fait changer la **police** avec la taille (Archivo Narrow 600 à 11 pt dans la barre, exactement le bloc `3a`), mais aucun rôle de `Typo` n'est Bebas à 20 pt. En ajouter un rouvrirait la porte que `Typo` a fermée — c'est textuellement le motif qui garde l'écart 8 au jeton, et le traiter autrement ici serait incohérent. Deux points sur un carré de 46, sur un glyphe d'une lettre : la porte de bloc le montre désormais, donc il ne peut plus se perdre | permanent, sauf demande du design |
| **La porte de bloc n'assène rien, et c'est délibéré — donc elle ne protège que ce qu'on regarde.** `catalogue-porte` met la valeur attendue à côté de chaque composant, mais aucun test ne compare les deux : un test recopierait les mêmes nombres et n'attraperait ni la forme, ni la police, ni le poids — c'est-à-dire exactement ce qui a laissé passer `PersonTile` en rectangle. Le corollaire est qu'**elle ne mord que si le catalogue est ouvert et lu.** Elle appartient donc à la relecture d'un lot `I` ou `V`, pas à la suite de tests, et un lot livré sans avoir ouvert le catalogue reste aussi exposé qu'avant | méthode, à chaque lot `I` et `V` |
| ~~**La CI a un mode d'échec intermittent : un runner sans aucun simulateur.**~~ **Réparé le 2026-08-05, après deux occurrences en une heure** — `Catalogue iOS` sur le run `30985835698`, puis `Build iOS` sur `30989335077`. Cause commune : le runner `macos-latest` arrive parfois sans **aucun** appareil simulé créé, et `xcodebuild` n'imprime alors que des placeholders. Le runtime iOS est là, les appareils ne sont pas créés. Deux corrections de nature différente : les **builds** passent à `generic/platform=iOS Simulator`, parce que compiler pour le simulateur demande un SDK et pas un iPhone — c'est le spécificateur correct, pas un contournement ; les **tests**, qui ont réellement besoin d'un appareil, passent par `scripts/ci-destination.sh`, qui résout par identifiant et crée l'appareil s'il manque. Le script ne masque rien : un runtime iOS réellement absent le fait sortir en erreur | ✅ `scripts/ci-destination.sh` |
| `AppIcon.appiconset` déclare 11 emplacements sans un seul nom de fichier : `actool` ne produit rien et l'app n'a **pas d'icône**. **Le dessin est livré** — [`docs/design/icon/cineshelf-icon.svg`](./design/icon/cineshelf-icon.svg), trois rectangles, aucune courbe (addendum 3). Reste à produire les exports et à les poser dans le catalogue, et trois décisions de design à trancher : variante sous 32 px, fond sur écran d'accueil sombre, ton assourdi de la tranche | avant 25 |
| Prédicat de production sans couverture : **il n'en reste qu'un**, `Bootstrap.existingProfile`, structurellement inatteignable en test — il ne sert qu'au cas d'une relation inverse désynchronisée par CloudKit. Les six qui étaient déclarés dans des vues (`MediaEnvironment`, `TitleDetailView`, `RouteInspector`, `Sidebar`, `TitleFilterSheet`, `DemoCatalog`) sont rapatriés dans `CineShelfCore/Queries/EntityQueries.swift`, couverts par `EntityQueryTests`, et la règle `no_predicate_outside_core` interdit qu'un septième réapparaisse dans une vue | `L17` |
| `MediaRepository.asset(withID:)` : code mort, aucun appelant dans le dépôt | — |
| **`DEVELOPMENT_TEAM` s'applique à toutes les cibles, y compris les bundles de test.** Une équipe sans certificat « Mac Development » les fait donc tous échouer sur `No signing certificate`, alors qu'aucun test n'a besoin d'être signé. C'est pour ça que la clé est **commentée** dans `Local.xcconfig.example` : mesuré, une copie sans édition faisait passer les 52 tests du catalogue de vert à build cassé. Le jour où un vrai identifiant est posé, ouvrir Xcode une fois suffit à créer le certificat — mais **le vérifier avec `xcodebuild test`, pas seulement avec `-showBuildSettings`** : c'est exactement l'angle mort qui a laissé passer ce défaut | `P0` |
| **Le simulateur iOS ne peut pas valider les budgets de `docs/04` §4, et il ne faut pas croire la mesure faite.** Il exécute le code sur le **processeur et le GPU du Mac** : le décodage d'image y est servi par une machine dix fois plus puissante que l'appareil, et sans son accélérateur dédié — donc un chiffre relevé au simulateur ne dit **rien** du défilement sur un iPhone. C'est la même erreur de catégorie que les seuils sur runner partagé (`CLAUDE.md`), à un détail près qui la rend plus traître : le simulateur est *plus rapide* que l'appareil, donc il donne des chiffres **rassurants** — un budget qui passe au simulateur peut échouer d'un facteur cinq sur le matériel. Les budgets se vérifient avec **Instruments, sur appareil**, ce qui suppose `P0` vérifiée. Tant que ce n'est pas fait, les budgets de `04 §4` sont des **intentions**, pas des mesures, et `L5` ne peut pas prétendre les avoir tenus | `P0` puis `L5` |
| **Une sauvegarde réécrit l'ordre d'affichage des genres d'une fiche.** `ArchiveWriter.sorted(_:)` normalise `Title.genres` et `Person.genres` par `uuidString`, et sa justification d'origine — « SwiftData ne garantit pas l'ordre d'un `to-many` » — est **fausse** : mesuré par la revue, il le préserve. Le tri reste **nécessaire** à la propriété qui fait la valeur de ce format (deux archives du même catalogue identiques octet pour octet, donc diffables), et `filterKeys` est insensible à l'ordre — `FilterKey.keys` trie et dédoublonne — donc rien de fonctionnel ne casse. Ce qui change est l'ordre dans lequel les genres s'affichent après une restauration. Le jour où cet ordre devient signifiant, il faudra un `orderIndex` sur la relation, pas retirer le tri | `V5` |
| **L'état intermédiaire d'une restauration n'est vérifié par aucun test.** Les dérivés sont posés dès la passe 1 précisément pour qu'aucune ligne commise par `checkpoint()` ne soit vide — mesuré par la revue avant correction : 700 titres sur 700 traversaient le disque avec `sortName` et `searchText` vides, et une interruption les y laissait. Mais le constater demande un **observateur concurrent** sur un second `ModelContainer` ouvert sur le même fichier, ce qui n'a pas sa place dans un test unitaire. Ce qui reste vérifié est l'état final ; ce qui protège l'invariant est l'appel de la passe 1, et le retirer ne fait rougir personne | `V8` |
| **Une restauration qui lève perd son bilan.** `restore(_:from:)` construit le rapport dans un état local : si un `save()` échoue à un lot tardif, ce qui a déjà été commis reste en base et **aucune trace de ce qui est entré** n'est rendue. Le remède est le même que celui de la progression — un acteur sur le modèle d'`ImportActor`, dont la fermeture de progression rapporte au fil de l'eau | `V8` |
| **Une archive se restaure sans progression ni annulation.** `ArchiveRestorer` est synchrone. `docs/04` §7 ne demande la progression que pour l'import, et 2 000 titres prennent **2,4 s** — mais un catalogue réel de 10 000 titres gèlera l'interface, et une restauration n'est pas une opération qu'on interrompt à l'aveugle. Le patron existe déjà : `ImportActor`, son verrou de réentrance indexé sur le `ModelContainer`, et ses lots de 200. **La restauration est superlinéaire pour la raison déjà mesurée à `L11b`** — `save()` sur une table qui grossit, pas le résolveur : ne pas re-diagnostiquer | `V8` |
| **La passe des dérivés de la restauration ne sauvegarde pas par lots**, contrairement aux deux premières : tout est accumulé et sauvegardé une fois. Sans effet mesurable à 2 000 titres. À surveiller au-delà, avec la même méthode — mesurer avant de changer | `L13` |
| **Aucun test ne vérifie la déclaration du type de fichier d'archive.** Elle n'est contrôlée que par `plutil -lint`, et `UTType(filenameExtension:)` fabrique un type **dynamique** quand la déclaration manque : une faute de frappe dans `fr.feltrin.cineshelf.archive` passerait tous les tests, et ne se verrait qu'au premier AirDrop qui n'offre pas CineShelf comme destination. La vérification appartient à `Tests/CineShelfTests`, seule cible qui ait un bundle — même raison qui y a mis `CloudKitConformanceTests` | `V8` |
| **Une archive restaurée dans une base non vide ne met rien à jour, par construction.** La fusion par identifiant laisse intacte toute entité déjà présente : c'est ce qui rend l'opération sûre, et ce qui fait qu'elle ne sait pas « restaurer par-dessus ». Si un vrai « remplacer par la sauvegarde » devient nécessaire, c'est une **opération distincte** à écrire — pas un drapeau sur celle-ci, qui perdrait sa seule garantie | — |
| `ColorTokens.typedAccessor(for:)` n'a plus d'appelant de production depuis que `ProfileSession.accentColor` est un `switch` sur `ProfileAccent` : API `public` exercée par les seuls tests. La garder tant que le catalogue peut en avoir besoin, sinon la passer `internal` | — |
| **Teinte de profil : deux choix seulement** (`accent/solid`, `accent/text`). Ce sont les deux seuls jetons d'accent à alpha 1 ; `accent/soft` est un lavis de fond (alpha 0,10 à 0,22) qui rendrait l'accent invisible en `.tint`. Si le prompt 18 veut de vraies couleurs par profil, il faudra étendre la palette dans `colors.tokens.json`, pas réutiliser les rôles existants. **La palette entière étant à refaire, ce point se tranchera avec la nouvelle** | `V7` |
| **Passe sur les réglages, reportée** (décision actée, voir « Arbitrages tranchés » point 3) : le périmètre réel des options n'est pas connu tant que la synchronisation, la corbeille et l'espace occupé n'ont pas ajouté les leurs. Dessiner l'écran avant reviendrait à le redessiner | après les prompts 21 et 22 |
| **`Legacy/` du design system est en sursis jusqu'à `V12`.** L'ancienne direction (17 jeux de couleur, 12 rôles typo, ombres, bordures, `CardMetrics`, proportions 3:2 et 4:5) vit dans `Packages/DesignSystem/Sources/DesignSystem/Legacy/`, plus `colors.legacy.tokens.json` et trois `.ttf`. Elle n'est là que pour que le banc d'essai s'affiche : la retirer ne casserait pas la compilation, elle rendrait du **transparent**. La règle SwiftLint `no_legacy_design_system` interdit à tout fichier neuf de la lire, avec une liste d'exclusions **figée** (8 fichiers de `App/`, les 7 composants, les planches de composants du catalogue). Procédure de suppression en 7 points dans `Legacy/README.md` | `V12` |
| **L'interlettrage est en points, pas en `em`.** La planche 8 donne des `em` ; `.tracking()` prend des points, donc la conversion est faite à la taille de base et l'interlettrage ne grandit pas avec Dynamic Type. SwiftUI n'expose pas d'interlettrage relatif, et l'alternative serait de lire la taille rendue à chaque passe. Écart assumé, visible surtout sur `display` à AX5 | `V12` |
| **L'interlignage est approximé.** SwiftUI n'a pas de « line height » : `.lineSpacing()` ajoute de l'espace **entre** les lignes, en plus de l'interligne naturel de la police. `Typo.Leading.spacing(for:at:)` suppose cet interligne naturel à 1,2 fois la taille et rend 0 en dessous — donc les ratios serrés de la planche 8 (`display` à 1.0, `title.1` à 1.05) ne sont pas resserrés, seulement pas élargis. Resserrer demanderait un `TextRenderer` | `V12` |
| **`Icon.ratingStar` et `Icon.watchedMark` portent des noms longs** parce que `Icon.rating` et `Icon.watched` désignent encore les `SymbolPair` de l'ancienne direction. Les noms courts se libèrent avec `Legacy/` | `V12` |
| **L'accesseur de `separator` s'appelle `separatorLine`.** `ShapeStyle.separator` existe déjà dans SwiftUI : déclarer le nôtre sous le même nom ne casse pas la compilation, ça rend `.separator` **ambigu**, et une vue peut alors prendre la couleur système d'Apple au lieu du token. Le nom du token reste `separator` dans le JSON, fidèle à la planche 8 ; seul l'accesseur Swift est désambiguïsé, par `ACCESSOR_OVERRIDES` dans `generate-colors.py` | permanent |
| **Le forçage sombre n'est posé que sur la galerie et la visionneuse** — `V3` (`29644e1`), et c'est le premier écran qui le pose. Reste à faire sur l'accueil et les fiches. Texte d'origine : Le forçage sombre n'est posé nulle part. L'arbitrage 1 dit que l'accueil, les fiches et la galerie sont forcés en sombre par écran (`.preferredColorScheme(.dark)` sur la racine de chaque surface de visionnage), et non globalement. Les tokens sont prêts — les quatre apparences existent, `bg/viewer` est identique dans les quatre — mais **aucun écran ne le pose** : ce sont les tâches `V` qui écriront ces racines | ~~`V3`~~ `V5` |
| **Le diff d'édition en masse est écrit mais personne ne le relit.** `L10` pose un `BulkEditDiff` versionné dans `ActivityEntry.payload` et laisse `undoneAt` vide ; `ActivityEntry.isUndoable` dit déjà `true`. Aucun code ne l'annule encore — c'est `L20`. Deux conséquences : `V6` ne doit pas livrer l'édition en masse sans `L20` (déjà noté au tableau des vues), et **le format du diff ne doit pas changer sans faire évoluer `BulkEditDiff.currentVersion`** — un `payload` déjà en base ne se relit pas autrement. `BulkEditDiff.decoded(from:)` refuse une version inconnue plutôt que de deviner | `L20` |
| **Le repliage de texte est invariant de locale depuis le 2026-08-04 — audit fait, ne pas régresser.** `sortName`, `searchText` et `nameKey` sont persistés **et synchronisés par CloudKit** : une valeur écrite depuis un appareil est interrogée depuis un autre. Replier avec `locale: .current` fait donc replier les deux côtés de la comparaison différemment, ce qui la rend **fausse quelle que soit la locale** — c'est un défaut structurel de la synchronisation, pas un cas limite, et il est muet. Le site qui mordait vraiment est `Genre.nameKey`, qui sert au dédoublonnage : deux appareils désaccordés créent un doublon **en silence**. Le turc (`I` → `ı`) n'est **qu'une illustration** mesurable de la divergence, pas la raison de la règle. Compromis assumé : le tri n'est pas sensible à la locale (sans effet en français ; `ö` suédois se trierait avec les `o`) — voir `docs/02` §3. Les 12 sites passent par `String.foldedForMatching` (`TextFolding.swift`), seule locale du dépôt, `en_US_POSIX`. **Aucune migration** : `fr_FR` et `en_US_POSIX` replient identiquement, donc les valeurs déjà en base sont inchangées — seul un appareil turc aurait divergé. Deux filets, parce qu'un seul ne suffit pas : 11 tests d'invariance, **et** la règle `no_folding_outside_text_folding` — vérifié, un modèle qui contourne `TextFolding` passe tous les tests sur une machine française | permanent |
| **L'addendum d'erreurs décrit deux causes qui n'ont plus d'objet, il est à amender.** Sur les six causes de la planche 11e : « **Année absente** » suppose que l'année est requise pour créer un titre, or `docs/02` §3.3 rend `releaseDate` **optionnel** — un titre sans année est valide, et la refuser à l'import écarterait des lignes que le modèle accepte. Même motif que la note bornée à 5 : la planche décrit un rendu, la source du modèle est `docs/02`. Signalé, pas appliqué, et `ImportValidatorTests.missingYearIsNotAnError` verrouille le bon comportement. « **Support inconnu** » perd son objet faute de champ au modèle (arbitrage du 2026-08-04, aucune migration). Restent quatre causes réelles, plus la ligne illisible que la planche ne montrait pas | `L11b` |
| **Le profil Movix n'est pas livré, et le mécanisme qui le remplace est en place.** L'arbitrage du 2026-08-04 l'a refusé : le script source est inaccessible, et `isBuiltIn` interdit de retirer un profil livré, donc un profil faux serait pire qu'aucun. Ce qui existe : `ImportMappingRepository` (mémorisation par `headerSignature`, refus de supprimer un `isBuiltIn`, correspondance personnelle qui masque une intégrée), et des **alias par champ** dans `CSVField` — une donnée, pas du code en dur — qui reconnaissent `runtime_min`, `my_score`, `genre_raw` en correspondance *déduite*. Livrer un profil un jour ne demandera donc **aucun code**, seulement un enregistrement | `L11b` |
| ~~**Réalisation, Distribution et Ajouté le ne s'importent pas encore.**~~ **Réglé par `L11b`.** `ImportWriter.setRelation` écrit les deux relations — `case "director": attachCredits(value, role: .director)` et `case "cast": attachCredits(value, role: .cast)` — via un résolveur de personnes par nom, ce qui était précisément la pièce manquante. `added_at` reste **délibérément ignoré** à l'écriture, et son en-tête le dit : `createdAt` datant l'entrée en base, un import ne le réécrit pas. Texte d'origine : Les trois colonnes ont été ajoutées au schéma en fin de `L11a` (la planche 11d les fait correspondre à un fichier réel). L'export les écrit — distribution triée par `orderIndex`, pas par nom — et la correspondance les reconnaît avec certitude. **Écrire un crédit depuis une cellule est `L11b`** : ça demande de résoudre une personne par son nom, et `GenreRepository.findOrCreate` n'a aucun équivalent pour les personnes ni les collections | `L11b` |
| **Le dédoublonnage n'existe pas encore, donc l'aperçu ne compte aucun doublon.** La planche 11e annonce « 96 doublons » comme une catégorie de premier plan, à côté des prêtes et des en erreur. `L11a` ne la produit pas : reconnaître un doublon exige d'interroger le magasin, ce qui est exactement ce que la coupe met dans `L11b`. `ImportAnalysis` n'a que `readyRows` et `refusedRows` ; la troisième catégorie devra s'y ajouter. **Vérifié le 2026-08-05 : toujours vrai, et la destination était périmée.** `L11b` est close, et elle a bien livré une clé de doublon — `ImportWriter.duplicateYear` — mais **à l'écriture seulement**. L'aperçu, lui, ne compte encore rien. La part logique (une troisième catégorie dans `ImportAnalysis`) n'a donc plus de tâche propriétaire : elle passe avec l'écran qui l'affiche | `V8` |
| **Le lecteur CSV perd au maximum une ligne, et il le chiffre — audit fait le 2026-08-04, ne pas régresser.** Trois défauts muets y vivaient, tous trouvés par une revue qui a construit un paquet sonde pour exercer des entrées que la suite n'atteignait pas. Les invariants à tenir : (a) **un guillemet n'ouvre un champ qu'en début de champ** — sinon un pouce dans un titre (`Le mur de 6\" de haut`) coûte huit lignes valides ; (b) après une refermeture forcée, la lecture **ne reprend pas au milieu du champ** — sinon le guillemet fermant est relu comme ouvrant et avale la fin du fichier ; (c) `closingQuoteExists` **regarde en avant** au premier saut de ligne dans un champ quoté, et distingue la fin du fichier (aucun fermant, donc refus immédiat) du plafond de recherche (doute, donc on continue) — confondre les deux rend le mécanisme inopérant sans qu'aucun test ne bronche. Un budget de lignes seul ne peut pas arbitrer : mesuré, seuil bas = synopsis légitime déclaré fautif, seuil haut = 24 lignes perdues sur un fichier corrompu | permanent |
| **Le rapport redéposable doit rejouer les corrections, pas le fichier d'origine.** `ImportRow.settingCell` écrit dans `cells` **et** dans `rawFields`, parce que le fichier de reprise est construit depuis le second. L'oublier annule silencieusement le travail de l'utilisateur : corriger 214 années, exporter les écartées, redéposer, et les 214 corrections ont disparu. Seule exception, explicite et testée : une valeur saisie pour un champ qu'aucune colonne n'alimente reste hors du fichier | permanent |
| **La déduction de colonne par le contenu ne porte que sur des formes discriminantes.** Année, booléen, multivaleur. Jamais une date ni un entier : trois dates peuvent être une sortie, un achat ou un ajout, et la règle « une forme, un seul champ disponible » ne protège que par accident — mesuré, `bought_at` était déduite en `release_date` dès qu'un alias avait pris `added_at`. Une colonne non reconnue n'est pas une erreur ; une colonne mal devinée en est une, et elle est muette | permanent |
| **L'injection de formule à l'export est un non-choix assumé.** `CSVWriter.escaped` ne préfixe pas les cellules commençant par `=`, `+`, `-` ou `@`, donc un tableur tiers peut les évaluer. Le rapport des écartées rejoue des cellules venues d'un fichier étranger, donc l'entrée n'est pas seulement celle de l'utilisateur. Non traité **exprès** : la mitigation habituelle — préfixer d'une apostrophe — change la valeur de la cellule, et casserait la propriété qui fait la valeur de ce rapport, être redéposable à l'identique. L'app est mono-utilisateur, sans chemin de partage. À rouvrir si un export devient partageable | — |
| **L'écriture d'un import est superlinéaire, et ça vient de SwiftData — mesuré, ne pas re-diagnostiquer.** Import de 1 200 lignes, temps par lot de 200 : 164, 340, 557, 778, 1 269, 1 143 ms. 4 000 lignes prennent **40 s**. Trois hypothèses écartées par la mesure : ce n'est pas le `fetch` par ligne du résolveur (0,14 ms à vide, 0,36 ms sur 5 000 titres), ce n'est pas l'accumulation d'objets dans le contexte (un contexte **neuf par lot** donne la même courbe : 75, 277, 538, 735, 823, 1 019 ms), c'est le `save()` sur une table qui grossit. Conséquence pour **`L13`**, qui importera les vraies données : prévoir la durée, et mesurer sur appareil avant de promettre quoi que ce soit. Ne pas « optimiser le résolveur », il n'est pas en cause | `L13` |
| **La réactivité pendant un import n'est couverte par aucun test, et c'est assumé.** `Task.yield()` toutes les 50 lignes existe parce que la version synchrone tenait son fil d'exécution **6,3 s d'affilée** sur 1 500 lignes — et que le fil **principal** était l'un de ceux que le pool coopératif donnait à l'acteur, donc l'interface gelait. Mesuré après : réveils du fil principal toutes les ~35 ms. Mais les tests d'annulation annulent depuis la fermeture de progression, donc depuis l'acteur : le drapeau est vu sans qu'aucune suspension soit nécessaire, et **retirer `Task.yield()` les laisse tous verts** (preuve d'échec tentée). Ce qui justifie la ligne est la mesure, pas un test — même statut que les budgets de `docs/04` §4, à revérifier avec Instruments sur appareil | permanent |
| **Un import n'affine jamais une date déjà là.** Conséquence directe de « compléter sans jamais écraser » : un titre daté au 1er janvier avec `releasePrecision == .year` — ce qu'un import d'année seule produit — ne sera **pas** repassé au jour exact par un second import qui porte la date complète. La ligne est comptée « inchangée ». C'est cohérent avec la règle et ça se corrige à la main ou par édition en masse ; si ça devient gênant, la décision à rouvrir est « compléter » vs « affiner », pas la clé de doublon | `L20` |
| **`ImportActor` refuse deux imports simultanés, et cette garde est structurelle.** Depuis que `importRows` est asynchrone, l'acteur est **réentrant** : pendant un `await Task.yield()`, un second appel s'exécuterait entre deux lots du premier, les deux partageant le `ModelContext` — donc le `rollback()` de l'un jetterait le lot en cours de l'autre, et les deux rendraient un bilan plausible et faux. `ImportRunError.alreadyRunning` le refuse. **Ne pas retirer ce verrou en croyant qu'un acteur sérialise déjà** : il sérialise les *pas*, pas les *transactions* | permanent |
| **La clé de doublon d'un titre est « nom replié + année », et l'année peut venir de deux colonnes.** `ImportWriter.duplicateYear(of:)` lit `year` **puis** `release_date`. Ne regarder que la première était un bug bloquant : `TitleQuery.living` traite une année nulle comme « cherche un titre **sans** date », donc un fichier portant « Date de sortie » seule écrivait une date puis cherchait son absence — mesuré, deux lignes identiques importées deux fois donnaient **quatre** fiches, sans un signal. Toute colonne future qui alimenterait `releaseDate` doit entrer dans cette fonction | permanent |
| **Le bilan d'import se replie par entité, pas par ligne.** Un fichier peut décrire la même fiche sur plusieurs lignes — un export « une ligne par visionnage » le fait. Sans repliage, le bilan comptait « 1 ajouté, 2 complétés » pour **un** titre, et le même `UUID` figurait dans `createdTitleIDs` **et** dans `completions` : `L20` aurait supprimé le titre puis tenté de restaurer des champs sur une fiche disparue. Précédence `created > completed > unchanged`, valeurs d'avant fusionnées avec **la première** gagnante — c'est celle d'avant l'import | permanent |
| **Un réimport enrichi ajoute les membres manquants des relations, et le privé est monotone.** Deux arbitrages du 2026-08-04, tous deux réversibles mais à ne pas défaire par inadvertance. (a) `genres`, `director` et `cast` sont **additifs** : un second fichier plus riche complète au lieu de ne rien faire — mesuré, l'ajout était sinon abandonné sans être compté nulle part. Rien n'est jamais retiré, et un import identique reste « inchangé ». La **collection** n'est pas additive : un titre n'en a qu'une, donc l'écrire remplacerait. (b) `is_private` ne va que dans un sens : un fichier peut rendre privé, jamais rendre public. Exposer un contenu marqué privé est la seule des deux erreurs qui ne se répare pas (fuite fermée par `L3`, index Spotlight unique pour l'appareil). **Cette monotonie est gardée deux fois** — `isEmpty` et `setTyped` — et casser une seule des deux laisse les tests verts : ce n'est pas une redondance à simplifier | permanent |
| **Le verrou d'import protège un `ModelContainer`, pas une instance d'acteur.** Il était indexé sur `ObjectIdentifier(actor)` : deux `ImportActor` sur le même conteneur avaient deux verrous, et s'entrelaçaient — mesuré, **600 titres au lieu de 300**, sans qu'aucun `alreadyRunning` ne soit levé. Une propriété calculée qui fabrique un acteur par accès suffit à déclencher le cas. Et `ObjectIdentifier` est une adresse **recyclée** : cinq acteurs successifs donnaient deux identités, donc la clé n'identifiait pas un acteur. `NSMapTable` à clés faibles comparées par pointeur — pas `weakToStrongObjects()`, qui appelle `-hash` sur un `ModelContainer` qui n'est pas `Hashable` et le signale en console | permanent |
| **Un helper de test qui construit un CSV doit échapper.** La première version de `csv(header:rows:)` joignait les champs par `;` sans rien échapper, pour « ne pas dépendre de l'écrivain qu'on éprouve ». Conséquence : **aucun** test l'employant ne pouvait exercer une valeur contenant le séparateur ou un guillemet, et une revue a cru y voir un bug de production qui n'existait pas. Il passe désormais par `CSVWriter` ; `rawCSV(_:)` reste pour les cas qu'un écrivain correct ne produit pas — une ligne trop courte, un encodage fautif — et le format brut est vérifié octet par octet par `CSVWriterTests`, qui n'utilise ni l'un ni l'autre | permanent |
| ~~Grille non navigable au clavier sur Mac~~ **Réglé par `V0 bis`.** L'écart nommait `PosterCard`, qui n'est plus le composant de la grille : `TitlesGrid` pose des `PosterTile`, et `PosterTile` est un `Button` avec `.focusable(action != nil)` — donc atteignable au clavier et activable par Retour. `PosterCard` garde son `onTapGesture` mais part avec `Legacy/` à `V12`. **La passe d'accessibilité complète reste `V12`** : ce qui est réglé est la navigabilité de la grille, pas l'ordre de focus de tous les écrans | ✅ `ef4ed7e` |
| ~~`MediaEnvironment.displayScale` jamais alimenté~~ **Réglé par `L5`.** Le modificateur `.displayScale(feeding:)` le renseigne depuis l'environnement SwiftUI, et `imageLoader()` **lit l'échelle à l'appel au lieu de la capturer** : une capture aurait figé la valeur de l'évaluation de la scène, donc déplacer la fenêtre vers un écran @1x aurait continué à produire du @2x sans que rien le signale | ✅ `L5` |
| `DemoCatalog` hors des repositories : **décision actée** — une fixture n'est pas une action utilisateur, et on ne veut pas 300 `ActivityEntry` fictives dans le fil. L'invariant `refreshDerived()` tient et `DemoCatalogTests` le vérifie. Reste factice : `MediaAsset.checksum` et `blurHash` non calculés | — |
| `Profile.requiresBiometry` affiché mais non appliqué | `L14` |
| ~~Préchargement de l'écran suivant~~ **Appelé, et son effet est mesuré — `V3`** (`29644e1`). La chaîne complète : `MasonryGrid` signale l'index qui entre à l'écran, `PrefetchScheduler` en déduit une frontière et un ordre, `MediaEnvironment.prefetch` le passe au cache. **Mesure** (`PrefetchEffectTests`) : 0 affichage chaud sur 24 sans préchargement, **23 sur 24** quand le défilement est plus lent que le décodage, 12 sur 24 à 5 ms par pas — le mécanisme est assené, le recouvrement seulement imprimé. **Reste la console de gestion**, qui a ses propres vignettes | ~~`V3`~~ · `V6` |
| `MediaRepository.attach` + invariante `hasExactlyOneOwner` | `L16` |
| ~~`Bootstrap` ne branche pas `startObservingMemoryPressure()`~~ **Écart périmé, et il l'était avant `L5`.** Vérifié le 2026-08-05 : le cache est instancié dans `CineShelfApp.init()` et l'observation est branchée par `.task { media.startObservingMemoryPressure() }` sur `RootView` — le prompt 11 l'avait fait sans que la ligne soit retirée. **Un écart connu qui ne l'est plus est une fausse dette** : il envoie chercher un défaut qui n'existe pas, et il coûte le même temps qu'un vrai | ✅ prompt 11 |
| Dédoublonnage médias : global au magasin (décision actée) | — |
| Reprise d'import par lot de 200, pas par élément | `L11` · `L13` |
| `⇧⌘I` / `⇧⌘E` présents mais grisés | `V8` |
| Avertissement à l'écran quand un profil change de bibliothèque | `V7` |
| Les 36 primitives sont générées dans le `.xcassets` alors qu'aucune vue ne doit les lire — à élaguer si le poids devient un sujet | — |
| ~~**Les filtres sont rendus en `StateBadge`, faute du jeton de `I5`.**~~ **Réglé par `I5`** : `FilterChip` existe, avec sa cible de 44 pt et sa croix de retrait. **Les deux écrans qui contournaient restent à reprendre** — la rangée de filtres des titres (`V0 bis`) et celle de la galerie (`V3`) posent encore un badge | à reprendre dans `V6`, ou à la première passe qui touche ces deux écrans |
| **Les jetons de filtre de la galerie ne sont pas ceux du bloc `13c`.** Le prototype propose « Toutes · Affiches · Jaquettes · Plans · Sans titre » — un filtre par **nature d'image**. Ce qui est implémenté filtre par **source** (titre, personne, collection, orphelin), qui est ce que `L1 bis` a écrit et mesuré. Les deux ne se recouvrent qu'en un point : « Sans titre » est l'orphelin. Filtrer par `MediaSlot` est un **autre** filtre, à écrire — et il n'a pas le piège de l'orphelin, `slotRaw` étant une colonne de `MediaAttachment` | une tâche `L` d'appoint, puis retouche de `GalleryView` |
| **La galerie n'a aucun contexte dans la matrice `disposition × taille`, donc son menu « Affichage » n'est pas rendu.** Le bloc `13c` montre un « Portrait · Medium ▾ » dans sa barre, mais les huit contextes de la v1 — ceux qui font foi, `L1 bis` l'a tranché — n'en comptent aucun pour la galerie, et « portrait » n'a de toute façon aucun sens en maçonnerie, où le ratio est celui de l'image. **Ajouter un neuvième contexte rouvrirait le vocabulaire que `L1 bis` a fermé** : à ne pas faire sans arbitrage. Ce qui serait réglable est la **largeur de colonne**, pas la disposition | à trancher — sans doute un cran de `PosterScale` mémorisé hors du vocabulaire v1 |
| **La barre de sélection de la galerie est posée sous l'en-tête, pas en bas de fenêtre.** Le bloc `6f` l'épingle au bas du cadre ; l'écran est un *contenu* de la `ScrollView` que le chrome possède (décision de `V0`), et rien ne s'épingle au bas de la fenêtre depuis l'intérieur d'un contenu défilant. Ouvrir une seconde `ScrollView` serait pire que l'écart | le jour où le chrome propose un emplacement bas |
| **Deux actions du bloc `6f` ne sont pas rendues** : « Rattacher à… » demande un sélecteur d'entité (`I9`) et « Exporter » appartient à l'export. Un bouton inerte est pire qu'un bouton absent — il apprend à ne pas croire l'interface | `I9` puis `V6` · `V8` |
| **L'épaisseur du liseré de sélection diverge entre le bloc `6f` (3 pt, vers l'intérieur) et le §7 (2 pt, offset 3).** Le bloc rendu gagne sur la prose de synthèse, comme la barre latérale du §4.6 avait perdu contre les douze écrans qui n'en montraient aucune. `Stroke.selection = 3` | inscrit, pas à corriger |
| **Les jaquettes de `DemoCatalog` n'ont pas de `blurHash`.** Les images de galerie en ont depuis `V3`, puisqu'elles passent par `MediaIngestor` ; les jaquettes remplissent leurs champs à la main depuis le prompt 11. Donc le placeholder du bloc `9b` — le dégradé de blurhash — n'est exercé que par les médias de galerie, jamais par une affiche | une passe sur `attachPoster`, cinq lignes |
| **L'archivage d'une image n'a aucun écran qui la retrouve.** `MediaQuery.galleryAssets` exclut `isArchived`, ce qui est **déduit** du bloc `6f` : il propose « Archiver » comme action de masse, donc archiver doit faire quelque chose de visible. Mais aucun bloc ne dessine l'écran des images archivées, donc une image archivée disparaît sans recours depuis l'interface | `V10`, avec la corbeille |
| **La visionneuse est une feuille sur macOS, pas une surface plein écran.** `fullScreenCover` n'existe pas sur macOS ; c'est le même choix que `CropEditor` à `V2 bis`. Le zoom, le pincement et le mode immersif fonctionnent dedans, mais la fenêtre garde son chrome système — donc « aucun chrome » du bloc `6d` n'est vrai que du chrome de l'app | à revoir si une vraie fenêtre plein écran devient nécessaire |
| **`TitleFilterPerformanceTests` porte le même défaut de calibration que `SearchPerformanceTests` avait, et il n'a pas encore rougi.** Son plafond est de **25 ms**, calé sur une mesure locale. Le rapport runner / local observé le 2026-08-05 est de 7 à 10 : ce seuil est donc un flake en attente, exactement comme l'autre. Il vit dans la cible app (job « Tests logique (macOS) »), qui est passée au vert ce jour-là — c'est de la chance, pas une preuve. **Non corrigé par `V3`** : la tâche soldait un reste-à-faire et n'avait pas à toucher un test qui passe, mais l'attente d'une occurrence n'a ici aucune valeur d'information, la cause étant déjà connue et écrite | à relever au prochain rouge, ou à la prochaine passe qui touche ce fichier |
| ~~**Les tâches `V` se terminent sur « non vu ».**~~ **Réglé par la sonde de pixels** (`PixelProbe`, `ContentRenderTests`) : cinq assertions de non-vacuité et de distinction, sans aucune permission. `screencapture` est abandonné — la cause est identifiée (TCC attribue l'autorisation à `Switchboard.app`, pas au terminal) et elle n'a plus d'importance. **Ce qui reste hors de portée est le jugement esthétique**, et c'est le tien | méthode |
| **`DatePrecision` existe en double, sous deux noms.** Le modèle le persiste (`Title.releasePrecisionRaw`), `DesignSystem` porte `DateFieldPrecision` pour le rendre. Le double est inévitable — la règle de dépendances interdit aux deux paquets de se connaître — mais **le même nom faisait cesser de compiler `TitleEditor`**, avec un message qui ne nommait ni le type ni le module (« ambiguous use of `year` »). `DisplayVocabularyTests` accorde les `rawValue` | inscrit, comme `CardLayout` / `DisplayLayout` |
| **Les couleurs de profil sont des littérales `displayP3`, hors du catalogue d'assets.** C'est délibéré : une couleur de profil est une **valeur persistée que l'utilisateur choisit**, pas un rôle de l'interface, et elle doit rester la même en clair et en sombre. Trois des quatre sont relevées de la planche 6, la quatrième est l'accent | inscrit, pas à corriger |
| **`TokenFieldRow` pose ses jetons dans un `LazyVGrid` adaptatif, pas dans un vrai flux.** SwiftUI n'a pas de `WrappingHStack` ; un `Layout` maison serait de l'arithmétique à écrire et à tester pour un champ qui porte rarement plus de six valeurs. La grille retourne à la ligne sans qu'on calcule rien, au prix de colonnes de largeur égale — donc d'un jeton court aussi large qu'un long | à revoir si un champ porte vingt genres |
| ~~**Rien ne lit `ActivityEntry`.**~~ **Réglé par `L18`**, et **son écran par `V5b`** (`5c065d3`) : `ActivityFeedView` pagine par curseur de date et groupe par jour local. La boucle est fermée — écrit au prompt 6, lu à `L18`, montré à `V5b` | ✅ `5c065d3` |
| ~~**Le rendu des cinq écrans de `V4` et `V5b` n'est pas assené.**~~ **Réglé par la cible `CineShelfScreenTests`** (`d104974`), qui a un `TEST_HOST` et sonde les sept écrans plus le contrôle négatif. **Deux défauts trouvés en la branchant** : `ImageRenderer` ne met pas en page un `ScrollView` — d'où `ScreenScroll` — et trois écrans de `V5b` portaient un `ScrollView` redondant à l'intérieur de celui de `RegularRootView`. **Ce qui reste vrai** : le *chargement* des images n'est pas couvert ici, voir la ligne suivante | ✅ `d104974` |
| ~~**La console rend le même compte de couleurs vide et peuplée, cause non trouvée.**~~ **Expliqué le 2026-08-06 : `ImageRenderer` ne capture pas les vues adossées à AppKit.** Le test décisif est la variation avec les données — un `Table` rend **9 couleurs à 0, 3 et 60 lignes** quand un `VStack` des mêmes données rend 9, 15 et 74. Les 30 couleurs de la console sont son chrome ; `NSTableView` ne passe pas dans le rendu, et un `Form` groupé ne rend rien du tout. **Ma première lecture était fausse** : j'avais pris ces 9 couleurs pour la preuve que le corps rendait. La règle « une porte de rendu doit varier avec ses données » entre dans `CLAUDE.md` | ✅ expliqué · remplacement ci-dessous |
| **La porte de la console n'existe pas encore, et les trois tests d'interface sautent.** L'infrastructure est en place — `CineShelfUITests` gagne macOS (mesuré : elle y tourne, contrairement à ce que `project.yml` affirmait), amorçage par `-cineshelf-seed <n>` en DEBUG, trois identifiants d'accessibilité, trois tests qui portent les vérifications voulues. **Ce qui bloque** : l'app se lance, `wait(for: .runningForeground)` passe, et **aucune fenêtre n'apparaît dans l'arbre d'accessibilité** — l'application y figure « Disabled », son sous-arbre ne contient que la barre de menus. Les tests **sautent** plutôt que de rougir sur un défaut qui n'est pas celui qu'ils cherchent. **C'est pour ça que la ligne 21 reste en 🔶** | à reprendre — c'est la porte de l'écran le plus dense |
| **Le transfert entre bibliothèques du bloc `7f` n'est pas rendu** — « Déplacer vers une autre bibliothèque », avec sa clôture transitive et son aperçu des dépendances. C'est `L15`, reportée en v1.1. En rendre la coquille donnerait un bouton qui ne déplace rien | v1.1 avec `L15` |
| **La corbeille et la maintenance du bloc `7g` ne sont pas rendues** — « Vider maintenant », « Analyser ». C'est `L16`, tâche 23, non faite | `L16`, puis une reprise de `V7` |
| **La console ne liste que les titres et les personnes.** Le bloc `7a` en montre une dizaine dans sa colonne de gauche, mais l'édition en masse de `L10` ne couvre que ces deux entités : une entrée « Genres » ouvrirait une table dont l'inspecteur ne saurait rien faire | à rouvrir si `L10` s'étend |
| **Les profils sont une section des réglages, pas l'écran séparé du bloc `7f`.** Motif : `AppSection` n'a pas de cas « Profils », et en ajouter un pousserait une entrée de plus dans une barre d'onglets qui n'en couvre déjà que cinq sur douze. Un écran inatteignable serait pire que dense | `V12`, ou une reprise de la navigation |
| ~~**La correction en masse depuis l'aperçu (`11f`) n'est pas livrée**, ni l'abandon avec reprise de brouillon (`11g`)~~ — **résolu par `9c0e3f9`.** `11f` livre « saisir une valeur pour toutes », la seule des quatre stratégies de la planche qu'`ImportCorrection` sait exprimer ; les trois autres sont nommées comme non livrées. `11g` livre les trois issues et le brouillon reprenable | — |
| ~~**La correspondance mémorisée n'est pas rejouée**~~ — **résolu par `9c0e3f9`** : `rememberedMapping(forHeader:in:)` fait la jointure, et la case « Mémoriser » du bloc `11d` l'écrit. Les deux se livraient ensemble ou pas du tout — une lecture sans écriture n'aurait jamais rien rendu | — |
| **`CSVFormatTests` décide du format CSV et ne cite presque aucune source** : 34 fonctions, **une** citation. C'est le voisin direct du défaut de `L12`, et l'infraction la plus nette à la règle « un test cite la source de son assertion » entrée dans `CLAUDE.md` le 2026-08-07. Relevé par le `grep` que la doctrine impose au moment d'écrire la règle ; **non corrigé** dans cette passe, pour ne pas rouvrir un fichier au milieu d'une autre tâche. Mesure d'ensemble : 16 fichiers de test sur 55 citent une source | une passe dédiée |
| **Le bandeau de reprise d'import n'est pas sur l'écran Titres**, contrairement à la planche `11g` qui l'y dessine. Il est sur l'écran d'import, à l'état `idle`. Le poser sur Titres ferait connaître `ImportDraftStore` à une autre `Feature` et ouvrirait un routage entre les deux. Conséquence réelle : un utilisateur qui ne rouvre pas Import ne saura pas qu'un brouillon l'attend | `V10` ou une passe de navigation |
| **Trois des quatre stratégies de correction en masse de la planche `11f` ne sont pas livrées** : « déduire l'année du titre », « chercher dans la fiche existante » et « importer en brouillon ». La première demande une règle d'extraction dans le cœur ; les deux autres exigeraient d'interroger le magasin **depuis l'aperçu**, ce que la coupe `L11a`/`L11b` interdit. Elles sont nommées ici plutôt que rendues en boutons inertes | une passe dédiée, après une décision sur la coupe |
| **`ContentRenderTests` sur iOS dépend d'un simulateur chaud.** Mesuré le 2026-08-07 : rouge au premier passage (`loaded.distinctColours` → 2 au lieu de > 8, avec `IOSurfaceClientSetSurfaceNotify failed` dans le log), **vert au second, sans changement de code**. Un runner CI est toujours froid — la CI passe donc par chance, pas par construction. Le remède est le même que celui déjà appliqué au lancement iOS sous XCUITest : préchauffer, ou attendre la surface avant de rendre | `V12` ou une passe CI |
| **Le brouillon d'import n'est jamais écrit puis relu par l'app réelle.** `ImportDraftStore` est couvert par ses tests, `restoredAnalysis()` aussi, et le rendu du bandeau par la sonde d'écran — mais le chemin complet « abandonner, quitter, rouvrir, reprendre » passe par le disque et par le cycle de vie de la vue, et rien ne l'exerce | un test d'interface |
| **Aucun import réel n'a été joué de bout en bout.** Le parcours demande un `fileImporter`, donc un clic. Les transitions sont couvertes par `ImportFlowTests`, l'écriture par les tests de `L11b` ; ce qui n'est exercé par rien est la **couture** — la seconde lecture du fichier à l'étape d'analyse, et le passage des lignes à `ImportActor.importRows` | `V8` second jalon, ou un test d'interface |
| **L'écran d'import relit le fichier deux fois** — une fois pour la correspondance, une fois pour l'analyse — en gardant son `URL` plutôt que son `Document`. C'est un choix : garder 1 284 lignes analysées en mémoire pendant que l'utilisateur choisit ses colonnes coûte plus que la relecture. À revoir si un fichier très gros rend la seconde lecture visible | à mesurer si ça se voit |
| **`LocalAuthenticationEvaluator` n'a jamais tourné contre le système.** Aucun test ne peut déclencher Face ID ou Touch ID : la frontière est un protocole et les tests fournissent un évaluateur factice, comme la fiche l'exige. Conséquence à dire : sa **traduction d'erreurs** — `.userFallback` traité comme une annulation, `.biometryLockout` distingué — est écrite contre la documentation d'Apple, pas contre le comportement observé. Le premier passage réel sera à `V7`, à la main, sur un appareil | `V7`, vérification manuelle |
| **`AppLock.isEnabled` n'existe pas encore** : `LockPolicy.decide` le prend en paramètre, mais rien ne le stocke. C'est un `@AppStorage` — un réglage **local à l'appareil**, `docs/02` §9.1 le dit — donc il appartient à l'écran de réglages, pas au cœur. `V7` le pose, et c'est lui qui branchera `LockPolicy` sur `scenePhase` | `V7` |
| ~~**`Profile.requiresBiometry` est affiché mais jamais appliqué.**~~ **Réglé par `L14`** (`2893e7c`) : `PrivacyScope.resolve` masque le contenu privé tant qu'un profil qui l'exige n'a pas été déverrouillé. C'était un interrupteur qui ne faisait rien, donc pire qu'un réglage absent | ✅ `2893e7c` |
| **Le chargement des images n'est pas couvert par la sonde d'écran**, et le fichier le dit : `ImageRenderer` rend de façon synchrone, donc un `.task` n'a pas tourné, et le décor n'attache aucun média. Ce chemin est couvert par `ContentRenderTests` de `DesignSystem`, qui injecte un chargeur et laisse tourner la boucle. **Croire que la suite d'écran couvre les deux serait l'erreur exacte qui a laissé passer `MediaFill`** | permanent — à ne pas « corriger » en dupliquant la sonde |
| **`Profile.accent` est lu 53 fois et écrit nulle part.** Trouvé par le balayage de propagation de la règle « une capacité lue et jamais écrite ». Ce n'est pas un défaut aujourd'hui — l'écran qui l'écrirait est `V7`, profils et réglages — mais c'en sera un si `V7` livre sans le sélecteur de couleur. `ProfileColorPicker` existe depuis `I9` et n'a, lui non plus, aucun appelant | `V7` |
| ~~**Le texte d'origine de l'écart de rendu, conservé parce qu'une ligne rayée dit qu'on y a regardé.**~~ La règle « une tâche `V` se termine par un rendu assené » a été appliquée : la sonde a été écrite, puis **retirée**, parce que `CineShelfTests` n'a **aucun `TEST_HOST`** — `project.yml` le documente (« la lier à la cible app imposerait de lancer l'interface ») et compile des fichiers app choisis un par un. Rendre `PeopleView` y demanderait la fermeture transitive de toutes les vues. Ce qui a été fait à la place couvre le risque réel de cette tâche — le portrait invisible, six tests et une preuve d'échec — mais **aucun pixel des cinq écrans n'a été vu**. Trois issues possibles : une cible de test à `TEST_HOST` dédiée, une extraction des compositions vers `DesignSystem` (où les sondes tournent déjà), ou l'acceptation explicite | `V12`, ou une tâche dédiée |
| **Le lieu de naissance du bloc `4d` n'est pas rendu** — « Cork, Irlande ». `Person` n'a pas de champ pour ça, et le schéma est **fermé** depuis le 2026-08-03 : l'ajouter exige un `VersionedSchema` et un `MigrationStage`, ce qu'un écran ne déclenche pas. Ce n'est pas un cas de « le design contraint le modèle » — c'est bien une donnée à stocker, simplement hors du périmètre d'une tâche `V` | une migration, si le champ est voulu |
| **« 41 doublons possibles » de l'en-tête `4c` n'est pas calculable**, et **l'écran de fusion de `V4` n'existe pas** : les deux viennent de `L8`, reportée en v1.1, dont la fiche du report nomme explicitement « l'écran de fusion de `V4` ». L'en-tête des personnes annonce donc le seul compte qu'il sait tenir | v1.1 avec `L8` |
| **L'« Annuler » de chaque ligne du Fil (bloc `5e`) n'est pas rendu.** C'est `L20`, tâche 19 du palier 3. `ActivityItem.isUndoable` existe déjà et dit *laquelle* serait annulable ; ce qui manque est l'exécuteur. La ligne est rendue **sans le bouton** plutôt qu'avec un bouton inerte — même décision que les actions absentes de `SyncStatus` | `L20`, puis une reprise du fil |
| **Le « Profils ▾ » du bloc `5e` n'est pas rendu.** `ActivityFilter` ne porte pas de profil, et `ActivityEntry` non plus — le schéma est fermé. Le filtre par type est livré, celui par profil ne peut pas l'être sans migration | une migration, si le filtre est voulu |
| **L'en-tête du fil annonce ce qu'il montre, pas le total du journal.** Le bloc `5e` écrit « 1 402 événements » ; l'écran lit une fenêtre de cent au plus, et un `fetchCount` sur tout le journal à chaque rendu coûterait plus que la fenêtre elle-même. « 47 événements · 30 jours conservés » est donc exact et plus modeste que le prototype | à trancher si le total compte |
| **`TitleEditor` reste le dernier fichier de `Features/Titles` dans `no_legacy_design_system`**, et il n'est **plus bloqué** : `I7`–`I9` sont faites, et `PersonEditor` (`63bf776`) démontre le branchement complet — champs, anatomie d'erreur, récapitulatif de refus, et la conversion `PrecisionDate` ↔ `Date` qui manquait. Le reprendre est désormais mécanique | `V0 bis`, l'éditeur |
| **Le tri des personnes par crédits et des rayons par nombre de titres se fait en mémoire.** SwiftData ne trie pas sur le compte d'une relation. Sans pagination — les deux grilles rendent tout ce que le filtre laisse passer — l'ordre est complet ; le jour où l'une pagine, « la personne la plus créditée » deviendrait « celle de la page ». `PersonSortField.sortsInMemory` expose le cas plutôt que de le laisser deviner | à revoir si une grille pagine |
| **Le jeton de filtre « Genre » de la grille des personnes ne porte pas le nom du genre.** La vue n'a que son `UUID`, et le résoudre demanderait un `fetch` par rendu. Le jeton dit qu'un filtre porte et sa croix le retire, ce qui est sa fonction ; il ne dit pas *lequel*. La grille des titres a le même défaut sous une autre forme | `V6`, ou une passe sur les jetons |
| **Le filtre du fil s'applique après le `fetch`, donc une fenêtre filtrée peut rendre moins que `limit`.** `action` et `entityType` sont des `rawValue` de `String` : un prédicat sur un `Set` d'énumérations demanderait de les convertir et de traverser deux ensembles, pour une différence non mesurable sur cent lignes. La vue pagine sur la date, donc elle retrouve les entrées manquantes au tour suivant — mais un écran qui afficherait « 12 résultats » sur une fenêtre filtrée dirait faux | `V5b`, si le compte est affiché |
| **Les statistiques n'ont aucun écran, et leur durée totale exclut les séries.** `L18` rend des séries de valeurs ; `Swift Charts` vient avec `V11`, et la fiche le dit. `runtimeExclusions` compte ce que le total ne couvre pas — encore faut-il que l'écran l'affiche, sinon « 412 heures » se lira comme le temps de toute la bibliothèque | `V11` |
| **`L7` n'utilise pas `LPMetadataProvider`, contre sa propre fiche.** Il va chercher l'URL lui-même — connexion, redirections, lecture — sans exposer de point de contrôle, or la protection demandée porte exactement là-dessus : un serveur public répondant `302 Location: http://127.0.0.1:6379/` obtiendrait ce que la garde empêche. Le fetch passe par `URLSession` et son délégué. **Ce qu'on perd** : l'icône et l'image de prévisualisation, que `LPMetadataProvider` rend en plus d'un titre | à rouvrir seulement derrière un mandataire local, ou en acceptant le trou |
| **La garde de lien ne voit pas la résolution DNS.** Un nom d'hôte public qui *résout* vers une adresse privée passe : `LinkGuard` lit le texte de l'URL, la résolution a lieu dans `URLSession`, qui n'expose pas l'adresse retenue. Fermer ce chemin demanderait de résoudre soi-même puis de forcer la connexion sur l'adresse validée — hors de portée de `URLSession` | inscrit ; la parade complète est un `NWConnection` à la main |
| **Les IPv4 en octal ou en hexadécimal ne sont pas reconnues comme adresses.** `0177.0.0.1` et `0x7f.0.0.1` sont refusées par le parseur, donc jugées comme des **noms** : avec des points, elles passent la garde. `URLSession` les résout-elle comme des adresses ? Non vérifié | à mesurer, puis à fermer dans `IPAddress.parseIPv4` |
| **`URLSessionLinkFetcher` n'a jamais émis de requête.** La fiche interdit toute sortie réseau dans les tests, donc la garde est couverte et le **chemin réseau ne l'est pas** : ni la lecture en flux, ni la borne de 512 Ko, ni le refus de redirection à l'exécution. Le protocole `LinkMetadataFetching` rend la chose testable le jour où on acceptera un serveur local dans la suite | une sonde hors dépôt, si le besoin se présente |
| **`L17` ne sera pas vérifiable avant le prompt 21.** La machine, les six messages et le calcul d'espace sont écrits et couverts **en simulation**. Ni les notifications réelles du coordinateur CloudKit, ni leur charge utile, ni leur ordre d'arrivée, ni les cas de compte et de quota n'ont été joués — aucun test local ne peut les produire | repasse après l'activation de CloudKit |
| **`SyncState` de `DesignSystem` a quatre cas là où `SyncStatus` en a six.** Le jeu visuel ignore `needsAccount` et `quotaExceeded` : l'indicateur de la barre ne peut pas les distinguer, et un mappage les écraserait sur `.failed`. Le double est le motif habituel — les deux paquets ne peuvent pas se connaître —, mais ici il **perd de l'information** | `V10`, qui réécrit l'indicateur |
| **La marge horizontale du tableau est de 18 pt aux deux crans de densité.** Seul le bloc dense la rend ; une valeur ample déduite par proportion serait une mesure que personne n'a dessinée. Choix de ne pas inventer | au premier rendu ample de la console |
| **Aucun bloc ne rend une ligne de tableau sélectionnée.** Le bloc `7a` annonce « 1 sélectionnée » dans son en-tête sans qu'on voie laquelle. `TableRow` pose donc un fond `bg.fill` **plus** une barre d'accent de 2 pt : le fond seul est déjà celui du survol, donc « sélectionnée » et « sous le curseur » auraient rendu la même chose — le motif exact de « deux états qui rendent la même chose ». Déduction, pas relevé | à confirmer au design |
| **Le jeton de filtre n'a qu'une graisse là où le prototype en a deux.** Bloc `7d` : actif en 600, inactif en 400. Le système n'a pas d'Archivo Narrow 400 — les faces enregistrées sont `SemiBold` et `Bold`. Ajouter une face pour un écart de graisse sur 11 pt coûterait un fichier de police et une entrée de registre ; les deux états restent distincts par le fond et la couleur du texte | à rouvrir seulement si le design y tient |
| **La vignette de ligne de tableau (16 × 24) est hors de l'échelle d'affiche.** `PosterScale.xs` fait 32 pt de large, donc 48 de haut : une ligne de 30 pt ne peut pas la contenir. C'est le seul endroit de l'app où une image sort des six crans, et la contrainte vient de la ligne, pas de l'échelle | inscrit, pas à corriger |
| **La sélection multiple se déclenche par bouton sur les deux plateformes.** Le bloc `6f` demande « bouton sur iPad, appui long sur iPhone ». Le bouton est rendu partout ; l'appui long n'est pas posé | `V12`, avec la passe d'accessibilité et les gestes |

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

### Arbitrage de la revue visuelle du catalogue — 2026-08-04

> **Tranché par le client, à conserver.** Dix écarts relevés en confrontant les composants
> livrés par `I2` `I3` `I4` `I6` aux blocs qui les spécifient. Le classement ci-dessous
> **fait foi** ; il ne se re-débat pas, il s'exécute.
>
> **Le principe qui sépare les deux colonnes** — reporté dans `CLAUDE.md` : *les rendus
> gagnent quand ils s'accordent entre eux, le jeton gagne quand ils se contredisent.*

#### À corriger — les blocs sont précis et cohérents entre eux

| # | Composant | Le bloc dit | Le code fait | Décision |
|---|---|---|---|---|
| 1 | `ProfileAvatar` · barre | `3a` : `font:600 11px 'Archivo Narrow'` sur le carré de 26 ; `7f` : `font:400 20px 'Bebas Neue'` sur celui de 46 | `Typo.title2` (**Bebas 22 pt**) aux deux tailles | **Corriger.** Le prototype change de police avec la taille, et les deux blocs sont d'accord chacun sur le sien. Même motif que `PersonTile` : une valeur relevée sur un bloc, généralisée à tort — ✅ `4759d80`, la barre passe à `Typo.label` (Archivo Narrow 600, 11 pt, soit exactement `3a`). **Le carré de 46 garde Bebas à 22 et non 20** : aucun rôle de `Typo` n'est Bebas à 20, et en ajouter un rouvrirait la porte que `Typo` a fermée — même motif que l'écart 8. Les 2 pt passent aux écarts connus |
| 2 | `ProfileAvatar` · barre | `3a` : **26 pt** | **28 pt** | **Corriger.** Le 28 venait de moi, pas d'un bloc — ✅ `4759d80` |
| 5 | `RatingBar` · étoile vide | `8a` : `oklch(0.34 0 0)` | `bgFill` `#2B2B2B` = oklch **0,289** (mesuré ; l'estimation « ≈ 0,26 » de cette table était fausse) | **Corriger.** Les étoiles vides se lisent moins que dessiné — l'écart réel est plus petit qu'annoncé, mais il existe et va dans le sens dit. Tranché en écrivant le correctif : **un jeton**, `rating/empty`, et non une valeur dérivée de `bgFill` — la barre vit aussi sur les surfaces de gestion, qui suivent l'apparence système, où « éclaircir le fond » donnerait une étoile plus claire que sa surface. ✅ `3627a51` |
| 3 | `TileRail` · gouttière | **iPhone 10 · iPad 14 · Mac 14** | `breakpoint.gridGutter(density)` = 16 dense / **24 ample** | **Corriger** — vérifié le 2026-08-04, voir ci-dessous. ✅ `c055df1` : `Breakpoint.railGutter`, point d'entrée distinct de `gridGutter(_:)`, qui reste la gouttière de **grille** |

**L'écart 3 était « à vérifier avant de trancher », et la vérification est concluante.** Le
prototype Mac ne montre pas la densité ample, mais l'addendum 2 a rendu l'accueil et la
fiche en **iPhone** *et* en **iPad**. Relevé dans son HTML :

| Format | Gouttière de rail | Marge de gauche | Jeton `Breakpoint.screenMargin` |
|---|---|---|---|
| iPhone 393 | **10** | 20 | 20 — **exact** |
| iPad 834 | **14** | 28 | 28 — **exact** |
| Mac 1280–1440 | **14** | 36 · 40 · 44 | 32 |

Deux conclusions, et elles vont dans des sens opposés :

- **La gouttière de rail ne suit pas la densité.** Elle vaut **10 sous 430 pt et 14
  au-delà** — trois formats d'accord entre eux. `Density.baseGridGutter` (16/24) n'a rien à
  voir avec elle. Les rendus gagnent : c'est une mesure **par point de rupture**, comme
  `screenMargin`, et pas une mesure de densité.
- **La marge de rail, au contraire, se confirme comme jeton.** Les deux formats rendus pour
  de vrai tombent **exactement** sur `Breakpoint.screenMargin` (20 et 28) ; seuls les blocs
  Mac errent entre 36, 40 et 44. C'est la définition d'une valeur jamais contrôlée, donc
  l'écart 4 reste au jeton — et cette mesure le renforce au lieu de l'affaiblir.

#### À garder au jeton — l'écart est inscrit, le code ne bouge pas

| # | Composant | Le bloc dit | Le code fait | Motif |
|---|---|---|---|---|
| 4 | `TileRail` · marge de gauche | `2a` 44 · `3a` 40 · `4b` 36 | `Breakpoint.screenMargin` = 32 | **Trois blocs Mac, trois valeurs** : jamais contrôlée. Et iPhone/iPad tombent pile sur le jeton |
| 6 | `AdaptiveTileGrid` · gouttière | `4a` : 18 | 16 (dense) | 18 n'est aucun cran de l'échelle de base 4 |
| 7 | `TileRail` · libellé → rangée | `2a`/`3a` : 10 | `Space.s3` = 12 | 10 n'est aucun cran |
| 8 | `StateBadge` · vignette | `9d` : 9 px, `+0.18em` | `Typo.label` : 11 pt, `+0.12em` | Une taille de police par usage rouvrirait la porte que `Typo` a fermée |
| 9 | `ProgressTrack` · piste | `11e` : `oklch(0.28 0 0)` | `bgFill` = oklch 0,289 (mesuré) | **Un** centième de luminance, pas deux : la mesure faite en corrigeant l'écart 5 renforce cet arbitrage au lieu de l'affaiblir. Et le §10 dit lui-même qu'aucun jeton de piste n'existe |
| 10 | `PersonTile` · casting | `4b` : cercle 96 pt | cran `.m` = 92 | Aucun cran de `PosterScale` ne vaut 96, et l'échelle est une fonctionnalité |

#### `catalogue-porte` — la tâche qui rend ces écarts vérifiables

**À faire AVANT les corrections 1, 2, 3 et 5**, parce qu'elle est ce qui permettra de les
constater au lieu de les déduire.

**Le constat qui la motive.** `PersonTile` a été livrée fausse à `I2` — un rectangle 2:3 là
où la direction montre des cercles — et elle a passé **tous les tests** *et* la planche du
catalogue. Il a fallu trois lots et un écran qui s'en servait pour s'en apercevoir. Le
catalogue montre chaque composant **seul**, jamais à côté de sa planche : on y vérifie qu'un
composant existe et qu'il tient dans les quatre apparences, pas qu'il **ressemble** au bloc.
C'était pourtant sa seule raison d'être.

**Objectif.** Que chaque composant du catalogue affiche, à côté de lui, **la valeur attendue
du bloc qui le spécifie** — pour qu'un écart se voie.

- Une petite structure de référence par composant : le bloc source (`4b`, `9d`…), et les
  mesures qu'il donne (taille, gouttière, police, couleur), en texte.
- Rendue à côté du composant, dans le même style que les notes existantes des planches.
- **Aucune assertion** : c'est une porte d'acceptation **visuelle**, pas un test. Un test qui
  comparerait des nombres se contenterait de recopier les mêmes valeurs et n'attraperait
  rien de ce que l'œil attrape (la forme, la police, le poids).
- Les dix écarts de la revue y entrent comme **premier contenu** : ils sont la démonstration
  que la porte fonctionne, puisqu'on sait déjà ce qu'elle doit montrer.

**Terminé quand** : les composants de `I2` `I3` `I4` `I6` portent leur bloc et leurs mesures
dans le catalogue, et que les écarts 4, 6, 7, 8, 9, 10 s'y **lisent** sans avoir à ouvrir
une planche.

**Rigueur légère.** Le classement de la section « La rigueur se règle sur
l'irréversibilité » ne change pas : c'est du catalogue, rien ne s'écrit en base.

#### Relecture du tableau — 2026-08-05

**Première relecture complète depuis la création du tableau.** Déclenchée par une trouvaille
de `L5` : `startObservingMemoryPressure()` y traînait comme dette alors qu'il était branché
depuis le prompt 11. La question « combien d'autres ? » n'avait jamais été posée.

**86 lignes relues contre le code du jour.** Le décompte est au journal. Ce qui suit est le
seul contenu qui **disparaît** du tableau, avec son motif — un retrait sans trace se relit
comme un oubli.

| Ligne retirée | Pourquoi elle est sans objet |
|---|---|
| `Typo.sectionTitle` inutilisé dans `App/` | Le jeton n'existe plus sous ce nom : il est passé dans `Legacy/LegacyTypography.swift` avec l'ancienne direction. La ligne nommait un symbole absent, et le sujet est déjà porté par « `Legacy/` du design system est en sursis jusqu'à `V12` », qui l'emmène en bloc |
| Bloc « Bibliothèques » de la barre latérale affiché mais inerte | `App/Navigation/Sidebar.swift` a été **supprimée** par `V0` : douze écrans rendus n'en montrent aucune. Plus de bloc, donc plus d'inertie. Le sujet réel — où l'on change de bibliothèque — a sa propre ligne, qui l'envoie à `V7` |
| Le pont `Binding<AppSection?>` de `Sidebar` avale la désélection | Même motif : la vue n'existe plus. La remarque de fond qu'elle portait — « si un état *rien de sélectionné* devient nécessaire, c'est `NavigationModel.section` qu'il faudra rendre optionnelle, pas la vue » — n'a plus de support, et la réintroduire supposerait une barre latérale que la direction retenue n'a pas |

**Ajouté à la routine, et c'est la leçon.** Le tableau se relit **à chaque fin de palier**, pas
jamais. Une dette résolue qu'on n'a pas rayée coûte exactement le temps d'une vraie : elle
envoie chercher un défaut absent, et le jour où on la découvre elle fait douter de tout le
reste du tableau.


### Arbitrages tranchés

Trois questions posées pendant la refonte de la direction artistique. Elles sont
fermées : ce ne sont plus des questions ouvertes, et il n'y a pas à y revenir sans
élément nouveau.

**1. Portée de l'apparence claire - la recommandation du design est retenue.**

Les surfaces de gestion suivent l'apparence système, claire ou sombre. L'accueil, les
fiches et la galerie sont **forcés en sombre**, quelle que soit l'apparence choisie
par l'utilisateur.

C'est la convention d'Apple sur ses propres surfaces de visionnage : Photos, Aperçu et
Final Cut forcent le sombre. Second motif, pratique celui-là : cela évite de dessiner
et de tester une variante claire pour des écrans dont le design dit lui-même qu'elle
n'y fonctionne pas.

Ce que ça implique :

- les quatre apparences de l'Asset Catalog restent (Any, Dark, Any HC, Dark HC) : les
  surfaces de gestion en ont besoin, et le contraste élevé reste une contrainte du
  brief sur **tous** les écrans ;
- le forçage se pose par écran, avec `.preferredColorScheme(.dark)` sur la racine de
  chaque surface de visionnage, pas globalement sur l'app ;
- une valeur claire reste néanmoins renseignée pour tout jeton : un jeton partagé
  entre gestion et visionnage doit se résoudre correctement des deux côtés.

**2. Doublons du multi-sélecteur - déjà résolu côté logique.**

`GenreRepository.findOrCreate(name:target:in:)` dédoublonne déjà sur `nameKey`, replié
sans casse ni accents, par bibliothèque et par cible. Saisir un genre existant ne crée
donc aucun doublon, quelle que soit la façon dont il est tapé.

Il ne reste que la part visible : pendant la saisie, afficher « genre existant »
plutôt que « créer » quand la frappe correspond à un `nameKey` connu. C'est une
**tâche V**, portée par `V5`, pas une question ouverte.

**3. Passe sur les réglages - reportée, le design a raison.**

À reprendre quand le périmètre réel des options sera connu, c'est-à-dire **après les
prompts CloudKit** (21 et 22) : la synchronisation, la corbeille et l'espace occupé
ajoutent des réglages qu'on ne sait pas encore énumérer. Dessiner l'écran maintenant
reviendrait à le redessiner ensuite.

**4. Les manques du système de couleur - tranchés le 2026-08-04, avant `I1`.**

Le §10 du handoff en listait quatre. Deux se déduisent sans aucune valeur nouvelle, un
est une décision déjà prise, et un seul demandait un arbitrage. Un cinquième manque,
que le handoff ne listait pas, est apparu en relisant l'arbitrage 1.

| Manque | Décision |
|---|---|
| **Teinte de remplissage d'état** | **Aucun jeton.** Ce n'était pas un oubli : l'addendum écrit « aucun fond coloré, et je n'en ai pas créé ». La règle est conservée telle quelle - l'état passe par le libellé, le trait, le symbole et le message. Si une teinte devient nécessaire un jour, la forme compatible avec « zéro translucidité sur surface opaque » est un **aplat opaque pré-composé**, procédé de `bg.inset`, jamais un `danger` à 12 % |
| **Couleur d'avertissement** | **Aucun jeton.** Un jaune d'avertissement tomberait vers la teinte 95, trop près de l'accent ambre (teinte 66) pour que « l'ambre ne sert qu'à trois choses » reste lisible. **Et le détournement de `danger` était faux, pas seulement provisoire** : le §6 écrit qu'une colonne non reconnue « n'est pas une erreur », et elle était rendue en rouge. Elle passe en **`text.tertiary`** ; la correspondance déduite garde `accent`. L'avertissement est porté par `exclamationmark.triangle`, ce que le système fait déjà |
| **Trait d'état** | **Aucune couleur nouvelle** - le designer le dit lui-même : « une combinaison de deux tokens existants ». L'épaisseur se découple de la couleur, et `stroke.emphasis` 2 pt rejoint `stroke.hairline` 1 pt pour le récapitulatif de refus |
| **Piste de progression** | **Aucune couleur nouvelle.** `progress.track` est un alias de `bg.fill` ; les segments restent `success`, `danger`, `text.tertiary`. C'est déjà ce que le prototype utilise |
| **`bg.inset`, trois apparences sur quatre** (hors handoff) | **Déduites**, en reprenant le rapport choisi par le designer en sombre - 35,4 % du chemin `bg.canvas` vers `bg.surface`. `#080808` sombre (canonique), `#000000` sombre HC, `#f6f6f6` clair, `#f8f8f8` clair HC. C'est l'arbitrage 1 qui l'a rendu nécessaire : `bg.inset` est le fond de la console, et les surfaces de gestion suivent désormais l'apparence système. À ne pas confondre avec `bg.viewer`, identique dans les quatre apparences et **volontairement** |

**Deux hexadécimaux du handoff étaient faux**, corrigés dans `design/README.md` §4.1 :
`bg.inset` donné à `#1f1f1f` (la valeur de `bg.raised`, *au-dessus* de `bg.surface`) et
`bg.viewer` à `#0f0f0f` (*plus clair* que `bg.canvas`). Les deux contredisaient le rôle
écrit du jeton, et pour la même raison : ce sont les deux jetons ajoutés tardivement,
dont l'hexadécimal n'avait pas été recalculé depuis l'`oklch`. Les valeurs `oklch` de la
planche 8 font foi, et c'est `#080808` et `#010101`.

**Ce que ça change pour `I1`** : plus rien ne bloque. Le total est de **zéro couleur
nouvelle à inventer** et trois valeurs déduites d'une échelle existante. Le détournement
que le handoff signalait vivait dans les **écrans** d'import, pas dans les jetons : il
n'y avait donc rien à graver dans le catalogue d'assets - mais il y avait bien un trou à
combler, `bg.inset`, que personne n'avait vu.

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

### Le chemin critique — trois paliers, sur Mac

> **Recentré sur le Mac le 2026-08-04 (3).** Les deux versions précédentes de cette
> section ordonnaient le travail autour d'un jalon iPhone — d'abord « juger le design sur
> mes vraies affiches », puis « l'app s'installe sur mon iPhone ». **Les deux étaient à
> côté** : l'objectif principal est l'app **sur Mac**, et l'iPhone vient après.
>
> Ce que ça change concrètement : **`P0` (la signature) sort du chemin critique.** Elle ne
> bloque rien — le Mac ne demande aucune signature, le simulateur iOS non plus. Elle se
> vérifiera le jour où l'appareil devient nécessaire, c'est-à-dire pour les **mesures de
> performance réelles**, en fin de parcours.

Le Mac n'a besoin de rien d'autre que du code : `DemoCatalog` peuple 120 titres depuis les
Réglages, et la signature ad hoc suffit. Les trois paliers ci-dessous décrivent donc
uniquement du travail d'interface et de logique.

#### Palier 1 — belle et navigable sur Mac

Ce qui rend l'app présentable : l'accueil, la grille des titres, la fiche. C'est le palier
qui remplace le banc d'essai des prompts 10 et 11.

> **Palier atteint le 2026-08-04** : les sept premières lignes sont faites ou en 🔶 assumé.
> Les lignes 8 et 9 sont nées de la **revue visuelle** qui l'a clos — elles ne rallongent pas
> le palier, elles réparent la porte d'acceptation qui lui manquait.

| # | Tâche | Ce qu'elle débloque | Rigueur |
|---|---|---|---|
| 1 | `I2` — carte affiche (6 variantes) · carte paysage · carte personne | Tout ce qui affiche une image de catalogue. Le lot qui change le plus l'allure | légère — ✅ `8262878` |
| 2 | `I3` — carte collection · vignette galerie · **avatar de profil** | L'avatar est réclamé par le chrome (sélecteur de profil), la vignette par la fiche | légère — ✅ `ad55476` |
| 3 | `I4` — rail horizontal · grille adaptative · squelette de chargement | **Sans lui aucun écran ne peut être posé** : c'est lui qui porte les 6 points de rupture | légère — ✅ `3f24344` `a2757f6` |
| 4 | `I6` — badge d'état · barre de notation · indicateur de progression | Les états d'une carte et d'une fiche : vu, favori, note | légère — ✅ `a745c7f` |
| 5 | `V0` — **chrome** : navigation régulière, barres d'outils, en-têtes, sélecteur de profil | Remplace la coquille du prompt 10. Toutes les `V` s'y posent | légère — ✅ `e84324c` |
| 6 | `V0 bis` — **titres** : grille, fiche, éditeur | Remplace le prompt 11. C'est l'écran où l'app se juge | légère — 🔶 **grille et fiche faites** `ef4ed7e` `8ad3342` · **éditeur bloqué sur `I7`–`I9`** |
| 7 | `V5a` — **accueil** : hero + rails par genre | Le premier écran qu'on voit. Demande `L18` pour la règle de choix du hero | légère — 🔶 **écran fait** `25d25b0` · **le choix éditorial du hero reste à `L18`** |
| 8 | `catalogue-porte` — chaque composant du catalogue affiche **la valeur attendue de son bloc** | La porte d'acceptation visuelle qui manquait : `PersonTile` a été livrée fausse et a passé tests **et** catalogue. **Avant** les corrections, qu'elle rend vérifiables | légère — ✅ `fec43ee` |
| 9 | **Corrections 1, 2, 3, 5** de la revue visuelle — police et taille de `ProfileAvatar`, gouttière de `TileRail`, étoile vide de `RatingBar` | Les quatre écarts où les rendus concordent. Arbitrage tranché, voir sa section | légère — ✅ `4759d80` `c055df1` `3627a51` |

**`V0` et `V0 bis` sont des tâches nouvelles, et leur absence était un trou du plan.** Les
prompts 10 (navigation) et 11 (titres) sont marqués ✅ — mais en **banc d'essai**, et
aucune tâche `V` ne les reprenait : le tableau des `V` est indexé sur les prompts 12 à 24.
Sans elles, « refaire la grille des titres contre le nouveau design » n'appartenait à
personne. `V5a` détache l'accueil de `V5`, qui portait cinq écrans d'un bloc.

#### Palier 2 — utilisable au quotidien sur Mac

Ce qui manque pour s'en servir vraiment : trouver, parcourir les images, et que ça ne
saccade pas.

| # | Tâche | Ce qu'elle débloque | Rigueur |
|---|---|---|---|
| 8 | `L5` — préchargement de vignettes, pression mémoire, échelle d'écran | Le défilement qui ne saccade pas | légère — ✅ **API et échelle faites** · **l'appel depuis les vues reste à `V3`/`V6`** |
| 9 | `L1 bis` — filtres de galerie (source, mélange à graine stable) et store de préférences | La galerie ne peut pas s'écrire sans sa source de données | légère — ✅ **les deux moitiés faites** · l'appel depuis les vues reste à `V3` |
| 10 | `I10` — vue vide paramétrée · notification temporaire | Chaque écran a un état vide ; sans lui ils sont muets quand il n'y a rien | légère — ✅ |
| 11 | `V1` — recherche : champ, portées, résultats groupés | `L2` et `L3` sont faites depuis longtemps et ne servent à rien sans écran | légère — ✅ **cinq portées sur les six de la planche** : « Images » n'est pas servable, voir les écarts |
| 12 | `V2` — médias : `PhotosPicker`, glisser-déposer, collage, éditeur de recadrage | Ajouter ses propres images. `L4` est faite, son geste n'existe pas | légère — ✅ **`CropEditor` livré par `V2 bis`** |
| 13 | `catalogue-images` — des échantillons avec de vraies images, et les quatre cas de chargement | La porte de bloc était **aveugle sur le composant qui compte** : avec `imageURL: nil`, une tuile sans image et une tuile cassée rendaient le même aplat. C'est ce qui a laissé passer le défaut de `MediaFill` pendant quatre sessions | légère — ✅ |
| 14 | `V2 bis` — `CropEditor`, le geste et ses deux ratios | Détaché de `V2`, où il aurait été bâclé. Le calcul était déjà là depuis `L4` ; ce qui manquait était l'écran | légère — ✅ |
| 13 | `V3` — galerie : masonry, matrice rendue, visionneuse | L'écran qui montre le mieux la direction « plein cadre » | légère — ✅ `3a6df7f` `8e9f6e5` `05838f9` `b437687` `29644e1` `862431f`. **Le palier 2 est clos.** La matrice `layout × size` n'y est pas rendue : la galerie n'a aucun contexte dans le vocabulaire de la v1, voir les écarts |

#### Palier 3 — complète

**Compressé le 2026-08-06 : quatorze lignes deviennent douze, par quatre regroupements.** Les
tâches réunies sont celles qui touchent les mêmes fichiers ou le même écran — les séparer
faisait rouvrir deux fois le même contexte, ce qui est la seule chose qu'un découpage ne doit
jamais coûter.

> **Trois prémisses de la compression demandée ne tenaient pas, et les corriger change le
> tableau. Elles sont dites ici plutôt que corrigées en silence.**
>
> 1. **`V8` n'est pas un doublon de `V3`.** `V3` est la galerie ; `V8` est **l'import et
>    l'export** — sélecteur de champs, aperçu ligne à ligne, correction en masse, progression
>    (prompt 19, planche 5 blocs `7c` et `7d`, addendum 1 blocs `11d`–`11g`). La retirer
>    laisserait `L11a`, `L11b` et `L12` — **trois tâches faites, dont deux à rigueur
>    maximale** — sans aucun écran, et sept écarts inscrits sans destination. Elle reste.
> 2. **`L15` n'est pas dans ce palier**, elle est **reportée en v1.1** (transfert entre
>    bibliothèques). Elle ne peut donc pas passer en fin de palier 3 : il n'y a que **trois**
>    tâches à rigueur maximale ici, pas quatre.
> 3. **`L14` n'est pas à rigueur maximale**, et le classement le dit depuis qu'il existe :
>    « légère **sauf la portée du déverrouillage** ». C'est cette portée qui est critique — un
>    déverrouillage qui déborde d'un profil expose du contenu privé — pas la tâche entière.
>
> **Et une contrainte d'ordre que « les maximales en fin de palier » viole.** `V6` ne se livre
> pas sans `L20`, `V7` pas sans `L14` : les mettre après le groupe `V6`+`V7` inverserait une
> dépendance dure. Elles sont donc placées **juste avant** lui — isolées et tardives, ce qui
> est l'intention, sans casser ce qui en dépend. Seule `L16` peut vraiment finir, puisque seule
> `V10` la réclame.

| # | Tâche | Ce qu'elle débloque | Rigueur |
|---|---|---|---|
| 14 | `I5` — ligne de tableau · jeton de filtre · compteur | La console de gestion et les barres de filtre | légère — ✅ |
| 15 | **`I7` + `I8` + `I9`** — tous les champs de formulaire, en un lot | Tout éditeur : titre, personne, collection, profil. **Regroupés** : les trois lots partagent la même planche 6, la même anatomie d'erreur et la même coquille — les séparer faisait l'écrire trois fois | légère — ✅ **`I9` ne recoupe pas `I10`** : le récapitulatif de refus du bloc `11c` est « dans le contenu, pas en notification », donc `ValidationSummary` existe **pour ne pas** être `Banner` |
| 16 | `L18` — sélections éditoriales, fil d'activité, statistiques | L'accueil (`V5a`), « ma liste », le fil | légère — ✅ **`ActivityEntry` a enfin un lecteur** : `ActivityFeed`, décroissant, fenêtré sur le `fetch`, paginé par curseur de date, groupé par jour local. Les écrans restent à `V5b` (fil) et `V11` (statistiques) |
| 17 | **`L7` + `L17`** — aperçu de lien, et état de synchronisation | `V5b` pour le premier, `V10` pour le second | légère — 🔶 **`L7` faite** : garde SSRF, délai de 3 s, repli qui ne bloque jamais. **`L17` écrite et couverte en simulation, pas vérifiée** : aucune notification réelle du coordinateur n'a été jouée, et ce ne sera possible qu'**après le prompt 21**. Sa ligne reste en 🔶 jusque-là, délibérément |
| 18 | **`V4` + `V5b`** — personnes, collections, genres, liens, fil | **Regroupés** : ce sont les mêmes formes — une grille, une fiche, un éditeur — sur quatre entités, et elles partagent leurs composants au point qu'écrire la seconde après la première serait la recopier | légère — ✅ **`V4`** `63bf776` · **`V5b`** `5c065d3`, sur `0e46116` (cœur) et `83f9c82` (portraits). **Le patron de `V0 bis` a tenu** : ce qui manquait était sous la vue, pas dedans — cinq capacités lues et jamais écrites, dont l'épinglage des genres. **Rendu des écrans non vu**, et la cause est architecturale : `CineShelfTests` n'a pas de `TEST_HOST` |
| 19 | `L20` — annulation de l'édition en masse et de la fusion | `V6`. **Doit passer avant `L13`** : le champ est posé, le format se fige | **maximale** — ✅ **`4434416`**. **Aucun changement de schéma** : `payload` et `undoneAt` existent depuis la fermeture du 2026-08-03, la fiche disait le contraire et c'était périmé. La sonde a trouvé **deux** défauts : `isUndoable` et `undo` divergeaient hors fenêtre, et une entrée purgée se disait « jamais annulable » |
| 20 | `L14` — `AppLock` : authentification, délai de grâce, portée par profil | `V7`, le verrouillage | légère **sauf la portée du déverrouillage**, qui est une seconde porte : un déverrouillage qui déborde expose du contenu privé — ✅ **`2893e7c`**. `PrivacyScope` **masque par défaut** : les neuf écrans montraient le privé en l'absence de profil. `requiresBiometry` est **appliqué** pour la première fois. Règle de lint `no_direct_private_flag`, lancée sur tout le dépôt avant ajout et prouvée par injection |
| 21 | **`V6` + `V7`** — console de gestion, profils, bibliothèques, verrouillage | **Regroupés** : la console et les réglages sont le même registre dense (planche 5), et `V7` n'est qu'un panneau de plus dans ce registre. **Ne pas livrer sans `L20` ni `L14`**, qui précèdent | légère — 🔶 **`d11615a`**. Console, édition en masse dans l'inspecteur, verrou, voile, profils. **Les deux mesures inexpliquées le sont désormais** — `ImageRenderer` ne capture pas AppKit — mais **la porte de remplacement n'est pas verte** : les trois tests d'interface sautent, aucune fenêtre n'apparaissant dans l'arbre d'accessibilité. Donc 🔶, et pas ✅ |
| 22 | `V8` — import et export : aperçu ligne à ligne, corrections, progression | `L11a` `L11b` `L12` sont faites et n'ont **aucun** écran. Sept écarts inscrits y pointent | légère — ✅ **premier jalon `12a8b8a`, second jalon `9c0e3f9`**. Jalon 1 : `11d` → `11e` → écriture → `11j`, plus l'export et le modèle vide. Jalon 2 : `11f` (correction en masse, une seule des quatre stratégies de la planche — les trois autres nommées, pas simulées), `11g` (abandon à trois issues, brouillon reprenable) et la jointure `ImportMapping` → `ColumnMapping`, livrée **avec** la case « Mémoriser » sans quoi la lecture n'aurait jamais rien rendu |
| 23 | `L16` — maintenance et corbeille : orphelins, purge à 30 jours | `V10`. **La seule maximale qui puisse vraiment finir le palier** : rien d'autre ne la réclame | **maximale** |
| 24 | `V10` — synchronisation : indicateur, corbeille, espace occupé | — | légère |
| 25 | `V12` — passe d'accessibilité sur les écrans définitifs | — . **En dernier par nécessité** : elle porte sur les écrans définitifs, donc sur tous les autres | légère |

**Douze lignes, dont trois à rigueur maximale ou à seconde porte** — `L20`, `L14` et `L16`.
Quatorze avant compression.

**Reportées en v1.1**, donc absentes de ces paliers : `L6` `L8` `L9` `L15` `L19`, `V9`,
`V11`, et `V6` au-delà d'une `Table` brute. Voir « Reporté en v1.1 ».

#### Ce qui reste après les trois paliers

| # | Tâche | Note |
|---|---|---|
| 28 | **`P0` vérifiée sur appareil** | Le jour où l'iPhone devient nécessaire — c'est-à-dire pour les mesures de `docs/04` §4, que le simulateur **ne peut pas** faire. Voir l'écart correspondant |
| 29 | **prompt 2** — dump du bundle web | Dans l'autre dépôt. Voir la fiche pour l'emplacement du clone |
| 30 | `L13` — migration des vraies données | **Dernière étape avant CloudKit** : elle gèle `versionIdentifier` |
| 31 | **prompt 21** — CloudKit | Abonnement requis |

#### Ce qui est déjà fait, et qui porte tout ça

| Tâche | État |
|---|---|
| `L1` requêtes interrogeables | ✅ `eb05149` `e347b11` |
| `L2` service de recherche | ✅ `6ea6a8e` |
| `L3` indexation Spotlight | ✅ `4e696ee` |
| `L4` mathématiques du recadrage | ✅ `07890db` |
| `L10` édition en masse | ✅ `68688b2` |
| `L11a` CSV — format et analyse | ✅ `902bfb1` … `4a42907` + revue |
| `L11b` CSV — application au magasin | ✅ `8f68345` + revue `c393ed9` |
| `L12` archive `.cineshelfarchive` | ✅ `e7e2915` `7a10b52` + revue `47ceb35` |
| `I1` tokens de la nouvelle direction | ✅ `9b4b64e` |
| `P0` mécanique de signature | 🟡 `9984a52` + correctif `faf07cd` — **configurée, non vérifiée sur appareil.** La première livraison avait un défaut : un `.example` dont la copie cassait tous les tests |

### Tâches d'appoint — à insérer quand tu veux changer de sujet

Elles ne sont sur le chemin d'aucune autre : aucune ne retarde `L13`, et aucune n'en
dépend. Utiles quand tu veux souffler ou avancer sur un autre front.

| Tâche | Objectif en une ligne | Docs à lire | Dépend de | État |
|---|---|---|---|---|
| `L1 bis` | Filtres de galerie (source, mélange à graine stable) et store de préférences d'affichage hors des vues | `02 §3.7 §3.10`, `04 §1 §3` | — | ✅ |
| `L20` | **Annulation de l'édition en masse et de la fusion** — journal inversable | `02 §3.9`, `03 §12` | `L8` `L10` | ✅ **`4434416`** — **ne touche pas au schéma**, contrairement à ce que sa fiche annonçait |
| `L5` | Préchargement de vignettes, pression mémoire, échelle d'écran | `04 §4` | — | 🔶 |
| `L6` | Génération d'une couverture en mosaïque | `03 §6`, `04 §4` | `L4` | ⬜ |
| `L7` | Aperçu de lien : garde SSRF, délai, repli, libellé déduit | `03 §8` | — | ✅ — **sans `LPMetadataProvider`**, qui n'expose aucun point de contrôle sur ses redirections. Voir l'écart |
| `L8` | Détection de doublons et exécuteur de fusion | `03 §5`, `02 §3.4` | — | ⬜ |
| `L9` | Suggestion de casting | `03 §4` (ligne « Suggestion de casting ») | `L8` | ⬜ |
| `L14` | `AppLock` : authentification, délai de grâce, portée par profil | `02 §9`, `03 §1 ter` | — | ✅ `2893e7c` — **l'écran reste à `V7`** ; `LocalAuthenticationEvaluator` n'a jamais tourné contre le système |
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

### `P0` — Signature de développement — **configurée, non vérifiée sur appareil**

> **Hors du chemin critique.** Elle ne bloque rien : le Mac ne demande aucune signature
> et le simulateur iOS non plus. Ce qui suit est en place et mesuré ; ce qui manque est
> une vérification sur un vrai iPhone, à faire le jour où l'appareil sert — donc pour les
> mesures de performance de `docs/04` §4, en fin de parcours.

**Objectif.** Que `xcodebuild` accepte de signer pour un **appareil**, sans mettre
d'identifiant personnel dans un dépôt public.

**Rigueur légère.** Aucune donnée écrite, aucun comportement à l'exécution : soit le
build pour appareil réussit, soit il échoue en le disant.

**Le blocage, mesuré.** `DEVELOPMENT_TEAM: ""` dans `project.yml`, et
`security find-identity -v -p codesigning` rend **0 identité** : ni certificat, ni compte
enregistré dans Xcode. Un Apple ID **gratuit** suffit — profil de 7 jours, renouvelable
par un simple rebuild. L'abonnement payant ne sert qu'à CloudKit (prompt 21), au widget
et aux App Intents (`L19`, reportée en v1.1).

**Pourquoi un `xcconfig` et pas la valeur en dur.** Le dépôt est **public**. Un
identifiant d'équipe n'est pas un secret critique, mais c'est un identifiant personnel
qui n'a rien à faire dans un historique public et qu'on ne peut plus retirer ensuite.
Il vit donc dans `Local.xcconfig`, **gitignoré**, et `project.yml` s'y réfère par
`configFiles`. `Local.xcconfig.example` est versionné et documente la clé attendue.

Le mécanisme a un second avantage, celui qui compte à l'usage : `xcodegen generate`
régénère le `.xcodeproj` à chaque ajout de fichier, donc **une équipe choisie dans
l'interface d'Xcode serait perdue à la régénération suivante**. Un `xcconfig` survit.

**Ce que je ne peux pas faire à ta place :** la connexion du compte. Elle est
interactive, dans Xcode › Settings › Accounts.

**Le mécanisme est en place et vérifié** — `9984a52`, plus le correctif `faf07cd`, dont la
raison d'être est instructive : **la première série de mesures était verte et insuffisante.**

Elle vérifiait `-showBuildSettings`, donc la *lecture* de la valeur. Le défaut était dans
le **geste** que le `README` recommande — copier `Local.xcconfig.example` — qui posait un
`REMPLACE_MOI` actif et faisait échouer `xcodebuild test` sur `DesignSystemAssetTests`,
une cible sans rapport avec la signature. Trois mesures vertes, et le défaut passait entre
elles. La règle qui en sort est dans `CLAUDE.md` : une preuve exerce le geste, pas
seulement la valeur.

Les mesures, dans leur état corrigé :

| Mesure | Résultat |
|---|---|
| Sans `Local.xcconfig` | `-showBuildSettings` ne rend **aucune** valeur — le défaut vide |
| Avec `Local.xcconfig = SONDE12345` | rend **`SONDE12345`** |
| `DEVELOPMENT_TEAM: ""` réintroduit dans `project.yml`, `Local.xcconfig` toujours rempli | rend une valeur **vide** — le build setting du projet écrase bien le `xcconfig`, silencieusement |
| Build appareil sans équipe | `error: Signing for "CineShelf" requires a development team.` |
| Builds macOS et simulateur iOS | `** BUILD SUCCEEDED **` — le dépôt compile sans configuration locale, ce dont la CI a besoin |
| **Le geste recommandé**, joué en entier : copie du `.example` sans édition | `DEVELOPMENT_TEAM` vide, **52 tests du catalogue verts**. C'est la mesure qui manquait |

Le troisième est le seul qui comptait vraiment : il vérifie l'affirmation portée par les
commentaires, au lieu de la supposer. C'est aussi le premier endroit à regarder si le
`xcconfig` paraît ignoré.

**Il te reste trois commandes**, dans le `README` § « Signer pour un appareil » : ajouter
le compte dans Xcode, relever l'identifiant, le coller dans `Configuration/Local.xcconfig`.

**Terminé quand :** `xcodebuild -scheme CineShelf -destination 'generic/platform=iOS'
build` réussit, et que l'app s'installe sur l'iPhone depuis Xcode. **Ces deux points ne
sont pas vérifiés** — d'où le statut « configurée, non vérifiée sur appareil » plutôt
qu'un ✅. Ce qui est vérifié est le mécanisme : le tableau ci-dessus. La signature ad hoc
macOS (`CODE_SIGN_IDENTITY[sdk=macosx*]: "-"`) reste en place tant qu'il n'y a pas
d'abonnement : elle ne gêne pas iOS, et la retirer casserait le build macOS local.

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
- **Réconcilier les huit contextes vers ceux du handoff**, qui sont ceux de la v1 :
  `movies` · `actors` · `collections` · `social` · `home_movies` · `home_actors` ·
  `home_collections` · `home_social`. Le jeu actuel de `CardDisplayContext`
  (`home, titles, people, collections, gallery, bookmarks, genre, filmography`) est une
  invention de l'intégration, pas une reprise : il compte bien huit entrées mais ce ne
  sont pas les mêmes. La matrice `layout × size` est une **fonctionnalité existante**
  (`06` §5), donc c'est le jeu d'origine qui fait foi.

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
- **La couleur dominante d'un média — assignée ici par `I4`.** La planche 7 demande de
  « remplacer la trame rayée par la couleur dominante de l'image » sous les squelettes
  de chargement. La donnée existe déjà : elle se déduit de la **première composante du
  `blurHash`**, que `MediaAsset` porte. C'est donc un **décodeur, pas un champ** — le
  schéma fermé n'a rien à recevoir, et c'est ce qui permet de l'ajouter après la
  fermeture du 2026-08-03. Le producteur naturel est ce lot, qui est déjà celui qui lit
  les vignettes. `TileSkeleton` gagnera un paramètre de couleur le jour où il existe ;
  d'ici là il remplit en `bg.surface`, et la note est dans son en-tête.

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

### `L11` — CSV, coupée en `L11a` et `L11b`

**Coupée le 2026-08-04**, après reconnaissance et mesures. La frontière n'est pas un
compte de lignes : c'est **« rien n'est écrit dans la bibliothèque »**, la garantie que le
design énonce lui-même. `L11a` est entièrement testable sans un seul `save()`, donc elle
échappe par construction au piège qui a coûté 42 tests verts ; `L11b` est exclusivement
faite de ce piège. Les mélanger, c'est risquer que la partie facile consomme l'attention
et que la dangereuse soit écrite en fin de course.

En prime, `L11a` livre l'export complet — utilisable seul, et suffisant pour que `L12`
démarre.

> **Correction d'une inversion.** La fiche disait « Reprise **par élément** et non par lot
> (écart connu) ». C'est l'inverse : le tableau des écarts dit « par lot de 200, pas par
> élément », et `ImportActorTests.insertionErrorPropagates` le vérifie — « seuls les lots
> déjà sauvegardés sont durables ». La reprise est **par lot**, et c'est `L11b` qui la
> traite.

#### `L11a` — le format et l'analyse. Aucune écriture de modèle.

- **Sérialiseur maison** : UTF-8 **avec BOM**, séparateur `;`, échappement RFC 4180 par
  doublement du guillemet, fins de ligne `CRLF`. Un gabarit vierge par entité.
- **Lecteur tolérant, écrit à la main.** `TabularData` est **exclu pour l'import** :
  mesuré, une seule ligne mal formée fait rejeter le fichier **entier** — 5 000 lignes
  valides, une cassée à la 2 501e, zéro ligne exploitable. L'aperçu « 771 prêtes, 417 en
  erreur » de l'addendum est donc impossible avec lui. Il reste bon pour l'export.
- **Resynchronisation après un guillemet non fermé**, au-delà de 8 lignes englobées :
  sans elle, une faute de frappe dans une cellule fait disparaître la moitié du catalogue
  de l'aperçu, ce qui est conforme à RFC 4180 et inacceptable ici.
- Schéma de colonnes par entité, et sélection de champs — la liste des champs exportables
  est une **donnée**, pas une vue.
- Correspondance des colonnes et ses trois qualités : sûre, déduite du contenu, non
  reconnue. Une colonne non reconnue **n'est pas une erreur**.
- `ImportMapping` et son repository — il n'en a aucun aujourd'hui, et **personne ne le
  lit** : nom, `headerSignature`, correspondance JSON. La signature se calcule sous une
  **locale invariante** : l'entité est synchronisée par CloudKit, et tous les `folding` du
  dépôt utilisent `.current`, ce qui la rendrait non reproductible d'un appareil à l'autre.
- Validation ligne à ligne avec statut et message, causes **groupables** sur le modèle de
  `BulkRefusalReason`. Revalidation après correction, sans reparser le fichier.
- **Le rapport nomme les colonnes ignorées.** Contrepartie de l'abandon des champs libres :
  une colonne non reconnue ne doit pas disparaître en silence.
- Le rapport CSV des écartées : format d'origine + colonne `cineshelf_erreur` en fin de
  ligne, redéposable.
- Fixtures écrites **à la volée** plutôt qu'en ressources : les octets exacts — BOM, CRLF,
  encodage — restent visibles dans le test au lieu d'être cachés dans un binaire.

#### `L11b` — l'application au magasin. Tout le risque est là.

- Résolution des références : `GenreRepository.findOrCreate` existe ; **il n'y a aucun
  équivalent pour les personnes ni les collections**, c'est à écrire.
- Dédoublonnage contre l'existant **et intra-lot**. `CLAUDE.md` prévoit nommément ce cas :
  le comportement avant sauvegarde est le sujet, donc le dire dans le nom du test et
  couvrir le chemin SQL ailleurs.
- Entrée dans `ImportActor`, lots de 200, progression, **annulation** — qu'il n'a pas
  aujourd'hui, pas un `Task.checkCancellation()`.
- **Le piège central** : les repositories sont `@MainActor` à cause du `SpotlightIndexer`,
  `ImportActor` est un acteur. `L10` a résolu le dilemme en restant `@MainActor`, ce que
  `L11b` ne peut pas faire pour 1 284 lignes. Il faudra appeler `refreshDerived()`
  explicitement dans le contexte de l'acteur **et le prouver par un test**, ou ouvrir une
  troisième porte d'écriture — que le dépôt a déjà refusée deux fois.
- Brouillon d'import local, un seul à la fois, survivant à la fermeture. **Aucun modèle
  ne le porte et le schéma est fermé** : ce sera un fichier, pas une entité.
- Journal de lot : une entrée pour l'import, pas une par titre — `JournalPolicy.batched`.
- Bilan chiffré, et les quatre suites de l'addendum.

**Trois décisions arbitrées le 2026-08-04, avant d'écrire :**

| Sujet | Décision |
|---|---|
| **Support, Étagère, nombre de visionnages** — trois colonnes du mock sans champ au modèle | **Colonnes ignorées nommées.** Aucune migration. Conséquence assumée : deux des six causes d'erreur de l'addendum perdent leur objet, l'addendum est à corriger ou l'écart à accepter |
| **L'échelle de la note** | **0–10 en base, 0–5 à l'affichage.** `docs/02` §3.3 et `TitleFormat.fiveStarRating` avaient raison ; `BulkEditor.Bounds.ratings = 0...5` était un bug de `L10`, corrigé — il aurait refusé à l'import la moitié de l'échelle |
| **Le profil Movix** | **Pas de profil intégré pour l'instant.** Le script source est inaccessible, et `isBuiltIn` interdit de retirer un profil livré : un profil faux serait pire qu'aucun. `L11a` livre l'enregistrement de mappages personnels et la reconnaissance par `headerSignature` |

**Dépend de `L10`** — mais **de forme, pas d'appel** : `BulkEditor` travaille sur des
entités déjà en base désignées par `UUID`, et il écrit. Les corrections de l'aperçu portent
sur des **lignes de CSV** qui n'existent nulle part, et le design garantit que rien n'est
écrit avant l'appui final. Ce qui se réutilise est le patron — descripteur, validation
préalable, refus groupés par cause — et `Bounds`, dont les bornes d'année viennent déjà de
l'addendum d'import.

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
- **Écrire un `LegacyRecord` par entité importée** (type, identifiant natif, table et
  clé d'origine). Il existe depuis la fermeture du schéma, et il change la nature de
  deux choses :
  - le **rapport de vérification** devient spécifique — il nomme les enregistrements
    manquants au lieu d'annoncer un écart de compte ;
  - la **comparaison champ à champ des cinquante titres** (`02 §7` étape 3) se mécanise,
    puisque chaque titre natif sait de quel enregistrement web il vient. Sans ce lien,
    la comparaison se fait à la main ou pas du tout.
- Il rend surtout possible la **réconciliation** : le mode de défaillance réaliste n'est
  pas « la migration a planté » mais « trois semaines plus tard je remarque que les dates
  de sortie sont toutes au 1er janvier ». À ce moment-là il faut recouper avec la source
  et corriger, sans toucher à ce que l'utilisateur a saisi depuis. Et « effacer et
  recommencer » aura cessé d'être une issue : après le prompt 21, effacer se propage à
  tous les appareils.
- La purge des `LegacyRecord` est une **action explicite** de l'utilisateur, jamais
  automatique — une purge silencieuse retirerait le recours au moment précis où il
  servirait.
- Compter les recadrages importés dont le `zoom` est inférieur à 100 : ils sont relevés
  à l'affichage, c'est le seul endroit où la v1 et le natif divergent visiblement (`L4`).

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

# Tâches INTÉGRATION DU DESIGN — la chaîne `I`

**Ce que « intégration » veut dire ici :** du SwiftUI dans
`Packages/DesignSystem`, validé **au catalogue** et nulle part ailleurs. Aucune
écriture de modèle, aucun accès au magasin, rien dans `App/` — le banc d'essai des
prompts 10 et 11 ne se touche pas. Rigueur **légère** pour toute la chaîne : compile,
teste, regarde la planche, avance.

`I1` a livré les tokens. `I2` et suivantes livrent les composants, **par lots de trois,
avec une validation groupée au catalogue** — ils sont indépendants entre eux, donc les
valider un par un coûtait un aller-retour par composant sans rien apprendre de plus.

### L'inventaire, et d'où il vient

Vingt-six composants, tirés de `06` §5.5 (les champs), §5.7 (les états), §5.8 (la liste
« Composants »), plus la clarification en tête de ce document : les champs de formulaire
sont des composants de la chaîne `I`, l'écran d'import est un écran de `V8`.

Trois décisions de décompte, pour que le chiffre soit vérifiable :

- La « note » de §5.5 et la « barre de notation » de §5.8 sont **le même composant**,
  compté une fois, en version lecture et en version éditable.
- Les **quatre marques d'erreur** de l'addendum 1 font **un** modificateur commun, pas
  quatre composants — les appliquer champ par champ était le défaut de la première
  tentative.
- Des neuf surfaces superposées de §5.6, **une seule** est un composant : la
  notification temporaire. Les huit autres (feuille, popover, dialogue, confirmation
  destructive, menu contextuel, menu de barre d'outils, visionneuse, panneau latéral)
  sont des primitives SwiftUI que les tokens habillent — en écrire une version maison
  serait du code « au cas où », et perdrait le comportement système.

### Les neuf lots

> **Le numéro d'un lot n'est pas son rang de travail, et c'est un piège qui a mordu.**
> Cette table est triée par numéro parce que c'est ainsi que les lots ont été découpés ;
> l'ordre d'exécution est celui du **chemin critique**, plus haut, et il entrelace les `I`
> avec les `V`. Après `I4` vient `I6`, **pas `I5`** : `I5` porte les composants de la
> console de gestion, qui appartient au palier 3. La colonne « Quand » donne le rang, pour
> qu'il n'y ait plus à le déduire.

| Tâche | Les trois composants | Planche de validation | Quand | État |
|---|---|---|---|---|
| `I2` | Carte affiche (les 6 variantes de la matrice) · carte paysage · carte personne | Planche 1 et §5 du handoff — la matrice se juge d'un bloc | palier 1, rang 1 | ✅ `8262878` — `PosterTile` couvre affiche **et** paysage par `CardLayout`. Le troisième composant était `PosterTileDetail`, **supprimé par `V0 bis`** faute de foyer dans les planches ; `PersonTile` y a aussi été corrigée en cercle 1:1, la version de `I2` la rendant en rectangle 2:3 |
| `I3` | Carte collection · vignette galerie · avatar de profil | Planche 3 bloc `4e`, planche 4 bloc `6b`, planche 5 bloc `7f` | palier 1, rang 2 | ✅ `ad55476` |
| `I4` | Rail horizontal · grille adaptative (les 6 points de rupture) · squelette de chargement | Planches 1 et 3 — le squelette est un rail vide à la géométrie finale, il se valide avec eux | palier 1, rang 3 | ✅ `3f24344` `a2757f6` |
| `I6` | Badge d'état · barre de notation · indicateur de progression | Planche 6 blocs `8a` `8c` (notation), addendum 1 bloc `11e` (progression), planches 3 et 7 (badge). **Pas « planche 7 » seule**, comme cette colonne l'a longtemps dit : les trois composants sont sur trois planches différentes | palier 1, rang 4 | ✅ `a745c7f` |
| `I10` | Vue vide paramétrée · notification temporaire | Planche 7 blocs `9a` (vide) et `9c` (bandeau) — **pas « planche 7 » seule** : le bandeau est une interruption, pas un état vide | palier 2, rang 10 | ✅ |
| `I5` | Ligne de tableau · jeton de filtre · pastille de compteur | Planche 5, aux deux crans de densité | palier 3, rang 14 — avec la console | ✅ — **la « pastille » n'en est pas une** : le bloc `7a` ne dessine qu'un nombre en mono, sans fond. Le nom vient de l'inventaire écrit avant la direction artistique |
| `I7` | Champ texte · zone de texte · champ nombre | Planche 6 | palier 3, rang 15 | ✅ — livré avec `I7`+`I8`+`I9`, une seule anatomie |
| `I8` | Date à précision variable (année / mois / jour) · sélecteur simple · interrupteur | Planche 6 | palier 3, rang 15 | ✅ — livré avec `I7`+`I8`+`I9`, une seule anatomie |
| `I9` | Sélecteur multiple avec création à la volée · sélecteur de couleur de profil · marques d'erreur de champ | Planche 6 et addendum 1 (11a–11c, 11i) | palier 3, rang 15 | ✅ — **aucun recoupement avec `I10`**, vérifié : le récapitulatif de refus n'est pas un bandeau |

**Neuf tâches**, `I2` à `I10`, huit lots de trois et un de deux. Contre vingt-six
tâches avant regroupement.

Les lignes sont désormais dans l'**ordre de travail**, pas dans l'ordre numérique — c'est
la table qu'on lit pour savoir quoi faire ensuite, et la trier par numéro faisait dire
« `I5` » à qui venait de finir `I4`.

**Terminé quand**, pour chaque lot : les trois composants s'affichent sur leur planche
du catalogue dans les quatre apparences, `swiftlint --strict` est à zéro — dont
`no_legacy_design_system`, qu'aucun composant neuf n'a le droit de contourner —,
`xcodebuild test -scheme DesignSystemCatalog` passe, et un lot ne se rouvre pas pour
polir le lot précédent.

---

# Tâches VUES

> **Dégelées le 2026-08-04 (2).** La direction artistique est produite
> ([`docs/design/`](./design/), direction « 2a Plein cadre ») et le catalogue de tokens est
> validé. La condition de départ n'est donc plus « attendre le design » mais **« attendre
> les composants »** : chaque `V` démarre quand les lots `I` qui la fournissent sont passés,
> et la colonne « S'appuie sur » le dit déjà.
>
> Ce qui ne change pas : chacune s'écrit **une seule fois**, contre le design final, et
> l'interface des prompts 10 et 11 reste un banc d'essai qu'on ne polit pas — elle est
> remplacée par les `V`, pas amendée.

Chacune s'écrit **une seule fois**, contre le design final.

| Tâche | Écrans | Prompt d'origine | S'appuie sur |
|---|---|---|---|
| `V0` | **Chrome** — navigation régulière (Mac, iPad) et compacte (iPhone), en-têtes et comportement au défilement, barres d'outils (tri, filtres, affichage, actions), sélecteur de profil, indicateur de synchronisation, barre de menus et raccourcis Mac. **Remplace la coquille du prompt 10**, qui est un banc d'essai. **Les menus d'écran (tri, filtres, affichage) ne sont pas posés par le chrome** : ils trieraient quoi ? Ils appartiennent à l'écran qui les porte, donc à `V0 bis` | 10 | `I2` `I3` `I4` — ✅ `e84324c` |
| `V0 bis` | **Titres** — grille, filtres, tri, bascule d'affichage · fiche (hero, affiche, métadonnées, casting, galerie, liens) · éditeur. **Remplace le prompt 11.** L'éditeur attend les champs `I7`–`I9` ; la grille et la fiche non | 11 | `V0`, `I2` `I4` `I6` — 🔶 **grille `ef4ed7e` et fiche `8ad3342` faites**. **L'éditeur reste, et il est bloqué** : ses champs sont ceux de `I7`–`I9`, palier 3. `TitleEditor` garde donc l'ancienne direction et reste dans la liste d'exclusion `no_legacy_design_system` — c'est le seul fichier de `Features/Titles` qui y figure encore |
| `V5a` | **Accueil** — hero + rails par genre. Détaché de `V5`, qui portait cinq écrans d'un bloc | 16 | `V0`, `I4`, `L18` — ✅ **écran fait** `25d25b0`, **choix éditorial livré par `L18`** : `HomeSelection` descend dans `CineShelfCore`, le hero se classe sur l'image large puis le synopsis puis la note, et la rotation quotidienne porte sur les sept candidats de tête. Onze tests, dont « stable dans la journée » |
| `V1` | Recherche : champ, portées, suggestions, résultats groupés. **L'anti-rebond de la saisie est affaire de vue, pas du service** : `SearchService` est une fonction pure, appelable à chaque frappe, et c'est la vue qui décide quand l'appeler. Le mettre dans le service le rendrait intestable et imposerait un rythme à des appelants qui n'ont pas de frappe à amortir — l'App Intent de `L19`, par exemple. Deux branches obligatoires, et le compilateur les impose : `SearchOutcome.idle` (champ vide → recherches récentes) et `.results` dont les groupes peuvent être vides (→ « aucun résultat ») | 12 | `L2` `L3` |
| `V2` | Médias : `PhotosPicker`, import de fichier, glisser-déposer, collage, `CropEditor`, branchement de `MediaThumbnail` | 13b | `L4` `L5` |
| `V3` | Galerie : masonry, matrice `layout × size` rendue, visionneuse, immersif | 14 | `L1 bis` `L4` `L5` — 🔶 **écran, visionneuse, immersif et sélection faits** `29644e1`. **La matrice n'est pas rendue et ne peut pas l'être** : les huit contextes de la v1 n'en comptent aucun pour la galerie, et « portrait » n'a pas de sens en maçonnerie. Écart inscrit |
| `V4` | Personnes : grille, fiche, éditeur, écran de fusion champ par champ | 15 | `L8` `L9` — ✅ `63bf776`. **L'écran de fusion n'est pas livré** : la fiche du report de `L8` le nomme comme partant avec elle. `PersonEditor` est le **premier appelant de production** des champs `I7`–`I9` |
| `V5b` | Collections, genres, liens et signets, fil — **l'accueil en est détaché, voir `V5a`**. **Dont** : le multi-sélecteur de genres affiche « genre existant » plutôt que « créer » quand la frappe correspond à un `nameKey` connu (voir « Arbitrages tranchés », point 2) | 16 | `L6` `L7` `L18` — ✅ `5c065d3`. **L'épinglage d'un genre vit sur l'écran Collections**, décidé par le sous-titre du bloc `4e` (« 38 rayons · 14 genres épinglés ») |
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

> ## Où vit le dépôt web, et le piège qui s'y cachait
>
> | | |
> |---|---|
> | **Sur le disque** | `~/Documents/02 - Perso/App/ControlHub/sites-apps/cineshelf` |
> | **Son vrai dépôt** | `github.com/FELTRINCyril/CineShelf_old` — **privé** |
> | Technologie | React + Vite, Express + SQLite, Cloudflare Worker optionnel |
> | État au 2026-08-04 | un seul commit, `56ed7a7` « Initial CineShelf codebase », arbre propre, rien à pousser |
>
> **Le piège, corrigé le 2026-08-04 (2).** Le dépôt GitHub de l'app web s'appelait
> `CineShelf` ; il a été renommé `CineShelf_old`, et le nom libéré a été repris par l'app
> **native**. Or le clone local gardait `origin = github.com/FELTRINCyril/CineShelf.git`,
> qui pointait donc désormais vers un dépôt **sans aucun commit commun** — `56ed7a7` n'est
> pas un ancêtre de son `origin/main`.
>
> Conséquence si on ne l'avait pas vu : un `git pull` dans le dossier web ramenant l'app
> native, un `git push --force` écrasant l'app native. L'URL est corrigée par
> `git remote set-url`, et `git ls-remote` confirme `refs/heads/main → 56ed7a7`.
>
> **La leçon générale :** renommer un dépôt GitHub et réutiliser son nom laisse tous les
> clones existants pointer vers le nouvel occupant, **en silence**. GitHub ne redirige que
> tant que l'ancien nom reste libre.
>
> Ce dossier n'est pas suivi par le dépôt `ControlHub` qui l'héberge (dépôt imbriqué, zéro
> fichier suivi) : sa seule sauvegarde est `CineShelf_old`.

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
