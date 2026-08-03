# Handoff — CineShelf, application native Apple

> **Ce document est le paquet de design livré, extrait dans le dépôt et amendé sur
> place.** Deux catégories de changements y ont été faites, et elles sont signalées
> partout où elles interviennent :
>
> 1. **Une correction de fond**, au §7 et au §10 : le contenu privé est porté par
>    l'entité et non par le profil. La formulation d'origine conduisait à une fuite.
> 2. **Le retrait des copies de `03-FONCTIONNALITES-NATIF.md` et `06-BRIEF-DESIGN.md`**
>    que le paquet embarquait. Elles étaient identiques aux nôtres au moment de la
>    livraison, et l'auraient cessé au premier changement. Les renvois pointent
>    désormais vers `docs/`, qui fait foi.
>
> Les prochaines livraisons s'extraient ici de la même façon — voir `docs/README.md`.

Étape 9 du travail de design, mise à jour après les addenda. Ce dossier est le paquet de transmission au développement : tout ce qui a été décidé, mesuré et rendu, sous une forme lisible sans avoir assisté à la conversation.

Le paquet contient huit planches de validation et trois addenda. Les addenda ne remplacent rien : ils comblent les trous que la section 10 de ce document signalait — états d'erreur de champ, parcours de récupération à l'import, adaptations iPhone et iPad, icône de l'app.

---

## 1. Vue d'ensemble

CineShelf est une bibliothèque de films **possédée et locale** : l'utilisateur catalogue ce qu'il a (disques, fichiers, éditions), pas ce qu'un service lui propose. L'app est native Apple, sur trois plateformes — macOS, iPadOS, iOS — avec un modèle de données et une partie du code déjà existants.

Le design couvre : l'écran d'accueil, douze écrans de navigation, la galerie d'images et son éditeur, sept écrans de gestion (console, import, export, fusion, profils, réglages), les formulaires, les surfaces superposées, les états vides, de chargement et d'interruption, et le système de tokens complet.

**Direction retenue : « 2a Plein cadre ».** Noir uniforme, un seul accent ambre, aucune bordure, aucune ombre, aucune translucidité d'interface. L'affiche est l'interface : elle n'a ni cadre, ni coin arrondi, ni légende au repos.

## 2. Ce que sont les fichiers de ce dossier

Les fichiers `.dc.html` sont des **références de design réalisées en HTML**. Ce sont des prototypes qui montrent l'apparence et le comportement voulus — **pas du code à reprendre**. Le travail consiste à **recréer ces écrans en SwiftUI**, dans le projet existant, avec ses conventions, ses vues et son modèle de données déjà en place. Aucune ligne de HTML, de CSS ni de JavaScript ne doit se retrouver dans l'app.

Les couleurs sont exprimées en `oklch()` dans les prototypes, avec l'équivalent hexadécimal donné en regard dans la planche 8. C'est l'hexadécimal qui sert de référence pour le catalogue d'assets Xcode.

## 3. Fidélité

**Haute fidélité.** Couleurs, typographie, espacement, tailles et contrastes sont définitifs et mesurés. Les écrans doivent être recréés au pixel près, à trois exceptions près, explicitement documentées :

- **Aucune icône d'interface n'a été dessinée.** Partout où un prototype montre une pastille carrée ou un caractère typographique, il faut le SF Symbol correspondant — la correspondance complète est en section 8. L'icône de l'app, elle, est fournie en SVG (section 13).
- **Les fonds de hero sont des affiches agrandies et floutées.** Dans l'app, ce sont de vraies images larges (16:9) recadrées par contexte.
- **Les chromes système sont approximatifs** : feux de fenêtre macOS, Dynamic Island, barre de statut iOS. Utiliser les composants système, pas les dessins.

## 4. Les tokens

Source unique : planche 8. Valeur canonique en `oklch`, hexadécimal donné pour le catalogue d'assets.

### 4.1 Couleur — quatre apparences

Colonnes : Sombre (défaut) · Sombre contraste élevé · Clair · Clair contraste élevé.

| Token | Rôle | Sombre | Sombre HC | Clair | Clair HC |
|---|---|---|---|---|---|
| `bg.canvas` | fond de tous les écrans | `#040404` | `#000000` | `#fafafa` | `#ffffff` |
| `bg.inset` | zone de travail dense (console, panneaux) | `#1f1f1f`* | — | — | — |
| `bg.surface` | listes denses, panneaux, lignes | `#131313` | `#0a0a0a` | `#f0f0f0` | `#ebebeb` |
| `bg.raised` | feuilles, popovers, dialogues | `#1f1f1f` | `#171717` | `#ffffff` | `#ffffff` |
| `bg.fill` | champs, jetons, boutons secondaires | `#2b2b2b` | `#353535` | `#dedede` | `#d1d1d1` |
| `bg.viewer` | visionneuse et mode immersif | `#0f0f0f` | `#000000` | `#0f0f0f` | `#000000` |
| `text.primary` | titres, valeurs, corps | `#f5f5f5` | `#ffffff` | `#161616` | `#060606` |
| `text.secondary` | sous-titres, métadonnées | `#a4a4a4` | `#cacaca` | `#525252` | `#2e2e2e` |
| `text.tertiary` | libellés, aides, compteurs | `#7f7f7f` | `#9e9e9e` | `#6c6c6c` | `#4d4d4d` |
| `accent` | sélection, liens, actif, marque | `#ffb75f` | `#ffc774` | `#ab4700` | `#a14400` |
| `accent.onAccent` | texte posé sur l'accent | `#040404` | `#000000` | `#ffffff` | `#ffffff` |
| `danger` | suppression, échec | `#f75d59` | `#ff7d76` | `#c21725` | `#a90015` |
| `success` | sync terminée, ligne validée | `#67d283` | `#84e79c` | `#137738` | `#00642a` |
| `separator` | traits de tableau, 1 px | `#171717` | `#2e2e2e` | `#d9d9d9` | `#b3b3b3` |
| `private.mask` | contenu privé verrouillé | `#0e0e0e` | `#030303` | `#dedede` | `#cacaca` |

\* `bg.inset` = `oklch(0.135 0 0)`. Un cran entre `bg.canvas` et `bg.surface`, pour que les lignes de tableau se détachent sans trait. `bg.viewer` = `oklch(0.07 0 0)` : reste sombre dans les quatre apparences, comme une vue plein écran de Photos ou d'Aperçu.

Voiles et translucidité — **uniquement posés sur une image**, jamais sur une surface opaque, jamais de matériau système ni de flou d'interface :

- `scrim.modal` — noir à 62 % (sombre), 78 % (sombre HC), 34 % (clair), 50 % (clair HC)
- `scrim.crop` — `oklch(0.09 0 0 / 0.68)`, masque de l'éditeur de recadrage
- `fill.onImage` — `oklch(1 0 0 / 0.14)`, boutons secondaires sur un hero
- `chip.onImage` — `bg.canvas` à 82 %, pastille d'état sur une affiche

Contrastes mesurés (WCAG 2.1), tous les textes ≥ 4,5:1 dans les quatre apparences. Les traits de tableau sont à 3,0:1 en sombre normal : conforme pour un élément non textuel, accepté explicitement par le client.

**Aucun token d'ombre.** `shadow: none` est une règle du système. Si une vue semble en avoir besoin, c'est le signe d'un écran hors-système, pas d'un token manquant.

### 4.2 Typographie

Familles : **Bebas Neue** (titrage), **Archivo** et **Archivo Narrow** (interface), **Public Sans** (corps), **IBM Plex Mono** (chiffres et métadonnées). À embarquer dans le bundle.

| Token | Taille / interlignage | Famille | Interlettrage | `relativeTo:` |
|---|---|---|---|---|
| `display` | 56 / 1.0 | Bebas Neue | +0.02em | `.largeTitle` |
| `title.1` | 34 / 1.05 | Bebas Neue | +0.02em | `.title` |
| `title.2` | 22 / 1.15 | Bebas Neue | +0.03em | `.title2` |
| `headline` | 15 / 1.3 | Archivo 600 | 0 | `.headline` |
| `body` | 15 / 1.55 | Public Sans 300 | 0 | `.body` |
| `callout` | 13 / 1.45 | Archivo 400 | 0 | `.callout` |
| `label` | 11 / 1 | Archivo Narrow 600 | +0.12em, capitales | `.caption` |
| `action` | 12 / 1 | Archivo Narrow 600 | +0.08em, capitales | `.subheadline` |
| `meta` | 11 / 1.35 | IBM Plex Mono 400 | +0.02em | `.caption2` |
| `numeric` | 12 / 1.3 | IBM Plex Mono 500 | 0, tabulaire | `.footnote` |
| `micro` | 10 / 1.4 | IBM Plex Mono 400 | +0.04em | `.caption2` |

Règles : tout chiffre aligné en colonne est en IBM Plex Mono tabulaire. Deux niveaux de capitales seulement — `label` nomme un champ, `action` se clique. Les capitales ne servent jamais à un titre de contenu.

**Basculement accessible.** Jusqu'à `.xxLarge`, Bebas grandit normalement. À partir de `.accessibilityMedium`, les trois styles de titrage (`display`, `title.1`, `title.2`) passent en **Archivo Narrow 700** et la densité bascule en ample, y compris sur Mac. Conséquences validées : les formulaires en regard passent en libellé-au-dessus, les grilles perdent une à deux colonnes, et le mot CINESHELF perd son allure de logotype (à transformer en image si nécessaire). Rendus : planche 8, bloc 10l.

Dynamic Type est suivi dès le premier lancement sur iOS et iPadOS. Sur macOS la typographie est fixe ; seule la densité varie.

### 4.3 Espacement, densité, géométrie

Base 4 pt : `space.1` 4 · `space.2` 8 · `space.3` 12 · `space.4` 16 · `space.5` 24 · `space.6` 32 · `space.7` 48 · `space.8` 64.

| Mesure | Dense | Ample |
|---|---|---|
| Hauteur de ligne de tableau | 28 | 44 |
| Hauteur de barre d'outils | 44 | 60 |
| Marge horizontale d'écran | 24 | 36 |
| Espacement vertical de formulaire | 10 | 20 |
| Hauteur de champ | 28 | 38 |
| Cible tactile minimale | — | 44 |
| Gouttière de grille | 16 | 24 |
| Interlignage du corps | 1,45 | 1,6 |

**Densité par défaut** : dense sur macOS, ample sur iOS. Sur iPadOS : ample par défaut, dense dès qu'un pointeur (clavier Magic Keyboard, trackpad, souris) est détecté, avec une transition en `dur.base` et un réglage manuel dans les préférences.

Rayons : `radius.none` 0 (affiches, images, tout ce qui est photographique) · `radius.xs` 2 (jetons, champs, boutons) · `radius.s` 4 (cartes non-affiche) · `radius.m` 10 (popover, menu, notification) · `radius.l` 14 (feuille modale). `radius.sheet` = `radius.l` appliqué **aux deux coins hauts seulement**, et uniquement sur iOS/iPadOS ; sur macOS la feuille est un dialogue centré à angles francs.

Trait : `stroke.hairline` 1 px, couleur `separator`. C'est le seul trait autorisé.

### 4.4 Mouvement

| Token | Durée | Courbe | Usage |
|---|---|---|---|
| `dur.instant` | 0 ms | — | sélection dans un tableau dense |
| `dur.fast` | 120 ms | easeOut | survol, focus, bascule d'état |
| `dur.base` | 220 ms | easeInOut | panneau, bandeau, bascule de densité |
| `dur.sheet` | 320 ms | spring(0.86, 0.28) | feuille, changement de palier |
| `dur.zoom` | 380 ms | spring(0.9, 0.3) | affiche → visionneuse plein écran |
| `dur.slow` | 600 ms | easeInOut | fondu du hero au changement de titre |

### 4.5 Plans (ordre de superposition)

`layer.content` 0 · `layer.sticky` 10 · `layer.menu` 30 · `layer.scrim` 40 · `layer.modal` 50 · `layer.viewer` 60 · `layer.notification` 80.

Deux règles : un seul plan modal à la fois — une feuille ne s'ouvre pas au-dessus d'un dialogue, elle le remplace ; la notification passe au-dessus de tout, y compris de la visionneuse.

### 4.6 Points de rupture

Sur **largeur de fenêtre**, pas sur classe de taille. Le nombre de colonnes indiqué est celui de la grille en portrait medium ; il se recalcule pour les autres crans, la largeur de carte étant fixe.

| Largeur | Contexte | Colonnes | Ce qui change |
|---|---|---|---|
| < 430 | iPhone portrait | 2 | barre d'onglets, marges 20, hero pleine hauteur, un rail visible, inspecteur en feuille |
| 430–743 | iPhone paysage, fenêtre étroite | 3 | barre d'onglets, hero à 62 %, deux rails visibles |
| 744–1023 | iPad portrait | 4 | barre latérale en superposition refermée par défaut, marges 28, inspecteur en feuille |
| 1024–1279 | iPad paysage, fenêtre Mac réduite | 5 | barre latérale permanente, marges 24, inspecteur en colonne |
| 1280–1679 | Mac standard | 6 | barre latérale + inspecteur simultanés, marges 32, console dense |
| ≥ 1680 | Mac large | 7+ | marges 64, gouttière 24, largeur de synopsis plafonnée à 720 |

## 5. La matrice disposition × taille — fonctionnalité existante

**Point d'attention pour l'implémentation.** Ce n'est pas une préférence de design : c'est une fonctionnalité déjà présente dans le modèle de données. L'utilisateur choisit `portrait|paysage × compact|medium|large`, **indépendamment sur huit contextes**, et le réglage est mémorisé par contexte.

Échelle sous-jacente, six crans, exprimés en **largeur de carte** :

`poster.xs` 32 · `poster.s` 56 · `poster.m` 92 · `poster.l` 140 · `poster.xl` 200 · `poster.xxl` 280

Le ratio dérive la hauteur : **2:3 en portrait, 16:9 en paysage**. Le ratio 16:9 a été retenu parce que l'éditeur de recadrage produit déjà 16:9 et 2:3, parce que les images larges arrivent en 16:9, et parce que 3:2 ne serait que 8 % plus haut à largeur égale — invisible en rangée, mais désaligné du fond de hero.

Correspondance (contexte, disposition, taille) → cran :

| Contexte | Compact | Medium | Large | Défaut |
|---|---|---|---|---|
| Accueil · rail titres | `poster.m` | `poster.l` | `poster.xl` | portrait medium |
| Accueil · rail personnes | `poster.s` | `poster.m` | `poster.l` | portrait compact |
| Accueil · rail collections | `poster.m` | `poster.l` | `poster.xl` | paysage medium |
| Accueil · rail social | `poster.s` | `poster.m` | `poster.l` | paysage compact |
| Titres · grille | `poster.m` | `poster.l` | `poster.xxl` | portrait medium |
| Personnes · grille | `poster.s` | `poster.m` | `poster.xl` | portrait compact |
| Collections · grille | `poster.m` | `poster.l` | `poster.xxl` | paysage medium |
| Social · fil | `poster.m` | `poster.l` | `poster.xl` | paysage medium |

Les six combinaisons sont rendues pour de vrai dans la planche 8, bloc 10f. Constat à connaître : une affiche portrait recadrée en 16:9 perd le haut et le bas de la composition, donc souvent son titre imprimé. Le paysage n'a de sens que sur les contextes où l'image source est réellement large.

**Écart connu** : l'accueil de la planche 1 montre des cartes de rail à 172 px, qui n'est aucun cran de l'échelle. Le code doit utiliser `poster.xl` (200). Le rendu final différera légèrement de ce prototype.

## 6. Écrans

Tous les prototypes d'écran sont au format Mac 1280 × 760 sauf mention contraire. Un `data-screen-label` dans le HTML identifie chaque écran.

### Accueil (planche 1, bloc 2a — format 1440 × 900)
Hero plein cadre à 100 % de la hauteur : image large floutée, trois voiles superposés (dégradé vers le bas, dégradé vers la droite, trame horizontale à 1,4 %), barre de navigation transparente en haut à 66 px. Bloc de titre à gauche : surtitre de collection en `label` ambre, titre en `display` à 136 px, ligne de métadonnées en capitales, synopsis, trois boutons (primaire blanc sur noir, deux secondaires en `fill.onImage`). Le premier rail n'affleure qu'en bas de cadre, la dernière carte coupée par le bord droit. Aucune métadonnée sous les affiches.

### Douze écrans de navigation (planche 3)
Titres, Fiche titre, Personnes, Fiche personne, Collections, Fiche collection, Galerie, Recherche, Ma liste, Signets, Fil, et l'accueil complet. Grille ou rails selon le contexte, chrome de la planche 2. Le Fil est un **journal d'activité daté**, pas un flux social.

### Galerie (planche 4)
Matrice des six tailles, comportement en colonnes, visionneuse plein écran avec zoom (fond `bg.viewer`), mode immersif (chrome masqué, compteur « Image 14 sur 47 »), éditeur de recadrage (cadre libre, aperçu simultané 16:9 et 2:3, masque `scrim.crop`), sélection multiple avec barre d'actions en bas.

### Sept écrans de gestion (planche 5)
Console avec inspecteur (lignes 28 pt, usage clavier, fond `bg.inset`), édition en masse (« valeurs multiples » pour les champs divergents), import CSV avec validation en direct, export CSV/JSON avec sélection de colonnes, fusion champ par champ, profils, réglages.

### Formulaires et surfaces (planche 6)
Le même jeu de champs en dense et en ample. Types : texte, nombre, bascule, date à précision variable (**trois crans : année, mois, jour**), note en cinq étoiles pleines (pas de demi-étoile), multi-sélecteur avec création de valeur en cours de saisie, jetons de couleur en liste fermée. Surfaces : feuille à trois paliers (ouverture au palier intermédiaire), popover, dialogue, confirmation destructive, menus, notification, panneau latéral.

### Erreurs de champ (addendum 1, blocs 11a–11c, 11i)
Anatomie à quatre marques, dans les deux densités : libellé en `danger`, trait 1 px en `danger`, triangle `exclamationmark.triangle` dans le champ, message en `micro` sous le champ. Quatre cas couverts — format invalide, requis vide, hors bornes, valeur refusée. Le message dit quoi faire, jamais ce qui est faux. L'erreur apparaît à la sortie du champ, sauf dépassement de bornes signalé immédiatement. Un requis vide reste neutre (mention `Requis` en `text.tertiary`) jusqu'à la tentative de validation. Aucun fond coloré : le système n'a pas de teinte d'état.

Refus à la validation : rien n'est fermé, rien n'est perdu, aucune valeur remise à zéro. Récapitulatif en tête du formulaire (dans le contenu, pas en notification) listant les champs fautifs sous forme de liens ; focus sur le premier ; Enregistrer devient inerte en `bg.fill` + `text.tertiary` jusqu'à correction du dernier champ. Retour à la validité : message et triangle partent ensemble, trait en `success` avec une coche de 1,2 s, puis aucune marque — un champ valide au repos ne se signale pas.

### Import, parcours complet (addendum 1, blocs 11d–11g, 11j)
Quatre étapes : correspondance des colonnes, aperçu, corrections, import.

1. **Correspondance** — une ligne par colonne du fichier, avec ses trois premières valeurs et le champ CineShelf visé. Trois qualités de correspondance : sûre, déduite du contenu (à vérifier), non reconnue. Une colonne non reconnue **n'est pas une erreur** : elle est ignorée par défaut et l'import peut avancer ; le menu propose aussi de créer un champ libre. Correspondance mémorisable pour les fichiers de même en-tête. Aucune donnée écrite à cette étape.
2. **Aperçu à forte proportion d'erreurs** — 1 284 lignes, 771 prêtes, 417 en erreur, 96 doublons. Les erreurs sont groupées **par cause, pas par ligne** : six causes, chacune avec son action de masse. Filtres Toutes / En erreur / Doublons / Prêtes. Deux sorties possibles dès cet écran : importer les lignes prêtes, ou tout importer avec les erreurs en brouillon.
3. **Correction en masse** — un dialogue par cause, plusieurs stratégies avec le nombre de lignes que chacune résout, et un aperçu avant → après sur les premières lignes concernées. Réversible jusqu'à l'import, annulable correction par correction.
4. **Abandon à mi-parcours** — trois issues, aucune destructrice par défaut : reprendre plus tard (brouillon conservé : fichier, correspondance, corrections), importer les lignes prêtes maintenant, tout abandonner (seule action destructrice, confirmation standard). Fermer la fenêtre ou quitter l'app équivaut à « reprendre plus tard ». Un seul brouillon d'import à la fois. Au retour, un bandeau de reprise se pose sur l'écran Titres.
5. **Fin d'import** — bilan chiffré (ajoutés, écartés, doublons fusionnés), causes du rejet, liste des décisions de masse appliquées et encore annulables, et quatre suites : voir les titres ajoutés (filtre conservé 30 jours), exporter le rapport des écartées, reprendre les écartées, annuler tout l'import. Le rapport est un CSV au format d'origine avec une colonne `cineshelf_erreur` en fin de ligne : corrigé dans un tableur, il se redépose et repart directement à l'aperçu. Si l'app était en arrière-plan, le bilan arrive aussi en notification (`layer.notification`).

### iPhone et iPad, quatre écrans (addendum 2)
Les quatre écrans qui changent de nature selon le format, rendus en iPhone portrait (393 × 852) et iPad portrait (834 × 1194). Les huit autres écrans de navigation suivent soit le modèle de grille, soit le modèle de fiche, et se déduisent des points de rupture.

- **Accueil** — iPhone : hero à 100 %, rail affleurant au-dessus de la barre d'onglets, titre à 76 px, deux actions (un bouton plein + une cible de 44), « Modifier » renvoyé dans la fiche. iPad : hero à 62 %, deux rails visibles, barre latérale repliée derrière le bouton de menu, cartes de rail en `poster.l`.
- **Fiche titre** — iPhone : affiche en `poster.m` posée à côté du titre, champs en libellé-au-dessus sur une colonne, trois actions maximum. iPad : `poster.xl` comme sur Mac, champs en deux colonnes, second rail (galerie du titre, paysage 16:9, `poster.l`).
- **Galerie** — 2 colonnes à 393 px, 4 à 834 px, à cran de carte constant : le nombre de colonnes n'est pas un réglage, la grille prend ce qui rentre. Seul écran où les ratios se mélangent réellement (2:3, carré, 16:9), donc seul écran qui exige la maçonnerie en colonnes indépendantes. Sélection multiple : bouton sur iPad, appui long sur iPhone ; barre d'actions en bas dans les deux cas.
- **Console** — iPhone : la table devient une **liste** de lignes de 60 avec vignette `poster.xs`, titre en `headline` et une ligne de métadonnées en mono où l'ambre signale ce qui manque ; inspecteur en feuille ; édition en masse via le mode Modifier. iPad : table à quatre colonnes (au lieu de sept sur Mac), lignes de 44 puisque la densité par défaut est ample — deux colonnes de plus si un clavier est branché et que la densité passe en dense. L'inspecteur n'est jamais une colonne sous 1024 px.

Non dessinés, assumés : iPad paysage (très proche du Mac déjà rendu), iPhone paysage, les gestes (appui long, balayage, pincement) et les écrans avec clavier logiciel ouvert — sur iPhone, la feuille d'inspecteur perd 336 px quand il apparaît, à vérifier au développement.

### États (planche 7)
Sept états vides, chacun disant ce qui manque et proposant une action principale (blanche) et une secondaire (grise). Squelettes à la **géométrie finale exacte** — ratio réservé, aucun saut de mise en page, aucune animation de balayage ; dans l'app, remplacer la trame rayée par la couleur dominante de l'image. Bandeaux d'interruption (hors ligne, synchronisation, quota, verrouillage Face ID) qui se posent sous la barre et **n'effacent jamais le contenu déjà chargé**. Contenu privé masqué : géométrie exacte de l'affiche, aplat `private.mask`.

## 7. Comportements

- **Barres** : fond nul au repos, `bg.canvas` opaque au défilement, transition `dur.base`. Aucune translucidité, aucun matériau.
- **Survol d'affiche** : `scale(1.06)` en `dur.fast`. Pas d'ombre, pas de contour, sauf en sélection (contour ambre 2 px, offset 3 px).
- **Défilement horizontal** : signalé uniquement par la carte coupée au bord droit. Ni flèche, ni dégradé, ni pagination.
- **Sélection dans un tableau dense** : `dur.instant`, aucune animation.
- **Ouverture d'une image** : transition `dur.zoom` de l'affiche vers la visionneuse.
- **Opérations destructrices** : confirmation systématique. Aucune annulation après coup n'est prévue dans le design — voir section 10.
- **Contenu privé** : `isPrivate` est porté **par l'entité** — un titre, une personne, une collection, un média. Ce n'est **pas** une propriété du profil.

  > **Corrigé le 2026-08-03 par rapport au handoff livré**, qui écrivait « géré au niveau du profil, pas du titre. Un titre est privé parce qu'il appartient à un profil verrouillé par Face ID ». C'est faux dans notre modèle : un `Title` appartient à une `Library` et jamais à un `Profile`. Ce que le profil porte est `hidesPrivateContent`, un réglage qui décide de l'**affichage**.
  >
  > La conséquence n'est pas théorique. Suivre la formulation d'origine rendrait un titre privé visible dès qu'un profil permissif est ouvert, et — plus grave — **indexable dans Spotlight, dont l'index est unique pour l'appareil** et n'a aucune notion de profil actif. C'est la fuite que `L3` a fermée. Règle et argument dans `docs/04` §6.
  >
  > **Ce que le handoff dit du rendu reste valable** : géométrie exacte de l'affiche, aplat `private.mask`, `eye.slash` sur la vignette masquée. C'est le déclencheur qui était faux, pas l'apparence.

## 8. Icônes — correspondance SF Symbols

Rendu : `.regular` partout, `hierarchical` quand le symbole accompagne du texte, `monochrome` dans les barres. Un seul symbole prend l'ambre : celui de l'élément actif.

| Usage | Symbole | Note |
|---|---|---|
| Accueil | `house` | onglet et barre latérale |
| Titres | `film.stack` | |
| Personnes | `person.2` | jamais `person.crop.circle` |
| Collections | `rectangle.stack` | |
| Galerie | `photo.on.rectangle.angled` | |
| Ma liste | `heart` | plein quand le titre y est |
| Signets | `bookmark` | plein quand marqué |
| Fil | `clock.arrow.circlepath` | journal, pas un flux |
| Recherche | `magnifyingglass` | |
| Ajouter un titre | `plus` | jamais `plus.circle` dans une barre |
| Modifier | `pencil` | |
| Supprimer | `trash` | toujours en `danger` |
| Importer | `square.and.arrow.down` | |
| Exporter | `square.and.arrow.up` | |
| Fusionner | `arrow.triangle.merge` | |
| Recadrer | `crop` | |
| Remplacer l'image | `arrow.2.squarepath` | |
| Trier | `arrow.up.arrow.down` | |
| Filtrer | `line.3.horizontal.decrease` | ambre si un filtre est actif |
| Disposition portrait | `rectangle.portrait` | sélecteur de la matrice |
| Disposition paysage | `rectangle` | sélecteur de la matrice |
| Taille de vignette | `square.grid.2x2` | menu compact/medium/large |
| Note | `star` | plein pour les crans remplis |
| Vu | `checkmark` | jamais `eye` |
| Contenu privé | `eye.slash` | sur la vignette masquée |
| Profil verrouillé | `faceid` | `lock.fill` en secours |
| Réglages | `gearshape` | |
| Profils | `person.crop.circle` | unique usage |
| Hors ligne | `wifi.slash` | bandeau |
| Synchronisation | `arrow.triangle.2.circlepath` | en rotation pendant la tâche |
| Espace disque | `externaldrive` | bandeau de quota |
| Erreur | `exclamationmark.triangle` | jamais en ambre |
| Fermer une surface | `xmark` | dialogues et visionneuse |
| Plus d'actions | `ellipsis` | menu contextuel |
| Navigation avant | `chevron.right` | lignes de liste |
| Plein écran | `arrow.up.left.and.arrow.down.right` | visionneuse |

## 9. Ce que le code reçoit

**Couleur** : un catalogue d'assets Xcode, une entrée par token, quatre variantes par entrée (Any/Dark × Normal/High Contrast). Aucun `Color(hex:)` dans le code applicatif ; le catalogue est le seul point d'entrée, ce qui rend le basculement d'apparence gratuit. `accent` est aussi l'`AccentColor` du projet.

**Le reste** : des constantes statiques, sans injection.

```swift
enum Space { static let s1: CGFloat = 4, s2 = 8, s3 = 12,
  s4 = 16, s5 = 24, s6 = 32, s7 = 48, s8 = 64 }

enum Radius { static let none: CGFloat = 0, xs = 2,
  s = 4, m = 10, l = 14 }

enum Poster {
  case xs, s, m, l, xl, xxl
  var width: CGFloat { ... }
  func size(_ layout: PosterLayout) -> CGSize   // .portrait 2:3 | .landscape 16:9
}

extension Font {
  static let display = Font.custom("BebasNeue-Regular",
    size: 56, relativeTo: .largeTitle)
  static let headline = Font.custom("Archivo-SemiBold",
    size: 15, relativeTo: .headline)
  // …
}

@Environment(\.density) var density   // .dense | .roomy
```

La densité est la seule valeur dynamique, posée une fois par plateforme dans l'environnement.

## 10. Décisions arrêtées et points ouverts

**Arrêté** — ratio 2:3 verrouillé avec recadrage · aucune métadonnée sous les affiches au repos · hero à 100 % · coupe au bord droit comme seul signal de défilement · zéro translucidité d'interface · zéro ombre · densité iPad ample par défaut et dense au pointeur · Dynamic Type suivi sur iOS, fixe sur Mac · ambre foncé `#ab4700` en apparence claire · basculement Bebas → Archivo Narrow à `.accessibilityMedium` · contenu privé **au niveau de l'entité** (corrigé — voir §7) · traits de tableau à 3,0:1 acceptés.

**Ouvert, à trancher avant de coder les écrans concernés :**

1. **Portée de l'apparence claire.** L'accueil et la fiche titre ont été rendus en clair (planche 8, bloc 10k). Verdict du design : ça tient techniquement mais ce n'est plus la même app — les affiches ne flottent plus, le blanc pèse plus que les images, et le hero perd tout son effet. Recommandation : **apparence claire pour les écrans de gestion**, accueil et fiches **forcés en sombre** quelle que soit l'apparence système, comme une visionneuse. L'alternative honnête est l'app sombre uniquement. L'accueil clair tel quel n'est pas recommandé.
2. **Annulation.** Le design prévoit une confirmation avant chaque opération destructrice, mais aucun retour arrière après coup, alors que l'app édite en masse et fusionne. À arbitrer.
3. ~~**États d'erreur de champ.**~~ **Traité** — addendum 1, blocs 11a–11c et 11i, voir section 6.
4. ~~**Écran d'import.**~~ **Traité** — addendum 1, blocs 11d–11g et 11j, voir section 6.
5. **Doublons du multi-sélecteur.** La création de valeur en cours de saisie n'a aucun contrôle de doublon, ce que la fusion doit rattraper ensuite.
6. **Réglages.** L'écran existe pour que la liste soit complète ; il mérite une passe dédiée quand le périmètre réel des options sera connu. Sur Mac, la convention est une fenêtre de réglages à onglets, séparée.

**Traité depuis** : les adaptations iPhone et iPad des quatre écrans qui changent de nature (addendum 2) ; l'icône de l'app (addendum 3).

**Non rendu, accepté comme tel** : l'apparence contraste élevé (valeurs calculées et vérifiées, aucun écran rendu) ; les huit autres écrans de navigation en iPhone et iPad, qui se déduisent des points de rupture et des deux modèles rendus ; iPad et iPhone en paysage.

**Ouvert par les addenda** — quatre valeurs manquent au système de couleur, et je n'en ai inventé aucune (addendum 1, bloc 11h) :

1. **Teinte de remplissage d'état.** Aucun fond coloré léger n'existe et la règle « zéro translucidité sur surface opaque » interdit un `danger` à 12 %. Contournement : le champ garde `bg.fill`, la ligne garde `bg.surface`, l'état passe par le libellé, le trait et le message. Sur une table de 417 lignes fautives, c'est moins repérable qu'un fond teinté.
2. **Couleur d'avertissement.** Le système a `danger` et `success`, sans intermédiaire. Les colonnes non reconnues sont donc rendues en `danger` (elles demandent une décision) et les correspondances déduites en `accent` : deux tokens détournés qu'un `warning` réglerait proprement.
3. **Trait d'état.** `stroke.hairline` n'est défini qu'avec la couleur `separator`. Les champs en erreur utilisent le même trait en couleur `danger` ; le récapitulatif de refus utilise un trait de 2 px, seule entorse à l'épaisseur unique.
4. **Piste de progression.** Aucun token de piste ni de remplissage. La barre 771 / 417 / 96 utilise `bg.fill` en piste et `success`, `danger`, `text.tertiary` en segments.

Décisions ouvertes sur l'icône (addendum 3) : la variante de dessin sous 32 px (gouttière élargie), le fond de l'icône sur écran d'accueil sombre (`bg.canvas` ou `bg.surface`), et le ton assourdi `#c98b45` de la tranche — hors planche 8, volontairement, parce qu'une icône n'est pas une interface et que ce ton n'apparaît nulle part dans l'app.

## 11. Assets

- **Affiches** : images publiques de Wikipédia, utilisées uniquement comme contenu de démonstration. À remplacer par les images de la bibliothèque de l'utilisateur.
- **Images larges de hero** : aucune n'existe. Les prototypes utilisent l'affiche agrandie et floutée. L'app doit consommer un vrai emplacement média paysage recadré par contexte.
- **Portraits de personnes** : aucun. Les fiches personne utilisent une affiche recadrée.
- **Icônes d'interface** : aucune. Voir section 8.
- **Icône de l'app** : `icon/cineshelf-icon.svg`, trois rectangles, aucune courbe. Voir section 13 pour la géométrie et les exports.
- **Polices** : Bebas Neue, Archivo, Archivo Narrow, Public Sans, IBM Plex Mono — toutes sous licence SIL Open Font, à embarquer.

## 12. Fichiers

Les huit planches de validation, dans l'ordre du plan de design. Chaque planche se termine par un relevé écrit des écarts au brief, des décisions prises sans validation explicite et des réserves du designer.

| Fichier | Contenu |
|---|---|
| `CineShelf - Planche 1 - Direction.dc.html` | directions artistiques, palette, typographie, écran d'accueil |
| `CineShelf - Planche 2 - Chrome.dc.html` | chrome macOS, iPadOS, iOS |
| `CineShelf - Planche 3 - Navigation.dc.html` | les douze écrans de navigation |
| `CineShelf - Planche 4 - Galerie.dc.html` | galerie, visionneuse, recadrage, sélection |
| `CineShelf - Planche 5 - Gestion.dc.html` | console, import, export, fusion, profils, réglages |
| `CineShelf - Planche 6 - Formulaires.dc.html` | champs, feuilles, dialogues, menus, panneaux |
| `CineShelf - Planche 7 - Etats.dc.html` | vides, chargement, interruptions, contenu privé |
| `CineShelf - Planche 8 - Tokens.dc.html` | **le système complet** — couleur, typo, espacement, matrice, symboles, plans, ruptures, apparence claire, basculement typographique |
| `CineShelf - Addendum - Erreurs et import.dc.html` | erreurs de champ dans les deux densités, parcours d'import complet, tokens manquants |
| `CineShelf - Addendum 2 - iPhone et iPad.dc.html` | accueil, fiche titre, galerie, console en iPhone et iPad portrait |
| `CineShelf - Addendum 3 - Icone.dc.html` | icône de l'app, toutes les tailles, dock Mac, écran d'accueil iOS |
| `icon/cineshelf-icon.svg` | source de l'icône |
| `support.js` | runtime nécessaire à l'ouverture des fichiers `.dc.html` |
| ~~`brief/06-BRIEF-DESIGN.md`~~ | **retiré** — lire [`../06-BRIEF-DESIGN.md`](../06-BRIEF-DESIGN.md) |
| ~~`brief/03-FONCTIONNALITES-NATIF.md`~~ | **retiré** — lire [`../03-FONCTIONNALITES-NATIF.md`](../03-FONCTIONNALITES-NATIF.md) |

Ouvrir les planches dans un navigateur, `support.js` dans le même dossier. **La planche 8 est le document de référence** : en cas de désaccord entre une planche d'écran et la planche 8, la planche 8 gagne.

## 13. L'icône de l'app

Concept unique, tiré de la direction 2a : une affiche pleine, et la suivante coupée par le bord droit parce qu'il y en a d'autres. C'est la seule signature graphique propre à la direction retenue, et elle dit ce que dit le premier écran de l'app. Aucun texte, aucune courbe, aucune ombre, aucun dégradé, aucun coin arrondi dans le dessin : le masque est appliqué par le système, comme pour les affiches de l'app.

Géométrie, sur une grille de 1024 :

| Élément | Valeur |
|---|---|
| Fond | `#050505` — `bg.canvas` |
| Affiche | x 128 · y 112 · 536 × 800 · ratio 2:3 · `#ffb75f` (`accent`) |
| Tranche | x 744 · y 112 · 280 × 800 · coupée à 1024 · `#c98b45` |
| Gouttière | 80 |

Sur macOS, même dessin en retrait de 10 % dans le carré, selon la grille d'Apple.

Exports attendus dans le catalogue d'assets : 1024 pour l'App Store (sans transparence, sans coin arrondi) ; iPhone 180 · 120 · 87 · 80 · 58 · 60 · 40 · 29 · 20 ; iPad 167 · 152 · 76 · 40 · 29 · 20 et leurs @2x ; macOS 1024 · 512 · 256 · 128 · 64 · 32 · 16 avec @2x pour chaque cran.

Constats de contexte, rendus dans l'addendum 3 : dans le dock macOS l'icône est la plus sombre de la rangée, et c'est ce qui la fait ressortir ; l'ambre n'entre en collision avec aucune icône chaude du dock par défaut. Sur un écran d'accueil iOS clair elle tient son cadre ; sur un fond sombre le noir de l'icône se fond dans le fond et il ne reste que les deux blocs ambres — acceptable, mais ce n'est plus la même image. Remonter le fond à `bg.surface` (#131313) réglerait le cas, avec deux tokens existants ; la décision n'est pas prise.

À 16 px, la gouttière tombe à 1,25 px. Deux options, non tranchées : élargir la gouttière à 112 unités pour les tailles sous 32 px (variante de dessin, pratique courante chez Apple), ou l'accepter telle quelle.
