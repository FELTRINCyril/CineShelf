# `V3` — ce qui est fait, et ce qui reste

> **Écrit le 2026-08-05 à l'arrêt de la session, à ta demande.** Le code de `V3` est écrit,
> compilé et testé ; ce qui reste est de la **vérification à l'œil** et de l'**écriture**
> (journal, tableau d'état, écarts). Ce fichier est un relais, pas une référence : il se
> supprime quand tout ce qu'il liste est fait.

---

## 1. Ce qui est fait, et mesuré

### Le code

| Fichier | Ce qu'il apporte |
|---|---|
| `Packages/MediaKit/…/PrefetchWindow.swift` | signature corrigée : `indices(from frontier:count:)`. L'ancienne `indices(visible: Range<Int>)` est **supprimée** |
| `Packages/MediaKit/…/PrefetchScheduler.swift` | **neuf** — frontière (le maximum), cran d'émission, différence avec l'ordre précédent |
| `Packages/DesignSystem/…/Layout/MasonryColumns.swift` | **neuf** — répartition en colonnes, bornes des proportions dégénérées |
| `Packages/DesignSystem/…/Layout/MasonryGrid.swift` | **neuf** — colonnes indépendantes, `onAppear` par élément |
| `Packages/DesignSystem/…/Cards/MediaFit.swift` | **neuf** — l'image en `contain`, le seul endroit du système qui laisse des bandes |
| `Packages/DesignSystem/…/Cards/GalleryThumb.swift` | liseré de sélection du bloc `6f` à la place du voile d'accent |
| `Packages/DesignSystem/…/Metrics.swift`, `Icons.swift` | `Stroke.selection`, `Icon.previousImage` / `nextImage` / `selectionMark` |
| `Packages/CineShelfCore/…/EntityQueries.swift` | `MediaQuery.galleryAssets(hidingPrivate:)` |
| `Packages/CineShelfCore/…/FlagRepository.swift` | le favori d'une image — `MediaFlag` n'avait **aucun** écrivain |
| `App/Features/Gallery/GalleryView.swift` | l'écran : en-tête, jetons de source, mélange, sélection |
| `App/Features/Gallery/GalleryMasonry.swift` | la requête, la maçonnerie, le **premier appelant du préchargement** |
| `App/Features/Gallery/GalleryPresentation.swift` | `GalleryFormat` et `GalleryOrder`, hors de la vue donc testés |
| `App/Features/Gallery/GallerySelectionBar.swift` | la barre du bloc `6f` |
| `App/Features/Gallery/MediaViewer.swift` | visionneuse `6c` et immersif `6d` |
| `App/Features/Titles/TitleDetailView.swift` | la galerie de la fiche : toutes les images, cliquables, recadrables |
| `App/DemoData/DemoGallery.swift` | **neuf** — images de galerie à ratios dégénérés, personnes, collections, orphelins |
| `App/Navigation/NavigationModel.swift` | `galleryFilter` persisté (source **et** graine) |
| `Catalog/BlockSpecs.swift`, `LayoutSheets.swift`, `CardSheets.swift`, `SampleImageLoader.swift` | planche de maçonnerie, et de **vraies images au bon ratio** sur les vignettes de galerie |

### Les trois arbitrages, pour que tu n'aies pas à les refaire

1. **`PrefetchWindow` — variante `onAppear`, pas `ScrollPosition`.** En maçonnerie les colonnes
   ont des hauteurs différentes, donc **la tranche visible n'existe pas** : il y a une frontière
   par colonne. `ScrollPosition` ne rend qu'un identifiant d'ancrage pour toute la vue de
   défilement — muet sur les autres colonnes, et muet **au repos**, c'est-à-dire au premier
   affichage, quand précharger sert le plus.

2. **L'agrégation entre colonnes est le `max`, et elle est écrite et testée.** Le motif : un index
   qui a **apparu** a déjà été réclamé par le chemin d'affichage, donc seul l'au-delà du maximum
   n'est réclamé par personne. La frontière ne régresse jamais, et il n'y a **pas** d'heuristique
   de demi-tour : avec 40 et 25 sur deux colonnes, l'écart entre colonnes dépasse déjà le seuil
   qu'un tel test devrait employer, donc il lirait la colonne en retard comme une remontée.
   `PrefetchSchedulerTests` porte les deux cas.

3. **Point 3 de ton message : tu avais raison de le demander, et la conclusion tient quand même.**
   `6b` est rendu à **393, 1194 et 1920 px** — pas au format Mac. Donc à **393 px**, la seule
   largeur que `6b` et `13c` rendent tous les deux, ils se contredisent : **3 colonnes contre 2**,
   soit 116 pt de carte contre 140. Ce sont bien des valeurs comparables. Et `6b` se contredit
   lui-même : ses trois largeurs impliquent 116, 222 puis 223 de carte, donc un compte de
   colonnes **par format** et non une carte constante. Verdict inchangé : les rendus divergent →
   le jeton fait foi ; `13c` est le seul bloc qui **nomme** un cran (`poster.l`), il le nomme aux
   deux formats qu'il rend, et `PosterScale.l` avec les jetons de marge et de gouttière redonne
   exactement 2 à 393 et 4 à 834.

### Les mesures, telles qu'elles sont sorties

**Le préchargement fait quelque chose, et c'est chiffré** (`PrefetchEffectTests`, MediaKit) :

| Régime | Affichages trouvant leur image en mémoire |
|---|---|
| sans préchargement | **0 sur 24** |
| avec, défilement plus lent que le décodage (drainé) | **23 sur 24** |
| avec, défilement à 5 ms par élément | **12 sur 24** |

Le premier et le deuxième sont **assénés** : le rapport ne dépend d'aucune horloge. Le troisième
est **imprimé seulement** — sur un runner GitHub, un seuil ne mesurerait que la machine.

**La branche « orphelin »** (`GalleryFixtureTests`, cible app), sur 60 titres de démonstration :

```
[V3] source « orphelin » sur 205 médias et 193 pièces jointes : 12 orphelins en 39,0 ms,
     contre 171 médias de titres en 25,1 ms
     (la branche « orphelin » fait deux fetch complets, l'autre un seul filtré)
```

Aucun seuil assené : le coût linéaire est un fait de conception, pas une régression. Ce qui est
assené est la **justesse** — 12 orphelins sur 12 attendus, et disjoints des médias de titres.
**Atténuation ajoutée** : un filtre inactif — le cas par défaut — ne déclenche **aucun** `fetch`,
donc la galerie ordinaire ne paie jamais cette branche.

### Les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **461 · 70 · 64** |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **114 tests** (99 avant) |
| `xcodebuild test -scheme DesignSystemCatalog` macOS · iOS | ✅ **71** et **70** |
| `xcodebuild build -scheme CineShelf` macOS · iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 281 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| `xcodebuild test -scheme CineShelfUITests` | ❌ **non lancée** |

---

## 2. Ce qui reste — dans cet ordre

### a) La commande non lancée

```bash
xcodebuild test -scheme CineShelfUITests -destination 'platform=iOS Simulator,name=iPhone 17'
```

Un seul test dans cette cible, et `V3` ne touche pas la navigation qu'il exerce — mais **ça ne
se déduit pas**, ça se lance.

### b) La vérification à l'œil, que je ne peux pas faire

Rien de ce qui suit n'est couvert par un test, et c'est le cœur d'une tâche `V` :

```bash
open ~/Library/Developer/Xcode/DerivedData/CineShelf-*/Build/Products/Debug/DesignSystemCatalog.app
```

- **planche « Rail · Grille · Squelette · I4 », section Maçonnerie** : les colonnes coulent-elles
  séparément ? Les images sont-elles **dessinées à leur propre ratio** (21:9, 9:21, carré) ou
  toutes en 2:3 recadrées ? Deux colonnes à 393 pt, quatre à 834 ?
- **planche `I3`, vignette de galerie** : la deuxième de chaque colonne est sélectionnée — le
  liseré d'accent est-il **à l'intérieur** du cadre, avec sa pastille cochée en haut à droite ?
- **l'app sur Mac**, section Galerie : la grille se remplit-elle d'images (et non d'aplats) ? Le
  clic ouvre-t-il la visionneuse ? Les flèches et la bande de vignettes changent-elles d'image
  sans refermer ? « Immersif » masque-t-il le chrome ? La sélection multiple coche-t-elle au lieu
  d'ouvrir ?
- **la fiche titre** : le rail de galerie montre-t-il **toutes** les images (avant, il en montrait
  cinq) et le clic mène-t-il au recadrage ?

### c) `docs/journal.md` — l'entrée de `V3`

Ce qu'elle doit porter, et qui n'est écrit nulle part ailleurs :

- **la signature était le défaut, pas l'absence d'appelant** — quatre sessions d'écart inscrit
  sous une mauvaise cause. La leçon généralisable : « aucun appelant » peut vouloir dire
  « aucun appelant **possible** », et c'est l'API qu'il faut alors regarder, pas la liste des
  appelants ;
- **les trois arbitrages** du §1 ci-dessus, en particulier le troisième : ma première formulation
  comparait 3 colonnes et 2 colonnes sans vérifier que les largeurs étaient comparables. Elles
  l'étaient, mais **je ne l'avais pas vérifié** — la conclusion était juste par chance, ce qui est
  précisément ce que la règle « une règle de doctrine énonce sa raison » interdit ;
- **les chiffres du préchargement**, tels quels ;
- **`DemoCatalog` était le cas nul**, et personne ne l'avait vu : aucune pièce jointe `.gallery`,
  aucun orphelin, une seule proportion. L'écran aurait été **vide** et trois des quatre branches
  du filtre n'auraient été exercées par rien. C'est la troisième fois que ce motif mord ;
- **deux gardes existantes ont mordu**, et c'est une bonne nouvelle : `Icon.all` a refusé deux
  constantes de même glyphe, et `file_length` a refusé `BlockReference.swift` à 513 lignes ;
- **un test que j'avais écrit faux** : j'attendais `clamped(aspect: .infinity)` à la borne haute,
  or l'infini n'est pas une image très large mais une division par zéro, donc c'est le repli qui
  s'applique. Le code avait raison.

### d) `docs/PROMPTS.md` — trois endroits à cocher, avec les hash

1. le tableau « Ce qui reste », **ligne 14 · Galerie + visionneuse** → ✅ ;
2. le **palier 2**, ligne `V3` → ✅ ; le palier 2 est alors **clos** ;
3. le tableau des tâches `V`, ligne `V3` → l'état et le hash.

> Le hash s'inscrit dans un commit **suivant**, jamais par `--amend`. Vérification :
> ```bash
> grep -oE '`[0-9a-f]{7}`' docs/PROMPTS.md | tr -d '`' | while read h; do
>   git merge-base --is-ancestor $h HEAD || echo "$h orphelin"; done
> ```
> Seul faux positif attendu : `56ed7a7` (app web, autre dépôt).

### e) Les écarts — à rayer

Six lignes des « Écarts connus » sont **fermées** par `V3`, et chacune doit être rayée en nommant
ce qui l'a fermée :

| Écart | Ce qui le ferme |
|---|---|
| « `PrefetchWindow` demande une tranche visible que rien ne sait lui donner » | signature remplacée par `indices(from:count:)`, `PrefetchScheduler` ajouté, appelée par `GalleryMasonry` |
| « Préchargement de l'écran suivant — API livrée par `L5`, appel côté vue à faire » | l'appel existe, et son effet est mesuré. **Reste `V6`** pour la console : la ligne se scinde |
| « `CropEditor` n'est atteignable que depuis la fiche titre, et sur une seule image » | atteignable depuis la visionneuse, sur toute image de galerie. **Reste `V4` et `V5b`** pour les personnes et les collections |
| « Le forçage sombre n'est posé nulle part » | `.preferredColorScheme(.dark)` sur la galerie et la visionneuse. **Reste `V5`** pour l'accueil et les fiches |
| « Le catalogue ne pouvait pas révéler ce défaut — à reprendre avec `V3` » | la planche de maçonnerie porte de vraies images, dessinées **au ratio de la tuile** |
| « La différence d'ensembles des orphelins … ce n'est mesuré que sur des centaines » | mesuré et imprimé ; le filtre inactif ne l'emprunte plus du tout |

### f) Les écarts — à inscrire, neufs

1. **Les jetons de filtre de la galerie ne sont pas ceux du bloc `13c`.** Le prototype propose
   « Toutes · Affiches · Jaquettes · Plans · Sans titre » — un filtre par **nature d'image** ; ce
   qui est implémenté est le filtre par **source** (titre, personne, collection, orphelin), qui
   est celui que `L1 bis` a écrit et mesuré. Les deux ne se recouvrent qu'en un point :
   « Sans titre » est l'orphelin. Un filtre par `MediaSlot` reste à écrire — où : une tâche `L`
   d'appoint, puis retouche de `GalleryView`.
2. **La galerie n'a pas de contexte dans la matrice `disposition × taille`.** Le bloc `13c`
   affiche un « Portrait · Medium ▾ » dans sa barre, mais le jeu des huit contextes de la v1 —
   celui qui fait foi — n'en contient aucun pour la galerie, et « portrait » n'a de toute façon
   aucun sens en maçonnerie. Le menu « Affichage » n'est donc **pas** rendu. Où : à trancher avec
   toi ; ajouter un neuvième contexte rouvrirait le vocabulaire que `L1 bis` a fermé.
3. **La barre de sélection est sous l'en-tête, pas en bas de fenêtre.** Le bloc `6f` l'épingle au
   bas du cadre ; l'écran est un *contenu* de la `ScrollView` que le chrome possède (décision de
   `V0`), et rien ne s'épingle au bas de la fenêtre depuis l'intérieur d'un contenu défilant. Où :
   le jour où le chrome propose un emplacement bas.
4. **« Rattacher à… » et « Exporter » ne sont pas rendues** dans la barre de sélection : la
   première demande un sélecteur d'entité (`I9`, palier 3), la seconde appartient à `V8`. Un
   bouton inerte est pire qu'un bouton absent.
5. **L'épaisseur du liseré de sélection diverge entre le bloc `6f` (3 pt, vers l'intérieur) et le
   §7 (2 pt, offset 3).** Le bloc rendu gagne sur la prose de synthèse, comme la barre latérale du
   §4.6 avait perdu contre les douze écrans. `Stroke.selection = 3`.
6. **Les jaquettes de `DemoCatalog` n'ont toujours pas de `blurHash`.** Les images de galerie en
   ont, puisqu'elles passent par `MediaIngestor` ; les jaquettes remplissent leurs champs à la
   main depuis le prompt 11. Donc le placeholder du bloc `9b` — le dégradé — n'est exercé que par
   les médias de galerie. Où : une passe sur `attachPoster`, cinq lignes.
7. **L'archivage d'une image n'a pas d'écran qui la retrouve.** `MediaQuery.galleryAssets` exclut
   `isArchived`, ce qui est déduit du bloc `6f` (il propose « Archiver », donc archiver doit faire
   quelque chose de visible) — mais aucun bloc ne dessine l'écran des images archivées. Où :
   `V10`, avec la corbeille.
8. **La visionneuse est une feuille sur macOS, pas une surface plein écran.**
   `fullScreenCover` n'existe pas sur macOS ; c'est le même choix que `CropEditor`. Le zoom, le
   pincement et le mode immersif fonctionnent dedans, mais la fenêtre garde son chrome système.

### g) Enfin

```bash
git push origin main
gh run list --limit 3    # et si c'est rouge, c'est le sujet avant toute autre tâche
```

---

## 3. Ce que je n'ai pas fait, et qui n'est pas dans `V3`

- **le pincement pour changer de cran dans la galerie** (addendum 2 §« Les gestes ») : nommé par
  le design, jamais spécifié, et sans contexte de matrice pour la galerie il n'a rien à régler ;
- **le glisser-déposer vers la galerie** : l'import se fait depuis une fiche, c'est `V2` ;
- **la sélection par appui long sur iPhone** (bloc `6f` : « bouton sur iPad, appui long sur
  iPhone ») : le bouton « Sélectionner » est rendu sur les deux. Écart mineur, à inscrire si tu
  le veux.
