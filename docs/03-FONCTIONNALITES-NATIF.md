# CineShelf — Fonctionnalités : correspondance web → natif

> **Destinataire : Claude Code.** Remplace `03-FONCTIONNALITES-ET-API.md`. Même inventaire, transposé. Sert de **liste de contrôle** : rien ne doit manquer à l'arrivée.

Légende : ✅ conservé · ♻️ conservé, forme native · 🔀 repensé · ⛔ disparaît (sans perte) · ⏸ reporté · ➕ gagné gratuitement

---

## 1. Comptes & identité

| Web | Natif |
|---|---|
| Inscription / connexion / JWT | ⛔ Compte iCloud de l'appareil |
| `must_change_password`, changement de mot de passe | ⛔ |
| Rôles user/admin, gestion des utilisateurs | ⛔ |
| **Profils liés** (sous-comptes isolés) | ✅ **Profils** façon Netflix — un compte Apple, plusieurs profils |
| **Bascule de profil** | ✅ Sélecteur au lancement + menu dans la barre latérale (`⌃⌘1…9` sur Mac) |
| **Compte bac à sable** + réinitialisation | ✅ Profil sur sa propre bibliothèque + « Vider cette bibliothèque » |
| **Transfert entre profils** (options, aperçu, clôture transitive) | ✅ « Déplacer vers une autre bibliothèque », avec aperçu des dépendances |
| Sessions révocables | ⛔ géré par iCloud |

> ~1 800 lignes d'authentification, de sessions et d'administration disparaissent. Ce qui reste, c'est le **profil** — la partie que tu utilises réellement.

### 1 bis. Profils — le modèle retenu

Deux notions séparées, ce qui couvre les deux usages avec un seul lien :

| | Ce que c'est |
|---|---|
| `Library` | Un **catalogue** : titres, personnes, collections, genres |
| `Profile` | Une **personne qui consulte** : nom, avatar, couleur, ses listes, ses préférences |

- **Plusieurs profils sur la même bibliothèque** → modèle Netflix. Catalogue commun, watchlist / favoris / vus / notes perso séparés.
- **Un profil sur sa propre bibliothèque** → isolation totale (l'ancien bac à sable).

| Fonctionnalité de profil | Détail |
|---|---|
| Sélecteur au lancement | Affiché si > 1 profil, avec option « ouvrir directement le dernier profil » |
| Avatar | SF Symbol ou emoji + couleur d'accent, pas de photo à gérer |
| Listes par profil | `TitleFlag`, `PersonFlag`, `MediaFlag` |
| Préférences d'affichage par profil | Disposition × taille × densité, par contexte |
| Profil verrouillé | `requiresBiometry` — Face ID pour entrer dans ce profil |
| Profil sans contenu privé | `hidesPrivateContent` — le profil « Invité » ne voit jamais les entités `isPrivate` |
| Basculer | Sélecteur, ou `⌃⌘1…9` sur Mac |
| Créer / renommer / supprimer | Supprimer un profil n'efface pas le catalogue, seulement ses listes |

### 1 ter. Sécurité & confidentialité

| Fonctionnalité | Statut |
|---|---|
| **Verrouillage de l'app par Face ID / Touch ID** | ➕ `LocalAuthentication`, avec repli automatique sur le code de l'appareil |
| Délai de grâce (immédiat · 1 · 5 · 15 min) | ➕ sinon le réglage est trop pénible et finit désactivé |
| **Écran de confidentialité** dans le sélecteur d'apps | ➕ masque l'aperçu dès `.inactive` |
| **Verrouillage par profil** | ➕ un profil peut exiger une authentification |
| **Contenu privé flouté** jusqu'au déverrouillage | ♻️ réutilise le flag `isPrivate` déjà présent partout dans le schéma v1 |
| Masquer le contenu privé de Spotlight | ➕ ne pas indexer ce qui est `isPrivate` |
| Touch ID / Apple Watch sur Mac | ➕ même API |

> C'est un **verrou d'interface**, pas du chiffrement — voir `02-… §9.4`. Pour un catalogue personnel c'est largement suffisant : ça empêche quelqu'un qui prend ton téléphone posé sur la table de fouiller dedans.

## 2. Préférences & affichage

| Web | Natif |
|---|---|
| Avatar utilisateur | ⛔ (ou photo du compte iCloud) |
| Disposition `portrait` / `landscape` | ✅ `CardLayout` |
| Taille `compact` / `medium` / `large` | ✅ `CardSize` |
| Préférences indépendantes par contexte (×8) | ✅ `@AppStorage`, par profil **et** par contexte |
| `page_size` | 🔀 disparaît — `LazyVGrid` charge à la demande, pas de pagination |
| Menu d'affichage inline | ♻️ `Menu` dans la barre d'outils |
| Thème | ➕ suit le système, avec forçage clair/sombre optionnel |
| Densité | ➕ **deux crans** — dense / ample, posés une fois par plateforme dans l'environnement. *Corrigé le 2026-08-03 : ce document annonçait trois crans (compacte / standard / confortable), le handoff de design en livre deux, et ce sont des écrans dessinés.* |

## 3. Visibilité

| Web | Natif |
|---|---|
| `is_private` par entité | ✅ `isPrivate` — sert maintenant à masquer d'un partage futur et de Spotlight |
| `is_hidden` | ♻️ `isArchived` |
| « Afficher les cachés » | ✅ bascule dans la barre d'outils |
| « Voir tout » / « Voir seulement les miens » (admin) | ⛔ un seul utilisateur |
| Mode édition d'image | ✅ bascule globale conservée |
| Corbeille / restauration | ➕ `deletedAt` + purge à 30 jours |

## 4. Titres

| Web | Natif |
|---|---|
| CRUD | ✅ |
| Titre, synopsis, sortie + précision, durée, note, collection | ✅ |
| Séries : saisons / épisodes | ♻️ `kind` explicite |
| Filtres : recherche, collection, genre, personne, durée, note | ✅ `#Predicate` composé |
| Tranches de durée pré-réglées | ✅ |
| Tris : ajout, titre, note, sortie, durée × asc/desc | ✅ `SortDescriptor` |
| Pagination serveur | 🔀 `LazyVGrid` + `fetchLimit` progressif |
| Jaquette + jaquette portrait alternative | ✅ `MediaSlot.primary` / `.portrait` |
| Recadrage par contexte | ✅ `MediaCrop` |
| Casting + nom du personnage | ♻️ + `orderIndex` + rôles techniques |
| **Suggestion de casting** | ♻️ calcul local : personnes fréquemment co-créditées, correspondance de nom dans le synopsis |
| Genres multiples | ✅ |
| Galerie + liens attachés | ✅ |
| Navigation précédent/suivant depuis la liste | ✅ + `⌥↑` / `⌥↓` sur Mac |
| Suivi par épisode | ⏸ v2 |

## 5. Personnes

| Web | Natif |
|---|---|
| CRUD acteurs | ✅ `Person` |
| Âge calculé | ✅ (+ date de décès) |
| Filtres par tranche d'âge | ✅ |
| Genres de personne | ✅ |
| Filmographie | ✅ |
| Photo + recadrage liste/détail | ✅ |
| CRUD profils sociaux | 🔀 rôle `.social` sur la même `Person` |
| Lien social ↔ acteur | 🔀 devient natif — l'écran de liaison disparaît |
| **Détection de doublons** | ♻️ local, sur `sortName` + distance de Levenshtein + date de naissance |
| **Fusion d'entités** (aperçu + choix champ par champ) | ♻️ conservée pour les vraies personnes en double |
| Fusion acteur ↔ social | ⛔ sans objet |

> ~2 600 lignes (2 pages, 4 modules serveur × 2 backends, 6 routes) remplacées par un rôle dans un tableau.

## 6. Collections & genres

| Web | Natif |
|---|---|
| CRUD collections + compteur | ✅ |
| Couverture + recadrage carte/hero | ✅ |
| **Couverture générée depuis les films** | ✅ composition locale d'une mosaïque |
| **Rayons** = collections + rayons par genre | ✅ concept conservé, c'est la structure de l'accueil |
| CRUD genres, cibles multiples | ✅ |
| Création de genre à la volée | ✅ |
| Adoption de genre | 🔀 sans objet (plus de propriétaire) — devient « déplacer vers une autre bibliothèque » |
| Épinglage de genre | ✅ genres épinglés dans la barre latérale |
| Couleur de genre | ➕ jeton de couleur, pas un hex libre |

## 7. Médias & galerie

| Web | Natif |
|---|---|
| Upload data-URL → fichier / R2 | ♻️ `PhotosPicker`, `.fileImporter`, glisser-déposer, presse-papiers |
| Service de fichier avec contrôle de visibilité | ⛔ accès direct au store |
| Image / vidéo | ✅ |
| Média principal par entité | ✅ `slot` |
| **Recadrage interactif** (position + zoom) | ✅ `MagnifyGesture` + `DragGesture` |
| Édition inline d'image | ✅ |
| **Galerie globale** + filtre par source | ✅ |
| Masonry | ✅ |
| Lazy loading | ♻️ + blurhash |
| **Lightbox** | ♻️ plein écran natif, zoom, balayage, `.navigationTransition(.zoom)` |
| **Scroll immersif** | ✅ |
| Favoris de galerie | ✅ |
| Mélange | ✅ |
| Stockage R2 | ⛔ CloudKit `CKAsset` |
| Dérivés multi-tailles côté serveur | 🔀 vignettes locales, non synchronisées |
| Déduplication par checksum | ✅ à l'import |
| Détection d'orphelins | ✅ tâche de maintenance |
| Quick Look, partage système, Live Text | ➕ gratuits |

## 8. Liens

| Web | Natif |
|---|---|
| Liens attachés aux entités | ✅ |
| **Signets autonomes** | ✅ |
| **Aperçu de lien** (titre + favicon) | ♻️ `LPMetadataProvider` du framework LinkPresentation — fait exactement ça, avec la vignette en prime |
| Déduction du libellé depuis l'URL | ✅ |
| Blocs de liens sur les fiches | ✅ |
| Extension de partage (« Ajouter à CineShelf » depuis Safari) | ➕ |

## 9. Recherche

| Web | Natif |
|---|---|
| FTS5 sans accents | ♻️ `searchText` replié + prédicat |
| Recherche globale | ✅ étendue à toutes les entités |
| Recherche navbar instantanée | ✅ `.searchable` + `.searchScopes` |
| Résultats groupés | ✅ |
| Recherche dans les sélecteurs | ✅ |
| Recherches récentes / suggestions | ➕ `.searchSuggestions` |
| **Spotlight système** | ➕ CoreSpotlight : trouver un film depuis l'écran d'accueil |

## 10. Import / export

Le morceau le plus lourd de la v1 (~3 100 lignes serveur + 7 dialogues). **Décision : CSV d'abord, XLSX reporté.**

| Web | Natif |
|---|---|
| Export Excel / CSV par entité | ♻️ **CSV** en v1 (`TabularData`) |
| Sélecteur de champs | ✅ |
| Aperçu avant export | ✅ |
| **Export bundle** (données + médias) | ♻️ dossier `.cineshelfarchive` ou ZIP, via `.fileExporter` |
| **Gabarit** vierge | ♻️ CSV modèle |
| Import avec aperçu ligne à ligne | ✅ `Table` éditable |
| **Revalidation** après correction | ✅ |
| **Édition en masse** dans l'aperçu | ✅ |
| Résolution des références | ✅ local |
| Import bundle avec médias | ✅ |
| Import CSV Movix | ✅ profil de mappage dédié |
| **Excel `.xlsx`** | ⏸ **reporté** — voir ci-dessous |
| Import en tâche de fond avec progression | ➕ |

**Sur le XLSX reporté.** En Swift, la lecture est faisable (`CoreXLSX`), l'écriture n'a pas d'équivalent mature. Trois options quand tu y reviendras, par ordre de préférence :

1. **Écrire le XLSX à la main** — un `.xlsx` est un ZIP contenant du XML. Pour des tableaux plats sans mise en forme (ce dont tu as besoin), c'est ~300 lignes avec `ZIPFoundation`. Chemin le plus propre.
2. **Export CSV + ouverture dans Numbers/Excel** — zéro code, couvre 90 % de l'usage réel.
3. Une petite fonction serveur dédiée — mais ça réintroduit un backend que la décision « 100 % natif » écarte.

En attendant, le CSV UTF-8 avec BOM s'ouvre correctement dans Excel et Numbers.

## 11. Accueil, fil, profil

| Web | Natif |
|---|---|
| **Hero** avec sélection de films | ✅ |
| **Sections par genre** | ✅ `ShelfRail` |
| Rangées à défilement horizontal | ✅ |
| Page **Fil** | ♻️ `ActivityEntry` |
| **Profil** : watchlist + favoris | ♻️ écran « Ma liste », alimenté par les flags du profil courant |
| Compteurs de catalogue | ✅ |
| Restauration de scroll | ✅ `.scrollPosition` |
| Filtres dans l'URL | 🔀 état de navigation `@Observable`, restauré au lancement |
| Écran de réveil du serveur | ⛔ plus de serveur |
| Statistiques (genres, décennies, notes) | ➕ Swift Charts, quasi gratuit |

## 12. Gestion de base (ex-« Réglages », 10 onglets)

Les 10 onglets `movies · actors · collections · genres · social · medias · saved-links · links · relations · users` étaient une **console de gestion de données**, pas des préférences. En natif :

- **Mac / iPad** : une fenêtre `Bibliothèque` avec barre latérale d'entités et une `Table` triable, colonnes redimensionnables, sélection multiple, édition inline, `.inspector` pour le détail.
- **iPhone** : onglet Bibliothèque → liste par entité → détail.
- L'onglet `users` disparaît. L'onglet `relations` devient un inspecteur de casting.
- Les vraies préférences vont dans la scène `Settings` (Mac) ou un écran Réglages (iOS).

| Web | Natif |
|---|---|
| Grille de données, colonnes configurables | ✅ `Table` + `TableColumnCustomization` |
| Édition inline | ✅ |
| **Édition en masse** | ✅ sélection multiple + inspecteur |
| Médias / liens en brouillon | ✅ |
| Ouverture en superposition | ♻️ `.inspector` |
| Lien direct vers la base depuis une entité | ✅ `⌥⌘L` |
| Chargement par onglet | ✅ natif |

---

## 13. Ce que le natif apporte en plus, presque gratuitement

À mettre dans la roadmap une fois la v1 stable — ce sont les choses qui feront que l'app *se sent* native :

| Gain | Effort |
|---|---|
| **Hors ligne complet** | inclus |
| **Sync multi-appareils** | inclus |
| Dynamic Type, VoiceOver, contraste élevé | inclus si les composants sont natifs |
| **Spotlight** (CoreSpotlight) | ~½ jour |
| **Handoff** entre Mac et iPhone | ~½ jour |
| **Extension de partage** depuis Safari | ~1 j |
| **Widgets** (prochain à voir, ajouté récemment) | ~2 j |
| **App Intents / Raccourcis / Siri** | ~2 j |
| **Quick Look** sur les médias | inclus |
| **Glisser-déposer** Finder ↔ app | ~1 j |
| **Swift Charts** pour les statistiques | ~1 j |
| Menu bar, raccourcis clavier, services Mac | ~1 j |
| Sauvegarde Time Machine / iCloud | inclus |

---

## 14. Décompte

| | Web (v1) | Natif (v2) |
|---|---:|---:|
| Fonctionnalités inventoriées | ~130 | ~130 |
| Conservées à l'identique ou améliorées | — | ~105 |
| Repensées | — | ~12 |
| Disparues sans perte (comptes, admin, serveur) | — | ~10 |
| Reportées (XLSX, suivi d'épisodes) | — | 2 |
| Gagnées gratuitement (Spotlight, Handoff, Face ID, widgets…) | — | ~20 |
| Lignes de code estimées | ~58 500 | **~15 000 – 20 000** |

La division par trois ne vient pas d'un renoncement : elle vient de la suppression du backend en double (23 000 l.), de l'authentification (1 800 l.), de la fusion acteur/social (2 600 l.), de la virtualisation et de la pagination faites main (~1 200 l.), et du fait qu'une grande partie de l'infrastructure (sync, offline, accessibilité, thèmes) est fournie par la plateforme.
