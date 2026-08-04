# CineShelf — état du dossier `docs/`

App SwiftUI multiplateforme iOS · iPadOS · macOS, SwiftData + CloudKit privé, aucun
backend. Réécriture native d'une app web React + Express retirée.

**Décisions actées :** l'app web est retirée · CSV d'abord, XLSX reporté · cible
unique multiplateforme dès le départ · **la direction artistique est en refonte
complète** (voir `06-BRIEF-DESIGN.md`).

## Documents actifs

| Fichier | Contenu | Statut |
|---|---|---|
| [`00-AUDIT.md`](./00-AUDIT.md) | État des lieux chiffré de l'app web : ce qu'il faut reproduire, ce qu'il ne faut pas reproduire | référence, figé |
| [`02-MODELE-SWIFTDATA-CLOUDKIT.md`](./02-MODELE-SWIFTDATA-CLOUDKIT.md) | Contraintes CloudKit, les 17 `@Model`, recherche sans FTS, verrouillage biométrique, migration depuis le web | **fait foi**, amendé au fil des sessions |
| [`03-FONCTIONNALITES-NATIF.md`](./03-FONCTIONNALITES-NATIF.md) | Les ~130 fonctionnalités transposées une par une. Le contrat : rien ne doit manquer | **fait foi** |
| [`04-ARCHITECTURE-SWIFTUI.md`](./04-ARCHITECTURE-SWIFTUI.md) | Structure du projet, couche d'accès, pipeline médias, budgets de perf, tests | **fait foi**, amendé au fil des sessions |
| [`06-BRIEF-DESIGN.md`](./06-BRIEF-DESIGN.md) | Le brief de design : registre média, écrans à concevoir, méthode « rendus d'abord, Swift après ». C'est un **brief**, pas une spécification : les tokens seront déduits des écrans | actif, remplace l'ancien `01` |
| [`PROMPTS.md`](./PROMPTS.md) | Le plan et **le seul suivi d'avancement** : tâches LOGIQUE (L1, L2...), tâches VUES, tableau d'état avec hash de commit, écarts connus | actif |
| [`journal.md`](./journal.md) | Une entrée par session : ce qui a été fait, ce qui a été mesuré, ce qui a été décidé | actif |

## Documents archivés — `_archive/`

Aucun ne sert de référence pour du travail neuf. Chacun porte un bandeau qui dit
pourquoi il est là et ce qui l'a remplacé.

| Fichier | Pourquoi |
|---|---|
| `OBSOLETE-design-system-productivite.md` | ex-`01-DESIGN-SYSTEM-APPLE.md`. Mauvais registre : app de bureautique Apple au lieu d'app média. Remplacé par `06-BRIEF-DESIGN.md` |
| `OBSOLETE-roadmap-natif.md` | ex-`05-ROADMAP-NATIF.md`. Les 11 lots sont remplacés par le tableau d'état de `PROMPTS.md` |
| `OBSOLETE-guide-execution.md` | ex-`GUIDE-EXECUTION.md`. Les 24 sessions sont remplacées par le tableau d'état de `PROMPTS.md` |
| `SETUP.md` | Le prompt d'installation. Exécuté au prompt 4 (`03fff62`), plus à rejouer |

## Les idées qui structurent le tout

1. **Concevoir sous contraintes CloudKit dès le premier jour**, même sans
   l'abonnement : pas d'unicité, toutes les relations optionnelles, toute propriété
   avec une valeur par défaut, `sortName` et `searchText` maintenus à l'écriture.
   `CloudKitConformanceTests` l'impose.
2. **`actors` + `social_profiles` → une seule entité `Person`** avec des rôles.
   Supprime ~2 600 lignes de code de fusion et deux écrans.
3. **Profils façon Netflix.** Un compte Apple, plusieurs `Profile` (nom, avatar,
   listes et préférences propres), chacun rattaché à une `Library`. Deux profils sur
   la même bibliothèque partagent le catalogue et séparent les listes ; un profil sur
   sa propre bibliothèque est isolé (l'ancien bac à sable).
4. **Ne jamais synchroniser les dérivés d'images.** Original en `CKAsset`, vignettes
   générées et cachées localement : le quota iCloud appartient à l'utilisateur.
5. **La logique avant les vues.** Chaque tâche restante est coupée en deux : une part
   LOGIQUE testable et insensible au design, une part VUES à écrire une seule fois,
   contre le design final. Découpage dans `PROMPTS.md`.
6. **Média, pas bureautique.** Le voisinage est l'app TV d'Apple, Plex, Infuse — pas
   Finder ni Numbers. Sauf pour les surfaces de gestion, où c'est l'inverse et où
   c'est assumé (`06-BRIEF-DESIGN.md` §3).

## Où en est le projet

Voir le tableau d'état de [`PROMPTS.md`](./PROMPTS.md) — c'est le **seul** endroit
où l'avancement se suit. Ne rien cocher dans `03-FONCTIONNALITES-NATIF.md` : ses
symboles décrivent l'intention retenue pour chaque fonctionnalité, pas l'avancement.

## Estimation

~130 fonctionnalités conservées, **~15 000 à 20 000 lignes** contre 58 500. La
division par trois vient de la suppression du backend en double, de
l'authentification, de la fusion acteur/social, et du fait que sync, hors-ligne,
accessibilité, thèmes et virtualisation sont fournis par la plateforme.

---

## Les livraisons de design s'extraient, elles ne s'ajoutent pas

Le paquet de design vit dans [`design/`](./design/), **en fichiers**, pas en archive.

La première livraison est arrivée en `.zip` et a été extraite le 2026-08-03 ; l'archive
a été retirée du dépôt. Les suivantes suivent le même chemin, pour trois raisons :

- un binaire ne se **diffe** pas — on ne voit ni ce qui a changé d'une livraison à
  l'autre, ni ce qu'une correction a touché ;
- chaque archive resterait dans l'historique **pour toujours**, à 400 Ko pièce ;
- le `README.md` du paquet **est la spécification** : il doit rester lisible,
  cherchable, et corrigeable sur place. Il l'a déjà été — voir l'encadré en tête du
  fichier.

**Ce qui se retire à l'extraction** : les copies de documents que `docs/` porte déjà.
Le paquet embarquait `03-FONCTIONNALITES-NATIF.md` et `06-BRIEF-DESIGN.md` ; elles
étaient identiques aux nôtres au moment de la livraison et auraient cessé de l'être au
premier changement. Une seconde source de vérité ne se surveille pas, elle s'élimine :
les renvois pointent vers `docs/`.

**Ce qui se corrige sur place** : ce qui contredit le modèle. Les corrections sont
signalées à l'endroit où elles portent, avec la raison — pas silencieusement.
