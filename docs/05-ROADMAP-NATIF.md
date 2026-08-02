# CineShelf — Feuille de route native

> Remplace `05-ROADMAP.md`. Cible unique multiplateforme, web retiré, CSV d'abord.

**Règle maintenue depuis la v1 :**
> Aucune donnée perdue, aucune fonctionnalité perdue. La liste de contrôle fait foi : `03-FONCTIONNALITES-NATIF.md`.

---

## La stratégie en deux temps

Tu n'as pas encore l'abonnement Apple Developer. Ce n'est **pas** un blocage, à une condition : concevoir dès maintenant sous les contraintes CloudKit.

```
Phase A — sans abonnement          FeatureFlags.cloudKitEnabled = false
  Magasin SwiftData purement local, sur ton Mac et sur ton iPhone via déploiement direct
  (7 jours de validité, à re-signer — acceptable pendant le développement)
  Modèle écrit sous contraintes CloudKit, validé par le test de conformité
  Toute la v1 fonctionnelle peut être construite ici

Phase B — après l'abonnement       FeatureFlags.cloudKitEnabled = true
  Ajout de l'entitlement iCloud + du conteneur
  Premier envoi, TestFlight, notarisation Mac
```

Le test de conformité CloudKit (`04-ARCHITECTURE-SWIFTUI.md` §9) est ce qui rend la bascule sûre. Sans lui, tu découvres les incompatibilités le jour où tu paies.

---

## Les lots

| Lot | Objet | Durée | Phase |
|---|---|---|---|
| **0** | Filet : oracle du comportement actuel + dump des données | 2–3 j | A |
| **1** | Squelette du projet + modèle + test de conformité | 3–4 j | A |
| **2** | DesignSystem : tokens + composants | 5–7 j | A |
| **3** | Navigation adaptative + catalogue (titres) | 6–8 j | A |
| **4** | Médias : import, vignettes, recadrage, galerie | 6–8 j | A |
| **5** | Personnes, collections, genres, liens | 5–7 j | A |
| **6** | Bibliothèque (ex-Réglages) + import/export CSV | 6–8 j | A |
| **7** | Migration des données réelles | 3–4 j | A |
| **8** | Bascule CloudKit + sync | 4–5 j | **B** |
| **9** | Finitions Apple : Spotlight, Handoff, partage, raccourcis | 4–6 j | B |
| **10** | Publication : TestFlight, App Store, Mac | 3–5 j | B |

Total ≈ 47 à 65 jours effectifs. En apprentissage à côté de l'alternance, compter 4 à 6 mois — Swift et SwiftUI sont à apprendre en même temps.

---

### Lot 0 — Filet de sécurité

Avant d'écrire une ligne de Swift.

- [ ] **Enregistrer 5 parcours Playwright contre l'app web actuelle** — ils décrivent le comportement attendu et serviront d'oracle pour les XCUITest
- [ ] Écrire `export-native-bundle.mjs` dans l'app web : dump complet (JSON + originaux des médias résolus depuis data-URL, disque et R2)
- [ ] Lancer le dump, vérifier les compteurs du `manifest.json`
- [ ] **Archiver le dossier hors du Mac** (disque externe + cloud) — c'est ton unique filet
- [ ] Capturer chaque écran de l'app actuelle : la référence visuelle de ce qui doit exister

**Critère de sortie** : tu peux perdre l'app web demain sans perdre une donnée.

---

### Lot 1 — Squelette

- [ ] Projet Xcode, cible unique iOS 18+ / macOS 15+ (à ajuster selon tes appareils)
- [ ] Trois packages locaux : `DesignSystem`, `CineShelfCore`, `MediaKit`
- [ ] Les 17 `@Model` de `02-MODELE-SWIFTDATA-CLOUDKIT.md` (dont `Profile`, `TitleFlag`, `PersonFlag`, `MediaFlag`)
- [ ] `Persistence.makeContainer(cloudKit:)` + `FeatureFlags`
- [ ] **Le test de conformité CloudKit** ← le plus important du lot
- [ ] `VersionedSchema` + `SchemaMigrationPlan` (vide, mais en place)
- [ ] Repositories : `TitleRepository`, `PersonRepository`, `GenreRepository.findOrCreate`, `FlagRepository`
- [ ] `refreshDerived()` sur chaque entité + tests
- [ ] SwiftLint + swift-format + CI (`xcodebuild test`)

**Critère de sortie** : `swift test` vert, y compris le test de conformité, avec un jeu de données factices inséré et relu.

---

### Lot 2 — DesignSystem

Le lot à confier à **Claude Design** avec `01-DESIGN-SYSTEM-APPLE.md`.

- [ ] `Colors.xcassets` : primitives + sémantiques, apparences Any / Dark / High Contrast
- [ ] `Color` typées, règle SwiftLint interdisant les couleurs littérales hors module
- [ ] `Typo` avec `relativeTo:` partout, Archivo embarquée
- [ ] `Space`, `Radius`, `Elevation`, `Motion`, `Ratio`, `CardMetrics`
- [ ] `PosterCard`, `ShelfRail`, `CatalogGrid`, `MediaThumbnail`, `StateView`, `FieldRow`, `FilterBar`, `DisplayMenu`
- [ ] Une app catalogue interne montrant chaque composant × chaque état × clair/sombre × Dynamic Type
- [ ] Tests de snapshot

**Critère de sortie** : la galerie de composants est lisible et correcte de `xSmall` à `AX5`, en clair et en sombre, et aucune couleur littérale n'existe hors du module.

---

### Lot 3 — Navigation & titres

- [ ] `RootView` adaptative : `TabView` compact / `NavigationSplitView` regular
- [ ] Sélecteur de profil au lancement + bascule (`⌃⌘1…9`)
- [ ] Barre latérale : sections + genres épinglés + menu de profil
- [ ] Accueil : hero + `ShelfRail` par genre
- [ ] Liste de titres : grille, tri, filtres, bascule affichage
- [ ] Fiche titre : hero, jaquette, métadonnées, casting, galerie, liens
- [ ] Éditeur de titre (feuille sur iOS, `.inspector` sur Mac/iPad)
- [ ] Navigation précédent/suivant respectant les filtres
- [ ] `.searchable` + résultats groupés
- [ ] Commandes Mac : `⌘N`, `⌘F`, `⌥⌘I`

**Critère de sortie** : le parcours 1 des XCUITest passe sur iPhone, iPad et Mac.

---

### Lot 4 — Médias

- [ ] Import : `PhotosPicker`, `.fileImporter`, glisser-déposer, presse-papiers
- [ ] Pipeline d'import : redimension 2 000 px, HEIC 0.8, sha256, blurhash, dimensions
- [ ] `ThumbnailCache` (acteur, cache disque + mémoire, purge)
- [ ] `MediaThumbnail` : blurhash → cache → générée, sans saut de mise en page
- [ ] `CropEditor` : pincement + glissement, aperçu par contexte
- [ ] Galerie masonry + filtre par source + mélange + favoris
- [ ] Visionneuse plein écran : zoom, balayage, partage, `.navigationTransition(.zoom)`
- [ ] Scroll immersif
- [ ] Déduplication à l'import sur checksum

**Critère de sortie** : défilement d'une grille de 2 000 jaquettes à fréquence pleine, < 250 Mo, mesuré avec Instruments sur un appareil réel.

---

### Lot 5 — Personnes, collections, genres, liens

- [ ] Personnes : liste, fiche, rôles, comptes sociaux, filmographie, tranches d'âge
- [ ] Détection de doublons locale + écran de fusion champ par champ
- [ ] Collections : liste, fiche, couverture générée depuis les titres
- [ ] Genres : CRUD, création à la volée, épinglage, cibles multiples
- [ ] Liens attachés + signets autonomes
- [ ] Aperçu de lien via `LPMetadataProvider`
- [ ] Ma liste : watchlist + favoris
- [ ] Fil d'activité

**Critère de sortie** : les 105 fonctionnalités « conservées » de la liste de contrôle sont cochées, sauf celles du lot 6.

---

### Lot 6 — Bibliothèque & transfert

- [ ] Fenêtre / onglet Bibliothèque : `Table` par entité, colonnes triables et personnalisables
- [ ] Sélection multiple + édition en masse via inspecteur
- [ ] Édition inline
- [ ] Gestion des profils : créer, renommer, avatar, couleur, supprimer
- [ ] Gestion des bibliothèques : créer, renommer, vider, rattacher un profil
- [ ] **Verrouillage** : Face ID app + par profil, délai de grâce, écran de confidentialité, contenu privé flouté
- [ ] Transfert d'entités entre bibliothèques, avec aperçu des dépendances
- [ ] Export CSV par entité + sélecteur de champs + aperçu
- [ ] Import CSV : aperçu en `Table` éditable, statut par ligne, revalidation, application par lots
- [ ] Profil de mappage « Movix »
- [ ] Archive complète `.cineshelfarchive` (export + import)
- [ ] Scène `Settings` : préférences réelles (dont verrouillage), séparées de la gestion de données

**Critère de sortie** : les parcours 3, 4 et 5 des XCUITest passent, et deux profils sur la même bibliothèque ont bien des watchlists distinctes.

---

### Lot 7 — Migration des données réelles

- [ ] Importeur du bundle web, dans un `ModelActor`, par lots, avec progression et reprise
- [ ] Fusion acteur ↔ profil social pendant l'import (étape 5 de `02-… §7`)
- [ ] Les 21 colonnes de recadrage → `MediaCrop`
- [ ] Les 8 assertions de vérification
- [ ] Comparaison champ à champ sur 50 titres échantillonnés
- [ ] Réindexation Spotlight

**Critère de sortie** : ton vrai catalogue est dans l'app native, en local, et tu peux l'utiliser une journée sans rien remarquer d'absent. **C'est ici que l'app web peut être éteinte.**

---

### Lot 8 — CloudKit ⟶ phase B

- [ ] Abonnement Apple Developer souscrit
- [ ] Conteneur iCloud créé, entitlement ajouté, `cloudKitEnabled = true`
- [ ] Premier envoi complet, en Wi-Fi, avec progression
- [ ] `SyncStatusBadge` + les 6 cas d'erreur explicites
- [ ] Test sur un second appareil : réception complète, cohérence
- [ ] Test hors ligne : modification sur deux appareils, reconvergence
- [ ] Passe de fusion des doublons de genres au démarrage
- [ ] Affichage de l'espace iCloud occupé par CineShelf
- [ ] Corbeille + purge à 30 jours

**Critère de sortie** : une modification faite sur le Mac apparaît sur l'iPhone en moins d'une minute ; une modification faite hors ligne survit à la reconnexion.

---

### Lot 9 — Finitions Apple

- [ ] CoreSpotlight : titres, personnes, collections, avec vignette et ouverture directe
- [ ] Handoff Mac ↔ iPhone (`NSUserActivity`)
- [ ] Extension de partage « Ajouter à CineShelf » depuis Safari
- [ ] App Intents : « Ajouter un film », « Chercher dans CineShelf »
- [ ] Statistiques en Swift Charts (genres, décennies, notes, durée totale)
- [ ] Widget « Prochain à voir »
- [ ] Audit d'accessibilité complet : VoiceOver, Dynamic Type AX5, contraste élevé, Reduce Motion, navigation clavier Mac
- [ ] Localisation (au minimum fr, éventuellement en)
- [ ] Icône d'app et écran de lancement

---

### Lot 10 — Publication

- [ ] TestFlight iOS + macOS
- [ ] Fiche App Store : captures pour chaque taille, description, mots-clés
- [ ] Étiquettes de confidentialité (simple : les données ne quittent pas iCloud)
- [ ] Notarisation de l'app Mac si distribution hors store
- [ ] Sauvegarde : documenter comment l'utilisateur exporte son archive
- [ ] README, ADR, journal des versions

---

## Ordre de travail avec les agents

### 1️⃣ Claude Design — lot 2

Prompt, avec `01-DESIGN-SYSTEM-APPLE.md` :

> Voici le design system de CineShelf, une app SwiftUI multiplateforme (iOS, iPadOS, macOS) de catalogue personnel de films. Le document contient la direction artistique, tous les tokens et les specs de composants — suis-le exactement, ne réinvente ni la palette ni les rôles typographiques.
>
> Produis un package Swift `DesignSystem` contenant :
> 1. `Colors.xcassets` avec les primitives et les sémantiques, en apparences Any / Dark / High Contrast, en Display P3.
> 2. Les extensions `Color` typées et la règle SwiftLint interdisant les couleurs littérales hors du module.
> 3. `Typo`, `Space`, `Radius`, `Elevation`, `Motion`, `Ratio`, `CardMetrics`.
> 4. Les composants de la partie D, en priorité `PosterCard` et `ShelfRail` (l'élément signature, partie A.4).
> 5. Une app catalogue montrant chaque composant dans chaque état, en clair et en sombre.
>
> Contraintes absolues : **Dynamic Type partout** (`relativeTo:`, jamais de taille fixe), `.rect(cornerRadius:style:.continuous)`, matériaux plutôt qu'ombres pour les surfaces superposées, `accessibilityReduceMotion` respecté, cibles ≥ 44 pt, bascule en liste au-delà de `.accessibility1`. C'est une app Apple, pas un site porté : SF Symbols, contrôles natifs, métriques système.

### 2️⃣ Claude Code — lots 1, 3 à 7

Prompt de démarrage, avec `02-MODELE-SWIFTDATA-CLOUDKIT.md`, `03-FONCTIONNALITES-NATIF.md`, `04-ARCHITECTURE-SWIFTUI.md` :

> Je reconstruis CineShelf (catalogue personnel de films et séries, aujourd'hui une app web React + Express de 58 000 lignes) en app SwiftUI multiplateforme iOS/iPadOS/macOS, avec SwiftData et CloudKit privé. L'app web est retirée : il n'y a plus de backend.
>
> Ces trois documents décrivent le modèle, l'inventaire fonctionnel complet (~130 items, qui fait office de contrat : rien ne doit manquer) et l'architecture.
>
> Commence par le lot 1 : le squelette, les 13 `@Model`, et surtout **le test de conformité CloudKit** — il doit exister et passer avant toute autre chose, parce que je n'ai pas encore l'abonnement Apple Developer et que je développerai en local (`cloudKitEnabled = false`) jusqu'au lot 8.
>
> Contraintes non négociables du modèle : toute propriété a une valeur par défaut ou est optionnelle, aucune contrainte d'unicité, toutes les relations sont optionnelles avec inverse déclaré, pas de règle de suppression `.deny`, `sortName` et `searchText` sont maintenus à l'écriture par `refreshDerived()`.
>
> Après chaque lot, coche les fonctionnalités correspondantes dans l'inventaire et lance les tests.

---

## Ce que je changerais si tu veux aller plus vite

Si 5 mois te paraît long, trois arbitrages possibles — dans cet ordre de préférence :

1. **iPhone d'abord, Mac ensuite.** Tu gardes la cible unique, mais tu ne soignes la disposition `regular` qu'au lot 9. Gain : ~1 mois. Coût : la fenêtre Bibliothèque du Mac (le remplaçant de tes 10 onglets de réglages) arrive tard.
2. **Reporter la galerie immersive et le mélange.** Ce sont les fonctionnalités les plus coûteuses par rapport à leur usage. Gain : ~1 semaine.
3. **Reporter la fusion et la détection de doublons.** Utile, mais pas au quotidien, et l'import corrige déjà l'essentiel en fusionnant acteurs et profils sociaux. Gain : ~1 semaine.

Je ne recommande pas de couper dans le lot 0 ni dans le lot 2. Le premier est ce qui garantit que tu ne perds rien ; le second est exactement ce que tu as demandé au départ — un design homogène, sobre et pilotable par tokens.
