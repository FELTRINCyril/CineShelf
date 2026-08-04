# `Legacy/` — l'ancienne direction artistique, en sursis

Ce dossier ne contient **rien de vivant**. C'est l'ancienne direction artistique,
celle de `_archive/OBSOLETE-design-system-productivite.md`, gardée le temps que les
tâches `V` réécrivent les écrans.

## Pourquoi il existe encore

L'interface des prompts 10 et 11 sert de **banc d'essai** pour exercer la logique :
on ne la polit plus, mais on ne la supprime pas non plus. Or elle lit des jetons que
la direction courante a supprimés — pas renommés, supprimés : les bordures, les
ombres, la teinte douce d'accent, les proportions 3:2 et 4:5, les statuts `info` et
`warning`.

Les retirer du catalogue d'assets ne casserait pas la compilation. **Ça rendrait du
transparent** — `Color(_:bundle:)` ne signale jamais un jeu absent. C'est
exactement la défaillance silencieuse que `ColorAssetTests` existe pour attraper, et
il n'y avait pas de raison de l'introduire volontairement.

## La règle

**Rien de neuf ne lit ce dossier.** Le code écrit à partir du 2026-08-04 utilise
`ColorTokens`, `Typo`, `Space`, `Radius`, `Stroke`, `Motion`, `Layer`, `Breakpoint`,
`Density`, `PosterScale`, `PosterContext`, `PosterSetting` et `Icon`.

Là où un nom existe des deux côtés, **le nouveau gagne** : les six jeux de couleur
communs (`bg/canvas`, `bg/surface`, `bg/inset`, les trois `text/*`), `Typo.body`,
`Radius.xs`, `Motion.base` et `Motion.sheet` prennent leur valeur courante, y compris
dans le banc d'essai. C'est ce qui fait de la bascule un remplacement et non une
cohabitation — et c'est sans risque, puisque le banc d'essai n'est pas livré.

## Quand ça meurt

**À `V12`**, la passe d'accessibilité sur les écrans définitifs : à ce moment-là plus
aucun écran de `App/` ne descend de l'interface des prompts 10 et 11.

La suppression est un seul geste, et elle doit être faite en bloc :

1. `rm -r Packages/DesignSystem/Sources/DesignSystem/Legacy/`
2. `rm Packages/DesignSystem/Sources/DesignSystem/Resources/colors.legacy.tokens.json`
3. Retirer de `Resources/Fonts/` : `ArchivoSemiExpanded-SemiBold.ttf`,
   `ArchivoSemiExpanded-ExtraBold.ttf`, `Archivo-Bold.ttf` — et les trois cas
   correspondants de `DesignSystemFonts.Face`.
4. Dans `scripts/generate-colors.py` : supprimer la lecture de
   `colors.legacy.tokens.json`, `write_legacy_token_list` et le calcul de `retired`.
5. `python3 scripts/generate-colors.py`, puis `xcodegen generate`.
6. Rendre leurs noms courts à `Icon.ratingStar` et `Icon.watchedMark`, qui ne les ont
   pris que parce que `Icon.rating` et `Icon.watched` désignaient des `SymbolPair`.
7. Retirer la règle `no_legacy_design_system` de `.swiftlint.yml`, devenue sans objet.

Ce qui reste ensuite compile ou ne compile pas : il n'y a pas d'état intermédiaire à
gérer, et c'est la raison pour laquelle tout est dans un seul dossier.

## Ce que ce dossier ne contient pas, et pourquoi

`CardLayout` et `CardSize` **ne sont pas ici**. Ce sont les deux axes de la matrice
`disposition × taille`, que la bascule conserve explicitement : c'est une
fonctionnalité de l'app, persistée par profil et par contexte, pas une décoration.
Elles vivent dans `Poster.swift` et servent aux deux directions.
