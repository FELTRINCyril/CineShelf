# CineShelf — Brief de design

> **Remplace `01-DESIGN-SYSTEM-APPLE.md`**, qui spécifiait le mauvais registre.
> Ce document est un **brief**, pas une spécification. Il dit ce qui doit être vrai, pas à quoi ça doit ressembler. La direction artistique et les tokens sont à produire par Claude Design, **déduits des écrans** et non décidés avant eux.

---

## 1. Le produit

CineShelf est le **catalogue personnel** d'une collection de films, séries, personnes, collections et images. Son propriétaire y range, annote, recadre, importe et fait grossir sa collection depuis des années. C'est privé, hors ligne, synchronisé sur ses appareils.

Deux usages, qui n'ont pas la même nature :

**Parcourir** — ouvrir l'app le soir, voir sa collection, chercher quoi regarder, se rappeler d'un film, redécouvrir une affiche. C'est du plaisir. L'image règne.

**Gérer** — corriger 40 titres importés, réassigner des genres, fusionner deux fiches en double, éditer en masse. C'est du travail. L'efficacité règne.

Une app qui traite les deux de la même façon échoue aux deux.

---

## 2. Le registre : média, pas bureautique

### Classe de référence

**app TV d'Apple, Apple Music, Plex, Infuse, Netflix, Letterboxd.**

Ce qu'elles ont en commun, et qui doit être vrai ici :

- L'œuvre est bord à bord, jamais dans un cadre.
- Le chrome est minimal, souvent translucide, parfois absent.
- Le sombre est le défaut, pas une option.
- La navigation se fait par rails horizontaux et grilles, pas par arborescence.
- La typographie est ample là où elle compte, et disparaît partout ailleurs.
- L'entrée dans une fiche est une transition, pas un changement de page.

### Anti-références, à ne pas reproduire

- **Finder, Mail, Notes, Numbers** — le registre que j'avais spécifié à tort.
- Toute interface où l'on voit un fond blanc de `List`, un `Form` système, un `.inspector` par défaut.
- Un site web porté : barre de navigation horizontale, boutons rectangulaires, cartes à ombre portée.
- Une app de streaming *commerciale* : pas de carrousels promotionnels, pas de « recommandé pour vous », pas d'appels à l'action. Ce n'est pas un catalogue de vente, c'est une collection privée.

### Ce que le natif Apple apporte quand même

Le langage média n'autorise pas à jeter la plateforme. Restent obligatoires : Dynamic Type, VoiceOver, Reduce Motion, contraste élevé, gestes système, menus contextuels, raccourcis clavier sur Mac, transitions `.navigationTransition(.zoom)`, SF Symbols pour les icônes fonctionnelles.

L'app TV d'Apple fait tout ça. C'est la preuve que « immersif » et « accessible » ne s'opposent pas.

---

## 3. Le partage assumé

| | Surfaces de navigation | Surfaces de gestion |
|---|---|---|
| **Écrans** | Accueil, Titres, Personnes, Collections, Galerie, Recherche, Fiches détail, Ma liste, Fil | Console de gestion (10 entités), édition en masse, import/export, fusion, réglages, profils |
| **Registre** | Média : immersif, image bord à bord, chrome minimal | Productivité : dense, tabulaire, efficace |
| **Densité** | Généreuse, l'image respire | Maximale, beaucoup de lignes visibles |
| **Couleur** | Vient du contenu | Vient de l'interface, neutre |
| **Référence** | app TV, Plex | Numbers, l'inspecteur de Xcode |

Les deux registres partagent **les mêmes tokens** — même palette, même typographie, même échelle. Ce qui change, c'est la densité, la place de l'image et la quantité de chrome. C'est ce partage qui empêche l'app de paraître schizophrène.

---

## 4. Contraintes non négociables

### Plateforme
- Cible unique multiplateforme : **iOS · iPadOS · macOS**, iOS 18+ / macOS 15+.
- Trois formats à couvrir pour chaque écran : iPhone (compact), iPad (regular), Mac (fenêtre redimensionnable, de 900 px à 6K).
- Sur Mac : survol, menus contextuels, raccourcis clavier, glisser-déposer avec le Finder.

### Accessibilité
- **Dynamic Type de `xSmall` à `AX5`**, sans troncature. Au-delà de `.accessibility1`, les grilles basculent en liste.
- Contraste **AA** : 4,5:1 pour le texte, 3:1 pour les composants — dans les trois apparences (clair, sombre, contraste élevé).
- VoiceOver : chaque carte annonce titre, année, état. Chaque action a un libellé.
- `Reduce Motion` et `Reduce Transparency` respectés — ce dernier compte double dans un design qui utilise des voiles.
- Cibles tactiles ≥ 44 pt.
- **Un thème clair doit exister.** Même si le sombre est le défaut et l'usage principal.

### Technique
- Aucune couleur littérale hors du package DesignSystem. Aucune taille de police fixe : `relativeTo:` partout.
- Les couleurs vivent dans un Asset Catalog, avec les 4 apparences. Générées depuis un JSON source unique.
- Les composants ne connaissent pas le modèle métier : ils prennent des **modèles de présentation** définis dans le DesignSystem.
- Zéro dépendance externe.
- Les images sont chargées par une closure asynchrone fournie par la couche appelante, avec placeholder `blurhash` et ratio réservé. **Zéro saut de mise en page.**
- Défilement à fréquence pleine sur 2 000 jaquettes, sous 250 Mo.

### Fonctionnel
`03-FONCTIONNALITES-NATIF.md` reste le contrat : **~130 fonctionnalités, rien ne doit manquer.** Notamment ces trois-là, qui contraignent le design :

1. **Matrice `layout × size`** : `portrait | landscape` × `compact | medium | large`, réglable indépendamment sur 8 contextes. Ce n'est pas un caprice esthétique, c'est une fonctionnalité existante.
2. **Recadrage par contexte** : une même image a un cadrage différent en carte, en hero, en latéral. Le design doit rendre ça manipulable.
3. **États de visibilité** : privé, archivé, corbeille. Ils doivent se lire sur une carte sans l'alourdir.

---

## 5. Ce qui doit être conçu — de A à Z

### 5.1 Chrome
- Navigation compacte (iPhone) et régulière (iPad, Mac)
- En-têtes d'écran, comportement au défilement
- Barres d'outils : tri, filtres, affichage, actions
- Barre de recherche et ses portées
- Sélecteur de profil et bascule
- Indicateur de synchronisation
- Barre de menus et raccourcis Mac

### 5.2 Écrans de navigation
1. Accueil — hero + rails par genre
2. Titres — grille, filtres, tri, bascule d'affichage
3. Fiche titre — hero, affiche, métadonnées, casting, galerie, liens
4. Personnes — grille
5. Fiche personne — portrait, biographie, filmographie, comptes sociaux
6. Collections — grille
7. Fiche collection — couverture, titres
8. Galerie — masonry, sources, mélange
9. Recherche — résultats groupés, suggestions
10. Signets
11. Ma liste — watchlist, favoris, vus
12. Fil d'activité

### 5.3 Écrans de gestion
13. Console de gestion — tableau par entité, colonnes, tri, sélection multiple
14. Édition en masse
15. Import — choix de fichier, aperçu ligne à ligne avec statuts, correction, revalidation, progression
16. Export — choix de champs, aperçu
17. Fusion d'entités — comparaison, choix champ par champ
18. Profils et bibliothèques
19. Réglages — dont verrouillage biométrique

### 5.4 Galerie, en détail
Masonry et ses colonnes selon la largeur · la matrice complète `portrait | landscape` × `compact | medium | large` rendue pour de vrai · visionneuse plein écran (zoom, balayage, partage) · défilement immersif · éditeur de recadrage · sélection multiple.

### 5.5 Formulaires
Champ texte, zone de texte, nombre, date à précision variable (année seule / mois / jour), note, sélecteur simple, sélecteur multiple avec création à la volée, interrupteur, sélecteur de couleur de profil · libellés, aide, validation, erreurs · groupes et sections · formulaire dense (gestion) et formulaire aéré (édition rapide).

### 5.6 Surfaces superposées
Feuille (avec ses paliers), popover, dialogue, confirmation destructive, menu contextuel, menu de barre d'outils, notification temporaire, visionneuse plein écran, panneau latéral d'édition.

### 5.7 États
Vide (par écran, avec son action) · chargement (squelettes à la géométrie finale) · erreur · hors ligne · synchronisation en cours · quota iCloud dépassé · verrouillé par biométrie · contenu privé masqué.

### 5.8 Composants
Carte affiche (6 variantes de la matrice) · carte paysage · carte personne · carte collection · vignette galerie · rail horizontal · grille · ligne de tableau · jeton de filtre · badge d'état · barre de notation · indicateur de progression · avatar de profil · pastille de compteur.

### 5.9 Identité
Icône d'app (toutes tailles iOS et macOS) · écran de lancement · un élément signature qui rende l'app reconnaissable en une capture d'écran.

---

## 6. Méthode de travail

C'est là que la première tentative a échoué : 2 120 lignes de Swift livrées avant que quiconque ait pu voir à quoi ça ressemblait.

**Règle : rendus visuels d'abord, Swift seulement après validation.**

| Étape | Livrable | Validation |
|---|---|---|
| 1 | 3 directions + l'écran de liste rendu pour chacune | choix d'une direction |
| 2 | Le chrome, rendu sur les 3 formats | validation |
| 3 | Les 12 écrans de navigation | validation écran par écran |
| 4 | La galerie et sa matrice | validation |
| 5 | Les 7 écrans de gestion | validation |
| 6 | Formulaires et surfaces superposées | validation |
| 7 | Les états | validation |
| 8 | **Les tokens, déduits de tout ce qui précède** | validation |
| 9 | Le code SwiftUI du DesignSystem | intégration |
| 10 | L'icône | — |

Les tokens arrivent en **étape 8**, pas en étape 1. C'est l'inversion qui change tout : une palette décidée dans le vide ne survit pas au premier écran réel.

---

## 7. Critère de réussite

Une seule question, à poser sur chaque écran :

> **Est-ce que ça ressemble à une app qu'on a envie d'ouvrir le soir pour regarder sa collection ?**

Si la réponse est « ça ressemble à un logiciel de gestion de base de données », l'écran est raté — sauf s'il fait partie des surfaces de gestion, où c'est précisément le but.
