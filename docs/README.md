# CineShelf — Dossier de refonte native

Refonte de `FELTRINCyril/CineShelf` (app web React + Express, 58 500 lignes) en **app SwiftUI multiplateforme iOS · iPadOS · macOS**, avec SwiftData et CloudKit privé.

**Décisions actées :** l'app web est retirée · CSV d'abord, XLSX reporté · cible unique multiplateforme dès le départ.

## Les 8 documents à utiliser

| Fichier | Contenu | À donner à |
|---|---|---|
| [`00-AUDIT.md`](./00-AUDIT.md) | État des lieux chiffré de l'app web : ce qui doit être reproduit et ce qu'il ne faut pas reproduire | toi |
| [`01-DESIGN-SYSTEM-APPLE.md`](./01-DESIGN-SYSTEM-APPLE.md) | Direction artistique, palette, Dynamic Type, tokens Swift, navigation adaptative, SF Symbols, specs de composants | **Claude Design** |
| [`02-MODELE-SWIFTDATA-CLOUDKIT.md`](./02-MODELE-SWIFTDATA-CLOUDKIT.md) | Contraintes CloudKit, les 17 `@Model` en Swift (dont `Profile` et les flags), recherche sans FTS, migration depuis le web | **Claude Code** |
| [`03-FONCTIONNALITES-NATIF.md`](./03-FONCTIONNALITES-NATIF.md) | Les ~130 fonctionnalités, transposées une par une. Liste de contrôle : rien ne doit manquer | **Claude Code** |
| [`04-ARCHITECTURE-SWIFTUI.md`](./04-ARCHITECTURE-SWIFTUI.md) | Structure du projet, pipeline d'images, sync, tests, distribution, coûts | **Claude Code** |
| [`05-ROADMAP-NATIF.md`](./05-ROADMAP-NATIF.md) | Les 11 lots, critères de sortie, stratégie avant/après l'abonnement | toi |
| ⭐ [`GUIDE-EXECUTION.md`](./GUIDE-EXECUTION.md) | **Par où commencer.** 24 sessions, chacune avec son agent, ses pièces jointes, son prompt à copier tel quel, sa vérification. Plus le `CLAUDE.md` à mettre à la racine du dépôt. | toi |
| `_archive-web/` | Documents de la version web. **4 sont marqués `OBSOLETE-` : ignore-les.** Le seul utile est `REFERENCE-app-web-existante.md`, qui décrit l'app actuelle et sert pendant la migration (phase 7). | référence |

## Les 6 idées qui structurent le tout

1. **Concevoir sous contraintes CloudKit dès le premier jour**, même sans l'abonnement. Pas d'unicité, toutes les relations optionnelles, toute propriété avec une valeur par défaut, `sortName` et `searchText` maintenus à l'écriture. Un test de conformité l'impose.
2. **`actors` + `social_profiles` → une seule entité `Person` avec des rôles.** Supprime ~2 600 lignes de code de fusion et deux écrans.
3. **Profils façon Netflix.** Un seul compte Apple, plusieurs `Profile` (nom, avatar, listes et préférences propres). Un `Profile` pointe vers une `Library` : deux profils sur la même bibliothèque partagent le catalogue et séparent les listes ; un profil sur sa propre bibliothèque est totalement isolé (l'ancien bac à sable). Verrouillage Face ID au niveau de l'app et au niveau du profil.
4. **Ne jamais synchroniser les dérivés d'images.** Original en `CKAsset`, vignettes générées et cachées localement. Le quota iCloud appartient à l'utilisateur.
5. **Natif, pas porté.** `NavigationSplitView`, `Table`, `.inspector`, `Material`, SF Symbols, Dynamic Type. C'est ce qui rend l'app sobre et professionnelle sans effort — et accessible gratuitement.
6. **Le lot 0 avant tout Swift.** Enregistrer le comportement de l'app actuelle et sortir un dump complet des données. Tant que ce n'est pas fait, ne touche à rien.

## Par où commencer

Ouvre [`GUIDE-EXECUTION.md`](./GUIDE-EXECUTION.md) et fais la **partie I** (préparation, `CLAUDE.md`), puis la **phase 0** dans l'ancien dépôt : enregistrer le comportement de l'app web et sortir un dump complet des données. Tant que ce dump n'est pas archivé hors de ton Mac, ne touche pas à Swift.

## Estimation

~130 fonctionnalités conservées, **~15 000 à 20 000 lignes** contre 58 500. La division par trois vient de la suppression du backend en double, de l'authentification, de la fusion acteur/social, et du fait que sync, hors-ligne, accessibilité, thèmes et virtualisation sont fournis par la plateforme.

11 lots, ~47 à 65 jours effectifs. Compter 4 à 6 mois en apprenant Swift en parallèle.
