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
| 12 | Recherche + Spotlight | `L2` `L3` | `V1` | ⬜ |
| 13b | Médias — recadrage, préchargement, import d'images | `L4` `L5` | `V2` | ⬜ |
| 14 | Galerie + visionneuse | `L1 bis` (source, mélange) | `V3` | ⬜ |
| 15 | Personnes + doublons + fusion | `L8` `L9` | `V4` | ⬜ |
| 16 | Collections, genres, liens, accueil, fil | `L6` `L7` `L18` | `V5` | ⬜ |
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
| **`Genre.colorToken` est une chaîne libre que rien ne valide** — exactement le défaut que `ProfileAccent` a corrigé (« un jeton invalide doit être impossible à écrire, pas avalé à la lecture »). Il n'a **pas** été typé à la fermeture du schéma, pour deux raisons : la palette de la nouvelle direction n'est pas intégrée, donc la liste fermée n'est pas connue ; et la question est d'abord de savoir si des pastilles de genre colorées ont encore un sens sous une direction à **un seul accent ambre** — c'est une addition postérieure à la v1, pas une fonctionnalité reprise. **La question part chez Claude Design.** En attendant, la précaution qui compte est déjà tenue : aucun repository ne l'expose à l'écriture, donc le défaut de `ProfileAccent` ne peut pas se reproduire par une vue. Le typer plus tard exigera un plan de migration | `V5` · question ouverte au design |
| **`TitleCollection` et `SavedLink` n'ont volontairement pas de `filterKeys`**, contrairement à `Title` et `Person`. Ce n'est pas une harmonisation en retard, c'est un arbitrage : la dénormalisation coûte un **invariant permanent** — un champ dérivé de plus à recalculer à chaque écriture, et une porte de plus à garder fermée — alors que ces deux tables comptent des dizaines de lignes, pas des milliers. La jointure `library?.id` ne se paie qu'en SQL, où elle est négligeable à cette échelle. Ce que la traversée coûtait vraiment, c'était le budget de vérification de types (7 253 ms et 7 446 ms avec `#Predicate`), et l'arbre manuel de `CollectionQuery` / `SavedLinkQuery` le règle sans rien dénormaliser. **Ne pas « harmoniser » sans mesurer d'abord** : la bonne raison d'ajouter `filterKeys` serait un critère de filtre que la jointure ne sait pas exprimer, ou un volume qui a changé d'ordre | permanent |
| **La barre de notation seule perd une décimale, en silence — lacune de design, question ouverte.** 8,4 sur 10 donne quatre étoiles, et 8,0 aussi ; le design ne montre **jamais** la valeur numérique à côté de la barre. Relevé au 2026-08-04 : huit occurrences dans la direction retenue affichent la barre nue — hero de l'accueil (planche 1 `2a`), fiche titre (planche 3 `4b`), champ « Note » (planche 6 `8a`), « Ma note » (planche 6 `8c` `8e`), et les quatre écrans iPhone/iPad de l'addendum 2. Les deux seuls endroits qui portent le nombre (`★ 4,5` sur la carte, `★ 4` dans le filtre) sont ceux où la barre n'est pas utilisée. **La conséquence est dans l'éditeur** : un titre noté 8,4 s'y présente en quatre étoiles pleines, et toucher une étoile écrit un entier — la décimale disparaît sans que l'utilisateur l'ait vue. `RatingBar` **n'invente ni demi-étoile** (exclue par la direction) **ni nombre d'autorité** (aucune planche ne le montre). En attendant l'arbitrage : tout appelant qui rend une note **modifiable** pose la valeur à côté, via `TitleFormat.ratingText` | question ouverte au design · `V0 bis` pour l'éditeur |
| **Le compte de colonnes du §4.6 diverge du calcul à 1280 pt, et c'est le calcul qui gagne.** Le tableau des points de rupture de `docs/design/README.md` donne une colonne « Colonnes » — 6 pour `macStandard` — alors que la règle arrêtée par l'addendum 2 bloc `13c` (largeur de carte fixe, la grille prend ce qui rentre) en donne 7 à `poster.l`. C'est le seul écart réel : à 1680 la table dit « 7+ », que le calcul satisfait, et aux deux largeurs que l'addendum a **rendues pour de vrai** — 393 et 834 — les deux coïncident exactement. `Breakpoint.columns` a donc été **supprimée** par `I4` plutôt qu'annotée : une constante morte qui contredit le code vivant finit par se faire « respecter » par quelqu'un qui croit corriger un oubli. Le compte n'existe plus qu'en un endroit, `GridMetrics.columnCount`. **Ne pas la réintroduire** ; si le design veut vraiment 6 colonnes à 1280, ce qui change est la largeur de carte de la grille des titres, pas le compte | permanent |
| **La densité a deux crans, pas trois.** `docs/03` §2 annonçait « compacte / standard / confortable » ; le handoff livre `.dense | .roomy`, et ce sont des écrans dessinés. `docs/03` est corrigé. Le cran est posé une fois par plateforme dans l'environnement — ample par défaut sur iPad, dense au pointeur — et c'est la seule valeur dynamique du système de design | `V5` |
| **Le store de préférences d'affichage ne portera que `layout` et `size`**, alors que `02 §3.10` décrit `{layout, size, pageSize, sort, dir}`. `pageSize` est abandonné par `03` (§2 : `LazyVGrid` charge à la demande). `sort` et `dir` sont déjà portés par `TitleFilter`, que `NavigationModel` sérialise et restaure au lancement : les mettre aussi dans le store créerait deux sources de vérité, et les y mettre sans les brancher serait du code « au cas où ». **Le jour où le tri doit persister par contexte, c'est `TitleFilter` qui lira le store — jamais le store qui dupliquera `TitleFilter`.** Le sens de cette dépendance n'est pas négociable : l'inverse redonne deux vérités | `L1 bis` |
| `AppIcon.appiconset` déclare 11 emplacements sans un seul nom de fichier : `actool` ne produit rien et l'app n'a **pas d'icône**. **Le dessin est livré** — [`docs/design/icon/cineshelf-icon.svg`](./design/icon/cineshelf-icon.svg), trois rectangles, aucune courbe (addendum 3). Reste à produire les exports et à les poser dans le catalogue, et trois décisions de design à trancher : variante sous 32 px, fond sur écran d'accueil sombre, ton assourdi de la tranche | avant 25 |
| `Typo.sectionTitle` inutilisé dans `App/` : **décision actée** — aucun en-tête de section n'est aujourd'hui sans style, donc rien à y brancher. Les quatre en-têtes de contenu de `TitleDetailView` gardent `railLabelStyle()` ; les promouvoir serait un changement de hiérarchie visuelle (12 → 20 pt de base sur iOS, perte des majuscules et du `tracking`), pas un branchement. À reprendre au prompt 16, qui écrit Accueil, Collections et Genres — de vrais groupes de contenu. Poser alors `sectionTitle` **une fois**, dans un `sectionTitleStyle()` sur le modèle de `railLabelStyle()`, plutôt que sur chaque appelant : ce serait un ajout aux composants, dont l'anatomie est désormais à refaire (voir la bascule) | `V5` |
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
| **Le forçage sombre n'est posé nulle part.** L'arbitrage 1 dit que l'accueil, les fiches et la galerie sont forcés en sombre par écran (`.preferredColorScheme(.dark)` sur la racine de chaque surface de visionnage), et non globalement. Les tokens sont prêts — les quatre apparences existent, `bg/viewer` est identique dans les quatre — mais **aucun écran ne le pose** : ce sont les tâches `V` qui écriront ces racines | `V3` `V5` |
| **Le diff d'édition en masse est écrit mais personne ne le relit.** `L10` pose un `BulkEditDiff` versionné dans `ActivityEntry.payload` et laisse `undoneAt` vide ; `ActivityEntry.isUndoable` dit déjà `true`. Aucun code ne l'annule encore — c'est `L20`. Deux conséquences : `V6` ne doit pas livrer l'édition en masse sans `L20` (déjà noté au tableau des vues), et **le format du diff ne doit pas changer sans faire évoluer `BulkEditDiff.currentVersion`** — un `payload` déjà en base ne se relit pas autrement. `BulkEditDiff.decoded(from:)` refuse une version inconnue plutôt que de deviner | `L20` |
| **Le repliage de texte est invariant de locale depuis le 2026-08-04 — audit fait, ne pas régresser.** `sortName`, `searchText` et `nameKey` sont persistés **et synchronisés par CloudKit** : une valeur écrite depuis un appareil est interrogée depuis un autre. Replier avec `locale: .current` fait donc replier les deux côtés de la comparaison différemment, ce qui la rend **fausse quelle que soit la locale** — c'est un défaut structurel de la synchronisation, pas un cas limite, et il est muet. Le site qui mordait vraiment est `Genre.nameKey`, qui sert au dédoublonnage : deux appareils désaccordés créent un doublon **en silence**. Le turc (`I` → `ı`) n'est **qu'une illustration** mesurable de la divergence, pas la raison de la règle. Compromis assumé : le tri n'est pas sensible à la locale (sans effet en français ; `ö` suédois se trierait avec les `o`) — voir `docs/02` §3. Les 12 sites passent par `String.foldedForMatching` (`TextFolding.swift`), seule locale du dépôt, `en_US_POSIX`. **Aucune migration** : `fr_FR` et `en_US_POSIX` replient identiquement, donc les valeurs déjà en base sont inchangées — seul un appareil turc aurait divergé. Deux filets, parce qu'un seul ne suffit pas : 11 tests d'invariance, **et** la règle `no_folding_outside_text_folding` — vérifié, un modèle qui contourne `TextFolding` passe tous les tests sur une machine française | permanent |
| **L'addendum d'erreurs décrit deux causes qui n'ont plus d'objet, il est à amender.** Sur les six causes de la planche 11e : « **Année absente** » suppose que l'année est requise pour créer un titre, or `docs/02` §3.3 rend `releaseDate` **optionnel** — un titre sans année est valide, et la refuser à l'import écarterait des lignes que le modèle accepte. Même motif que la note bornée à 5 : la planche décrit un rendu, la source du modèle est `docs/02`. Signalé, pas appliqué, et `ImportValidatorTests.missingYearIsNotAnError` verrouille le bon comportement. « **Support inconnu** » perd son objet faute de champ au modèle (arbitrage du 2026-08-04, aucune migration). Restent quatre causes réelles, plus la ligne illisible que la planche ne montrait pas | `L11b` |
| **Le profil Movix n'est pas livré, et le mécanisme qui le remplace est en place.** L'arbitrage du 2026-08-04 l'a refusé : le script source est inaccessible, et `isBuiltIn` interdit de retirer un profil livré, donc un profil faux serait pire qu'aucun. Ce qui existe : `ImportMappingRepository` (mémorisation par `headerSignature`, refus de supprimer un `isBuiltIn`, correspondance personnelle qui masque une intégrée), et des **alias par champ** dans `CSVField` — une donnée, pas du code en dur — qui reconnaissent `runtime_min`, `my_score`, `genre_raw` en correspondance *déduite*. Livrer un profil un jour ne demandera donc **aucun code**, seulement un enregistrement | `L11b` |
| **Réalisation, Distribution et Ajouté le s'exportent et se reconnaissent, mais ne s'importent pas encore.** Les trois colonnes ont été ajoutées au schéma en fin de `L11a` (la planche 11d les fait correspondre à un fichier réel). L'export les écrit — distribution triée par `orderIndex`, pas par nom — et la correspondance les reconnaît avec certitude. **Écrire un crédit depuis une cellule est `L11b`** : ça demande de résoudre une personne par son nom, et `GenreRepository.findOrCreate` n'a aucun équivalent pour les personnes ni les collections | `L11b` |
| **Le dédoublonnage n'existe pas encore, donc l'aperçu ne compte aucun doublon.** La planche 11e annonce « 96 doublons » comme une catégorie de premier plan, à côté des prêtes et des en erreur. `L11a` ne la produit pas : reconnaître un doublon exige d'interroger le magasin, ce qui est exactement ce que la coupe met dans `L11b`. `ImportAnalysis` n'a que `readyRows` et `refusedRows` ; la troisième catégorie devra s'y ajouter | `L11b` |
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

| # | Tâche | Ce qu'elle débloque | Rigueur |
|---|---|---|---|
| 1 | `I2` — carte affiche (6 variantes) · carte paysage · carte personne | Tout ce qui affiche une image de catalogue. Le lot qui change le plus l'allure | légère — ✅ `8262878` |
| 2 | `I3` — carte collection · vignette galerie · **avatar de profil** | L'avatar est réclamé par le chrome (sélecteur de profil), la vignette par la fiche | légère — ✅ `ad55476` |
| 3 | `I4` — rail horizontal · grille adaptative · squelette de chargement | **Sans lui aucun écran ne peut être posé** : c'est lui qui porte les 6 points de rupture | légère — ✅ `3f24344` `a2757f6` |
| 4 | `I6` — badge d'état · barre de notation · indicateur de progression | Les états d'une carte et d'une fiche : vu, favori, note | légère — ✅ `a745c7f` |
| 5 | `V0` — **chrome** : navigation régulière, barres d'outils, en-têtes, sélecteur de profil | Remplace la coquille du prompt 10. Toutes les `V` s'y posent | légère |
| 6 | `V0 bis` — **titres** : grille, fiche, éditeur | Remplace le prompt 11. C'est l'écran où l'app se juge | légère |
| 7 | `V5a` — **accueil** : hero + rails par genre | Le premier écran qu'on voit. Demande `L18` pour la règle de choix du hero | légère |

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
| 8 | `L5` — préchargement de vignettes, pression mémoire, échelle d'écran | Le défilement qui ne saccade pas. Branche `startObservingMemoryPressure()`, que personne n'appelle | légère |
| 9 | `L1 bis` — filtres de galerie (source, mélange à graine stable) et store de préférences | La galerie ne peut pas s'écrire sans sa source de données | légère |
| 10 | `I10` — vue vide paramétrée · notification temporaire | Chaque écran a un état vide ; sans lui ils sont muets quand il n'y a rien | légère |
| 11 | `V1` — recherche : champ, portées, résultats groupés | `L2` et `L3` sont faites depuis longtemps et ne servent à rien sans écran | légère |
| 12 | `V2` — médias : `PhotosPicker`, glisser-déposer, collage, éditeur de recadrage | Ajouter ses propres images. `L4` est faite, son geste n'existe pas | légère |
| 13 | `V3` — galerie : masonry, matrice rendue, visionneuse | L'écran qui montre le mieux la direction « plein cadre » | légère |

#### Palier 3 — complète

Le reste des `V`, et les `L` qu'elles réclament. L'ordre interne compte moins ; ce qui
compte est que **`L20` passe avant `L13`** (elle touche au schéma) et que `V6` ne se livre
pas sans elle.

| # | Tâche | Ce qu'elle débloque | Rigueur |
|---|---|---|---|
| 14 | `I5` — ligne de tableau · jeton de filtre · pastille de compteur | La console de gestion et les barres de filtre | légère |
| 15 | `I7` `I8` `I9` — les champs de formulaire, trois lots | Tout éditeur : titre, personne, collection, profil | légère |
| 16 | `L18` — sélections éditoriales, fil d'activité, statistiques | L'accueil (`V5a`), « ma liste », le fil. **Rien ne lit `ActivityEntry` aujourd'hui** | légère |
| 17 | `L20` — annulation de l'édition en masse et de la fusion | `V6`. **Doit passer avant `L13`** : le champ est posé, le format se fige | **maximale** |
| 18 | `L14` — `AppLock` : authentification, délai de grâce, portée par profil | `V7`, le verrouillage | légère **sauf la portée du déverrouillage** |
| 19 | `L16` — maintenance et corbeille : orphelins, purge à 30 jours | `V10` | **maximale** |
| 20 | `L17` — état de synchronisation, les 6 cas, espace occupé | `V10`. **Jamais vérifiable avant le prompt 21** | légère |
| 21 | `V4` — personnes : grille, fiche, éditeur | — | légère |
| 22 | `V5b` — collections, genres, liens et signets, fil | — | légère |
| 23 | `V6` — console de gestion : tableau, édition inline, édition en masse | — . **Ne pas livrer sans `L20`** | légère |
| 24 | `V7` — profils, bibliothèques, transfert, verrouillage | — | légère |
| 25 | `V8` — import et export : aperçu ligne à ligne, corrections, progression | `L11a` `L11b` `L12` sont faites et n'ont aucun écran | légère |
| 26 | `V10` — synchronisation : indicateur, corbeille, espace occupé | — | légère |
| 27 | `V12` — passe d'accessibilité sur les écrans définitifs | — | légère |

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
| `I2` | Carte affiche (les 6 variantes de la matrice) · carte paysage · carte personne | Planche 1 et §5 du handoff — la matrice se juge d'un bloc | palier 1, rang 1 | ✅ `8262878` — `PosterTile` couvre affiche **et** paysage par `CardLayout` ; le troisième composant est `PosterTileDetail` |
| `I3` | Carte collection · vignette galerie · avatar de profil | Planche 3 bloc `4e`, planche 4 bloc `6b`, planche 5 bloc `7f` | palier 1, rang 2 | ✅ `ad55476` |
| `I4` | Rail horizontal · grille adaptative (les 6 points de rupture) · squelette de chargement | Planches 1 et 3 — le squelette est un rail vide à la géométrie finale, il se valide avec eux | palier 1, rang 3 | ✅ `3f24344` `a2757f6` |
| `I6` | Badge d'état · barre de notation · indicateur de progression | Planche 6 blocs `8a` `8c` (notation), addendum 1 bloc `11e` (progression), planches 3 et 7 (badge). **Pas « planche 7 » seule**, comme cette colonne l'a longtemps dit : les trois composants sont sur trois planches différentes | palier 1, rang 4 | ✅ `a745c7f` |
| `I10` | Vue vide paramétrée · notification temporaire | Planche 7 | palier 2, rang 10 | ⬜ |
| `I5` | Ligne de tableau · jeton de filtre · pastille de compteur | Planche 5, aux deux crans de densité | palier 3, rang 14 — avec la console | ⬜ |
| `I7` | Champ texte · zone de texte · champ nombre | Planche 6 | palier 3, rang 15 | ⬜ |
| `I8` | Date à précision variable (année / mois / jour) · sélecteur simple · interrupteur | Planche 6 | palier 3, rang 15 | ⬜ |
| `I9` | Sélecteur multiple avec création à la volée · sélecteur de couleur de profil · marques d'erreur de champ | Planche 6 et addendum 1 (11a–11c, 11i) | palier 3, rang 15 | ⬜ |

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
| `V0` | **Chrome** — navigation régulière (Mac, iPad) et compacte (iPhone), en-têtes et comportement au défilement, barres d'outils (tri, filtres, affichage, actions), sélecteur de profil, indicateur de synchronisation, barre de menus et raccourcis Mac. **Remplace la coquille du prompt 10**, qui est un banc d'essai | 10 | `I2` `I3` `I4` |
| `V0 bis` | **Titres** — grille, filtres, tri, bascule d'affichage · fiche (hero, affiche, métadonnées, casting, galerie, liens) · éditeur. **Remplace le prompt 11.** L'éditeur attend les champs `I7`–`I9` ; la grille et la fiche non | 11 | `V0`, `I2` `I4` `I6` |
| `V5a` | **Accueil** — hero + rails par genre. Détaché de `V5`, qui portait cinq écrans d'un bloc. Le hero exige la règle de choix de `L18` : stable dans la journée, jamais un titre archivé ni privé si le profil les masque | 16 | `V0`, `I4`, `L18` |
| `V1` | Recherche : champ, portées, suggestions, résultats groupés. **L'anti-rebond de la saisie est affaire de vue, pas du service** : `SearchService` est une fonction pure, appelable à chaque frappe, et c'est la vue qui décide quand l'appeler. Le mettre dans le service le rendrait intestable et imposerait un rythme à des appelants qui n'ont pas de frappe à amortir — l'App Intent de `L19`, par exemple. Deux branches obligatoires, et le compilateur les impose : `SearchOutcome.idle` (champ vide → recherches récentes) et `.results` dont les groupes peuvent être vides (→ « aucun résultat ») | 12 | `L2` `L3` |
| `V2` | Médias : `PhotosPicker`, import de fichier, glisser-déposer, collage, `CropEditor`, branchement de `MediaThumbnail` | 13b | `L4` `L5` |
| `V3` | Galerie : masonry, matrice `layout × size` rendue, visionneuse, immersif | 14 | `L1 bis` `L4` `L5` |
| `V4` | Personnes : grille, fiche, éditeur, écran de fusion champ par champ | 15 | `L8` `L9` |
| `V5b` | Collections, genres, liens et signets, fil — **l'accueil en est détaché, voir `V5a`**. **Dont** : le multi-sélecteur de genres affiche « genre existant » plutôt que « créer » quand la frappe correspond à un `nameKey` connu (voir « Arbitrages tranchés », point 2) | 16 | `L6` `L7` `L18` |
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
