# Journal de bord

Une entrée par session de travail : ce qui a été fait, ce qui reste ouvert.

---

## 2026-08-02 — Initialisation du projet

**Fait**

- Squelette complet : `App/` (11 sections dans `Features/`, navigation compacte
  et large), `Packages/`, `Tests/`, `docs/`.
- Trois packages locaux SwiftPM, iOS 18 / macOS 15, Swift 6 language mode :
  `CineShelfCore` (sans SwiftUI), `DesignSystem` (avec `resources:`),
  `MediaKit` (dépend de Core). Un test qui passe dans chacun.
- `project.yml` XcodeGen : cible multiplateforme unique via
  `supportedDestinations: [iOS, macOS]`, `SWIFT_VERSION = 6.0`,
  `SWIFT_STRICT_CONCURRENCY = complete`, `DEVELOPMENT_TEAM` vide.
  `*.xcodeproj` gitignoré.
- `Info.plist` (fr, Face ID, photothèque, `UIAppFonts` d'Archivo en commentaire).
  Entitlements CloudKit isolées dans `CineShelf-CloudKit.entitlements`, non
  référencé : le projet compile sans abonnement Apple Developer.
- `CLAUDE.md`, `.swiftlint.yml` strict avec `no_literal_color` et
  `no_fixed_font_size`, `.swift-format`, CI GitHub Actions limitée aux PR et à
  `main`.

**Vérifications, toutes vertes**

| Contrôle | Résultat |
|---|---|
| Build iOS Simulator (iPhone 17) | `** BUILD SUCCEEDED **` |
| Build macOS | `** BUILD SUCCEEDED **` |
| `xcodebuild test -scheme CineShelf` (iOS et macOS) | 2 tests |
| `xcodebuild test -scheme CineShelfUITests` (iOS) | 1 test |
| `swift test` × 3 packages | 5 tests |
| `swiftlint --strict` | 0 violation / 29 fichiers |
| `swift-format lint` | 0 avertissement |

Les règles `no_literal_color` et `no_fixed_font_size` ont été vérifiées sur un
fichier sonde : elles lèvent bien une erreur dans `App/` et restent muettes dans
`Packages/DesignSystem/`.

**Contexte machine**

Xcode 26.6 (Swift 6.3.3), XcodeGen 2.46, SwiftLint 0.65, swift-format 603.
Le simulateur de référence est un iPhone 17. La plateforme iOS a dû être
téléchargée séparément (`xcodebuild -downloadPlatform iOS`) : Xcode 26 ne
l'embarque plus.

**Écarts assumés par rapport à `docs/SETUP.md`**

1. Les tests unitaires des packages sont dans `Packages/<Nom>/Tests/` et non
   sous `Tests/`, comme SwiftPM l'impose. `Tests/` contient `CineShelfTests`
   (logique, sans app hôte) et `CineShelfUITests`.
2. Deux schémas au lieu d'un. Sur macOS, XCUITest réclame l'autorisation
   d'accessibilité : la seule présence de la cible UI dans le schéma principal
   bloquait `xcodebuild test`. Le schéma `CineShelf` porte donc l'app et les
   tests de logique (iOS + macOS), le schéma `CineShelfUITests` les tests
   d'interface (simulateur iOS).

**Suite**

Prompt 5 de `docs/PROMPTS.md` — le modèle de données SwiftData.

---

## 2026-08-02 — Modèle de données SwiftData (prompt 5)

**Fait**

- Les 17 `@Model` de `docs/02` §3 dans `CineShelfCore/Models/`, un fichier par
  entité, plus les 9 énumérations de §3.1 persistées en `rawValue`.
- Chaque `rawValue` a sa propriété calculée : `Title.kind`,
  `Title.releasePrecision`, `Person.roles`, `Genre.target`, `Credit.role`,
  `MediaAsset.kind`, `MediaAttachment.slot`, `MediaCrop.context`,
  `SavedLink.kind`.
- `refreshDerived()` sur `Title`, `Person`, `TitleCollection`, `SavedLink` et
  `Genre` (`nameKey` est un dérivé de la même nature que `sortName`).
- `Persistence/` : `CineShelfSchemaV1: VersionedSchema` (1.0.0),
  `CineShelfMigrationPlan: SchemaMigrationPlan` aux étapes vides,
  `Persistence.makeContainer(cloudKit:inMemory:)`.
- `Repositories/FlagRepository.swift` — le code de §3.2 ter, requis par les
  tests de ce prompt. Le reste de la couche d'accès reste au prompt 6.

**Vérifications, toutes vertes**

| Contrôle | Résultat |
|---|---|
| Build iOS Simulator (iPhone 17) | `** BUILD SUCCEEDED **` |
| Build macOS | `** BUILD SUCCEEDED **` |
| `xcodebuild test -scheme CineShelf` (macOS puis iOS) | 8 tests |
| `xcodebuild test -scheme CineShelfUITests` (iOS) | 1 test |
| `swift test` × 3 packages | 31 tests (28 pour Core) |
| `swiftlint --strict` | 0 violation / 53 fichiers |
| `swift-format lint` | 0 avertissement |

**Le test de conformité CloudKit a déjà servi**

`ResourceLink.collection` existe dans `docs/02` §3.8 mais `TitleCollection`
§3.5 ne déclare pas le `links` correspondant : relation sans inverse, schéma
refusé par le miroir. `CloudKitConformanceTests` l'a attrapé au premier
lancement. J'ai ajouté le côté manquant, symétrique de `Title.links` et
`Person.links`. **`docs/02` §3.5 est à corriger.**

Autres tests de la suite, au-delà de l'init du conteneur : 17 entités, aucune
contrainte d'unicité, toute propriété optionnelle ou pourvue d'un défaut, toute
relation optionnelle et jamais `.deny`, plan de migration en 1.0.0.

**Où vivent les tests, et pourquoi**

`CloudKitConformanceTests` est dans la cible `CineShelfTests` et **pas** dans le
package. Sous `swift test`, le binaire n'a pas d'identifiant de paquet et
CloudKit termine le processus (`Invalid parameter not satisfying:
bundleIdentifier != nil`, signal 6) au lieu de lever une erreur. Vérifié : dans
`CineShelfTests`, un schéma valide s'initialise **sans l'entitlement iCloud**, et
un schéma invalide lève proprement un `SwiftDataError.loadIssueModelContainer`.
Les tests du package utilisent donc un magasin en mémoire **sans** miroir.

**Écarts par rapport aux documents, tous volontaires**

1. `makeContainer` prend un `inMemory: Bool = false` supplémentaire, pour que les
   tests partagent exactement le schéma de production. L'appel de `docs/04` §2
   reste valide tel quel.
2. `refreshDerived()` sur `TitleCollection` et `SavedLink` n'était pas fourni :
   écrit dans la même forme que celui de `Title`.
3. `@MainActor` porte sur `makeContainer` et non sur l'enum `Persistence`, sinon
   `Persistence.schema` est inaccessible depuis un test non isolé.
4. `MediaAsset.crop(for:)` renvoie une valeur nommée `CropValues` au lieu d'un
   tuple à trois membres, interdit par la règle `large_tuple`. Les membres
   s'appellent toujours `.x`, `.y`, `.zoom` : les appels de `docs/04` §4 sont
   inchangés.
5. Trois adaptations imposées par la configuration de lint validée, sans effet
   sémantique : `var id = UUID()` plutôt que `var id: UUID = UUID()`
   (`redundant_type_annotation`), identifiants d'au moins deux caractères dans
   `FlagRepository` et `crop(for:)` (`identifier_name`), et
   `extension Title { public var … }` plutôt que `public extension Title`
   (`NoAccessLevelOnExtensionDeclaration`).

**Hors périmètre, à faire plus tard**

`CineShelfApp` n'est pas encore branché sur `Persistence.makeContainer` :
`docs/04` §2 le prévoit, mais le prompt 5 ne le demande pas. À faire au
prompt 10 (navigation) au plus tard, sinon aucune vue n'aura de contexte.

`docs/03-FONCTIONNALITES-NATIF.md` n'est pas modifié : ce prompt ne livre aucune
fonctionnalité visible, et le document est fait de tableaux sans cases à cocher.

**Suite**

Prompt 6 — repositories et outillage.

---

## 2026-08-02 — Couche d'accès et amorçage (prompt 6)

**Fait**

- `CineShelfApp` ouvre le magasin : `Persistence.makeContainer(cloudKit:
  FeatureFlags.cloudKitEnabled)` en `init()`, exposé par `.modelContainer()`.
- `Bootstrap.ensureDefaults(in:)` dans `CineShelfCore` — pas dans une `View` :
  crée « Ma bibliothèque » (`isDefault`) et le profil « Moi » si la base est
  vide, réutilise l'existant sinon. Idempotent.
- `Repositories/` : `TitleRepository`, `PersonRepository`,
  `CollectionRepository`, `MediaRepository` en `create / update / softDelete /
  restore`. `update` appelle toujours `refreshDerived()` ; `MediaAsset` n'a pas
  de dérivé textuel, seul `updatedAt` bouge.
- `GenreRepository.findOrCreate(name:target:in:)` sur `nameKey` + cible +
  bibliothèque, plus `rename` qui rafraîchit la clé.
- `ProfileRepository` : créer, renommer, supprimer, changer de bibliothèque.
- `Services/` : `ActivityRecorder` (+ enum `ActivityAction`, protocole
  `ActivityDescribing`) et `ImportActor` en `@ModelActor` avec le patron de
  sauvegarde par lots de 200.

**Vérifications, toutes vertes**

| Contrôle | Résultat |
|---|---|
| Build iOS Simulator (iPhone 17) | `** BUILD SUCCEEDED **` |
| Build macOS | `** BUILD SUCCEEDED **` |
| `xcodebuild test -scheme CineShelf` (macOS et iOS) | 8 tests |
| `xcodebuild test -scheme CineShelfUITests` (iOS) | 1 test |
| `swift test` × 3 packages | 78 tests (75 pour Core) |
| `swiftlint --strict` | 0 violation / 72 fichiers |
| `swift-format lint` | 0 avertissement |

**Amorçage vérifié sur le vrai magasin, pas seulement en mémoire**

Lancement de l'app macOS depuis un conteneur vide, puis lecture directe du
`default.store` : une `ZLIBRARY` « Ma bibliothèque » par défaut, un `ZPROFILE`
« Moi » par défaut, deux entrées de fil `create`. Après un second lancement :
toujours 1 / 1 / 2. C'est ce que les tests unitaires ne pouvaient pas montrer —
que le magasin sur disque s'ouvre sous le sandbox et que l'amorçage ne double
pas.

Le test fumigatoire laisse un magasin dans
`~/Library/Containers/fr.feltrin.CineShelf` ; supprimer ce dossier suffit à
retrouver un premier lancement.

**Ce que les tests ont appris sur SwiftData**

`fetchCount` **voit les insertions en attente** : après une erreur au 250e
élément, le contexte de l'`ImportActor` compte 249 titres alors que 200
seulement sont sauvegardés (vérifié depuis un contexte neuf). Deux
conséquences :

1. Le dédoublonnage de `GenreRepository` fonctionne **avant** le premier
   `save()` — le cas qui compte pour l'import, qui insère par lots. Pas besoin
   de doubler le `fetch` d'une recherche dans la relation en mémoire.
2. Un import interrompu est reprenable **par lot**, pas par élément : le lot en
   cours est perdu. C'est explicite dans le test.

**Écarts et choix, à valider ou corriger plus tard**

1. Pas de `SpotlightIndexer`, que `docs/04` §3 montre dans
   `TitleRepository.update/softDelete` : l'indexation est au prompt 12. Les
   repositories sont le point de branchement.
2. `MediaRepository` n'a pas de `attach(asset:to:slot:)` : rien n'impose encore
   l'invariante `hasExactlyOneOwner` à l'écriture, elle n'est vérifiée qu'en
   test. À traiter au prompt 13/14.
3. `ActivityAction` ajoute `restore` aux cinq actions nommées par le prompt, et
   `ActivityEntry.action` est **optionnelle** : dans une piste d'audit, mieux
   vaut `nil` qu'un repli faux.
4. `ProfileRepository.move` ne touche pas aux flags du profil, qui pointent
   alors vers des titres restés dans l'ancienne bibliothèque. À trancher avec le
   transfert d'entités.
5. Échec du conteneur ou de l'amorçage : `fatalError`, comme `docs/04` §2. À
   remplacer par une vraie interface au prompt 22.

**Deux points ouverts, hors de ce prompt**

- Avec `cloudKitEnabled = true`, sur un appareil neuf, l'amorçage peut créer une
  bibliothèque par défaut avant que la sync n'ait rapatrié l'existante : c'est le
  doublon classique, à régler au prompt 22 avec la passe de fusion de `docs/02`
  §8.
- `docs/02` §3.5 ne déclare toujours pas `TitleCollection.links` : le fichier est
  identique à celui du commit d'initialisation. Le code garde la correction —
  sans elle le miroir CloudKit refuse le schéma — mais **le document reste à
  corriger**.

Le bloc « Ajoute aussi » du prompt 6 (`.swiftlint.yml` avec la règle sur les
couleurs littérales, `.swift-format`, `.github/workflows/ci.yml`,
`docs/journal.md`) était déjà livré au prompt 4 : vérifié, pas réécrit. La CI
n'a pas d'étape `swift-format lint` ; le prompt ne la demande pas.

`docs/03-FONCTIONNALITES-NATIF.md` reste inchangé : ce prompt livre de
l'infrastructure, aucune fonctionnalité visible, et le document est fait de
tableaux sans cases à cocher.

**Suite**

Prompt 7 — les tokens du design system, chez Claude Design.

---

## 2026-08-02 — Décisions arrêtées et corrections documentaires

**Trois décisions, désormais fermées**

1. **`CropValues` est conservé.** `MediaAsset.crop(for:)` renvoie une valeur
   nommée, pas un tuple à trois membres, et il n'y aura pas de
   `// swiftlint:disable large_tuple`. Les membres restent `.x`, `.y`, `.zoom` :
   les appels de `docs/04` §4 sont valides tels quels.
2. **`ProfileRepository.move` ne supprime pas les flags.** Ils suivent le profil
   et pointent vers des titres restés dans l'ancienne bibliothèque : ils
   deviennent donc invisibles, et **réapparaissent** si le profil revient sur sa
   bibliothèque d'origine. C'est le comportement voulu — rien n'est détruit. Un
   avertissement à l'écran l'expliquera au prompt 18 (profils & Face ID).
3. **`MediaRepository.attach` imposera `hasExactlyOneOwner` à l'écriture**, au
   prompt 13 (pipeline médias). D'ici là l'invariante n'est vérifiée qu'en test.

**Corrections documentaires**

- `docs/02` §3.5 déclare enfin `TitleCollection.links`, et une note au-dessus de
  §3.8 explique l'omission, comment `CloudKitConformanceTests` l'a relevée, et
  qu'elle était le seul cas du modèle. Le document et le code disent maintenant
  la même chose.
- La CI reçoit une étape `swift-format lint --recursive --strict`, dans le job
  `lint` : `swift-format` est livré avec la chaîne d'outils Xcode, il n'y a rien
  à installer. Vérifié que `--strict` existe et renvoie bien 1 sur une
  violation, et que `.build` n'est pas parcouru — c'est un dossier caché.

**Règle de travail**

`docs/` dans le dépôt est **la** référence. Toute correction issue d'une session
s'y répercute dans la même session, jamais « plus tard ».

---

## 2026-08-02 — Pipeline médias, partie logique (prompt 13)

Pris en avance sur le prompt 9, qui attend le `DesignSystem`. `MediaKit` ne
dépend que de `CineShelfCore` : aucune vue, aucun `import UIKit` ni `AppKit`, le
même code sur iOS et sur macOS.

**Fait**

- `Ingestion/MediaIngestor` : `ingest(data:)` et `ingest(fileURL:)` →
  redimension à 2 000 px sur le grand côté, HEIC 0.8, sha256, blurhash 4×3,
  dimensions et poids. `IngestedImage.draft` donne directement le
  `MediaAssetDraft` que le repository attend.
- `Ingestion/BlurHash` : encodeur écrit à la main, base 83, aucune dépendance
  externe. Coefficients calculés sur une réduction à 64 px de côté.
- `Ingestion/HEICEncoder` et `ImageDecoder` : encodage et décodage partiel
  partagés par l'ingestion et le cache.
- `Display/ThumbnailPreset` : `thumb` 160 pt, `card` 360 pt, `hero` 1200 pt.
- `Display/ThumbnailCache` : `actor`, mémoire (`NSCache` borné à 64 Mo) puis
  disque (`Caches/thumbnails/<assetID>-<preset>@<scale>.heic`, purge au-delà de
  200 Mo), purge sur pression mémoire, écritures différées et sérialisées.
- `ThumbnailLoader`, la closure `(UUID, CGSize, CGFloat) async -> CGImage?` que
  `MediaThumbnail` recevra au prompt 9, obtenue par `ThumbnailCache.loader()`.
- Dans `CineShelfCore` : `MediaAssetDraft` et
  `MediaRepository.findOrCreate(_:)`, qui réutilise l'asset de même checksum.

**Vérifications, toutes vertes**

| Contrôle | Résultat |
|---|---|
| Build iOS Simulator (iPhone 17) | `** BUILD SUCCEEDED **` |
| Build macOS | `** BUILD SUCCEEDED **` |
| `xcodebuild test -scheme CineShelf` (macOS et iOS) | 8 tests |
| `xcodebuild test -scheme CineShelfUITests` (iOS) | 1 test |
| `swift test` × 3 packages | 114 tests (38 pour MediaKit) |
| `swiftlint --strict` | 0 violation / 83 fichiers |
| `swift-format lint --strict` | 0 avertissement |

MediaKit a été relancé trois fois de suite, vert à chaque fois : la suite du
cache contient une mesure de performance, il fallait s'assurer qu'elle
n'introduisait pas d'instabilité.

**Les chiffres mesurés**

Vignette `card` @2× (720 px) depuis un original 2 000 × 3 000, par unité, sur ce
Mac :

| Étape | Coût |
|---|---:|
| Décodage partiel + redimension — le chemin d'affichage | **18,9 ms** |
| Idem, écriture HEIC sur disque comprise | 44,4 ms |
| Relecture depuis le cache disque | 2,2 ms |
| Relecture depuis le cache mémoire | ~0 ms |

Le budget de `docs/04` §4 est de 20 ms pour générer une vignette : il est tenu
sur le chemin d'affichage, et c'est **pour cela** que l'encodage et l'écriture
sont différés hors de ce chemin. À mesurer de nouveau sur le plus vieil appareil
visé, pas sur ce Mac — le budget de 250 Mo et les 120 fps sur 2 000 jaquettes ne
se valident qu'avec la grille réelle, donc au prompt 14.

**Trois erreurs de ma part, corrigées**

1. **Ma première mesure était fausse** : `Duration.components.attoseconds`
   n'inclut pas les secondes entières, donc 8,9 s se lisait « 0,9 s ». Le premier
   chiffre annoncé, 4,69 ms, était donc dix fois trop optimiste. Corrigé, et la
   conversion est désormais dans une fonction unique.
2. **Trois prémisses de test fausses sur le blurhash.** Sur un aplat, les
   composantes alternatives ne sont pas nulles : celles dont un indice vaut 0
   gardent une somme entière sur cet axe et valent 2·c/côté. L'encodeur était
   correct, mes tests supposaient le contraire. Ils vérifient maintenant des
   propriétés réellement vraies : la composante continue est la couleur moyenne
   (décodée et comparée à ±2), et les axes ne sont pas inversés (image coupée
   dans un sens puis dans l'autre).
3. **Un test intrinsèquement instable.** `NSCache` peut évincer à tout moment
   sous pression mémoire — ce qui arrivait quand la mesure de performance
   tournait en parallèle. Affirmer « la mémoire garde l'entrée » n'est donc pas
   testable. La suite est sérialisée, et les assertions portent désormais sur ce
   qui est garanti : l'entrée est bien posée, et cache chaud l'original n'est
   plus jamais relu.

**Reporté au prompt 13 bis, explicitement hors de cette session**

- `PhotosPicker`, `.fileImporter`, glisser-déposer, collage.
- `CropEditor` : `MagnifyGesture` + `DragGesture`, aperçu par contexte, écriture
  dans `MediaCrop`.
- Le branchement de `MediaThumbnail` sur `ThumbnailLoader` — prompt 9, avec le
  `DesignSystem`.

**Toujours ouvert**

- `MediaRepository.attach` et l'invariante `hasExactlyOneOwner` à l'écriture :
  décidé au prompt 13 pour être fait au prompt 13, ce n'est pas livré ici puisque
  le rattachement fait partie de la partie visuelle reportée. À traiter au
  prompt 13 bis.
- Le prompt 13 de `docs/PROMPTS.md` demande un dédoublonnage « pour ce
  propriétaire ». Il est pour l'instant global au magasin : le rattachement
  n'existe pas encore, donc la portée par propriétaire n'est pas exprimable.
- `Bootstrap` ne branche pas encore `startObservingMemoryPressure()` : le cache
  n'est instancié par personne tant qu'aucune vue n'affiche d'image.

**Répercuté dans `docs/04` §4**, selon la règle de la session précédente : les
trois presets chiffrés, le sha256 sur les octets source, l'absence de repli
JPEG, la pression mémoire par `DispatchSource`, et l'écriture différée.

**Suite**

Prompt 9 — intégration du `DesignSystem`, dès que Claude Design a livré. Sinon
prompt 13 bis.

---

## 2026-08-03 — Intégration du DesignSystem (prompts 8 bis et 9)

**Débloqué avant de commencer : le projet ne compilait plus**

Reprise sur une nouvelle machine, `xcodegen generate` puis build : échec.
XcodeGen 2.46.0 (dernière stable) écrit `SUPPORTED_PLATFORMS = ""` **et**
`TARGETED_DEVICE_FAMILY = ""` pour toute cible déclarée en
`supportedDestinations`. Deux symptômes distincts :

- plateforme non résolue -> Xcode compile la cible app avec un triplet
  indéterminé et rejette les modules SwiftPM (`Unable to resolve module
  dependency: 'CineShelfCore'`) ;
- device family vide -> plus aucun simulateur iOS ne correspond à la cible,
  même désigné par UDID.

Reproduit sur un spec minimal de six lignes, indépendant de `xcodeVersion`.
Les deux réglages sont donc explicités par cible dans `project.yml`, avec le
bloc de commentaire qui donne version, symptômes et commande de reproduction.
`ONLY_ACTIVE_ARCH: YES` ajouté en Debug seulement (Release reste universel).

Corrigé au passage : `PRODUCT_NAME` n'était écrit nulle part et Xcode 26 ne lui
donne plus de valeur par défaut. Les cibles de test échouaient sur
`module name "" is not a valid identifier` — `CineShelfTests` avait la même
bombe à retardement, simplement jamais déclenchée.

**Livraison Claude Design**

Archive `CineShelf Design System.zip` : 6 fichiers de fondations, 7 composants,
`colors.tokens.json`, une app de démonstration. Composants bien présents, ce
n'était pas une livraison tokens seuls.

Croisement des 23 jeux sémantiques avec `docs/01` §B.1 : **aucun oubli**. Noms,
ordre et valeurs identiques — les 59 valeurs `any`/`dark` ont été vérifiées une
à une contre les primitives citées par le doc, zéro écart. Aucun rôle n'est
dérivé par `.opacity()` : les quatre jeux à alpha (`bg/selected`, `accent/soft`,
`border/subtle`, `media/ring`) sont des Color Sets à part entière, ce qui permet
au contraste élevé de changer teinte *et* alpha. Le JSON applique en HC plus que
les trois règles du doc (aussi `media/ring`, `bg/selected`, `accent/soft`,
`accent/text`) : extension délibérée, documentée dans `COLORS.md`.

**Trois bugs dans le code livré**

- `StateView.Kind` : les fabriques `empty`/`failure` avaient tous leurs
  paramètres défaultés, donc exactement la signature des cases — redéclaration
  invalide, le package ne compilait pas. Corrigé en réduisant les paramètres.
- `StateView.body` : `message(...)` appelait la valeur liée par le motif au lieu
  de la méthode. `self.` manquant.
- Sept `.font(.system(size:))` sans `relativeTo:`, en violation de
  `no_fixed_font_size`. Remplacés par des styles de texte.

**Couleurs**

`scripts/generate-colors.py` génère les 59 Color Sets depuis le JSON : 4
apparences sur les sémantiques, display-p3, composantes float, dossiers à
espace de noms. Le script émet aussi `ColorTokens.generated.swift`, qui porte la
liste des tokens et un `switch` vers les accesseurs typés — ajouter un jeu au
JSON sans écrire son accesseur casse la **compilation**, pas seulement un test.

**Police — deux écarts avec la consigne, tranchés sur mesure**

1. `"Archivo"` n'est pas un nom PostScript. Relevé réel via
   `CTFontManagerCreateFontDescriptorsFromURL` : `Archivo-SemiBold`,
   `Archivo-Bold`, `ArchivoSemiExpanded-SemiBold`, `ArchivoSemiExpanded-ExtraBold`.
2. La variable `Archivo[wdth,wght].ttf` de Google Fonts n'expose que neuf
   instances nommées, **toutes en graisse, aucune en largeur**. L'axe `wdth` a
   six crans (62 / 75 / 87,5 / 100 / 112,5 / 125, relevés dans la source Glyphs
   upstream) : le `wdth` 112 demandé par `docs/01` §B.2 est donc le cran 112,5,
   dont le nom de famille est **« Archivo SemiExpanded »** — pas « Archivo
   Expanded », qui est le cran 125. Quatre statiques embarqués depuis
   Omnibus-Type/Archivo (la source amont référencée par Google Fonts), pas de
   `fontTools` requis. `heroTitle` et `railLabel` pointent sur SemiExpanded.

`cardTitle` reste en **SF Pro**, chasse normale : `docs/01` §B.2 le déclare en
SF Pro et Claude Design l'a livré ainsi. L'axe `wdth` ne s'applique qu'à Archivo.

Pas de `UIAppFonts` : Archivo vit dans le bundle de ressources du package, que
`UIAppFonts` ne sait pas atteindre. Enregistrement par
`CTFontManagerRegisterFontURLs`, appelé depuis `CineShelfApp.init()`.

**Indépendance du package : vérifiée**

Imports : `SwiftUI`, `Foundation`, `CoreText`. Rien d'autre.
`swift package show-dependencies` -> « No external dependencies found ».
Le catalogue le prouve aussi : il compile en ne liant que `DesignSystem`.

**Catalogue**

Cible `DesignSystemCatalog` (iOS + macOS) : planche des 59 Color Sets avec nom
et valeur résolue, onze rôles typographiques, rayons / espacements / élévations
/ proportions dessinés à taille réelle, et chaque composant dans ses états.
Barre d'outils : clair/sombre, contraste élevé, Dynamic Type normale/AX3/AX5,
largeur de plateforme simulée.

`\.colorSchemeContrast` est en lecture seule dans SwiftUI : la bascule contraste
agit au niveau **fenêtre** (`NSAppearance` sur macOS, `traitOverrides` sur iOS),
seul moyen de faire réellement résoudre les apparences HC du catalogue d'assets.

**Tests — trois découvertes qui changeaient la donne**

1. `Font.custom` retombe silencieusement sur une autre police. Le repli de
   CoreText est **Helvetica**, pas la police système : ma première version du
   test comparait à la mauvaise référence et ne protégeait de rien. La sonde est
   maintenant auto-calibrée (elle mesure le repli au lieu de le supposer).
   Vérifié en cassant volontairement un nom PostScript : le test échoue bien.
2. **SwiftPM ne lance pas `actool`.** `Colors.xcassets` est recopié tel quel,
   aucun `Assets.car` n'est produit, et sous `swift test` **aucune** couleur ne
   se résout. D'où la cible `DesignSystemAssetTests`, qui rejoue les mêmes
   sources sous xcodebuild avec les assets compilés, et un test sous
   `XCODE_ASSET_TESTS` qui échoue si le catalogue cesse d'être compilé — sans
   lui, une régression se traduirait par des tests « skipped », donc verts.
3. **`ImageRenderer` ignore `dynamicTypeSize` sur macOS.** Mesuré : un simple
   `Text().font(.body)` rend la même hauteur à `.large`, AX3 et AX5. Ce n'est pas
   un défaut des composants — macOS n'a pas Dynamic Type. Les assertions de
   croissance ne tournent donc que sur iOS, où elles passent, et une sentinelle
   macOS échoue le jour où Apple change ça.

Tests de rendu sur `PosterCard` et `ShelfRail` via `ImageRenderer` (aucune
bibliothèque ajoutée) : clair/sombre × compact/medium/large × normale/AX3. Pas
d'images de référence — elles se périment et personne ne les relit — mais des
propriétés : le rendu aboutit, clair et sombre donnent des pixels **différents**
(une couleur codée en dur les rendrait identiques), AX3 rend plus haut, et les
trois tailles se distinguent. Chaque famille d'assertions a son contrôle négatif.

`no_literal_color` re-vérifiée sur fichier sonde : muette dans
`Packages/DesignSystem/`, erreur dans `Catalog/`. Au passage, `Catalog` manquait
dans `included:` de `.swiftlint.yml` — le dossier n'était pas linté du tout.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| Build `DesignSystemCatalog` macOS / iOS | `** BUILD SUCCEEDED **` |
| `xcodebuild test -scheme CineShelf` (macOS) | 8 tests |
| `xcodebuild test -scheme DesignSystemCatalog` (macOS) | 20 tests |
| `xcodebuild test -scheme DesignSystemCatalog` (iOS) | 19 tests |
| `swift test` CineShelfCore | 75 tests |
| `swift test` DesignSystem | 19 tests (2 skipped, cf. `actool`) |
| `swiftlint --strict` | 0 violation / 106 fichiers |
| `swift-format lint --strict` | 0 avertissement |

**Rouge, non lié à cette session**

`MediaKit` — « Performance : 200 vignettes » échoue sur cette machine :
**21,5 ms** par vignette de décodage contre un budget de 20 ms. Reproductible
(20,9 / 21,1 / 21,9 sur trois passes), donc pas un aléa. `Packages/MediaKit`
n'a pas été touché de la session et ne dépend pas de `DesignSystem`. Le seuil
est un budget de performance : le relever est une décision produit, pas une
correction de lint. **À trancher.**

**Toujours ouvert**

- Le seuil de perf `MediaKit` ci-dessus.
- Les 36 primitives sont générées dans le `.xcassets` alors qu'aucune vue ne
  doit les lire ; seul le catalogue y accède, par nom. À élaguer si le poids du
  catalogue d'assets devient un sujet.
- `MediaThumbnail` n'est toujours pas branché sur `ThumbnailLoader` : c'était la
  seconde moitié du prompt 9, elle dépend du prompt 13 bis.
- Reste du prompt 13 bis inchangé (`PhotosPicker`, `CropEditor`,
  `MediaRepository.attach`).

**Suite**

Prompt 10, ou prompt 13 bis pour refermer le pipeline médias.

---

## 2026-08-03 (2) — Budgets de perf, cohérence des docs, navigation adaptative (prompt 10)

**Commits**

- `ee3b88c` — intégration du DesignSystem (travail de la session précédente, jusque-là non committé)
- `0aa8d05` — budgets de perf par chemin, chasse Archivo, commandes du catalogue

**Budgets de performance — le seuil de 20 ms remplacé par trois**

Le seuil unique « génération d'une vignette < 20 ms » avait été écrit avant
toute mesure et ne protégeait rien : à 120 Hz une image dure 8,3 ms, donc une
génération à froid n'y tient de toute façon pas, ni à 20 ni à 21,5 ms. Ce qui
protège le défilement, c'est le cache et le préchargement.

| Chemin | Budget | Mesuré |
|---|---|---|
| Génération à froid, hors thread principal | < 30 ms | 20,10 ms |
| Lecture depuis le cache disque | < 5 ms | 2,40 ms |
| Lecture depuis le cache mémoire | < 1 ms | 0,00 ms |

La justification est écrite dans `docs/04` §4 et dans le test, pour qu'on ne
relise pas ces chiffres comme un renoncement : le premier détecte une
régression algorithmique et rien de plus, les deux autres arrivent pendant un
défilement et doivent tenir dans une image.

**Pour le prompt 13 bis : le vrai correctif de performance, c'est le
préchargement** de l'écran suivant pendant le défilement. Aucun seuil sur la
génération ne remplacera ça.

**Cohérence des documents**

`docs/01` §B.2 appliquait une chasse `wdth` à `cardTitle`, qui est en SF Pro :
l'axe n'existe que pour Archivo. Mention retirée, et il est maintenant écrit
que le `wdth` 112 de `heroTitle` et `railLabel` correspond au cran
**SemiExpanded** et non Expanded. §A.5 annonçait la police variable embarquée
alors qu'on livre des statiques.

**Environnement**

`xcode-select -p` pointe désormais sur `/Applications/Xcode.app/Contents/Developer` :
plus besoin de `DEVELOPER_DIR`. Il n'y en avait aucune trace dans le dépôt, il
n'y avait donc rien à retirer.

`which -a xcodegen` ne renvoie qu'un chemin, `/opt/homebrew/bin/xcodegen`, mais
c'est un **fichier ordinaire de 14 Mo posé à la main** (2.46.0), pas le lien
symbolique de Homebrew. Le keg 2.45.4 est en Cellar et `brew doctor` le signale
comme non lié. Rien n'a été supprimé — voir la recommandation en fin de session.

### Prompt 10 — navigation adaptative

**Décisions prises** (les trois ambiguïtés entre documents ont été tranchées
avec le propriétaire avant d'écrire) :

- Onglets compacts conformes à `docs/01` partie C : Accueil / Catalogue
  (segmenté Titres·Personnes·Collections) / Galerie / Recherche / Plus. Les six
  sections auparavant inatteignables sur iPhone le sont maintenant.
- Nommage : « Plus » pour l'onglet fourre-tout, « Gestion » pour la console et
  sa fenêtre ⇧⌘L. « Bibliothèque(s) » est réservé à l'entité `Library`.
- Périmètre Mac complet : inspecteur + ⌥⌘I, fenêtre Gestion + ⇧⌘L, menus ⌘N /
  ⇧⌘I / ⇧⌘E / ⌘F, ⌃⌘1…9 pour les profils, ⌥↑ / ⌥↓ dans le détail.

**Structure**

`App/Navigation/` : `AppRoute` (destinations poussées), `AppSection` (11
sections de premier niveau), `CompactTab` (les 5 onglets), `CatalogueSegment`,
`NavigationModel`, `ProfileSession`, `Sidebar`, `ProfileMenu`, `ProfilePicker`,
`SectionPlaceholder`, `RouteDestination`, `CineShelfCommands`.

`AppSection` et `CompactTab` sont deux types distincts parce qu'ils ne se
correspondent pas un pour un : « Catalogue » couvre trois sections, « Plus » en
couvre cinq. `NavigationModel` maintient leur cohérence dans les deux sens, ce
qui est ce qui permet à une rotation d'iPad de ne pas perdre l'écran courant.

Une pile de navigation **par section** plutôt qu'une pile unique : en compact
chaque onglet a son `NavigationStack` et revenir dessus doit retrouver sa pile.

La restauration au lancement est **par profil** et porte sur la section, le
segment, les piles et l'état de l'inspecteur — pas sur les filtres (ils
n'existent pas encore) ni sur la largeur des colonnes (le système s'en charge).

`ProfileSession` est séparé de `NavigationModel` : le profil change une fois par
session, la navigation à chaque écran. Les deux vivent dans `App/Navigation/` et
non dans `Features/Settings/`, sans quoi la barre latérale importerait une
feature — ce que `docs/04` §1 interdit.

La teinte de l'app suit `Profile.accentToken`, résolu par le design system, avec
repli sur l'accent par défaut : un profil mal configuré ne doit pas casser
l'app. `docs/04` §2 écrivait `.tint(.accentText)` en dur ; le modèle prévoit
mieux.

**Écrans vides** : `ComingSoonView` (qui utilisait `ContentUnavailableView`) est
supprimée au profit de `SectionPlaceholder`, qui s'appuie sur `StateView` du
design system. Onze couples titre/message en français, qui décrivent ce que la
section contiendra plutôt que le fait qu'elle soit inachevée.

**Un détour à signaler** : `AppSection.destination` — le seul point où la
navigation touche une feature — a été sorti dans `AppSectionDestination.swift`.
Sans ça, tester `NavigationModel` imposait de lier la cible app à la cible de
test, donc un `TEST_HOST`, donc de lancer l'interface — exactement ce que le
commentaire de `project.yml` dit vouloir éviter. Les trois fichiers de logique
sont maintenant compilés directement dans `CineShelfTests`.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| `xcodebuild test -scheme CineShelf` (macOS) | 20 tests (8 + 12 de navigation) |
| `xcodebuild test -scheme DesignSystemCatalog` macOS / iOS | 20 / 19 tests |
| `swift test` Core / DesignSystem / MediaKit | 75 / 19 / 38 tests |
| `swiftlint --strict` | 0 violation |
| `swift-format lint --strict` | 0 avertissement |

Deux corrections de compilation, remontées par le sous-agent build :
`.keyboardShortcut(_:modifiers:)` n'accepte pas un `KeyEquivalent?` (passage à
`KeyboardShortcut?`), et `List(selection:)` à liaison non optionnelle n'existe
pas sur iOS (pont `Binding<AppSection?>` dans `Sidebar`, sans rendre la section
du modèle optionnelle).

**Revue — trois bugs bloquants trouvés et corrigés**

Le sous-agent de revue a relu le travail contre `docs/01` partie C, `docs/04` §2
et `CLAUDE.md`. Trois défauts réels, invisibles à la compilation :

1. **Piles partagées entre onglets.** `TabView` évalue le corps de *tous* les
   onglets ; « Catalogue » et « Plus » n'ayant pas de section propre, leur
   `NavigationStack` était lié à `paths[section courante]`. Trois piles vivantes
   sur un même tableau : pousser un détail depuis Galerie recouvrait la liste
   « Plus ». Corrigé par une clé de pile dédiée (`NavigationModel.StackID`), qui
   donne à « Plus » sa propre pile et à « Catalogue » celle de son segment.
2. **Le réglage « ouvrir directement le dernier profil » ne se rafraîchissait
   pas.** `@Observable` n'instrumente que les propriétés *stockées* : la
   propriété calculée sur `UserDefaults` écrivait bien la valeur, mais
   l'interrupteur ne bougeait pas. Passée en propriété stockée.
3. **⌃⌘1…9 n'était pas enregistré.** Les raccourcis étaient posés sur des
   boutons *à l'intérieur* d'un `Menu` de la barre latérale : SwiftUI ne les
   enregistre qu'une fois le menu déroulé, et jamais colonne repliée. Déplacés
   dans un `CommandMenu` de la barre de menus.

Corrigé aussi : la restauration abandonnait au lieu de réinitialiser, donc un
profil sans état enregistré héritait de la section, des piles et de
l'inspecteur du profil précédent — puis les réenregistrait sous son propre
identifiant. Les deux régressions les plus graves (1 et la fuite d'état) ont
maintenant leur test.

Écarts d'interface corrigés dans la foulée : le sélecteur segmenté du Catalogue
bascule en menu au-delà d'`.accessibility1` (`docs/01` §B.2 : pas de troncature
à AX5), le sélecteur de profil devient défilable (iPhone SE en AX5), les genres
épinglés passent à 44 pt, le profil actif est annoncé à VoiceOver et non plus
signalé par la seule teinte. Sur Mac, « Réglages » passe par `SettingsLink` et
« Gestion » par sa fenêtre plutôt que par la colonne du milieu — `docs/01` A.2
remplace justement l'overlay maison par ces deux scènes. Le `CommandMenu`
« Bibliothèque » devient « Aller à » : il ne contient aucune `Library`. Icônes
corrigées pour Import/Export (c'était le symbole de tri) et Gestion.

**Toujours ouvert**

- La colonne « Liste » de la disposition large n'a pas encore de contenu réel
  ni de barre d'outils (tri, filtres, affichage) : `docs/01` partie C les
  prescrit, ils arrivent avec les prompts de contenu.
- `Profile.requiresBiometry` est **affiché** dans le sélecteur de profil (un
  cadenas) mais **pas appliqué** : Face ID est le prompt 18.
- Le bloc « Bibliothèques » de la barre latérale est affiché mais inerte :
  changer de `Library` n'est pas dans le périmètre du prompt 10.
- ⌥↑ / ⌥↓ sont câblés mais toujours désactivés : `navigation.collection` n'est
  peuplée par aucune vue tant qu'il n'y a pas de liste réelle.
- ⌘N, ⇧⌘I et ⇧⌘E sont présents et grisés, donc pas encore câblés.
- Le pont `Binding<AppSection?>` de `Sidebar` avale la désélection. Cohérent
  tant que `section` est toujours définie ; si un état « rien de sélectionné »
  devient nécessaire, c'est le modèle qu'il faudra rendre optionnel, pas la vue.
- `docs/03` n'a aucun mécanisme de cochage alors que `CLAUDE.md` demande d'y
  cocher les fonctionnalités traitées : c'est un tableau de correspondance à
  symboles. À arbitrer (voir aussi la colonne d'état de `docs/PROMPTS.md`).
- Reste du prompt 13 bis inchangé, plus le préchargement noté plus haut.

**Suite**

Prompt 11 — Titres.

---

## 2026-08-03 (3) — Suivi d'avancement, puis les Titres (prompt 11)

**Commit préalable** — `3789eb5` : nouveau `docs/PROMPTS.md` avec sa colonne
d'état comme unique suivi d'avancement. Cinq points ouverts que le journal
portait manquaient au tableau « Écarts connus » (pression mémoire jamais
branchée, primitives non lues, bloc « Bibliothèques » inerte, raccourcis grisés,
pont de sélection de la barre latérale). `CLAUDE.md` ne demande plus de cocher
`docs/03` : ses symboles décrivent l'intention par fonctionnalité, pas
l'avancement.

### Prompt 11 — Titres

**La frontière de couche**, demandée comme patron pour les prompts 14 à 17 :
`App/Features/Titles/TitlePresentation.swift`. `DesignSystem` ne connaît pas
`Title`, `CineShelfCore` ne connaît pas SwiftUI, les deux se rencontrent là et
nulle part ailleurs. Trois règles à reprendre : la conversion est un `init` sur
le type de présentation et non une méthode sur le `@Model` ; tout formatage
destiné à l'œil (durée, année, note sur 5) vit là ; les données de profil sont
passées en paramètre, jamais lues depuis le titre — `Title.flags` contient les
flags de tous les profils.

**Le pont image** — `MediaThumbnail` est enfin relié à `ThumbnailCache`. Le
design system ne connaît qu'une `URL?`, le cache ne connaît que des `UUID` :
une URL synthétique `cineshelf-asset://<uuid>?preset=card` porte l'un jusqu'à
l'autre, décodée par `MediaEnvironment` qui fournit l'`ImageLoader`. Le cache
n'était **instancié par personne** jusqu'ici : rien n'était mis en cache, tout
était redécodé à chaque affichage.

**Données de démonstration** — `App/DemoData/DemoCatalog.swift`, `#if DEBUG`
intégralement. 120 titres, 30 personnes créditées, 6 collections, jaquettes
dessinées par le code (dégradé + repères, aucun octet d'image dans le dépôt).
Générateur déterministe : deux exécutions donnent le même catalogue, donc des
mesures comparables et des captures stables. Accessible depuis Réglages, avec
un bouton pour vider.

**Le point dur : `#Predicate` ne se type-check plus au-delà de ~6 clauses.**
Bissection en dix builds : `(title.genres ?? []).contains { … }` n'est pas
typable par `PredicateExpressions`, et la conjonction sature le vérificateur.
Le filtre est donc réparti — visibilité, recherche et collection dans le
prédicat SwiftData ; genre, personne, durée et note en mémoire dans
`matches(_:)`. **Aucun critère n'a disparu**, et `TitleFilterTests` vérifie
chacun des neuf, précisément parce que le risque est qu'un critère tombe entre
les deux mécanismes. Compromis assumé : les bornes ne sont plus poussées en
SQL. À plusieurs dizaines de milliers de titres il faudra dénormaliser plutôt
que forcer `#Predicate`.

**Revue — deux corruptions de données trouvées et corrigées**

1. **L'inspecteur écrivait les valeurs du titre précédent sur le suivant.**
   `TitleEditor` initialise son brouillon en `@State`, et SwiftUI réutilisait la
   vue quand la route changeait (⌥↑ / ⌥↓ avec l'inspecteur ouvert). Un
   « Enregistrer » appliquait alors l'ancien brouillon au nouveau titre.
   Corrigé par `.id(title.id)`.
2. **Chaque enregistrement détruisait la date de sortie exacte.** L'éditeur ne
   saisit qu'une année et réécrivait `releaseDate` au 1er janvier avec
   `precision = .year` — y compris quand on ne modifiait que la note. Une date
   connue au jour près était dégradée en silence. La date n'est désormais
   réécrite que si l'année a réellement changé.

Corrigé aussi : `DemoCatalog.clear()` supprimait **toutes** les personnes sans
crédit et **toutes** les collections vides du magasin entier, en dur — une
personne réelle saisie sans filmographie disparaissait. Le marquage est
maintenant explicite et le genre marqueur cherché dans la bonne bibliothèque.

Écarts d'interface corrigés : la bascule d'affichage persistait sans redessiner
(`UserDefaults` n'invalide aucune vue) ; ⌘N depuis une autre section levait un
drapeau que personne ne consommait ; le bouton « Ajouter un film » de l'écran
vide ne faisait rien ; l'inspecteur était inatteignable sur iPad (test de
plateforme au lieu de classe de taille) ; la recherche échouait sur les accents,
`Title.searchText` étant replié d'un seul côté ; un titre créé puis abandonné
par glissement restait sans nom en tête du tri ; le filtrage en mémoire était
refait deux fois par passe de rendu plus une fois par carte, avec une recherche
linéaire — mémoïsé et indexé. La bascule « archivés » remonte dans la barre
d'outils, comme le demande `docs/03` §3. Le balayage de la fiche ne vole plus
le défilement ni le retour système. La fiche respecte `hidesPrivateContent`.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| Tests `CineShelf` (macOS) | 33 tests |
| Tests catalogue (macOS) | `** TEST SUCCEEDED **` |
| `swift test` Core / DesignSystem / MediaKit | 75 / 19 / 38 |
| `swiftlint --strict` | 0 violation |
| `swift-format lint --strict` | 0 avertissement |

**Non couvert du §4, reporté** — suggestion de casting (§4.11, aucune
infrastructure, va au prompt 15) ; édition du casting, des genres et de la
collection depuis l'éditeur ; `seasonCount` / `episodeCount` lus mais non
éditables ; duplication d'un titre ; `MediaSlot.portrait` jamais lu ;
`.navigationTransition(.zoom)` — la source est déclarée par `PosterCard` mais
le namespace est privé à la grille, donc le chaînage vers la destination
n'existe pas. Tous reportés dans « Écarts connus » de `docs/PROMPTS.md`.

**Suite**

Prompt 12 — Recherche + Spotlight.

---

## 2026-08-03 (4) — Corbeille des genres, et l'invariant de DemoCatalog

### `Genre` gagne une suppression douce

C'était le dernier modèle de premier plan sans corbeille, et l'asymétrie était
tracée depuis deux sessions. La raison, écrite dans `docs/02` §3.5 : **ce n'est
pas le mot qu'on perdrait, ce sont les relations.** Un genre porte des liens
plusieurs-à-plusieurs vers les titres et vers les personnes ; le supprimer en
dur les détruit définitivement, et recréer « Policier » ensuite donne un genre
vide — il faudrait retrouver à la main les quatre-vingts titres qui le
portaient. `isArchived` ne suffit pas : il masque un genre qu'on garde, il ne
dit pas qu'on a voulu s'en débarrasser.

`softDelete` / `restore` calqués sur les quatre autres repositories, et
`deletedAt == nil` répercuté sur les six lectures de genre du dépôt. La plus
importante est celle de `GenreRepository.find` : sans elle, retaper un genre
supprimé le ressusciterait avec toutes ses anciennes associations, sans que
personne ne l'ait demandé.

**Deux conséquences écrites avant que quelqu'un ne bute dessus** : la passe de
fusion sur `nameKey` prévue par `docs/02` §8 doit se restreindre à
`deletedAt == nil`, faute de quoi elle refusionnerait le supprimé dans le vivant
et ramènerait exactement ce que la corbeille mettait de côté ; et tant que l'app
n'est pas publiée, `CineShelfSchemaV1` accueille un attribut optionnel sans
nouvelle étape de migration — à la publication, `V1` est gelée.

### `DemoCatalog` : la décision, et l'invariant

La décision de rester hors des repositories est maintenant écrite en tête de
fichier, pour que personne ne la « corrige » : une fixture n'est pas une action
de l'utilisateur, et générer 120 titres par les repositories produirait trois
cents `ActivityEntry` fictives dans le fil du prompt 16.

Ce qui n'est pas négociable, c'est `refreshDerived()`. Vérifié entité par
entité : `Title`, `Person` et `TitleCollection` l'appellent bien après que tous
leurs champs sources sont posés — le cas subtil étant `bio` et `summary`, écrits
*après* l'init qui a déjà rafraîchi. `DemoCatalogTests` verrouille l'invariant,
avec un contrôle négatif qui prouve qu'une mutation post-init laisse bien les
dérivés périmés.

**Deux bugs trouvés par les tests, tous deux réels :**

1. `clear()` n'atteignait personnes et collections *que* depuis un titre de
   démonstration. Or le stock est fixe (30 personnes, 6 collections) et
   distribué au hasard : certaines n'étaient créditées nulle part et
   survivaient au vidage. En usage réel aussi, pas seulement en test.
2. `markerGenre()` cherchait sur `name` quand `findOrCreate` cherche sur
   `nameKey`, replié sans accents ni casse. Une bibliothèque contenant déjà
   « demonstration » voyait `findOrCreate` réutiliser ce genre comme marqueur,
   que `markerGenre` ne retrouvait plus : le bouton « Vider » devenait un no-op
   silencieux et les 120 titres n'étaient plus supprimables.

Corrigé aussi, sur revue : un filtre par genre ou par collection dont l'entité a
disparu continuait de restreindre la liste **pour de bon**, avec un sélecteur
vide et une icône de filtre allumée — et l'état survivait au redémarrage,
puisque le filtre est persisté. Les filtres orphelins sont maintenant assainis.

Les dix genres thématiques ne sont **pas** supprimés par le vidage, et c'est
documenté : ils viennent de `findOrCreate`, qui réutilise un genre réel
homonyme, et rien ne distingue « créé par la démo » de « réutilisé ».

Ménage : `DemoCatalog.swift` scindé (il dépassait 500 lignes), un résidu
cyrillique dans le vocabulaire de démonstration et le filtre censé l'écarter —
qui ne l'écartait pas, `isLetter` étant vrai pour le cyrillique — deux boucles
`refreshDerived()` dont le commentaire énonçait une dépendance inexistante, et
`isPopulated` qui n'existait que pour son propre test désactive maintenant les
boutons quand il le faut.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| Tests `CineShelf` (macOS) | 42 tests |
| `swift test` Core / DesignSystem / MediaKit | 79 / 19 / 38 |
| `swiftlint --strict` | 0 violation |
| `swift-format lint --strict` | 0 avertissement |

**Suite**

Prompt 12 — Recherche + Spotlight.

---

## 2026-08-03 (5) — Entitlements par SDK, et le test qui manquait sur les couleurs

Deux changements isolés dans leur propre commit, avant les correctifs de fond :
tous deux vérifiés, donc autant les sortir du lot pour que la bissection reste
simple si la suite tourne mal.

**Fait**

`project.yml` : `CODE_SIGN_ENTITLEMENTS` devient
`CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`. `CineShelf.entitlements` ne contient que
des clés `com.apple.security.*`, qui n'ont aucun sens sur iOS, et un fichier
d'entitlements non vide y force une vérification de provisioning que le profil
gratuit ne satisfait pas. Vérifié sur les binaires : côté iOS plus aucune
entitlement, côté macOS les quatre attendues.

`ColorAssetTests` : quatre tests de plus, qui échouent si une couleur sémantique
retombe sur un défaut. Ils comblent un trou réel. Les tests existants
vérifiaient que les 59 *noms* de `ColorTokens.all` existent dans le catalogue
compilé ; ils ne vérifiaient pas les chaînes écrites à la main dans les
accesseurs de `Colors.swift`. Une faute de frappe y compilait, laissait la liste
de tokens juste, et faisait rendre du transparent à toutes les vues sans qu'un
seul test bronche.

La sonde est l'alpha : `Color(_:bundle:)` ne signale jamais un jeu absent, mais
un jeu absent rend transparent (mesuré : `0.0000/0.0000/0.0000 a=0.00`). Le
second filet compare l'accesseur au jeu résolu par son nom, dans le même
process donc sous la même apparence — la comparaison ne dépend ni du thème ni du
contraste élevé.

Et c'est en écrivant ce test qu'un défaut de `Colors.swift` est apparu : les 23
tokens y sont déclarés **deux fois**, une fois sur
`extension ShapeStyle where Self == Color`, une fois sur `extension Color`. Le
`switch` de `ColorTokens.generated.swift` n'atteint que la seconde — Swift
préfère le membre du type concret au membre d'extension de protocole. Or
`.background(.bgCanvas)`, ce que les vues écrivent, emprunte la première. 46
chaînes à la main pour 23 tokens, dont 23 que rien ne vérifiait. Le test couvre
maintenant les deux chemins ; la déduplication elle-même est le sujet du commit
suivant.

**Vérifications**

Preuve d'échec, en injectant une faute dans les deux accesseurs de `bgCanvas` :

| Contrôle | Résultat |
|---|---|
| Faute injectée sur les deux chemins | 4 échecs, les deux tests mordent |
| `Colors.swift` restauré | identique à `HEAD` |
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| Entitlements du binaire iOS / macOS | aucune / les quatre attendues |
| Tests `CineShelf` (macOS) | 42 tests |
| Tests `DesignSystemCatalog` | 24 tests (20 avant) |
| `swift test` Core / DesignSystem / MediaKit | 79 / 23 / 38 |
| `swiftlint --strict` | 0 violation |
| `swift-format lint` | 0 avertissement |

**Suite**

Les correctifs arbitrés : la clause de recherche de `TitleFilter` (la grille est
vide en permanence), l'audit des tests de `#Predicate`, la déduplication de
`Colors.swift`.

---

## 2026-08-03 (6) — La grille était vide en permanence, et pourquoi 42 tests ne l'ont pas vu

**Le bug**

`App/Navigation/TitleFilter.swift` mettait `title.searchText.contains(search)`
dans le prédicat même quand le terme cherché était vide, sur la foi d'un
commentaire qui affirmait : « une recherche vide donne `contains("")`, toujours
vrai ». C'est vrai de `String.contains("")` en Swift. C'est **faux** de la
traduction que SwiftData en fait : `CONTAINS ''` ne matche aucune ligne en SQL.
La grille des titres était donc vide en permanence, tant que l'utilisateur
n'avait pas tapé quelque chose — quelles que soient les données.

Bissection sur le magasin réel (122 titres), clause par clause :

```
BISECT deletedAt==nil:             121
BISECT archived:                   119
BISECT private:                    122
BISECT searchText.contains(""):      0     <-- ici
BISECT full sans search:           118
```

Les données n'ont jamais été en cause : 122 `Title`, 30 `Person`, 6
`TitleCollection`, 11 `Genre` bien présents, une seule `Library`, `sortName` et
`searchText` propres. `DemoCatalog` faisait son travail.

**Pourquoi les tests étaient verts, et c'est le vrai sujet de la session**

`TitleFilterTests` fetchait sans jamais appeler `context.save()`. Sur des objets
encore en attente, SwiftData évalue le `#Predicate` **en Swift** ; sa traduction
SQL n'est jamais exercée. Le test mesurait donc la sémantique Swift du prédicat,
pas celle du magasin — et un test vert couvrait une app cassée.

Mesuré : en ajoutant `save()` sans corriger le prédicat, **9 tests et 15
assertions** basculent au rouge. La règle est désormais dans `CLAUDE.md` :
tout test de `#Predicate` passe par le magasin, `save()` puis `fetch` ou contexte
neuf, jamais sur du pending. Quand le comportement avant sauvegarde est
lui-même le sujet — le dédoublonnage intra-lot d'import — le dire dans le nom du
test et couvrir le chemin SQL ailleurs.

L'audit de tout le dépôt a trouvé trois autres tests dans le même cas :
`targetsAreDistinct` et `librariesDoNotShareGenres` (`GenreRepositoryTests`),
`differentSourcesCreateTwoAssets` (`DeduplicationTests`). Chacun jugeait sa
clause discriminante sur un objet non sauvegardé. Corrigés, ils restent verts :
ils étaient mal testés, pas cassés. Le plus inquiétant des trois était
`librariesDoNotShareGenres` — rien ne prouvait que `library?.id` *discrimine* en
SQL, seulement qu'il peut matcher, et un genre qui fuit d'une bibliothèque à
l'autre serait exactement la même classe de bug.

**Filtre par bibliothèque**

Ajouté maintenant, avant que le prompt 18 n'introduise le multi-bibliothèque : la
grille ne filtrait sur aucune `Library` et aurait mélangé les catalogues. Posé
côté SQL, comme critère le plus sélectif.

Une seule traversée `(title.rel?.id ?? noID) == cible` tient dans le budget de
vérification de types, pas deux : les ajouter toutes les deux fait échouer les
*deux* prédicats sur `unable to type-check this expression in reasonable time`.
La collection est donc passée en filtrage mémoire, et rejoint les quatre autres
critères déjà là. Quatre tests nouveaux couvrent ce qui n'en avait aucun : la
recherche vide, la clause de bibliothèque (avec contrôle négatif sur une
bibliothèque inconnue), la collection depuis son nouvel emplacement, et la
**parité des deux prédicats**.

Ce dernier vient de la revue, et il comblait un trou réel : tous les autres tests
laissent la recherche vide, donc seule la branche du `guard` était exercée.
Vérifié en vidant le second littéral de ses quatre clauses de visibilité — la
suite restait entièrement verte. Autrement dit la duplication assumée des deux
prédicats venait de recréer, à côté du bug qu'on corrigeait, la même possibilité
de suite verte sur app cassée : un titre à la corbeille, archivé, privé ou d'une
autre bibliothèque réapparaissait dès qu'un terme était tapé. Le test compare
maintenant le résultat sous un terme qui matche tout au résultat sans recherche,
et il mord.

**Colors.swift : 46 chaînes pour 23 tokens**

Les accesseurs sémantiques étaient écrits à la main **deux fois** — une sur
`extension ShapeStyle where Self == Color`, une sur `extension Color`. Swift
préfère le membre du type concret au membre d'extension de protocole, donc le
`switch` généré ne traversait que la seconde, alors que `.background(.bgCanvas)`
emprunte la première. Vérifié par expérience : une faute de frappe dans la
version `ShapeStyle` passait tous les tests.

Les deux extensions sont maintenant générées par `scripts/generate-colors.py`
depuis `colors.tokens.json`, et délèguent à un bloc `extension ColorTokens` qui
est le **seul** endroit où la chaîne d'un token résout une couleur. Les deux
chemins d'appel restent ergonomiques (`Color.bgCanvas` et `.background(.bgCanvas)`),
et le `.xcassets` régénéré est identique au précédent.

**Polices : le handler qui avalait tout**

`CTFontManagerRegisterFontURLs` ne retourne rien ; son seul canal d'erreur est le
`registrationHandler`, dont le code jetait le tableau `errors` — et retournait
`false`, ce qui d'après le header CoreText **arrête** l'opération. Il retourne
maintenant `true`, remonte les erreurs dans un `RegistrationReport` lisible, et
les journalise (`subsystem == "fr.feltrin.CineShelf.DesignSystem"`).

Un test échoue si un `.ttf` est absent ou refusé. Vérifié en tronquant
`Archivo-Bold.ttf` : `CTFontManagerErrorDomain 103 : The file is not a
recognized or supported font file format.` Ce qui prouve au passage que le
risque du `false` n'était pas théorique — CoreText appelle bien le handler avec
une erreur.

Le rapport porte aussi `isComplete`, sur remarque de revue. Le header dit que le
handler est appelé « as errors are discovered or upon completion » et « may be
called multiple times » : lire `errors` sans vérifier le `done` reviendrait à
parier sur un appel synchrone. C'est bien ce qui se passe sur macOS, mais ce
n'est pas contractuel, et un rapport lu trop tôt serait vide plutôt que propre.

La police, elle, n'était pas cassée : les quatre fontes s'enregistrent, les
familles résolues sont `Archivo` et `Archivo SemiExpanded`, mesurées à la largeur
de rendu contre deux contrôles négatifs qui tombent tous deux sur
`.AppleSystemUIFont`. Ce qui donnait l'impression de Helvetica, c'est qu'Archivo
n'est appliquée qu'à six endroits, et que les onze titres d'écran passent par
`.navigationTitle`, que `Font.custom` n'atteint pas — comportement voulu, et
maintenant écrit dans `docs/01` §B.2.

**Les couleurs n'étaient pas cassées non plus**

Vérifié de bout en bout : `.process` correct, `actool` exécuté, `Assets.car`
produit et embarqué (macOS et iOS), namespaces préservés, 59/59 noms alignés,
`Bundle.module` résolu, 59/59 couleurs résolues in-process avec les bonnes
composantes. Le fait utile : un token absent ne rend pas « une couleur par
défaut », il rend **transparent**. Donc un fond système visible à l'écran n'est
pas la signature d'un asset non résolu — c'est un conteneur natif qui peint
par-dessus, et `.scrollContentBackground(.hidden)` n'apparaît nulle part dans le
dépôt. À reprendre écran par écran, pas en masse.

**Le reste**

`Profile.accentToken` était une `String` libre que rien ne validait, et
`ProfileSession` retombait silencieusement sur l'accent par défaut dès qu'elle ne
correspondait à rien. Typée par `ProfileAccent`, persistée en `accentRaw` :
le `switch` de `accentColor` est désormais exhaustif. Le repli n'a pas disparu
pour autant — il a changé de place, et c'est mieux ainsi : il est dans
`Profile.accent`, seul point d'entrée d'une valeur venue du magasin, et il ne
peut plus se déclencher que sur un enregistrement écrit par une version future
et rapatrié par CloudKit. Le commentaire le dit maintenant, au lieu de prétendre
qu'un jeton invalide n'existe plus.

Deux cas seulement dans l'énumération, et `accent/soft` en est exclu : c'est un
lavis de fond à alpha 0,10 en clair, jusqu'à 0,22 en contraste élevé. Comme
`ProfileAccent` est `CaseIterable` et qu'un `Picker` sur `allCases` est
exactement ce que le prompt 18 va construire, l'y laisser aurait livré un
réglage « teinte douce » qui rend l'accent invisible. Si de vraies couleurs par
profil sont voulues, il faudra étendre la palette dans `colors.tokens.json`, pas
détourner les rôles existants — c'est au tableau des écarts.

Changement visible à signaler : sans profil ouvert, la teinte passe de
`accentText` à `accentSolid`. C'est le défaut du modèle (`ProfileAccent.solid`),
donc l'écran de sélection montre désormais la teinte qu'un profil neuf portera.

Règle de version de schéma écrite dans `docs/02` §7 et `CLAUDE.md` :
`versionIdentifier` reste à `1.0.0` pendant tout le développement, tout
changement de modèle est libre, le magasin est effaçable. Le gel a lieu au
prompt 20, à l'import des vraies données, et devient un point de contrôle de ce
prompt. La commande `swift-format` de `CLAUDE.md` passe par `xcrun` : elle
n'était pas exécutable telle quelle.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| Tests `CineShelf` (macOS) | 45 tests (42 avant) |
| Tests `DesignSystemCatalog` | 25 tests (24 avant) |
| `swift test` Core / DesignSystem / MediaKit | 79 / 24 / 38 |
| `swiftlint --strict` | 0 violation / 129 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Preuve d'échec — `save()` sans corriger le prédicat | 9 tests, 15 assertions au rouge |
| Preuve d'échec — faute de frappe dans un accesseur de couleur | 4 assertions, les deux chemins |
| Preuve d'échec — `.ttf` tronqué | erreur CoreText 103 remontée |
| Preuve d'échec — second prédicat vidé de ses clauses | corbeille, archivé, privé et autre bibliothèque fuient |

**Revue**

Une revue du diff a trouvé cinq points importants, tous corrigés : la branche
« recherche non vide » non couverte, deux affirmations fausses que j'avais
ajoutées à `docs/01` (« toutes les vues forcent `.inline` » — quatre ne le font
pas ; et §B.1 montrait encore les accesseurs écrits à la main avec un `.ds()` qui
n'existe plus), `accent/soft` inutilisable en teinte, et deux commentaires du
même diff qui se contredisaient sur le repli d'`accentToken`. Plus le nommage
`accentTokenRaw` aligné sur la convention maison (`accentRaw`/`accent`, comme
`kindRaw`/`kind`), les messages d'échec de `ColorAssetTests` qui citaient encore
`Colors.swift`, et les journaux CoreText repassés en ASCII pur.

**Reste ouvert**

Deux points reportés au tableau des écarts. L'icône de l'app : `AppIcon` déclare
onze emplacements sans un seul fichier, donc `actool` ne produit rien et l'app
n'a pas d'icône — avant le prompt 25.

Et `Typo.sectionTitle`, qui reste inutilisé dans `App/`. L'inventaire a montré
qu'**aucun** en-tête de section n'est sans style : les quatre en-têtes de contenu
de `TitleDetailView` portent déjà `railLabelStyle()`, et tout le reste est du
`Section` natif de `Form`, `List` ou `Menu`, que le système stylise et qu'il ne
faut pas toucher. Les promouvoir ne serait donc pas un branchement mais un
changement de hiérarchie visuelle. Décision actée : on attend le prompt 16, qui
écrit Accueil, Collections et Genres, et on posera alors le rôle une fois dans un
`sectionTitleStyle()` plutôt que sur chaque appelant.

**Suite**

Prompt 12 — Recherche + Spotlight.

---

## 2026-08-03 (7) — Bascule de direction artistique, et le plan repris par la logique

Session de documentation et de planification : **aucune ligne de Swift**.

**Le ménage dans `docs/`**

`06-BRIEF-DESIGN.md` entre. Quatre documents sortent vers `docs/_archive/`, chacun
avec un bandeau qui dit pourquoi :

| Avant | Après | Motif |
|---|---|---|
| `01-DESIGN-SYSTEM-APPLE.md` | `_archive/OBSOLETE-design-system-productivite.md` | mauvais registre : app de bureautique Apple au lieu d'app média |
| `05-ROADMAP-NATIF.md` | `_archive/OBSOLETE-roadmap-natif.md` | remplacé par le tableau d'état de `PROMPTS.md` |
| `GUIDE-EXECUTION.md` | `_archive/OBSOLETE-guide-execution.md` | idem |
| `SETUP.md` | `_archive/SETUP.md` | l'installation est faite (`03fff62`) |

`docs/README.md` est réécrit : il décrivait huit documents dont trois sont
maintenant archivés, et pointait `GUIDE-EXECUTION.md` comme point d'entrée.
`CLAUDE.md` perd la référence au `01`, gagne celles du `06` et de `PROMPTS.md`, et
porte désormais la règle d'interface — **aucun travail visuel nouveau sans accord
explicite**.

Le `README.md` annoncé dans `~/Downloads` n'y était pas : seuls
`06-BRIEF-DESIGN.md` et une copie de `03-FONCTIONNALITES-NATIF.md` (identique à
celle du dépôt) s'y trouvaient. Le `README` a donc été réécrit depuis l'état réel
du dépôt, pas recopié.

**La bascule**

Une section de `PROMPTS.md` acte la séparation entre ce qui est mort et ce qui
survit du `01`. Obsolète : les valeurs de palette, le choix typographique,
l'anatomie des composants, l'architecture de navigation, tout chrome système par
défaut. Conservé, parce que c'est de l'architecture et non de l'esthétique : les
trois niveaux de tokens, l'Asset Catalog et ses quatre apparences,
`generate-colors.py`, `ColorAssetTests`, la couture par modèles de présentation,
les règles de lint, et la matrice `layout × size` — qui est une fonctionnalité de
l'app, pas une décoration.

L'interface des prompts 10 et 11 devient un **banc d'essai** : on l'exerce, on ne
l'investit plus, on ne la supprime pas. Noté au tableau des écarts, qui gagne aussi
la règle générale : les écarts d'apparence attendent le design, les écarts de
logique se corrigent normalement.

**Le plan, repris par la logique**

Chaque prompt restant est coupé en deux : une part LOGIQUE (aucun SwiftUI,
testable, insensible au design) et une part VUES, à écrire une seule fois contre le
design final. Résultat : **19 tâches `L1`…`L19`** et **12 tâches `V1`…`V12`**, avec
objectif, docs à lire, dépendances et état.

L'inventaire de départ comptait douze entrées ; sept manquaient et ont été
ajoutées : les requêtes interrogeables (`L1`, qui absorbe l'écart des cinq critères
filtrés en mémoire), la suggestion de casting (`L9`), l'édition en masse (`L10`),
l'archive `.cineshelfarchive` (`L12`), la maintenance et la corbeille (`L16`), les
sélections éditoriales et les statistiques (`L18`), et le déménagement du store de
préférences d'affichage hors d'une vue (dans `L1`).

`L1` passe en tête pour une raison de calendrier et non de goût : elle touche le
schéma, donc elle doit être faite **avant** le gel de `versionIdentifier` au
prompt 20.

**Le plan arbitré, et le critère qui a tout réordonné**

Les 7 ajouts et les deux choix contestables (`L1` en premier, `L8` non découpée)
sont validés. Un critère s'est ajouté à l'arbitrage, qui n'était pas dans ma
proposition et qui change l'ordre : **la nouvelle direction artistique ne pourra
être jugée que sur les vraies affiches**, pas sur des dégradés générés. Les vraies
affiches arrivent avec `L13`. Le chemin le plus court vers `L13` est donc le chemin
le plus court vers la capacité à valider le design.

Le chemin critique, désormais en tête du tableau :

```
L1 → L2 → L3 → L4 → L10 → L11 → L12 → prompt 2 → L13
```

Les onze autres — `L5` `L6` `L7` `L8` `L9` `L14` `L15` `L16` `L17` `L18` `L19` —
deviennent des **tâches d'appoint** : aucune ne retarde `L13`, aucune n'en dépend.

Le **prompt 2**, le dump du bundle depuis l'app web, cesse d'être une précaution
« avant le 20 » pour devenir une **dépendance dure** de `L13` : sans bundle, rien à
importer, et la direction reste injugeable. Il se fait dans l'autre dépôt.

**Trois vérifications demandées**

*Le fil d'activité.* Il n'était nulle part : `L18` couvrait le hero, les rayons, Ma
liste et les statistiques, pas la lecture d'`ActivityEntry`. Vérifié dans le code —
`ActivityRecorder` écrit, **personne ne relit**, aucune requête sur `ActivityEntry`
dans tout le dépôt. La lecture chronologique est donc ajoutée explicitement à
`L18` : ordre décroissant, fenêtrage, regroupement par jour, libellés depuis
`ActivityDescribing`, et les entrées dont la cible a disparu doivent rester lisibles.

*`L17` et CloudKit.* Noté sur sa fiche et dans les deux tableaux : la tâche peut
être écrite et couverte en simulation, mais **rien n'aura tourné contre un vrai
conteneur** avant le prompt 21 — ni les notifications réelles du coordinateur, ni
leur charge utile, ni leur ordre, ni les cas de compte et de quota. Au vert, elle
vaudra « écrite et simulée », pas « vérifiée ». Elle reste ouverte.

*`MediaSlot.backdrop`.* Il **est** lu : `TitleFormat.backdropAsset` →
`AssetURL.backdrop` → le hero 16/9 de `TitleDetailView`. Et `MediaThumbnail`
remplit déjà son cadre (`scaledToFill` dans un `aspectRatio`), donc pas de bandes
noires aujourd'hui. Deux réserves inscrites au tableau des écarts : `crop(for:)`
n'a **aucun appelant hors du modèle** — le remplissage est un cadrage centré, le
recadrage choisi n'est pas appliqué — et sans média `backdrop`, la fiche n'affiche
aucun hero au lieu de se replier sur la jaquette. À trancher avec la nouvelle
direction.

---

## 2026-08-03 (8) — Fin de session : où on en est, et ce qu'il faut pour reprendre ailleurs

Session de documentation uniquement, close proprement pour une reprise **sur une
autre machine**.

**Où on en est**

Onze prompts faits (4, 5, 6, 13a, 7, 8, 8bis+9, 10, 11 et trois passes de
correction). Le modèle, les repositories, le pipeline médias logique, le design
system intégré, la coquille de navigation et l'écran des Titres tournent, verts sur
iOS et macOS. `docs/` est à jour et le plan est arbitré.

La direction artistique est en refonte : l'interface des prompts 10 et 11 n'est plus
qu'un **banc d'essai** pour exercer la logique.

**La prochaine tâche : `L1`**

Rendre les critères de filtre interrogeables en SQL (dénormaliser collection, genres
et personnes créditées comme `searchText`), ajouter les filtres de personnes et de
galerie, et sortir le store de préférences d'affichage de `TitlesView` vers
`CineShelfCore`. Fiche complète dans `docs/PROMPTS.md`.

**Elle n'a pas été commencée, et c'est volontaire :** elle touche le schéma, et une
modification de modèle laissée à moitié faite au milieu d'un changement de machine
est exactement le genre de chose qui coûte une journée à démêler. Le magasin local
est effaçable (`versionIdentifier` à `1.0.0`), donc elle est gratuite aujourd'hui et
le restera au prochain démarrage.

**Ce qui n'est pas dans Git**

Rien de matériel. Le projet Xcode (`xcodegen generate`), les `.build/` et le
`DerivedData` se reconstruisent ; `Package.resolved` n'a rien à résoudre puisqu'il
n'y a aucune dépendance externe ; `.claude/settings.local.json` ne porte que des
autorisations locales. Les polices Archivo, `colors.tokens.json` et les 73 fichiers
de `Colors.xcassets` **sont** versionnés : aucun asset à retélécharger, aucun
transfert de fichier à faire.

La séquence complète depuis un clone est dans le `README.md` de la racine, section
« Reprise depuis un clone, sur une machine neuve ».

**Poussé**

Neuf commits attendaient sur `main` depuis `ee3b88c` — les sessions précédentes
avaient commité sans pousser. Tout est maintenant sur `origin/main`.

**Suite**

`L1`.

---

## 2026-08-03 (9) — `L1` : les filtres passent en SQL, et le plafond de `#Predicate`

Reprise sur une machine neuve. Rien à réinstaller : `xcodegen generate`, build macOS
vert, on enchaîne. `L1` découpée sur un critère plus net que le mien — **est-ce que
ça touche au schéma ?** — ce qui la ramène à titres + personnes et sort la galerie et
les préférences d'affichage dans `L1 bis`, insérable n'importe quand.

**Ce qu'on croyait, et ce qui était faux**

L'écart « cinq critères filtrés en mémoire » disait que `#Predicate` sature « au-delà
de ~6 clauses » à cause des **traversées de relation optionnelle** : `(x.rel?.id ??
sentinelle) == cible`. C'était mesuré, et c'était vrai — mais incomplet, et
l'incomplétude changeait tout le plan.

Dénormaliser les identifiants dans `Title.filterKeys` supprime bien toutes les
traversées. **Ça n'a pas suffi.** Le prédicat à douze clauses a demandé 36 s de
vérification de types, puis échoué.

Trois hypothèses testées, dans cet ordre :

1. *Les traversées sont le coût.* Faux — le prédicat n'en contient plus aucune et
   échoue quand même.
2. *C'est la profondeur de la chaîne `&&`, qui penche à gauche.* Faux — un arbre
   équilibré échoue aussi (22 865 ms).
3. *C'est le `@Model`.* Vrai. Les mêmes douze clauses sur un `struct` nu mimant les
   mêmes colonnes passent sous 200 ms. SwiftData ajoute ses propres surcharges de
   `PredicateExpressions`, et l'inférence explose.

Le plafond réel, sur `Title` : **cinq clauses**. Et cinq coûtent déjà 1 328 ms.

| Clauses | Vérification de types | Résultat |
|---|---|---|
| 4 | < 200 ms | passe |
| 5 | 1 328 ms | passe |
| 6 | 10 503 ms | échoue |
| 12 | 30 012 ms | échoue |

**La sortie**

Une macro d'expression doit tenir dans une seule expression : l'inférence porte donc
sur l'arbre entier d'un coup. Du code manuel, lui, a droit aux instructions. On
construit donc **le même arbre `PredicateExpressions`** — mêmes nœuds `build_*`, ceux
que la macro aurait expansés — coupé par des `let` intermédiaires. Chaque clause
devient un problème d'inférence indépendant et minuscule. Douze clauses : sous 200 ms.

C'est verbeux, et c'était le prix du filtrage en SQL. La seule alternative était de
continuer à rapatrier le catalogue entier, ce que `L1` avait pour objet de supprimer.

Vérifié, et pas supposé, que SwiftData traduit bien cet arbre : fetch depuis un
`ModelContext` neuf, sans aucun objet en attente, donc forcément servi par SQLite.

**Ce que ça a coûté ailleurs**

`refreshDerived()` lit maintenant les relations. C'est le seul invariant du modèle
qu'aucun type ne protège : une relation mutée sans rafraîchissement laisse
`filterKeys` en arrière et le filtre devient faux **sans que rien ne casse**. Les
chemins sont couverts un par un, par le magasin, dont celui qui n'a pas de garde-fou
possible — un `Credit` inséré depuis la personne. Un test documente aussi le piège à
l'envers, pour que le coût de l'oubli soit écrit quelque part.

Bonne nouvelle vérifiée au passage : aucun code de production ne mute aujourd'hui
`genres`, `credits` ni `collection` — seuls `DemoCatalog` et les tests. La fenêtre
était donc la bonne.

Et un non-événement qui méritait d'être affirmé : **renommer un genre n'invalide
rien**, puisqu'on stocke des identifiants. Un test le dit, parce que « rien à faire »
est le genre de conclusion qu'on croit à tort avoir oubliée.

**Les personnes**

`PersonFilter` dans `CineShelfCore` — type neuf, donc dans `Packages/`, contrairement
à `TitleFilter` qu'on complète là où il vit. Rôles dénormalisés par nécessité :
`roleValues` est un `[String]`, persisté en binaire, non interrogeable.

L'âge, non. Un vivant vieillit : un âge stocké serait faux dès le lendemain, sans
alerte. Deux branches, donc — bornes de `birthDate` calculées à la requête pour les
vivants, `ageAtDeath` dénormalisé (immuable par nature) pour les défunts. Il faut les
deux : quelqu'un mort jeune il y a longtemps aurait aujourd'hui l'âge d'un senior. Le
raisonnement est écrit dans le code, parce que « simplifier » en dénormalisant l'âge
est exactement ce qu'un lecteur futur tentera. Un test le rend vérifiable : la même
ligne, jamais réécrite, change de tranche douze ans plus tard.

Le prédicat prend `now:` en paramètre plutôt que de lire l'horloge — un test de borne
d'âge doit pouvoir fixer le jour, sinon il change de sens à chaque anniversaire de sa
fixture.

**Les mesures, et les deux seuils**

Sur 5 000 titres, douze critères actifs, magasin en mémoire, moyenne sur 5 itérations
après une passe à blanc :

| Requête | Durée | Titres rendus |
|---|---|---|
| Prédicat complet | **5,3 ms** | 32 |
| Aucun filtre | **248 ms** | 5 000 |

Le budget de `04 §4` est de 50 ms : on est dix fois dessous. Les assertions ne sont
**pas** calées sur le budget mais sur la mesure — 25 ms, soit cinq fois 5,3 ms. Un
seuil au budget laisserait passer une régression d'un facteur neuf en silence ; un
seuil à 6 ms clignoterait sur un runner partagé.

Les 248 ms sont un résultat en soi : ce n'est pas le prédicat qui coûte, c'est le
nombre d'objets matérialisés. L'écart « pas de `fetchLimit` progressif » a maintenant
son chiffre. Et le rapport de 46 entre les deux requêtes est le test qui attraperait
un retour au filtrage en mémoire — s'il tombait à 1, c'est qu'on relit tout.

Aucun `#Index` ajouté : un index B-tree n'aide pas un `CONTAINS` à joker initial, et
la marge ne le réclame pas. `docs/02` §6 demandait « où mesuré utile » — mesuré, pas
utile.

**Documents**

`docs/02` gagne une section §5 bis (`filterKeys`) et le tableau du plafond de
`#Predicate` : c'est une contrainte de plateforme, elle appartient au document qui
fait foi, pas à un commentaire de code. `CLAUDE.md` : « un commit par tâche » devient
« un commit par sujet cohérent » — l'intention était la bissectabilité.

**Ce qui reste ouvert**

`L1 bis` (galerie, préférences d'affichage), avec deux pièges déjà notés sur sa fiche :
« orphelin » écrit `asset.attachments?.isEmpty ?? true` ramènerait la traversée qu'on
vient de chasser, et les énumérations dupliquées entre `CineShelfCore` et
`DesignSystem` réclament un test d'égalité des `rawValue`.

**Suite**

`L2` — service de recherche.

---

## 2026-08-03 (10) — CI réparée, et l'invariant des relations fermé à clé

Quatre sujets demandés avant `L2`, plus le push des quatre commits de `L1`.

**La CI était rouge depuis `48c3dc8`, sur deux causes distinctes**

1. `swift-format: command not found`, exit 127. Il est livré avec la toolchain Xcode
   mais **n'est pas dans le PATH** : il faut `xcrun`. Le défaut ne se voyait pas parce
   que la commande documentée dans `CLAUDE.md` utilisait déjà `xcrun` — seul le
   workflow s'en passait.
2. `« Performance : 200 vignettes »` assenait les budgets de `docs/04` §4 tels quels.
   Le runner GitHub est virtualisé et son accélération d'image est absente
   (`AppleM2ScalerParavirtDriver` échoue au démarrage), donc le décodage retombe sur
   un chemin logiciel :

   | Chemin | En local | Sur le runner |
   |---|---|---|
   | décodage à froid | 15,2 ms | 266,5 ms |
   | relecture disque | 2,5 ms | 15,8 ms |

   Un facteur 17 sur le même code. Le test assène maintenant des **rapports** —
   indépendants de la machine, et c'est eux qui portent le sens, puisqu'un cache qui
   cesserait d'être lu les ramènerait à 1 — plus des plafonds absolus calés sur
   l'environnement le plus lent où il tourne. Le budget d'UX se vérifie sur appareil
   avec Instruments, comme `docs/04` §4 le demande lui-même.

`CLAUDE.md` gagne la règle : **une CI rouge bloque la tâche suivante.** Une CI rouge
que personne ne regarde apprend à ignorer le signal.

**Le pari de `PredicateExpressions`, documenté**

C'est l'endroit le plus fragile du dépôt et ça n'était écrit nulle part. Le
raisonnement complet est maintenant dans `predicateClause(active:_:)`, avec des
renvois depuis `TitleFilter` et `PersonFilter` :

- les `build_*` sont l'interface de la macro, leur nommage dit qu'elles ne sont pas
  destinées à l'usage direct ;
- une rupture d'API **ne compilerait pas** — échec bruyant, immédiat, trois fichiers ;
- le vrai risque est ailleurs : que SwiftData cesse de **reconnaître** la forme et
  retombe en mémoire. Le code compile, tous les tests de critères restent verts — ils
  vérifient *quels* titres sortent, pas *où* le filtrage a eu lieu — et l'app se remet
  à rapatrier cinq mille lignes. Aucune erreur.
- le seul garde-fou est
  `TitleFilterPerformanceTests.selectiveFilterDoesNotScanEverything`. Il est nommé
  dans le commentaire, et le test porte lui-même l'avertissement de ne pas le
  supprimer au motif qu'il « mesure des performances » : il ne mesure pas une
  vitesse, il prouve une forme.

**L'invariant des relations, rendu impossible à violer**

Il était sûr par accident : aucun code de production ne mutait `genres`, `credits` ni
`collection`. `V4` et `V5` vont écrire exactement ce code, donc la porte se ferme
avant qu'on prenne l'habitude de passer par la fenêtre.

- Mutateurs dans les repositories, seules portes autorisées : `setCollection`,
  `setGenres`, `move`, `addCredit`, `removeCredit` sur les titres ; `setGenres`,
  `setRoles`, `move` sur les personnes. Chacun délègue à `update(_:_:)`, qui appelle
  `refreshDerived()` et journalise.
- Règle SwiftLint `no_relation_write_outside_core` : écrire dans `.genres`,
  `.credits`, `.collection` ou `.library` hors de `CineShelfCore` est une erreur.
  Exclusions assumées et documentées dans le fichier — les tests et `DemoCatalog`
  posent les relations à la main exprès.
- Règle `no_predicate_outside_core` : `#Predicate` hors de `CineShelfCore` est une
  erreur, parce que le plafond de cinq clauses ne se devine pas et qu'une vue n'est
  couverte par aucun test. Les six prédicats qui vivaient dans des vues sont
  rapatriés dans `EntityQueries` et couverts — **l'écart « prédicats de production
  sans couverture » se réduit à un seul cas**, `Bootstrap.existingProfile`, qui est
  structurellement inatteignable.

Les deux règles ont été **vérifiées par une sonde** : un fichier temporaire portant
les violations, pour s'assurer qu'elles mordent. Une règle de lint qui ne déclenche
jamais ne protège rien, et rien ne le signale.

**Un vrai bug attrapé au passage**

`removeCredit` échouait sur son propre test. `ModelContext.delete(_:)` ne retire pas
l'objet des relations inverses avant la sauvegarde : `title.credits` contenait encore
le crédit supprimé, donc `refreshDerived()` recomposait `filterKeys` **avec** la
personne qu'on venait de décréditer, et le titre restait retrouvable par un filtre sur
elle. Il faut détacher (`credit.title = nil`) avant de supprimer. C'est exactement le
genre de faux positif silencieux que les mutateurs sont censés empêcher — et il était
déjà là, dans la première version des mutateurs eux-mêmes.

**Suite**

`L2` — service de recherche.

---

## 2026-08-03 (11) — `L2` : service de recherche, et `TitleFilter` descend dans le paquet

**Mesuré avant d'écrire, comme en `L1`**

`TitleCollection` et `SavedLink` n'ont pas de `filterKeys` : la portée de bibliothèque
exige donc une traversée `library?.id`, la construction la plus chère pour le
vérificateur de types. Cinq clauses — corbeille, archivage, privé, bibliothèque,
terme — écrites avec `#Predicate` :

| Prédicat | Vérification de types |
|---|---|
| Collections, macro | **7 253 ms** |
| Signets, macro | **7 446 ms** |
| Collections, arbre manuel | **< 200 ms** |

Elles compilaient, mais à une clause de l'échec et pour quinze secondes ajoutées à
chaque build propre du paquet. Arbre manuel, donc, comme `TitleFilter` et
`PersonFilter`.

**Décision de ne pas leur ajouter de `filterKeys`.** La dénormalisation a un coût
permanent — un invariant de plus à maintenir à chaque écriture, celui qu'on vient de
verrouiller à coups de règles de lint — et ces deux tables comptent des dizaines de
lignes, pas des milliers. La jointure ne se paie qu'en SQL, où elle est négligeable ;
le plafond de type-check se paie à chaque compilation. L'arbre manuel règle le second
sans introduire le premier.

Détail utile pour la suite : une chaîne optionnelle s'écrit `build_flatMap` dans
l'arbre, pas un `KeyPath` imbriqué. La forme se lit en dumpant l'expansion de la macro
(`-Xfrontend -dump-macro-expansions`), ce qui est la bonne façon de retrouver n'importe
quel nœud.

**`TitleFilter` descend dans `CineShelfCore`**

Conséquence de la règle validée — un seul chemin de visibilité. La recherche doit
masquer exactement ce que la grille masque, et `CineShelfCore` ne peut pas dépendre de
`App`. Le filtre descend donc dans le paquet et devient `public`.

Deux effets à noter. `TitleSortField.symbol` rend des noms de SF Symbols depuis le
paquet : même motif que `ProfileAccent`, dont le `rawValue` est un nom de jeu de
couleurs — désigner une ressource du design system sans importer SwiftUI. Et
`project.yml` listait explicitement `App/Navigation/TitleFilter.swift` dans la cible de
tests pour accéder au type `internal` ; l'entrée disparaît, il arrive maintenant par la
dépendance de paquet.

**`SearchOutcome` : deux états, et le type qui les impose**

La chaîne vide ne renvoie rien — un champ vide doit montrer les recherches récentes,
renvoyer tout matérialiserait 5 000 objets (248 ms mesurées en `L1`), et la grille
existe déjà pour parcourir le catalogue.

Mais « `SearchResults` vide veut dire qu'on n'a rien saisi » comme **convention** se
perdrait : quelqu'un écrit `if results.isEmpty` et confond les deux cas. C'est donc
dans le type — `.idle` ou `.results(SearchResults)`. Deux états et non trois : « aucune
correspondance » se déduit de `SearchResults.isEmpty`, donc rien ne peut se
désynchroniser, et le compilateur force `V1` à écrire les deux branches. La décision
appartient au service, pas à l'appelant : la règle vit à un seul endroit. L'espace seul
est `idle` aussi — le retrait des espaces précède le test de vacuité, et un test le
vérifie sur quatre formes de blanc.

**Ce que le service ne fait pas**

Pas d'anti-rebond. C'est une fonction, appelable à chaque frappe ; la vue décide quand
l'appeler. Le mettre ici le rendrait intestable et imposerait un rythme à des appelants
sans frappe à amortir — l'App Intent de `L19`. Noté au tableau des tâches `V`.

**Mesures**

Portée `.all` sur 5 000 titres, 500 personnes, 50 collections, 50 signets — huit
requêtes, deux par type (une tranche, un compte) : **8,3 ms**, et 11,1 ms sur un second
passage. Budget de `04 §4` : 50 ms. Seuil posé à 40 ms, environ quatre fois la mesure
haute.

Un second test comparait `.titles` à `.all` pour prouver que la portée restreint
vraiment la requête. Mesuré : 6,0 contre 11,1 ms, rapport de **1,85** — trop mince pour
être assené sans clignoter. Il est retiré, et la raison écrite à sa place : la preuve
que la portée restreint la requête est **catégorique**, elle vit dans
`scopesRestrictTheQuery` où une portée unique rend exactement zéro pour les trois
autres types. Une preuve catégorique vaut mieux qu'un rapport fragile — c'est la même
leçon que le facteur 46 de `L1`, appliquée dans l'autre sens.

**Recherches récentes**

Bornées à dix, dédoublonnées sur la forme repliée mais conservant la saisie
(« Amélie » et « amelie » sont la même recherche ; on réaffiche la dernière frappe),
un casier par profil, `UserDefaults` injecté pour que la suite de tests n'écrive pas
dans le domaine de l'app. Jamais `NSUbiquitousKeyValueStore` : ce qu'on a cherché est
une trace d'usage, pas une donnée du catalogue.

**Un piège d'outillage, pas de code**

`swift test` de MediaKit a échoué sur `cannot find 'GenreQuery' in scope` alors que
`CineShelfCore` compilait seul : artefact incrémental périmé, le fichier ayant été
ajouté au paquet pendant que le graphe de MediaKit était en cache. `rm -rf .build` le
règle. La CI fait un checkout neuf, elle n'y est pas exposée.

**Suite**

`L3` — indexation Spotlight. Elle dépend de `L2` pour la normalisation et la notion de
portée, qui sont maintenant en place.

---

## 2026-08-03 (12) — `L3` : indexation Spotlight, et la fuite qu'elle ferme

**Deux corrections de prémisse, relevées avant d'écrire**

`ActivityEntry.payload` **n'existe pas**. Le modèle porte `id`, `actionRaw`,
`entityTypeRaw`, `entityID`, `summary`, `createdAt`. La tâche `L20` (annulation de
l'édition en masse et de la fusion) doit donc *créer* le champ : c'est un changement de
schéma, elle hérite de la fenêtre de gratuité de `versionIdentifier`, et sa fiche le
dit en tête.

Le **handoff de design n'est pas dans le dépôt** — arbre propre, aucun fichier non
suivi. Sa section 7 est donc à corriger quand il arrivera : elle écrit que le contenu
privé serait « géré au niveau du profil, pas du titre », ce qui est faux dans notre
modèle. La correction est appliquée au code et à `docs/04` §6.

**Ce que `L3` ferme vraiment**

« Ne jamais indexer une entité privée » est la moitié facile. L'autre moitié est que
**la sortie de l'index doit suivre l'entrée dans l'état privé** : un titre indexé alors
qu'il était public, puis rendu privé, resterait trouvable depuis l'écran d'accueil du
système. L'app le masque partout correctement, donc rien ne signale la fuite. Même
chose pour la corbeille.

D'où la forme retenue : `sync(_:)` **décide à partir de l'état courant** plutôt que de
recevoir un ordre « indexe » ou « retire ». L'appelant n'a pas à savoir ce qui a
changé ; il lui suffit d'appeler après chaque écriture, et les repositories le font.
Un `update` qui bascule `isPrivate` et un `update` qui corrige une faute de frappe
passent par le même chemin. C'est la même stratégie que pour `filterKeys` : rendre
l'invariant impossible à violer plutôt que de compter sur la discipline.

**`isPrivate` est par entité, pas par profil**

Écrit dans le code parce que c'est contre-intuitif : l'index du système est **unique
pour l'appareil** et n'a aucune notion de profil actif. Indexer selon
`Profile.hidesPrivateContent` ferait dépendre le contenu d'un index partagé du profil
ouvert au moment de l'écriture — donc fuiterait dès qu'un profil permissif touche une
entité privée. La règle est absolue.

**Décision assumée : les entités archivées restent indexées.** `isArchived` masque ce
qu'on garde, ce n'est pas un état de confidentialité, et le contrat de `docs/03` §9 ne
cite que le privé et la corbeille. Un test fixe la décision pour qu'elle ne dérive pas
par accident.

**Le découpage qui rend la tâche testable**

`CSSearchableIndex` n'est pas utilisable sous `swift test` — le binaire n'a pas
d'identifiant de paquet, et une suite de tests n'a rien à écrire dans l'index de la
machine. Le code est donc coupé en deux :

- `SpotlightIndexer` prend **toutes** les décisions et rend des `SpotlightEntry`, des
  valeurs pures ;
- `CoreSpotlightIndex` convertit et passe les appels, sans une seule décision.

Les erreurs de l'index sont avalées volontairement : une indexation est un service
rendu, pas une écriture du catalogue, et l'écriture qui l'a déclenchée ne doit pas
échouer parce que Spotlight reconstruit son index.

**`SpotlightConfiguration` plutôt qu'un singleton.** `docs/04` §3 écrivait
`SpotlightIndexer.shared`, ce qui aurait rendu les repositories intestables. La valeur
est remplaçable, l'app pose la vraie au démarrage, et les tests passent leur propre
indexeur au repository sans toucher à l'état global. Par défaut,
`NullSpotlightIndex` ne fait rien — le chemin d'indexation est alors exercé à vide, ce
qui donne une seule forme de code au lieu de deux.

**L'identifiant est un contrat de compatibilité**

Un item indexé aujourd'hui est encore dans l'index du système après une mise à jour de
l'app. Changer le format sans réindexer rendrait tous les anciens items inouvrables —
visibles dans Spotlight, menant nulle part. C'est écrit sur `SpotlightItemID`, avec le
renvoi vers `reindexEverything(in:)`. Le décodage refuse tout ce qui n'est pas
exactement au format attendu, et ne rien ouvrir est le bon comportement : l'index peut
contenir des items d'une version antérieure.

Le décodage vit dans `CineShelfCore`, comme la fiche l'exige ; la correspondance vers
`AppRoute` reste dans l'app, parce que c'est la seule part qui soit vraiment de l'app.

**Ce qui manque encore, et c'est noté**

Les items sont indexés **sans vignette**. La fermeture qui les fournit existe, mais sa
valeur par défaut ne rend rien : `CineShelfCore` ne peut pas importer `MediaKit`. À
brancher avec `L5`, écart inscrit.

**Suite**

`L4` — mathématiques du recadrage.

---

## 2026-08-03 (13) — `L4` : le recadrage, et la sémantique qui n'était écrite nulle part

**Le trou trouvé en cherchant autre chose**

`docs/02` §2.4 disait ce que `(x, y, zoom)` **remplace** et donnait les bornes, mais
jamais ce que ces nombres **signifient**. Deux lectures étaient plausibles — « point
focal à centrer » ou « pourcentage du jeu restant » — et elles donnent des images
différentes. `L13` aurait importé les 21 colonnes de la v1 de travers sans que rien ne
le signale.

Sémantique arrêtée, et maintenant dans `docs/02` §2.4 : `zoom` est un facteur sur
l'échelle « couvrir » recalculée pour le cadre visé, `x` et `y` sont des pourcentages du
jeu restant. C'est `object-position` sur `object-fit: cover`, ce que la version web
faisait presque certainement — ses colonnes étaient des pourcentages avec 50 pour
défaut.

**La question du stockage, tranchée par le calcul et pas par la lecture**

La matrice du design impose 2:3 et 16:9 pour les mêmes contextes. Faut-il stocker deux
recadrages ? **Non**, et c'est démontrable :

> l'échelle « couvrir » vaut `max(fw/sw, fh/sh)`, donc la largeur visible en pixels
> source vaut `fw / couvrir ≤ fw / (fw/sw) = sw`, et de même en hauteur.

Le rect visible ne déborde donc jamais, le jeu restant n'est jamais négatif, et une
position exprimée en pourcentage de ce jeu est valide **par construction** — pour tout
ratio, y compris un troisième qui apparaîtrait. Un test balaie deux ratios de la matrice
et deux cas extrêmes, sur toutes les positions et tous les zooms : aucun débordement.

Ce que le handoff suggérait par son aperçu simultané 16:9 et 2:3 est donc exact, mais
maintenant on sait *pourquoi*, et la propriété survivra à un changement de matrice.

**Une valeur stockable qui n'est pas applicable**

La v1 laissait le zoom descendre à 50, ce qui laisserait du vide dans le cadre —
interdit par la règle du hero. L'application relève à 100 **sans réécrire la valeur
stockée** : réécrire la donnée de l'utilisateur au premier affichage serait pire que le
défaut qu'on corrige. Deux fonctions distinctes, `clampedZoom` (ce qu'on stocke) et
`applicableZoom` (ce qu'on applique), pour que la distinction ne se perde pas.

`L13` doit compter les recadrages importés à zoom < 100 : c'est le seul endroit où la v1
et le natif peuvent diverger visiblement, et ça se voit dans un rapport, pas à l'œil sur
5 000 titres. Noté sur la fiche.

**`crop(for:)` est branché**

C'était l'autre moitié de la tâche, et l'écart le disait depuis deux sessions : la
méthode existait sans appelant, donc chaque média était affiché centré quel que soit le
recadrage choisi, et `CropContext.hero` n'était lu nulle part.

`App/Media/CropDisplay.swift` est maintenant son unique appelant de production. Trois
contextes sont lus pour de vrai : `.hero` pour le fond de la fiche, `.detail` pour sa
jaquette, `.card` pour les cartes de la grille.

La couture passe par les modèles de présentation, comme `PosterCardModel` :
`DesignSystem` ne connaît ni `MediaCrop` ni `CropContext`, il reçoit trois nombres dans
un `MediaCropDisplay`. Sans `sourceAspect` — un média dont les dimensions ne sont pas
enregistrées, un aperçu de catalogue — le composant retombe sur le remplissage centré
d'avant : moins fidèle, jamais cassé.

Le calcul est écrit deux fois, une en pixels source (`CropGeometry.sourceRect`) et une
en points (`MediaThumbnail.cropped`), et c'est noté aux deux endroits : ils doivent
rester d'accord. `V2` réécrira le composant ; la plomberie, elle, est juste.

**Ce qui reste**

Les vignettes Spotlight ne sont toujours pas alimentées (`L5`), et le hero ne se replie
pas sur la jaquette quand il n'y a pas de `backdrop` — ça, c'est une décision de design,
donc `V2`.

**Suite**

La **fermeture du schéma**, avant `L10` : la fenêtre de gratuité se referme à `L13`, et
la liste se rend avant d'écrire. `L4` n'y ajoute rien — un seul recadrage sert tous les
ratios, donc `MediaCrop` est complet.

---

## 2026-08-03 (14) — Le handoff est arrivé, et trois hashes du tableau ne pointaient nulle part

**Un défaut de suivi, de mon fait**

Les hashes inscrits dans `docs/PROMPTS.md` pour `L2`, `L3` et `L4` désignaient des
commits **orphelins**. Cause : j'écrivais le hash dans le tableau puis je faisais
`git commit --amend` pour l'y intégrer — ce qui change le hash. Le tableau désignait
donc à chaque fois le commit d'avant l'amende, absent de l'historique poussé.

`bc96a3f` → `6ea6a8e`, `6c9e5d9` → `4e696ee`, `2a1f7b8` → `07890db`. Les dix-huit
hashes du document sont maintenant vérifiés atteignables depuis `HEAD`.

C'est exactement le genre de défaut que ce tableau existe pour éviter : il est le seul
suivi d'avancement, et sa valeur tient à ce qu'on puisse revenir au commit qu'il
désigne. `CLAUDE.md` porte maintenant la règle — le hash s'inscrit dans un commit
suivant, jamais par `--amend` — et la ligne de vérification.

**Le paquet de design est là**

`docs/CineShelf design system-handoff.zip`. Direction retenue : **« 2a Plein cadre »** —
noir uniforme, un seul accent ambre, aucune bordure, aucune ombre, aucune translucidité.
L'affiche est l'interface. Huit planches, trois addenda, un README de 33 Ko, l'icône en
SVG.

Il est entré dans le dépôt par mon `git add -A` du commit `L4`, sans que je l'aie
décidé. Ses copies de `03` et `06` sont **identiques aux nôtres** — vérifié — donc pas
de seconde source de vérité aujourd'hui ; elles divergeront le jour où l'un des deux
documents bougera, et c'est noté au tableau.

**Les deux erreurs annoncées, et il y en a deux et non une**

Le §7 « Comportements » écrit :

> **Contenu privé** : géré au niveau du **profil**, pas du titre. Un titre est privé
> parce qu'il appartient à un profil verrouillé par Face ID.

Et le §10 le répète dans les décisions arrêtées. Les deux sont faux dans notre modèle :
`isPrivate` est porté par l'entité, un `Title` appartient à une `Library` et jamais à un
`Profile`, et c'est `Profile.hidesPrivateContent` qui décide de l'affichage.

La conséquence n'est pas théorique. Suivre le handoff rendrait un titre privé visible
dès qu'un profil permissif est ouvert, et — plus grave — indexable dans Spotlight, dont
l'index est **unique pour l'appareil**. C'est la fuite que `L3` a fermée il y a deux
heures.

Ce que le handoff dit du **rendu** reste valable : géométrie exacte de l'affiche, aplat
`private.mask`, `eye.slash` sur la vignette masquée. C'est le déclencheur qui est faux,
pas l'apparence.

**Suite**

La fermeture du schéma, avant `L10`. Le handoff est maintenant lisible, donc son
balayage — « qu'est-ce qu'il suppose qu'on ne stocke pas ? » — peut se faire pour de
vrai.

---

## 2026-08-03 (15) — Fermeture du schéma

Passe transverse avant `L10`, pour ne rien découvrir après le gel. Balayage du handoff
de design (maintenant lisible), de `docs/03`, et des tâches `L` et `V` restantes, avec
une seule question : **qu'est-ce qui suppose une donnée qu'on ne stocke pas ?**

**Six manques, tous ajoutés**

| Ajout | Pour | Ce qui l'a révélé |
|---|---|---|
| `ActivityEntry.payload` | `L20` | Annuler une édition en masse suppose un diff |
| `ActivityEntry.undoneAt` | `L20` | Sans état, rien n'empêche d'annuler deux fois le même lot |
| `ActivityEntityType` | `L18` `L20` | Voir plus bas — le pire des six |
| `MediaAsset.isGenerated` | `L6` | Une mosaïque régénérable ne doit pas écraser une image posée par l'utilisateur |
| `ImportMapping` | `L11` | « Correspondance mémorisable » du handoff, « mappages personnels » de la fiche : aucun support |
| `LegacyRecord` | `L13` | Sans lien vers la source, une migration ne peut être que refaite, jamais réconciliée |

**Le pire des six, parce qu'il était déjà là et faux**

`ActivityEntry.entityTypeRaw` recevait `String(describing: Self.self)` — le nom Swift de
la classe — sous un commentaire affirmant que ça « suit les renommages sans table à
part ». C'est l'exact contraire : renommer un `@Model` change la chaîne, les anciennes
entrées gardent l'ancienne, et le fil se scinde silencieusement en deux seaux. Personne
ne l'aurait vu avant que `L18` filtre par entité ou que `L20` route une annulation.

Le champ est maintenant alimenté par une énumération à `rawValue` choisis stables, sans
chercher à coller aux noms Swift : le cas de `TitleCollection` le montre, son jeton est
`collection` — la classe s'appelle ainsi pour ne pas masquer `Collection` de la
bibliothèque standard, ce qui est un détail de Swift et n'a rien à faire dans le
magasin. Le test qui encodait l'ancienne intention s'appelait « le type d'entité vient
du nom du modèle » ; il affirme maintenant l'inverse, avec la raison.

**Deux non-ajouts, assumés**

Les **champs libres** à l'import de l'addendum 1 sont écartés : un modèle de données
défini par l'utilisateur est une fonctionnalité majeure déguisée en entrée de menu, et
le stocker en blob opaque serait pire que rien — ni interrogeable, ni cherchable, ni
filtrable, alors que l'utilisateur croirait l'avoir sauvé. Contrepartie inscrite sur
`L11` : **le rapport d'import nomme les colonnes ignorées.** Pas de perte silencieuse.

`Genre.colorToken` reste une chaîne libre. La palette n'est pas intégrée, et la question
de fond — des pastilles de genre colorées ont-elles un sens sous une direction à un seul
accent ambre ? — appartient au design. La précaution qui compte est déjà tenue : aucun
repository ne l'expose à l'écriture, donc le défaut de `ProfileAccent` ne peut pas se
reproduire par une vue.

**Ce que la conformité CloudKit a attrapé, encore une fois**

`ImportMapping.library` sans inverse : le miroir refuse le schéma **entier**.
Deuxième cas du projet après `TitleCollection.links`, et là encore
`CloudKitConformanceTests` a nommé la relation fautive au premier lancement. C'est
exactement pourquoi ce test existe et pourquoi il tourne avant chaque commit.

**Deux corrections venues du balayage, hors schéma**

Les **huit contextes d'affichage** de `CardDisplayContext` (`home, titles, people,
collections, gallery, bookmarks, genre, filmography`) sont une invention de
l'intégration. La v1 avait `movies · actors · collections · social · home_movies ·
home_actors · home_collections · home_social`, et le handoff liste exactement ça. Huit
de chaque côté, ensembles différents. La matrice est une fonctionnalité existante, donc
c'est le jeu d'origine qui fait foi — réconciliation inscrite sur `L1 bis`.

La **densité** a deux crans et non trois. `docs/03` annonçait « compacte / standard /
confortable » ; le handoff livre `.dense | .roomy`, et ce sont des écrans dessinés.
`docs/03` est corrigé.

**La fermeture**

Dix-neuf entités. `docs/02` (étape 0 bis), `docs/PROMPTS.md` et `CLAUDE.md` disent
maintenant la même chose : toute modification ultérieure exige un `VersionedSchema`
nouveau et un `MigrationStage`. Pas d'exception pour « ce n'est qu'un champ optionnel ».

Les champs sont posés, **aucune logique ne les consomme** — c'est le travail de `L6`,
`L11`, `L13`, `L18` et `L20`.

**Un piège d'outillage qui récidive**

`swift test` de MediaKit a de nouveau échoué sur « cannot find type in scope » alors que
`CineShelfCore` compilait seul : graphe de build mis en cache avant l'ajout du fichier.
Deuxième fois, donc c'est inscrit dans `CLAUDE.md` au lieu d'être re-diagnostiqué.

**Suite**

`L10` — édition en masse.

---

## 2026-08-03 (16) — Fin de session : où on en est, et ce qu'il faut pour reprendre ailleurs

Session close proprement pour une reprise **sur un autre Mac**.

**Ce qui a été fait aujourd'hui**

Six tâches et une passe transverse, toutes poussées et vertes en CI :

| | |
|---|---|
| `L1` | Requêtes interrogeables — titres et personnes (`eb05149` `e347b11`) |
| — | CI réparée, invariant des relations verrouillé (`8ae4dfb`) |
| `L2` | Service de recherche (`6ea6a8e`) |
| `L3` | Indexation Spotlight (`4e696ee`) |
| `L4` | Mathématiques du recadrage, `crop(for:)` branché (`07890db`) |
| — | Handoff de design extrait et corrigé, schéma fermé (`0d76294`) |

**Trois découvertes qui ont changé le travail, plutôt que de l'accompagner**

1. **`#Predicate` plafonne à cinq clauses sur un `@Model`.** Mesuré : 5 clauses coûtent
   1 328 ms de vérification de types, 6 échouent. Ni le nombre de clauses seul, ni les
   traversées de relation n'expliquaient le mur — c'est le `@Model`. La sortie est de
   construire l'arbre `PredicateExpressions` à la main, ce qu'une macro d'expression ne
   peut pas faire faute de droit aux instructions.
2. **La sémantique de `(x, y, zoom)` n'était écrite nulle part.** Deux lectures
   plausibles donnaient des images différentes, et `L13` aurait importé les 21 colonnes
   de la v1 de travers sans que rien ne le signale.
3. **`entityTypeRaw` recevait le nom Swift de la classe**, sous un commentaire affirmant
   l'inverse de ce que faisait le code. Un renommage de `@Model` aurait scindé le fil
   d'activité en deux seaux, en silence.

**Le schéma est fermé**

Dix-neuf entités. Toute modification ultérieure exige un `VersionedSchema` nouveau et un
`MigrationStage`, sans exception. Six manques ont été comblés avant fermeture, et aucune
logique ne les consomme encore — c'est le travail de `L6`, `L11`, `L13`, `L18` et `L20`.

**En attente de toi**

- **Cinq questions chez Claude Design**, consolidées dans `docs/PROMPTS.md` : portée de
  l'apparence claire, quatre valeurs manquantes au système de couleur, `Genre.colorToken`,
  trois décisions sur l'icône, passe sur les réglages. Aucune n'empêche les tâches `L`
  d'avancer ; **toutes empêchent les tâches `V`**.
- **Le prompt 2** — le dump du bundle depuis le dépôt web — reste la dépendance dure de
  `L13`, et donc de tout ce qui permettra de juger le design sur de vraies affiches.
- Les trois addenda, eux, **sont livrés** : ce n'est pas à attendre.

**Ce qui n'est pas dans Git, et pourquoi ce n'est pas grave**

Rien de matériel. Le projet Xcode se régénère (`xcodegen generate`), les `.build/` et
`DerivedData` se reconstruisent, `Package.resolved` n'a rien à résoudre puisqu'il n'y a
aucune dépendance externe, et `.claude/settings.local.json` ne porte que des
autorisations locales. Les polices, la palette et les dix-neuf fichiers de
`docs/design/` **sont** versionnés : aucun asset à retélécharger, aucun transfert de
fichier à faire.

**Suite**

`L10` — édition en masse. Elle ne dépend de rien, et le schéma lui donne déjà de quoi
journaliser ce qu'elle fera : `ActivityEntry.payload` et `undoneAt` attendent `L20`, qui
la suit immédiatement.

---

## 2026-08-04 — Un clone périmé de treize commits, et trois arbitrages de design

**L'incident, parce qu'il est instructif**

Reprise sur une nouvelle machine. Le dossier existait déjà, donc ni clone ni `git pull` :
j'ai travaillé une session entière sur un dépôt qui datait d'avant `L1`. Treize commits
de retard, dont la **fermeture du schéma** et la livraison de `docs/design/`.

**Rien ne l'a signalé.** `xcodegen generate` a marché, le build macOS est passé du
premier coup, le tableau d'état paraissait cohérent - il l'était, pour la version du
31 juillet. Le seul indice est une phrase que j'ai écrite sans y penser : « `L1` reste
en tête du chemin critique », alors que `L1` à `L4` étaient faites et poussées.

Un dépôt en retard se travaille sans rien signaler. C'est ce qui le rend plus dangereux
qu'un dépôt en avance, qui finit toujours par buter sur un `push` refusé. La règle est
maintenant dans `CLAUDE.md`, section « Reprise de session » : `git fetch`, puis **les
deux** sens du `log`, et le second avant d'écrire une ligne.

Le commit posé sur la base périmée (`ab95dcd`) a été **rebasé**, pas fusionné :
`7d5422f` sur `2063248`. Deux conflits, tous deux des ajouts adjacents - la ligne `V5`
du tableau des vues (leur version avait gagné `L20` sur `V6`, la mienne une mention sur
`V5` : les deux sont gardées) et la fin du journal. L'entrée que j'avais écrite pour
cette session a été jetée plutôt que fusionnée : elle affirmait que `docs/design/`
n'existait pas et que `L1` était la suivante. Fausse de bout en bout, et sur le sujet
même de l'incident.

**Trois arbitrages, désormais fermés** (section « Arbitrages tranchés » de `PROMPTS.md`) :

1. **Portée de l'apparence claire.** Gestion selon l'apparence système ; accueil, fiches
   et galerie forcés en sombre. C'est la recommandation du §10 du handoff, et la
   convention d'Apple sur ses surfaces de visionnage. Trois implications inscrites : les
   quatre apparences de l'Asset Catalog restent, le forçage se pose par écran et non
   globalement, et **tout jeton partagé garde une valeur claire renseignée**.
2. **Doublons du multi-sélecteur.** `GenreRepository.findOrCreate` dédoublonne déjà sur
   `nameKey` : le §10.5 du handoff décrit un problème que la logique a déjà résolu. Reste
   la part visible, inscrite dans `V5`.
3. **Passe sur les réglages.** Reportée après les prompts 21 et 22.

Les deux premières et la dernière quittent le tableau « En attente de Claude Design »,
qui ne compte plus que trois questions ouvertes : les quatre valeurs de couleur,
`Genre.colorToken`, et les trois décisions sur l'icône.

**Le troisième implication a immédiatement servi**

En relisant l'arbitrage 1 contre la planche 8 : **`bg.inset` n'a qu'une valeur sombre**
(§4.1, colonnes clair et HC à `—`). Or c'est le fond de la console et des panneaux de
gestion (blocs 7a-7g, 8a) - précisément les surfaces qui suivent désormais l'apparence
système. Il lui manque donc trois apparences sur quatre. C'est un cinquième manque du
système de couleur, révélé par l'arbitrage et non par le handoff, et c'est exactement le
genre de trou qu'une intégration hâtive graverait dans le catalogue d'assets.

`bg.viewer`, lui, est identique dans les quatre apparences et c'est **voulu** : la
visionneuse reste sombre en apparence claire, comme la vue plein écran d'Aperçu. Les deux
jetons se ressemblent, leur traitement est opposé.

**Vérifications après rebase**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| Tests `CineShelf` (macOS) | `** TEST SUCCEEDED **` |
| Tests `DesignSystemCatalog` (macOS) | `** TEST SUCCEEDED **` |
| `swift test` Core / DesignSystem / MediaKit | 159 / 24 / 38 |
| `swiftlint --strict` | 0 violation / 157 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Les 18 hashes du tableau d'état | tous atteignables depuis `HEAD` |
| `docs/design/` | 19 fichiers, README et planche 8 présents |

**Suite**

`I1`, dès que les manques du système de couleur sont tranchés. L'inventaire est rendu :
sur les quatre du handoff, deux se déduisent sans aucune valeur nouvelle, un est une
décision déjà prise qu'il faut seulement écrire, et un seul - la couleur
d'avertissement - ne se déduit pas et demande un arbitrage.

**Les manques du système de couleur, tranchés avant `I1`**

Bilan de l'inventaire : **zéro couleur à inventer.** Deux des quatre manques du §10 se
déduisent sans valeur nouvelle (le trait d'état est une combinaison de jetons existants,
le designer l'écrit lui-même ; la piste de progression est un alias de `bg.fill`), un est
une décision déjà prise qu'il fallait seulement inscrire (aucune teinte de remplissage
d'état), et un seul demandait un arbitrage.

Cet arbitrage - la couleur d'avertissement - est tranché sans nouveau jeton : un jaune
tomberait vers la teinte 95, trop près de l'accent ambre (66) pour que la règle « l'ambre
ne sert qu'à trois choses » reste lisible. **Et le détournement de `danger` n'était pas
seulement provisoire, il était faux** : le §6 du handoff écrit qu'une colonne non
reconnue « n'est pas une erreur », et le prototype la rendait en rouge. Elle passe en
`text.tertiary`.

Constat qui vaut d'être retenu : **le détournement signalé par le handoff vivait dans les
écrans, pas dans les jetons.** Il n'y avait donc rien à graver dans le catalogue
d'assets, contrairement à ce que la crainte de départ supposait. Mais il y avait bien un
trou, ailleurs, que personne n'avait vu - `bg.inset`, trois apparences sur quatre
manquantes - et c'est l'arbitrage sur l'apparence claire qui l'a fait sortir.

**Deux hexadécimaux faux dans le handoff**, trouvés en calculant ces valeurs et corrigés
dans `design/README.md` §4.1 : `bg.inset` livré à `#1f1f1f`, qui est la valeur de
`bg.raised` et se situe *au-dessus* de `bg.surface` ; `bg.viewer` livré à `#0f0f0f`, qui
est *plus clair* que `bg.canvas`. Chacun contredit le rôle écrit de son propre jeton, et
tous deux pour la même raison : ce sont les deux jetons ajoutés tardivement, légitimés
comme écarts dans la planche 8, dont l'hexadécimal n'a jamais été recalculé depuis
l'`oklch` canonique. Les bonnes valeurs sont `#080808` et `#010101`.

C'est la démonstration de ce que l'intégration devait éviter : ce n'est pas le
détournement qui aurait été gravé, ce sont deux valeurs simplement fausses, dans le
tableau qui sert de source au catalogue d'assets.

---

## 2026-08-04 (2) — `I1` : les tokens de la nouvelle direction

Les tokens seuls, aucun composant. L'ancienne direction est isolée, pas complétée.

**Ce qui entre**

| Volet | Contenu |
|---|---|
| Couleur | 19 rôles × 4 apparences, `colors.tokens.json` réécrit depuis la planche 8 |
| Typographie | 11 rôles, 5 familles embarquées, bascule du titrage à la première taille d'accessibilité |
| Métriques | 8 espacements, densité à 2 crans (7 mesures), 5 rayons + `sheet`, 2 traits, 6 durées, 7 plans, 6 points de rupture |
| Affiches | 6 crans (32 à 280) et la matrice complète : 8 contextes × 2 dispositions × 3 tailles |
| Symboles | les 37 SF Symbols de la section 8 |
| Catalogue | 5 planches, dont deux nouvelles (Affiches, Symboles) |

**Le JSON ne porte plus les composantes Display P3**

Elles étaient recopiées à la main à côté de chaque hex, et rien ne vérifiait qu'elles
correspondaient. `generate-colors.py` fait maintenant la conversion sRGB vers Display P3
lui-même, et le JSON ne contient que les hex de la planche 8 — donc il se relit contre
le handoff sans calcul. La conversion a été validée avant d'être adoptée : elle
reproduit les **128 composantes** de l'ancien fichier, calculées séparément, à 0,0002
près. Zéro écart.

**Deux hexadécimaux du handoff étaient faux, et c'est ça que l'intégration a évité**

Ce n'est pas le détournement de jeton qui aurait été gravé dans le catalogue d'assets —
il vivait dans les écrans d'import, pas dans les tokens. Ce sont deux valeurs
simplement fausses, dans le tableau qui sert de source :

| Jeton | Handoff | Réel | Pourquoi c'est faux |
|---|---|---|---|
| `bg.inset` | `#1f1f1f` | `#080808` | C'est la valeur de `bg.raised`, et elle est *au-dessus* de `bg.surface` — donc pas « un cran entre `bg.canvas` et `bg.surface` », qui est la raison d'être du jeton |
| `bg.viewer` | `#0f0f0f` | `#010101` | *Plus clair* que `bg.canvas` — donc pas « plus sombre que tout le reste pour que l'image porte seule » |

Même cause pour les deux : ce sont les deux jetons ajoutés tardivement, légitimés comme
écarts dans la planche 8, dont l'hexadécimal n'a jamais été recalculé depuis l'`oklch`
canonique. Corrigés dans `design/README.md` §4.1, avec la note qui l'explique.

**Trois pièges qui n'auraient rien cassé à la compilation**

1. **`IBMPlexMono-Medm`.** Le nom PostScript relevé sur les fichiers réels : le Regular
   s'appelle `IBMPlexMono` **sans** `-Regular`, et le Medium est abrégé en `-Medm`.
   Écrits « comme on les attend », `Font.custom` serait retombé sur Helvetica en
   silence. Un test paramétré verrouille les deux, et le commentaire de `Face` qui
   annonçait « nom PostScript et nom de fichier sont distincts, ne pas fusionner »
   trouve enfin son cas réel.
2. **`ShapeStyle.separator` existe déjà dans SwiftUI.** Déclarer le nôtre sous le même
   nom ne casse pas la compilation : ça rend `.separator` **ambigu**, et une vue peut
   prendre la couleur système d'Apple au lieu du token. C'est `ColorAssetTests` qui l'a
   attrapé. Le token garde son nom, l'accesseur devient `separatorLine`.
3. **`DynamicTypeSize.accessibilityMedium` n'existe pas.** La planche 8 écrit
   `.accessibilityMedium`, qui est le nom `ContentSizeCategory` de cette taille ;
   `DynamicTypeSize` l'appelle `.accessibility1`. La bascule passe par
   `isAccessibilitySize`, ce qui évite de traduire entre les deux échelles.

**Un interblocage, et ce n'était pas mon code**

La suite du package s'est mise à ne plus rendre la main : dix minutes à 0 % de
processeur. `sample` a montré la pile entière en attente dans `XTypeXPCClient run:`.

Cause : `fallbackFamilyName()` demandait à CoreText un nom de police inconnu, ce qui
déclenche une résolution par XPC vers `libFontRegistry` et son gestionnaire
d'auto-activation. Le test est paramétré **par fonte**, swift-testing exécute les cas en
parallèle : à quatre fontes ça passait, à onze les appels XPC concurrents se bloquent
mutuellement. Les deux sondes sont désormais des `let` globales, calculées une fois par
exécution. La suite passe en 0,12 s.

**Ce qui n'entre pas, et pourquoi**

Pas de niveau « primitives ». La planche 8 ne fournit aucune rampe : elle pose
directement 19 rôles avec leurs quatre apparences. En inventer une couche serait
inventer du design. Les 36 primitives de l'ancienne direction sont abandonnées — aucune
vue ne les lisait, seul le catalogue les affichait par nom, et l'écart correspondant se
ferme du même coup.

**L'ancienne direction : isolée, datée, et sous garde de lint**

`Packages/DesignSystem/Sources/DesignSystem/Legacy/` porte les 17 jeux de couleur, les
12 rôles typo, les ombres, les bordures, `CardMetrics` et les proportions 3:2 et 4:5.
Elle n'est pas là pour être reprise : elle est là parce que la retirer ne casserait pas
la compilation — **ça rendrait du transparent**, et c'est la défaillance silencieuse que
`ColorAssetTests` existe pour attraper.

Là où un nom existe des deux côtés, **le nouveau gagne** : les six jeux communs,
`Typo.body`, `Radius.xs` (2 pt au lieu de 4), `Motion.base` et `Motion.sheet`. Le banc
d'essai s'en trouve très légèrement différent, ce qui est exactement son rôle.
`no_legacy_design_system` interdit à tout fichier neuf de rattraper un concept supprimé,
avec une liste d'exclusions figée. La procédure de suppression, en sept points, est dans
`Legacy/README.md`.

**Aucun écran de `App/` n'a bougé.** Les deux builds passent sans qu'une ligne y ait été
touchée — c'était la condition du découpage.

**Deux règles de lint corrigées au passage**

`no_corner_radius` mordait sur sa propre documentation : la règle n'excluait pas les
commentaires, donc la docstring de `dsClip` qui explique *pourquoi ne pas* utiliser
`.cornerRadius()` la déclenchait. Et `identifier_name` refusait `s`, `m`, `l` — les noms
des crans de l'échelle d'affiche de la planche 8, qu'il aurait fallu renommer pour
diverger du handoff.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| Build `DesignSystemCatalog` macOS | `** BUILD SUCCEEDED **` |
| Tests `CineShelf` (macOS) | `** TEST SUCCEEDED **` |
| Tests `DesignSystemCatalog` macOS / iOS | `** TEST SUCCEEDED **` |
| `swift test` Core / DesignSystem / MediaKit | 159 / **46** / 38 (24 avant pour DesignSystem) |
| `swiftlint --strict` | 0 violation / 166 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Conversion sRGB vers P3 | 128 composantes de l'ancien fichier reproduites, 0 écart |
| Les 8 fontes de la direction courante | résolues sur leur vraie famille, mesuré hors test |
| Catalogue lancé | tourne, cinq planches |

**Non vérifié : le rendu à l'écran.** `screencapture` est refusé dans cet environnement
(pas d'autorisation d'enregistrement d'écran), donc je n'ai pas pu regarder les planches
moi-même. Ce qui est mesuré à la place est plus solide pour ce qui compte : les tests du
catalogue tournent avec le `Colors.xcassets` **compilé**, donc les 36 jeux résolvent
réellement, et les familles de police sont vérifiées par mesure de rendu.

**Suite**

Les composants sont l'étape suivante du design, pas de `I1` : ils appartiennent aux
étapes 1 à 10 de la méthode du `06 §6`, avant `V1`. Côté logique, `L10` reste la tâche
suivante du chemin critique.

---

## 2026-08-04 (3) — Deux épinglages : le seuil du basculement, et les collisions de noms

**Le seuil, écrit là où le handoff le nomme**

Le cran réel est **`DynamicTypeSize.accessibility1`**. `.accessibilityMedium` n'est pas
une casse valide de `DynamicTypeSize` : c'est le nom de cette taille dans
`ContentSizeCategory`, l'énumération dépréciée. La note est posée dans
`design/README.md` §4.2 et rappelée au §10, précisément pour que personne ne « corrige »
le code vers le nom du document — ça ne compilerait pas.

Correspondance **mesurée**, pas supposée : les deux énumérations ont douze cas dans le
même ordre, et `accessibilityMedium` comme `accessibility1` occupent le rang 7. C'est
aussi la première taille pour laquelle `isAccessibilitySize` est vrai, et c'est cette
propriété que le code utilise — plus lisible qu'une comparaison, et insensible à un
renommage futur des crans.

Effet de bord noté au passage : le handoff ne dit rien de `.xxxLarge`, qui tombe entre
« jusqu'à `.xxLarge` » et le seuil. Il reste en Bebas Neue, et un test le verrouille.

**Les collisions de noms, traitées en classe et non au cas par cas**

`ShapeStyle.separator` n'était pas un cas isolé mais un exemplaire. Les vingt statiques
que SwiftUI expose en position `ShapeStyle` implicite ont été **relevées par
compilation**, une par une : pour chaque nom candidat, compiler
`Text("x").foregroundStyle(.<nom>)` avec le seul `import SwiftUI`. Un nom absent échoue
sur `type 'ShapeStyle' has no member '<nom>'`, ce qui donne le contrôle négatif de la
sonde. Relevé sur le SDK macOS 15 :

```
primary secondary tertiary quaternary quinary
background foreground selection link placeholder fill tint separator windowBackground
regularMaterial thinMaterial ultraThinMaterial thickMaterial ultraThickMaterial bar
```

**Aucun des 19 accesseurs actuels n'en heurte une** — vérifié aussi par une sonde qui
les utilise tous les 19 en position implicite. `accent`, `danger` et `success` sont
libres, contrairement à ce qu'on pouvait craindre.

`ShapeStyleCollisionTests` garde la porte fermée, sur deux niveaux :

1. **À l'exécution** : `ColorTokens.accessorNames` — désormais généré, donc toujours à
   jour et tenant compte des désambiguïsations — est confronté à la liste native. Le
   message d'échec dit quoi faire : ajouter une entrée à `ACCESSOR_OVERRIDES`, sans
   toucher au nom du token dans le JSON. Les jeux legacy sont couverts aussi : ils sont
   encore lus par le banc d'essai, une collision y produirait la même prise de couleur
   système.
2. **À la compilation** : une vue privée utilise les 19 accesseurs en position
   implicite. Une ambiguïté future rend la suite non constructible — volontairement une
   erreur de compilation et non un test rouge, parce qu'une ambiguïté n'est pas
   rattrapable à l'exécution.

**Preuve d'échec, en deux temps parce que la première ne prouvait pas la bonne chose**

Retirer l'override a bien cassé la suite, mais par « symbole absent » : la compilation
échouait avant d'atteindre le test. Ça démontrait la détection, pas la garde.

La bonne démonstration ajoute au JSON un token nommé `fill`, dont l'accesseur dérivé
heurte `ShapeStyle.fill`. La suite compile alors, et **quatre tests mordent** sous des
angles différents, dont `colliding → ["fill"]` avec le message d'aide. Token retiré, 51
tests verts, aucun résidu dans le catalogue d'assets.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| `swift test` DesignSystem | **51 tests** (46 avant) |
| `swiftlint --strict` | 0 violation / 167 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Preuve d'échec — token nommé `fill` | 4 tests au rouge, message d'aide correct |
| Sonde des statiques natives | 20 relevées, contrôle négatif concluant |
| CI du commit `I1` | verte |

---

## 2026-08-04 (4) — `L10` : l'édition en masse

Deux arbitrages avant d'écrire : **tout ou rien strict** (validation d'abord, un refus
n'écrit rien) et **périmètre `Title` + `Person`**, les deux seules entités qui portent
`filterKeys`, des relations dénormalisées et un volume réel.

**Ce qui est livré**

`Services/BulkEdit/` : le descripteur (`TitleBulkMutation`, 17 cas ; `PersonBulkMutation`,
9 cas), la validation, l'exécuteur, le diff inversable. Les quatre opérations de la fiche
— remplacer, vider, ajouter à une relation, retirer d'une relation — sont portées par les
cas de l'enum plutôt que par un enum séparé : « vider » n'a pas de sens sur un `Bool` et
« ajouter » n'en a pas sur un scalaire, donc autant rendre ces combinaisons impossibles à
écrire plutôt qu'à valider.

Les relations sont désignées par `UUID`, jamais par objet : un `@Model` n'est pas
`Sendable`, et il appartient au contexte qui l'a lu.

**Le bug que j'étais en train d'écrire**

Ma première version faisait passer chaque mutation par `repository.update`. Or `update`
**journalise une entrée par entité** : cinquante titres modifiés auraient produit
cinquante `ActivityEntry` en plus de celle du lot — exactement ce que la fiche interdit,
et le fil en devenait illisible.

La tentation était alors de muter en direct, sans les repositories. Écartée : ce sont eux
qui appellent `refreshDerived()`, donc qui maintiennent `filterKeys`, et une relation
écrite sans rafraîchissement rend le filtre correspondant faux **en silence**. D'où
`JournalPolicy` — `.perEntity` par défaut, `.batched` pour un lot. Mieux un paramètre de
plus qu'une seconde porte d'écriture.

Au passage, un second piège du même genre : `PersonRepository.setGenres` et `setRoles`
acceptaient le nouveau paramètre **sans le transmettre** à `update`. Le lot aurait
journalisé quand même, et rien ne l'aurait signalé.

**Trois précautions pour le tout ou rien, chacune vérifiée**

| Précaution | Ce qu'elle évite |
|---|---|
| Contexte dédié, créé depuis le conteneur | `rollback()` annule les changements du contexte *entier* : partager celui des vues ferait perdre la saisie en cours dans un éditeur ouvert |
| `autosaveEnabled = false` | `rollback()` ne défait que ce qui est **en attente**. Un enregistrement automatique intercalé laisse la première moitié du lot sur disque |
| Validation avant la première écriture | Muter puis annuler, c'est mettre le contexte dans un état dont il faut sortir. Mesuré : un refus coûte 27 ms contre 108 ms pour une application — la sortie est bien précoce |

L'API a été sondée avant d'être utilisée, pas supposée : `rollback()` remet bien
`hasChanges` à `false` et vide `insertedModelsArray`, `autosaveEnabled` est réglable, et
`transaction(_:)` existe.

**`@MainActor` plutôt qu'un acteur, et pourquoi c'est acceptable**

Les repositories sont `@MainActor`, parce qu'ils tiennent un `SpotlightIndexer` dont
l'implémentation l'est. Les contourner pour gagner un acteur reviendrait à muter les
relations en direct — le prix est trop élevé. Le lot reste borné par construction : une
sélection que l'utilisateur a sous les yeux, pas un import. L'insertion massive, c'est
`ImportActor` et ses lots de 200, sujet de `L11`.

`BulkEditPerformanceTests` mesure pour que le jour où ce raisonnement cesse d'être vrai se
voie. Sur 500 titres — bien plus qu'une sélection réelle :

| Chemin | Total | Par titre |
|---|---:|---:|
| Champ scalaire | 108 ms | 0,22 ms |
| Relation (recompose `filterKeys`) | 275 ms | 0,55 ms |
| Refus (validation seule) | 27 ms | — |

Les plafonds assènés sont un ordre de grandeur au-dessus : ils attrapent une régression
algorithmique, pas le bruit d'un runner partagé.

**Le diff, contrat avec `L20`**

`ActivityEntry.payload` reçoit un JSON versionné : par entité, les changements
avant/après champ par champ, et les identifiants rattachés et détachés pour les
relations. Trois décisions qui comptent pour l'annulation :

- **Les valeurs sont des `String?`** avec un encodage explicite par type. Un `AnyCodable`
  maison finirait par accepter un dictionnaire imbriqué que l'annulation ne saurait plus
  relire. `Double` en `%.17g`, dates en ISO 8601 UTC — un diff écrit à Paris en juillet
  doit se relire en janvier.
- **`nil` veut dire « le champ était vide »**, pas « inconnu » : restaurer `nil` est une
  action.
- **La version est refusée si elle est inconnue**, pas devinée : une annulation qui
  interprète mal un diff est pire que pas d'annulation.

Le diff est capturé **avant** chaque écriture. `releaseDate` et `releasePrecision` y
bougent toujours ensemble — une date sans sa précision se relit comme une date au jour
près, et c'est le bug qui avait dégradé les dates exactes en 1er janvier au prompt 11.

**Les refus, groupables par cause**

Un enum de causes et non un message libre : l'aperçu d'import groupe 417 lignes fautives
en six causes, et un message libre ne se groupe pas. La cause la plus sournoise est
`relationInAnotherLibrary` — rien ne l'empêche techniquement, et le résultat est un genre
qui fuit d'un catalogue à l'autre. Elle est vérifiée **par entité**, une sélection pouvant
mélanger deux bibliothèques.

`GenreQuery.withIDs` et `CollectionQuery.withIDs` ne filtrent délibérément pas
`deletedAt == nil`, contrairement à toutes les autres requêtes de genre : sans ça, « à la
corbeille » et « n'existe pas » seraient indiscernables, alors que l'utilisateur n'a pas
la même chose à faire.

**Découpage imposé par le lint, et le filet qui va avec**

`applyToTitle` dépassait la complexité autorisée. Découpé en quatre corps — numérique,
date, texte et drapeaux, relations — avec un aiguillage **exhaustif et sans `default`** :
un cas ajouté à l'enum casse la compilation là, ce qui force à décider de sa famille. Les
corps ont un `default` avec `assertionFailure`, atteignable seulement si l'aiguillage est
faux. `BulkEditorDispatchTests` exerce les 17 et les 9 mutations pour que ce soit vérifié
et pas seulement écrit.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| Tests `CineShelf` (macOS) | `** TEST SUCCEEDED **` |
| `swift test` Core / DesignSystem / MediaKit | **200** / 51 / 38 (159 avant pour Core) |
| `swiftlint --strict` | 0 violation / 178 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Preuve d'échec — `guard refusals.isEmpty` retiré | 5 tests au rouge |
| Preuve d'échec — `.batched` remis en `.perEntity` | `perEntityEntries → 5` et `→ 2` |

Les assertions d'absence d'écriture relisent depuis un **contexte neuf**, jamais depuis
celui de l'éditeur : sur des objets encore en attente, un `rollback()` mal fait passe
inaperçu. C'est la règle de `CLAUDE.md`, et c'est ce qui avait coûté 42 tests verts sur
une grille vide.

`MediaKit` a échoué sur `cannot find type 'JournalPolicy' in scope` avant que
`rm -rf .build` ne le règle : le cas est déjà documenté dans `CLAUDE.md`, ce n'était pas
un défaut de code.

**Reste ouvert**

L'annulation elle-même est `L20` : `payload` et `undoneAt` sont écrits et lisibles, mais
personne ne les consomme encore. `V6` ne doit pas livrer l'édition en masse sans elle —
c'est déjà au tableau des tâches VUES.

---

## 2026-08-04 (5) — Quatre resserrages avant `L11`

**`JournalPolicy` perd sa valeur par défaut**

Deux mutateurs avaient accepté le paramètre sans le transmettre, dans la même heure. Sans
défaut, le compilateur force chaque site à décider : **24 sites** ont dû être explicités —
4 internes aux repositories, 2 dans `App/`, 18 dans les tests. Aucun n'a perdu en
lisibilité, sauf un qui était déjà cryptique avant : `update(title, journal: .perEntity)
{ _ in }` dans `addCredit` et `removeCredit`, où la fermeture vide veut dire « rafraîchis
les dérivés et journalise ». Le raisonnement est inscrit dans la docstring du type, avec
l'instruction de ne pas remettre de défaut.

Un piège au passage : mon `sed` a ajouté le paramètre à `CollectionRepository.update`, qui
ne le porte pas. Rattrapé par la compilation — ce qui est exactement l'intérêt de la
manœuvre.

**Une garde à la compilation se prouve en cassant le build**

Règle ajoutée à `CLAUDE.md`. La preuve d'échec des collisions `ShapeStyle` avait d'abord
consisté à retirer la désambiguïsation : la suite cessait de compiler **avant** d'atteindre
le test, et ce qu'on observait était « symbole absent », pas la garde qui mord. Ça
démontrait la détection, pas la garde.

La règle : pour prouver une garde de compilation, **introduire la faute que la garde existe
pour attraper** — pas retirer la garde. Retirer la garde prouve seulement qu'on l'utilisait.

**`.xxxLarge` inscrit comme décision, pas comme déduction**

Le handoff dit « jusqu'à `.xxLarge` » puis « à partir de `.accessibilityMedium` », et ne dit
rien du cran intermédiaire. Il fallait trancher pour écrire le code : `.xxxLarge` reste en
Bebas Neue, parce que ce n'est pas une taille d'accessibilité. C'est écrit dans
`design/README.md` comme **comblement de silence** et non comme lecture du document, avec
la manœuvre exacte pour l'inverser si le design en décide autrement.

**Les trois chaînes, expliquées là où la question se pose**

La confusion s'est produite pour de vrai : on ouvre le catalogue, on cherche les
formulaires et la console de gestion, on ne les trouve pas, et rien ne dit s'ils sont
oubliés ou pas encore arrivés.

`RoadmapSheet` est donc la **première** planche du catalogue, et `PROMPTS.md` porte la même
explication en tête : `L` la logique (invisible, testée), `I1` les tokens, `I2…In` les
composants un par un, `V1…V12` les écrans. Avec le cas qui piège : « les formulaires » se
répartit sur les deux chaînes visuelles — les **champs** sont des composants et se voient
dans le catalogue, l'**écran d'import** est `V8` et ne s'y verra jamais. Même découpage
pour la console : la ligne de tableau est un composant, la console est un écran.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| Build `DesignSystemCatalog` macOS | `** BUILD SUCCEEDED **` |
| `swift test` CineShelfCore | 200 tests |
| `swiftlint --strict` | 0 violation / 179 fichiers |
| `xcrun swift-format lint` | 0 avertissement |

---

## 2026-08-04 (6) — Reconnaissance de `L11`, un bug de `L10` corrigé, et la coupe

Session de reconnaissance et d'arbitrage. `L11a` n'est pas encore écrite.

**Le dépôt web n'est pas accessible** — ni en local, ni sur GitHub (un seul dépôt
`CineShelf`, le natif ; `Bobine` est une autre app). Les 3 100 lignes de `dataTransfer.js`
ne seront donc pas lues. La reconnaissance s'est faite sur les documents et le code.

**Ce que la mesure a tranché, contre ce que la fiche supposait**

La fiche `L11` dit « Lecture : `TabularData` ». Mesuré sur un vrai fichier de 5 000 lignes
avec BOM, point-virgule, accents et champs multilignes :

| Point | Résultat |
|---|---|
| Vitesse | 5 ms pour 5 000 × 5 |
| BOM en lecture | **retiré proprement** du nom de colonne, contre mon attente |
| Accents, champs quotés, `;` interne, multiligne | préservés |
| **Une ligne mal formée** | **rejet du fichier entier** — 4 999 lignes valides perdues |

Ce dernier point exclut `TabularData` pour l'import : l'aperçu « 771 prêtes, 417 en
erreur » de l'addendum est impossible si le fichier entier est refusé au premier guillemet
mal placé — et un export Excel réel en contient. Parseur maison, prototypé à **2 ms**,
plus rapide que `DataFrame` puisqu'il ne fait ni inférence ni colonnes typées.

Deux pièges de plus, mesurés : `csvRepresentation` **n'écrit pas** de BOM (il faut le
préfixer, sinon Excel massacre les accents), et l'inférence de type **dépend des
données** — `year` devient `String` dès qu'une seule valeur est vide.

**Et le piège que seule la mesure révèle** : un guillemet non fermé avale les 2 500 lignes
suivantes. Conforme à RFC 4180, catastrophique pour un aperçu. Resynchronisation retenue,
au-delà de 8 lignes englobées.

**Ce que la reconnaissance a trouvé et que je n'aurais pas vu**

- `CSVReadingOptions.nilEncodings` contient `"NA"`, `"NULL"`, `"n/a"` par défaut : **un
  titre nommé « NA » devient `nil`**. À neutraliser pour les colonnes textuelles.
- `headerSignature` doit se calculer sous une **locale invariante**. Tous les `folding` du
  dépôt utilisent `.current`, or `ImportMapping` est synchronisé par CloudKit : une
  signature calculée sous une autre locale ne reconnaîtrait plus le même en-tête. Le cas
  turc (`I` → `ı`) est le cas d'école.
- **Trois colonnes du mock d'import n'ont aucun champ au modèle** : Support, Étagère,
  nombre de visionnages. Deux des six causes d'erreur du design en dépendent.
- `ImportMapping` et `LegacyRecord` ne sont lus **par personne** — seules mentions hors
  de leur fichier : le côté inverse dans `Library` et la déclaration du schéma.
- La fiche `L11` **s'inversait** : « reprise par élément et non par lot », alors que le
  tableau des écarts et `ImportActorTests` disent le contraire. Corrigé.
- `BulkEditor` ne peut **pas** servir à la correction en masse de l'aperçu : il travaille
  sur des entités en base désignées par `UUID`, et il écrit. Les corrections portent sur
  des lignes de CSV qui n'existent nulle part. La dépendance à `L10` est **de forme**, pas
  d'appel — distinction inscrite sur la fiche pour qu'elle ne se perde pas.

**Un bug de `L10`, trouvé par l'arbitrage sur l'échelle de la note**

Trois sources se contredisaient : `Title.swift` disait « 0–10 », `BulkEditor.Bounds`
imposait `0...5` en refusant les demi-étoiles, le mock parlait de « Note · sur 10 ».

Vérification : `docs/02` §3.3 dit 0–10, et `TitleFormat.fiveStarRating` divise déjà par
deux **depuis le prompt 11**. La planche 6 du design décrit donc le **rendu**, pas le
modèle. `Bounds.ratings = 0...5` était un bug que j'avais introduit la veille en
appliquant une règle d'affichage au modèle — il aurait refusé à l'import **la moitié de
l'échelle**, et le refus des demi-étoiles rejetait une note de 8,4 que `ratingText` sait
pourtant écrire.

Corrigé : bornes `0...10`, contrainte d'arrondi supprimée, et le test « une demi-étoile
est refusée » — qui encodait le bug — remplacé par un test paramétré qui vérifie que 0 ;
3,5 ; 5 ; 8,4 et 10 sont acceptées et relues à l'identique.

**La coupe, et pourquoi cette ligne**

`L11` est coupée en `L11a` (le format et l'analyse, **aucune écriture de modèle**) et
`L11b` (l'application au magasin). La frontière est la garantie que le design énonce
lui-même : « rien n'est écrit dans la bibliothèque avant l'appui final ».

Ce n'est pas un compte de lignes. `L11a` est testable sans un seul `save()`, donc elle
échappe **par construction** au piège qui a coûté 42 tests verts ; `L11b` est exclusivement
faite de ce piège — plafond de `#Predicate`, pending contre SQL, frontière d'acteur,
`filterKeys`. Les mélanger, c'est risquer que la partie facile consomme l'attention.

**Trois arbitrages, pris avant d'écrire**

| Sujet | Décision |
|---|---|
| Les trois colonnes sans champ | Colonnes ignorées **nommées**, aucune migration. Deux causes de l'addendum perdent leur objet — écart assumé |
| L'échelle de la note | 0–10 en base, 0–5 à l'affichage. `L10` corrigée |
| Le profil Movix | **Aucun profil intégré** pour l'instant : le script source est inaccessible et `isBuiltIn` interdit de retirer un profil livré. Un profil faux serait pire qu'aucun |

**Vérifications**

| Contrôle | Résultat |
|---|---|
| `swift test` CineShelfCore | **201 tests** |
| `swiftlint --strict` | 0 violation |
| `xcrun swift-format lint` | 0 avertissement |
| Sondes TabularData | 4 fichiers de mesure, reproductibles |

---

## 2026-08-04 (7) — `L11a`, premier jalon : le format CSV dans les deux sens

**Livré et testé** : le sérialiseur, le lecteur tolérant, le schéma de colonnes comme
donnée, l'export et les gabarits. 35 tests, dont l'aller-retour complet.

**Ce module n'importe pas `TabularData`, et c'est le résultat d'une mesure.** La fiche
exigeait déjà un sérialiseur maison ; la mesure a ensuite exclu le cadre pour la lecture
aussi. Ne plus l'importer évite en prime les collisions de noms qu'il aurait causées —
il expose `Column`, `Row`, `DataFrame` et `CSVType`.

**Le lecteur, et la ligne qui n'emporte pas les autres**

Le cas qui a décidé de tout, mesuré : 5 000 lignes valides dont une seule mal formée à la
2 501e. `DataFrame` rend « Misplaced quote at row 2501 » et **zéro** ligne exploitable.
Le lecteur maison rend 4 999 lignes utilisables et une ligne nommée.

La resynchronisation au-delà de huit lignes englobées est le compromis visible de ce
choix : RFC 4180 dit qu'un guillemet ouvert protège les sauts de ligne — c'est sa raison
d'être — mais un guillemet jamais refermé avalerait 2 500 lignes. Preuve d'échec faite :
seuil désactivé, le test tombe à 25 lignes utilisables au lieu de 40 et « Titre 49 »
disparaît.

**Trois bugs attrapés par les tests, tous réels**

1. **Un décalage de fuseau d'un jour sur les dates.** Une date construite au 15 juin en
   heure locale s'écrivait `1970-06-14` en UTC. Or `Title.releaseYear` utilise
   `Calendar.current` : dans le **même fichier**, la colonne « Année » aurait été locale et
   « Date de sortie » en UTC, et un titre du 1er janvier aurait affiché l'année précédente.
   Le fuseau courant l'emporte — un CSV est relu par un humain, pas par un serveur.
2. **Un octet non UTF-8 était avalé en silence.** `String(decoding:as:)` remplace par
   U+FFFD, donc « Renée » venu d'un fichier Windows-1252 devenait « Ren?e » et passait
   pour une valeur. C'est la règle SwiftLint `optional_data_string_conversion` qui l'a
   signalé, et le remède ajoute une vraie capacité : `CSVMalformation.invalidEncoding`,
   ligne rendue et **nommée**.
3. `#expect` refuse un message `String` non littéral — trois sites corrigés.

**Décisions de format, chacune avec son motif**

| Point | Choix | Pourquoi |
|---|---|---|
| Séparateur de valeurs multiples | barre oblique | La virgule est le séparateur décimal en locale française, le point-virgule celui des colonnes |
| Décimales | point, pas virgule | Les deux conventions coexisteraient dans un fichier selon la locale de l'exportateur |
| Dates | ISO 8601 sans heure, fuseau courant | Un tableur le reconnaît comme date et le trie ; l'heure serait du bruit dans « Naissance » |
| Booléens | `oui` / `non` | L'app est en français, et `trueEncodings` de `TabularData` ne nous concerne plus |
| Clés de colonnes | stables, jamais renommées | Elles voyagent dans `ImportMapping.columnMapData`, entité **synchronisée** : renommer casserait les correspondances de tous les appareils sans le moindre signal |

**Ce que `L11a` n'a pas encore**

La correspondance des colonnes et ses trois qualités, `headerSignature` sous locale
invariante, le repository d'`ImportMapping`, la validation ligne à ligne avec causes
groupables, et les deux rapports. C'est la moitié subtile de `L11a`, et je préfère la
prendre entière plutôt que d'en écrire les trois quarts.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| `swift test` CineShelfCore | **236 tests** (201 avant) |
| `swiftlint --strict` | 0 violation / 185 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Preuve d'échec — resynchronisation désactivée | 25 lignes au lieu de 40, « Titre 49 » perdu |

---

## 2026-08-04 (8) — Le repliage de texte n'était pas reproductible entre appareils

**Une règle et un corollaire dans `CLAUDE.md`**

Les documents de design contraignent le **rendu**, jamais le **modèle**. Deux incidents, la
même erreur de catégorie : « cinq étoiles pleines » appliqué à `Title.rating`, et « contenu
privé au niveau du profil » appliqué à `isPrivate` — ce dernier aurait rendu un titre privé
indexable dans Spotlight, dont l'index est unique pour l'appareil.

Le corollaire vise les tests : **citer la source de chaque assertion non évidente**, et
tenir pour un signal d'alarme une source de design sur un sujet de modèle. C'est
exactement comment « une demi-étoile est refusée » a verrouillé le bug au lieu de
l'attraper — le test citait la planche 6, ce qui le rendait crédible.

**`TabularData` écarté : la raison est maintenant dans `docs/04` §7**

Elle n'était que dans un journal et dans un commentaire de code. Le motif principal est
éliminatoire — rejet du fichier entier sur une seule ligne mal formée, donc l'aperçu de
l'addendum est impossible — et trois motifs secondaires l'accompagnent : l'inférence de
type qui dépend des données, le séparateur non réglable après construction, et
`nilEncodings` qui transforme un titre nommé « NA » en `nil`. La table de correspondance
web → natif est corrigée du même coup.

**L'audit de locale, et le bug qu'il a trouvé**

12 sites repliaient du texte avec `locale: .current`. Cinq alimentent des champs
**persistés et synchronisés par CloudKit** — `Title`, `Person`, `TitleCollection`
(`sortName` et `searchText`), `Genre` (`nameKey`), `SavedLink` (`searchText`) — et quatre
replient le terme cherché pour le comparer à ces champs.

Mesuré avant de corriger :

| mot | fr_FR | tr_TR |
|---|---|---|
| Interstellar | interstellar | **ınterstellar** |
| ITALIA | italia | **ıtalıa** |
| Indépendant | independant | **ındependant** |

**Ce n'est pas un cas exotique** : le turc et l'azéri ont un `i` sans point, donc *tout* mot
contenant un `I` majuscule diverge. La moitié des titres écrits en capitales.

Le site qui mordait vraiment est `Genre.nameKey`, qui sert au dédoublonnage — notre
remplacement de `@Attribute(.unique)` que CloudKit interdit. Un iPhone en turc et un Mac en
français ne s'accordent pas sur la clé de « Indépendant », donc `findOrCreate` crée un
second genre **sans rien signaler**.

Point subtil : une locale invariante à l'écriture ne suffit pas. Le terme cherché est
replié au moment de la requête, et si les deux côtés diffèrent la comparaison est fausse
quelle que soit la locale — un `CONTAINS` qui ne matche pas ne lève aucune erreur. Les
quatre sites de requête sont donc traités aussi.

Les 12 sites passent par `String.foldedForMatching`, seul endroit du dépôt où une chaîne se
replie, en `en_US_POSIX`.

**Aucune migration nécessaire** : `fr_FR` et `en_US_POSIX` replient identiquement, donc les
valeurs déjà en base sont inchangées. Seul un appareil turc aurait divergé.

**Deux filets, parce qu'un seul ne suffisait pas**

11 tests d'invariance, un par site persisté, chacun comparant la valeur produite à ce que la
locale turque aurait donné.

Puis la preuve d'échec a révélé un trou : **un modèle qui contourne `TextFolding` passe les
cinq tests sur une machine française**, puisque `fr_FR` et `en_US_POSIX` replient pareil. La
régression n'était détectable que par une machine turque. D'où la règle
`no_folding_outside_text_folding` — vérifiée en injectant la faute, elle mord.

Au passage : ma première tentative de preuve n'avait rien prouvé, le `sed` n'ayant rien
remplacé (la forme réelle était `.foldedForMatching` seul sur sa ligne). Vérifier que
l'injection a bien eu lieu fait partie de la preuve.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| `swift test` CineShelfCore | **247 tests** (236 avant) |
| `swiftlint --strict` | 0 violation / 187 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Preuve — `TextFolding.locale` remis à `.current` | 2 assertions mordent |
| Preuve — un modèle contourne `TextFolding` | 5 tests **passent** → d'où la règle de lint |
| Preuve — la règle de lint, faute injectée | 1 violation, message correct |

---

## 2026-08-04 — `L11a`, seconde moitié : correspondance, validation, rapports

La première moitié (902bfb1) avait livré le format dans les deux sens. Restaient la
correspondance des colonnes, `headerSignature`, le repository d'`ImportMapping`, la
validation ligne à ligne et les deux rapports. Cinq commits, un par sujet.

**Les bornes sortent de `BulkEditor`** (`fe63fa0`)

Année 1888-2030, note 0-10, durée minimale : nées avec `L10`, et `L11a` en avait besoin.
Deux copies auraient divergé au premier ajustement, avec ce visage-là : l'édition en masse
accepte une note de 9, l'import la refuse, et rien ne dit laquelle a raison. `CatalogBounds`
porte les cinq, chacune avec sa source.

**Trois qualités de correspondance, et l'ordre des passes est la garantie** (`6676c44`)

Nom exact -> sûre. Alias déclaré -> déduite. Forme du contenu -> déduite. Sinon non
reconnue, ce qui **n'est pas une erreur** : ignorée par défaut et **nommée**.

Un champ n'est réclamé qu'une fois. Sans la règle, un fichier portant `year` et `annee`
alimente deux fois l'année et personne ne sait laquelle a gagné.

La déduction par le contenu **s'abstient** quand la forme est ambiguë. Trois dates peuvent
être une date de sortie comme une date d'ajout : deviner écrirait la mauvaise valeur dans le
bon champ, ce qui ne se voit jamais.

**Le profil Movix, arbitré autrement que par du code en dur.** L'arbitrage du 2026-08-04
refuse un profil intégré : le script source est inaccessible, et `isBuiltIn` interdit de
retirer un profil livré. Le besoin qu'il servait — reconnaître `runtime_min`, `my_score` —
est couvert par des **alias par champ**, une donnée de `CSVField`. Ils produisent une
correspondance *déduite*, que l'écran montre comme telle et qui se corrige d'un menu.

**Le motif de la propriété invisible, quatrième occurrence**

`headerSignature` se calcule par `foldedForMatching`, donc sous locale invariante :
`ImportMapping` est synchronisée par CloudKit, la signature est **écrite** par un appareil et
**comparée** par un autre.

Preuve d'échec, `locale: .current` injecté dans `headerSignature` — injection vérifiée
présente avant de conclure :

| Filet | Verdict |
|---|---|
| Les 5 tests de signature | **passent** |
| `no_folding_outside_text_folding` | 1 violation, message correct |

C'est la quatrième fois, après `no_literal_color`, `no_predicate_outside_core` et les
mutateurs de relation : quand la propriété est « ce code passe par tel unique point
d'entrée » plutôt que « ce code produit telle valeur », seule une règle de lint protège.
Inscrit dans `CLAUDE.md`.

**Une preuve d'échec qui a démoli mon propre test**

« Une ligne mal découpée ne produit qu'un refus » : court-circuit retiré, le test **passait
quand même**. Sa fixture — `["Dune", "2021", "de trop"]` sur un en-tête à deux colonnes —
restait valide après décalage, donc la validation cellule à cellule ne produisait rien de
plus. Le test ne couvrait pas la règle qu'il énonçait.

Fixture refaite pour que les cellules décalées soient elles-mêmes fautives : 4 refus au lieu
d'1 quand la garde tombe. Sans la vérification que l'injection avait bien eu lieu, j'aurais
conclu « le test mord » sur un test creux.

**Deux écarts avec l'addendum, le même motif que la note sur 5**

- **« Année absente » n'est pas une erreur.** `docs/02` §3.3 rend `releaseDate` optionnel.
  La planche 11e compte 214 lignes en erreur avec le message « L'année est requise pour créer
  un titre » : elle décrit un modèle où l'année est requise, et ce n'est pas le nôtre.
  Appliqué, ça écartait des lignes que le modèle accepte. Signalé, pas appliqué.
- La note reste bornée **0-10**, pas 0-5.

Deux des six causes de la planche perdent donc leur objet — « Année absente » et « Support
inconnu », ce dernier faute de champ au modèle. L'addendum est à amender.

**Un vrai bug attrapé par un test**

`20211`, la faute de frappe la plus banale sur une année, était refusée comme « attendu en
chiffres » parce que le lecteur exigeait quatre chiffres. Le message était **faux** devant
une cellule qui ne contient que des chiffres, et inactionnable. Le nombre est maintenant lu
puis borné : « Année attendu entre 1888 et 2030. Trouvé « 20211 » ». La reconnaissance de
colonne garde sa règle des quatre chiffres — reconnaître une colonne et accuser une cellule
ne demandent pas la même sévérité.

**Trois colonnes ajoutées au schéma** (`738f5c5`)

Réalisation, Distribution, Ajouté le. La planche 11d les fait correspondre à un fichier
réel ; sans elles, un tel fichier voyait sa réalisation tomber en « colonne ignorée ».
Décision prise contre l'option « les laisser non reconnues ». La distribution est triée par
`orderIndex` et non par nom : une distribution alphabétique met la doublure avant la tête
d'affiche. **L'écriture des crédits à l'import reste `L11b`**, qui n'a pas de résolution de
références pour les personnes.

**Les deux rapports** (`f6b13b4`)

Le bilan nomme les colonnes ignorées. Le fichier de reprise rend l'en-tête d'origine plus
`cineshelf_erreur` **en fin** de ligne — en tête, il décalerait tout le fichier redéposé — et
se relit sans que le BOM contamine la première colonne, ce qui était la raison d'être du
retrait de BOM à la lecture. Preuve d'échec sur le complètement des lignes courtes : sans
lui, le message d'erreur atterrit dans une colonne de données.

La revalidation après correction **ne reparse rien** : les `ImportRow` déjà en mémoire sont
retravaillées, et seules les lignes visées.

**Le repository d'`ImportMapping`** (`4a42907`)

L'entité existait sans personne pour la lire. Mémoriser deux fois le même en-tête met à jour
au lieu de dupliquer : pas d'`@Attribute(.unique)`, donc l'unicité se tient ici comme pour
`Genre.nameKey`. Une correspondance intégrée refuse d'être supprimée — la supprimer
localement la ferait revenir au prochain lancement. Les dix tests relisent depuis un contexte
**neuf**, donc le chemin SQL est exercé.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| `swift test` CineShelfCore | **320 tests** (247 avant) |
| `xcodebuild test` macOS (dont `CloudKitConformanceTests`) | **67 tests**, `TEST SUCCEEDED` |
| `swiftlint --strict` | 0 violation / 197 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Preuve — un champ réclamé deux fois | 1 test mord |
| Preuve — la valeur trouvée remise dans la clé de cause | 1 test mord |
| Preuve — court-circuit de malformation retiré | 4 refus au lieu d'1 (après réfection de la fixture) |
| Preuve — complètement des lignes courtes retiré | 2 assertions mordent |
| Preuve — `headerSignature` en `locale: .current` | 5 tests **passent** -> la règle de lint mord |

---

## 2026-08-04 — La revue de `L11a`, et les huit défauts qu'elle a trouvés

Sous-agent de revue lancé sur `L11a` complète, comme prévu. Il a fait la seule chose qui
pouvait trouver ces bugs : **construire un paquet sonde hors dépôt** qui lie `CineShelfCore`,
et exercer des entrées que la suite n'atteignait pas. J'ai reproduit chaque grief sur ma
propre sonde avant de corriger — un rapport de revue n'est pas une vérité — et les huit se
sont confirmés. Deux étaient même pires que décrits.

**Le lecteur d'octets était la pièce fragile, et c'était bien là.**

Trois défauts, tous **muets**, tous sur le chemin le plus banal :

| Entrée | Avant | Après |
|---|---|---|
| 15 lignes, dont `Le mur de 6" de haut` | 7 lignes, 8 avalées | 15 lignes, 0 fautive |
| 10 lignes, dont un synopsis de 12 lignes **correctement quoté** | 3 saines, 4 fautives, 3 évaporées | 10 saines |
| Fichier à fins de ligne `CR` seules | en-tête de 4 colonnes, 0 ligne | en-tête juste, 2 lignes |

Le premier vient de ce qu'un guillemet ouvrait un champ **n'importe où** dans la cellule. RFC
4180 ne le compte qu'en début de champ. Un pouce, une taille d'écran, une citation dans un
titre : huit titres valides disparaissaient, et le rapport annonçait « 7 analysées » sur 15.

Le second est plus vicieux : après la refermeture forcée, la lecture reprenait **au milieu du
champ**, donc le guillemet fermant était relu comme *ouvrant* et avalait la suite du fichier.
Les paragraphes du synopsis remontaient en fausses lignes de données.

**Le compromis du seuil n'était pas le bon compromis.** Un budget de lignes oppose deux
besoins qu'il ne sait pas distinguer : un synopsis de douze lignes est légitime, un guillemet
oublié doit coûter le moins possible. J'ai d'abord relevé le seuil de 8 à 32 — ce qui a fait
passer le pire cas de 8 lignes perdues à 24. Mesuré, donc abandonné.

La sortie est de **regarder au lieu de parier** : au premier saut de ligne dans un champ
quoté, chercher en avant un guillemet fermant. S'il n'y en a pas, le champ ne se refermera
jamais — ce n'est plus une hypothèse — et la ligne est close sans rien absorber. Un guillemet
oublié coûte désormais **une** ligne. Le budget ne sert plus que de garde-fou au cas tordu où
un guillemet parasite trouve un fermant appartenant à une autre cellule.

**Et j'ai écrit un bug dans le correctif lui-même** : la fin du fichier et le plafond de
recherche rendaient tous deux `true`, donc le cas même qu'on cherche à détecter se lisait
« champ légitime ». 25 lignes utilisables au lieu de 49, sur un fichier contenant **un seul**
guillemet. Attrapé par le test que je venais de resserrer — voir plus bas.

**Deux tests à moi étaient faux, et c'est le motif de `CLAUDE.md` qui se répète**

- « Les quatorze colonnes de la planche 11d se répartissent en trois qualités » appelait
  `analyze(header:)` **sans lignes**. La passe de déduction par le contenu ne jouait donc
  jamais, et l'assertion décrivait un classement que le fichier réel ne produit pas. Le test
  était crédible et verrouillait une intention fausse. Remplacé par deux tests, dont un avec
  les trois lignes de données du mock — celui-là échouait avant correction.
- Le test fondateur du lecteur assenait `usable.count >= 40` sur 50 lignes. Il tolérait neuf
  disparitions sans le dire, et la revue a mesuré 41 derrière ce vert. C'est un compte exact
  désormais, et c'est lui qui a attrapé mon bug de regard en avant.

**Le bug le plus coûteux : les corrections de masse ne repartaient pas**

`settingCell` mettait à jour `cells` et laissait `rawFields`, dont le rapport redéposable est
construit. Corriger 214 années, exporter les écartées pour finir les durées au tableur,
redéposer : les 214 corrections avaient disparu. Le fichier était redéposable au sens du
format, pas au sens du travail.

**La correspondance devinait une date d'achat en date de sortie**

La règle d'abstention — « une forme, un seul champ disponible » — ne protégeait que par
accident : dès qu'un alias avait réclamé `added_at`, `release_date` devenait le seul champ
`.date` restant, et `bought_at` le prenait. Seules les formes à contrainte **discriminante**
se déduisent désormais du contenu : année, booléen, multivaleur. Une date ou un entier, jamais.

**Le repository créait un doublon silencieux**

Le doublon de `Genre.nameKey`, transposé. La lecture triait sur `updatedAt` seul, donc une
correspondance personnelle ne masquait l'intégrée que si elle était plus récente — or un
`isBuiltIn` arrive par mise à jour ou par fusion CloudKit, donc **plus tard**. Et `save`,
trouvant l'intégrée, insérait un nouvel enregistrement à chaque appel : trois enregistrements
pour une signature, dont deux personnels.

**Deux trous de contrat comblés**

- Rien ne **rejouait** un mappage relu : `ColumnMapping` s'écrivait, se relisait, se
  versionnait, et aucune fonction n'en faisait une `ColumnAnalysis`. La promesse de la fiche
  n'était pas exécutable depuis Core sans mettre la logique de reprise dans une vue.
- La malformation de la ligne d'**en-tête** était jetée : le rapport accusait une colonne
  manquante au lieu d'un guillemet non fermé.

**Ce que la revue n'a pas trouvé**, et que je note parce que ça vaut autant : aucune
dépendance à la locale dans le code neuf, aucun tri instable, aucune assertion adossée à un
document de design pour une règle de modèle, et la frontière de la coupe `L11a` / `L11b`
intacte — `grep` sur `ModelContext` dans `Services/Transfer/` ne rend qu'un `Set.insert`.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| `swift test` CineShelfCore | **349 tests** (320 avant) |
| `xcodebuild test` macOS | **67 tests**, `TEST SUCCEEDED` |
| `swiftlint --strict` | 0 violation / 199 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Preuve — le guillemet ouvre à nouveau n'importe où | 2 assertions mordent |
| Preuve — fin de fichier confondue avec le plafond | 3 tests mordent |
| Preuve — la correction ne repart plus dans le rapport | 1 test mord |
| Preuve — la déduction reprend les dates | 3 assertions mordent |
| Preuve — l'intégré repasse devant le personnel | 1 test mord |

Les cinq preuves ont vérifié que l'injection était **réellement présente** avant de conclure,
comme la règle ajoutée à `CLAUDE.md` ce matin l'exige. Sans elle, la preuve n° 3 de la passe
précédente m'avait déjà menti une fois.

---

## 2026-08-04 — `cells` dérivé, la méthode de la sonde, et `L11b`

**La question de structure, d'abord.** `cells` et `rawFields` étaient bien deux stockages
indépendants : le correctif de la veille écrivait les deux, donc il traitait le symptôme.
Rien ne les obligeait à s'accorder — l'initialiseur public acceptait n'importe quelle paire,
et l'appelant calculait lui-même l'index de colonne, si bien qu'un index faux les aurait
désaccordés en silence.

`ImportRow` ne porte plus qu'une source : `rawFields`, la ligne du fichier. `cells` en est
une **projection** à travers `ColumnLayout`. `settingCell` ne prend plus d'index — la ligne
consulte sa propre disposition, donc personne ne peut lui en passer un faux. Une valeur
décidée pour un champ sans colonne va dans `overrides` : ce n'est pas un second stockage des
mêmes valeurs, un champ est dans l'un **ou** dans l'autre, et cette exclusion remplace
l'accord à maintenir. L'assertion d'accord reste écrite quand même, comme pour les deux
branches de `#Predicate` : c'est elle qui mordrait si quelqu'un remettait un stockage
parallèle.

**La méthode de la sonde, inscrite dans `CLAUDE.md`** — attendue sur `L11b`, `L13`, `L20`.
Elle a immédiatement payé.

### `L11b` : le piège central, désarmé en trois pièces

Les repositories sont `@MainActor` à cause de `SpotlightIndexer`, `ImportActor` est un
acteur, et 1 284 lignes ne peuvent pas passer par le fil principal.

| Pièce | Ce qu'elle porte |
|---|---|
| `EntityResolver`, **non isolé** | La règle de dédoublonnage. Les repositories `@MainActor` la lui **délèguent** : une seule règle, deux appelants |
| `ImportWriter` | `refreshDerived()` sur chaque entité, prouvé par **idempotence** |
| `SpotlightBatchIndexer` | L'indexation après commit, en une passe |

La clé de dédoublonnage des personnes est `sortName` : le schéma est fermé, donc pas de
`nameKey` — et `sortName` est déjà « nom prénom » replié en locale invariante. `Person.sortKey`
la compose au même endroit, et un test compare les deux. Sans lui, changer l'un des deux
casserait le dédoublonnage **en silence**, la recherche ne trouvant jamais de doublon.

`ActivityRecorder` perd son `@MainActor` : c'était une isolation par contagion.

### Trois défauts que la sonde a trouvés, et qu'aucun test n'aurait vus

**1. L'annulation était décorative.** La méthode était synchrone, donc elle tenait son fil du
premier au dernier titre :

| Mesure | Avant | Après |
|---|---|---|
| Fil tenu d'affilée, 1 500 lignes | **6,3 s** | ~35 ms entre deux réveils |
| `cancel()` programmé à 300 ms | exécuté à **6,8 s**, après la fin | mord au lot suivant |
| `Thread.isMainThread` dans la boucle | **vrai** — l'interface gelait | inchangé, mais la main est rendue |

Un test qui annule *avant* le démarrage passait au vert et ne prouvait rien.

**2. Le bilan d'une annulation était faux.** Il se calculait par
`created.prefix(lignes sauvegardées)`, où l'un compte des titres et l'autre des lignes : dès
qu'une ligne complétait un doublon au lieu d'en créer un, le bilan annonçait des titres qui
n'existaient pas. Remplacé par des **instantanés** pris à chaque frontière de lot — ça ne se
calcule pas, ça se constate.

**3. Rendre la méthode asynchrone a ouvert une porte.** Un acteur est **réentrant** : deux
imports simultanés partageaient le `ModelContext`, et le `rollback()` de l'un jetait le lot en
cours de l'autre. Deux bilans plausibles et faux. Un verrou les refuse.

### Deux mesures qui ont changé une décision

**Le seuil de suspension n'est pas celui du lot.** Aligner les deux faisait tenir le fil
160 ms d'affilée — un à-coup visible. La durabilité a pour unité le lot de 200, la réactivité
la sienne, à 50.

**La superlinéarité vient de SwiftData, pas de mon résolveur.** Mesuré, import de 1 200
lignes, temps par lot : 164, 340, 557, 778, 1 269, 1 143 ms. J'ai d'abord soupçonné le `fetch`
par ligne du résolveur, puis l'accumulation dans le contexte — un contexte **neuf par lot** ne
change rien (75, 277, 538, 735, 823, 1 019 ms). C'est le `save()` sur une table qui grossit.
4 000 lignes prennent 40 s. Écart inscrit pour `L13`, qui importera les vraies données.

### Un test que j'ai rendu déterministe, et qui a perdu son mordant

Les tests d'annulation annulaient après un `Task.sleep`. Sur une machine rapide, l'annulation
arrivait **avant** le premier lot : zéro titre écrit, et `0` étant un multiple de 200,
l'assertion « s'arrête à une frontière de lot » passait sans rien vérifier. Corrigé en
annulant depuis la fermeture de progression, donc à un point connu.

**Mais ça a coûté au test sa capacité à prouver la suspension** : annuler depuis l'acteur pose
le drapeau sans qu'aucune suspension soit nécessaire. Preuve d'échec tentée, `Task.yield()`
retiré : les cinq tests d'annulation **passent**. Ce qui justifie la ligne est donc la mesure
et non un test, et c'est écrit à côté d'elle. Même statut que les budgets de `docs/04` §4.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| `swift test` CineShelfCore | **398 tests** (349 avant) |
| `xcodebuild test` macOS | **67 tests**, `TEST SUCCEEDED` |
| `swiftlint --strict` | 0 violation / 209 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Bissectabilité du commit 1/3 seul | build vert, **355 tests** verts |
| Preuve — correction détournée vers `overrides` malgré une colonne | 4 tests mordent |
| Preuve — verrou de réentrance retiré | 3 assertions mordent |
| Preuve — `Task.yield()` retiré | **ne mord pas** : la mesure justifie la ligne, pas le test |

---

## 2026-08-04 — La revue de `L11b` : cinq défauts, dont un que j'aurais dû voir

Sous-agent de revue, méthode de la sonde appliquée comme `CLAUDE.md` l'exige désormais. **Cinq
vrais bugs**, tous reproduits sur ma propre sonde avant correction — un rapport de revue n'est
pas une vérité, et deux de ses griefs ne se sont pas confirmés.

### Les deux bloquants

**La clé de doublon ignorait « Date de sortie ».** L'année ne venait que de la colonne `year`,
et `TitleQuery.living` traite une année nulle comme « cherche un titre **sans** date » — ce qui
est juste par ailleurs. Un fichier portant « Date de sortie » seule écrivait donc une date puis
cherchait l'absence de date :

| Entrée | Avant | Après |
|---|---|---|
| 2 lignes identiques, importées 2 fois | **4 fiches** « Dune » | 1 |

Aucun signal, et un bilan cohérent avec lui-même. C'est le défaut que j'aurais dû voir : ma
sonde de la veille n'avait essayé que des fichiers avec « Année ».

**Le bilan comptait le même titre plusieurs fois.** Les issues étaient repliées ligne par ligne
et non par entité. Trois lignes décrivant la même fiche donnaient « 1 ajouté, 2 complétés » pour
**un** titre, et le même `UUID` figurait dans `createdTitleIDs` **et** dans `completions` — un
diff que `L20` aurait exécuté en supprimant le titre puis en tentant de restaurer des champs sur
une fiche disparue. Repliage par entité, précédence `created > completed > unchanged`.

### Les trois majeurs

- **La même personne répétée dans une cellule créait deux crédits.** Le côté genres avait son
  test ; l'entrée équivalente sur la colonne voisine n'avait pas été essayée.
- **Une date complète dans la colonne « Année » perdait son jour**, en silence, sur une cellule
  que l'aide du champ promet d'accepter et que rien ne refusait.
- **Le verrou de réentrance ne protégeait rien.** Indexé sur `ObjectIdentifier(actor)` : deux
  `ImportActor` sur le même conteneur avaient deux verrous. 600 titres au lieu de 300, sans
  qu'aucun `alreadyRunning` ne soit levé — et **mon propre montage de test** avait la propriété
  calculée qui déclenche le cas. Pire, `ObjectIdentifier` est une adresse **recyclée** : cinq
  acteurs successifs donnaient deux identités. Le verrou protège désormais un **magasin**, par
  `NSMapTable` à clés faibles comparées par pointeur.

### Deux comportements arbitrés plutôt que subis

**Un réimport enrichi ajoute.** Mesuré : un genre et un acteur ajoutés au fichier étaient
abandonnés sans être comptés nulle part — sur le geste le plus naturel après avoir complété son
tableur. Ce n'est pas une entorse à « ne jamais écraser » : rien n'est retiré, et un troisième
import identique est bien « inchangé ». Le diff porte les relations rattachées, faute de quoi
l'enrichissement serait appliqué mais **pas annulable**.

**Le privé est monotone** : un fichier peut rendre privé, jamais rendre public. Entre les deux
erreurs possibles, exposer un contenu marqué privé est la seule qui ne se répare pas — c'est la
fuite que `L3` a fermée.

### Deux griefs qui ne se sont pas confirmés, et ce qu'ils ont révélé

La revue signalait qu'une reprise de brouillon détruisait les valeurs contenant le séparateur, et
qu'une ligne mal découpée y redevenait prête. Sur un **vrai** fichier écrit par `CSVWriter`, ni
l'un ni l'autre : le brouillon est fidèle. Ce qui était faux, c'est **mon helper de test**, qui
joignait les champs par `;` sans échapper. Il rendait donc plus faible tout test l'employant, sans
que rien ne le montre. Corrigé pour passer par `CSVWriter` — et un `rawCSV` séparé est apparu pour
les cas qu'un écrivain correct ne produit pas, comme une ligne trop courte.

Le grief portait à côté, mais il pointait un vrai trou : **le chemin de reprise n'existait qu'en
test**. `malformationCauseKey` était écrit dans le brouillon et personne ne le lisait.
`restoredDocument()` et `restoredAnalysis()` livrent ce chemin.

### Un test creux, et une preuve qui a demandé de casser deux gardes

« Le verrou se relâche après une annulation » utilisait deux instances d'acteur, donc il passait
quoi qu'il arrive.

Et la monotonie du privé est gardée **deux fois** — par `isEmpty` et par `setTyped`. Casser une
seule des deux laisse les tests verts, puisque l'autre suffit. Il a fallu injecter les **deux**
fautes pour que le test morde. C'est écrit à côté du code : quiconque simplifie l'une en la
croyant redondante retire un filet, pas un doublon.

**Vérifications**

| Contrôle | Résultat |
|---|---|
| Build `CineShelf` macOS / iOS | `** BUILD SUCCEEDED **` |
| `swift test` CineShelfCore | **414 tests** (398 avant) |
| `xcodebuild test` macOS | **67 tests**, `TEST SUCCEEDED` |
| `swiftlint --strict` | 0 violation / 212 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Preuve — clé de doublon sans `release_date` | 3 assertions mordent |
| Preuve — dédoublonnage des crédits retiré | 1 test mord |
| Preuve — date complète tronquée à l'année | 3 assertions mordent |
| Preuve — enrichissement redevenu muet | 3 assertions mordent |
| Preuve — monotonie du privé, **les deux** gardes cassées | 1 test mord |

---

## 2026-08-04 — Fin de session : `L11a` et `L11b` faites, poussées

Changement de machine. Tout est sur `origin/main` en `b7c4284`, arbre de travail propre,
`origin/main..main` et `main..origin/main` vides, les 36 hashes du tableau d'état vérifiés
atteignables **depuis `origin/main`** et non depuis un HEAD local — c'est le piège du `--amend`,
qui a mordu trois fois.

### Ce qui est livré

`L11a` (le format et l'analyse, aucune écriture de modèle) et `L11b` (l'application au magasin)
sont faites, revues, et corrigées après revue. Le tableau d'état les coche avec leurs hashes ;
`L12` devient la suivante.

Le piège central de `L11b` — repositories `@MainActor` à cause de `SpotlightIndexer` contre un
`ImportActor` — est désarmé en trois pièces : `EntityResolver` non isolé auquel les repositories
**délèguent**, `ImportWriter` qui porte `refreshDerived()` prouvé par idempotence, et
`SpotlightBatchIndexer` qui indexe après commit.

### Les cinq défauts que la revue a trouvés

Tous reproduits sur ma propre sonde avant correction, tous corrigés, chacun avec son test de
non-régression et sa preuve d'échec :

| # | Défaut | Effet mesuré |
|---|---|---|
| 1 | La clé de doublon ignorait « Date de sortie » | **4 fiches** au lieu d'1, sans un signal |
| 2 | Le bilan repliait par ligne et non par entité | Le même `UUID` dans `created` **et** `completions` — diff non défaisable |
| 3 | Une personne répétée dans une cellule | 2 crédits vers la même personne |
| 4 | Une date complète dans la colonne « Année » | Jour et mois jetés en silence |
| 5 | Le verrou de réentrance sur `ObjectIdentifier(actor)` | **600 titres au lieu de 300**, aucun refus levé |

Le premier est celui que j'aurais dû voir : ma sonde n'avait essayé que des fichiers portant
« Année ». Le cinquième était déclenché par **mon propre montage de test**, qui fabriquait un
acteur par accès.

### Les deux arbitrages

**Un réimport enrichi ajoute.** `genres`, `director` et `cast` sont additifs : un second fichier
plus riche complète au lieu de ne rien faire. Mesuré, l'ajout était sinon abandonné sans être
compté nulle part — sur le geste le plus naturel après avoir complété son tableur. Rien n'est
jamais retiré, un import identique reste « inchangé », et le diff porte les relations rattachées
pour que `L20` puisse les détacher.

**Le privé est monotone.** Un fichier peut rendre privé, jamais rendre public. Exposer un contenu
marqué privé est la seule des deux erreurs qui ne se répare pas — la fuite fermée par `L3`, index
Spotlight unique pour l'appareil. La propriété est gardée **deux fois** (`isEmpty` et `setTyped`)
et casser une seule laisse les tests verts : ce n'est pas une redondance à simplifier.

### Ce qui reste à faire, et en premier

> **La réorganisation de rythme demandée pendant cette session n'a pas été faite.** C'est la
> **première chose** à traiter à la reprise, avant `L12`.
>
> Son contenu n'est pas inscrit ici et n'était plus dans mon contexte au moment de clôturer :
> je ne l'ai donc pas paraphrasé de mémoire, pour ne pas figer une version fausse d'une consigne
> dans le document qui fait référence. **À redire en une phrase à la reprise**, et à inscrire à ce
> moment-là. C'est exactement le motif que ce journal documente ailleurs : une consigne mal
> recopiée est pire qu'une consigne absente, parce qu'elle a l'air d'une décision.

Le reste du chemin critique est inchangé : `L12` (archive), puis **prompt 2** (dump du bundle web,
dépendance dure de `L13`).

### État des vérifications à la clôture

| Contrôle | Résultat |
|---|---|
| `git status` | propre |
| `origin/main..main` / `main..origin/main` | vides |
| Hashes du tableau atteignables depuis `origin/main` | 36 / 36 |
| `swift test` CineShelfCore | **414 tests** |
| `xcodebuild test` macOS | **67 tests** |
| `swiftlint --strict` | 0 violation / 212 fichiers |
| `xcrun swift-format lint` | 0 avertissement |
| Builds macOS et iOS | `** BUILD SUCCEEDED **` |

---

## 2026-08-04 — Réorganisation du rythme : la rigueur se règle sur l'irréversibilité

Planification seule, aucun code. C'est la réorganisation que la clôture précédente
signalait comme demandée et non faite, et dont elle avait **refusé de paraphraser le
contenu** de mémoire — à raison : la consigne redonnée en séance contenait deux points
que je n'aurais pas devinés (le regroupement de la chaîne `I` par lots de trois, et la
liste exacte des reports en v1.1).

**Le dépôt local était en retard de 34 commits**, dont `L10`, `L11a`, `L11b`, `I1` et
tout le handoff de design. `main..origin/main` non vide, `origin/main..main` vide :
fast-forward pur, aucun commit local à rebaser. C'est le cas que la section « Reprise de
session » de `CLAUDE.md` décrit, et le contrôle des deux sens l'a attrapé avant la
première écriture. Deuxième fois en deux jours.

### Cinq décisions inscrites

1. **La rigueur ne dépend plus de la couche.** « Chaîne `L` = rigueur maximale » était
   faux, et n'était écrit nulle part — c'était une règle orale, ce qui explique qu'elle
   n'ait jamais été corrigée. Le critère est désormais l'irréversibilité, en une
   question : *si cette tâche a un défaut et que personne ne le voit pendant trois
   semaines, est-ce que la donnée est récupérable ?* Deux crans, et une seconde porte
   qui compte autant sans être de l'irréversibilité — exposer du privé ne se répare pas.
2. **La longueur des rapports suit le même cran.** Cinq lignes sur une tâche légère. Les
   rapports détaillés restent là où ils ont servi.
3. **La chaîne `I` est inventoriée et regroupée** : 26 composants → **9 lots de trois**,
   `I2` à `I10`, validation groupée au catalogue. Elle n'avait jamais été inventoriée —
   le plan disait « `I2` et suivantes, un par un » sans que personne sache combien.
4. **Cinq reports en v1.1**, inscrits avec ce qui reste en v1 pour chacun.
5. **Deux arbres de travail**, `main` pour la chaîne `L` et `chain-i` pour la chaîne `I`.

### Trois corrections au classement proposé

Le classement donné en séance était juste sur les dix tâches qu'il nommait. Il en
laissait **quatre non classées, et toutes les quatre écrivent sans retour** — ce qui
aurait laissé la plus dangereuse des quatre tomber en rigueur par défaut :

- **`L8`** (doublons et fusion) est **maximale**. C'est la correction la plus importante :
  la fusion transfère des relations et marque le perdant supprimé, et rien ne l'annule
  avant `L20`. `L20` était classée maximale — or `L20` n'est que le **filet** de `L8`.
  Classer le filet en maximale et l'opération en défaut est exactement à l'envers.
- **`L15`** (transfert entre bibliothèques) est **maximale** : elle rejoue l'exécuteur de
  `L8`.
- **`L16`** (maintenance et corbeille) est **maximale** : c'est la seule tâche qui
  **supprime définitivement**, et après le prompt 21 la suppression se propage à tous
  les appareils.
- **`L14`** ne tient dans aucun des deux crans sur l'axe de l'irréversibilité : sa
  logique de verrou est légère, mais la **portée du déverrouillage et le délai de grâce**
  décident qui voit le privé. Classée légère « sauf un point nommé », plutôt que
  d'ouvrir un troisième cran.

`L5` et `L6` ont été examinées et **restent légères** : ce que `L5` perd sous pression
mémoire est un cache régénérable, et une mosaïque fausse (`L6`) se voit au premier coup
d'œil. `L17` est légère pour une raison de plus que celle donnée — sa propre fiche dit
qu'elle ne sera jamais vérifiable avant le prompt 21, donc la rigueur y achète du vide.
`L18` est légère avec deux points nommés : le filtre du privé, et la mesure de tout
prédicat nouveau.

### Trois conséquences du report de `L8`, qui n'étaient pas dans la consigne

1. **Le format du diff de `L20` doit rester capable de porter une fusion** même si `L8`
   part en v1.1 — sinon `L8` devra faire évoluer `BulkEditDiff.currentVersion`, et un
   `payload` déjà en base ne se relit pas autrement.
2. **`L15` se réduit au transfert** : sa fusion des genres en double dépend de `L8` et
   part avec elle.
3. **`L13` importera les doublons du bundle web**, et rien en v1 ne les fusionnera. Son
   rapport de vérification doit donc les **compter et les nommer** — `LegacyRecord` le
   lui permet — même sans savoir les résoudre.

### Le chemin jusqu'à l'iPhone avait deux étapes manquantes

`L12 → prompt 2 → L13` amène les vraies données dans le magasin **d'une machine**. Pas
sur l'iPhone, et le plan ne le disait nulle part :

- **`P0` — la signature.** `DEVELOPMENT_TEAM` est vide et deux `CODE_SIGN_IDENTITY: "-"`
  traînent dans la cible : dans cet état l'app ne s'installe **que** dans le simulateur.
  Un Apple ID gratuit suffit ; l'abonnement ne sert qu'à CloudKit, au widget et aux App
  Intents, tous trois hors chemin puisque `L19` est reportée.
- **`P1` — faire entrer le bundle dans l'appareil.** Sans CloudKit, une migration jouée
  sur le Mac ne se propage pas. **Conséquence directe sur `L13` : elle doit lire un
  bundle choisi par l'utilisateur, pas un chemin local.** Le coût d'y penser à
  l'écriture est nul ; celui d'y penser après est une réécriture de son point d'entrée.

### Les fichiers que les deux arbres se disputent

Six, par nuisance décroissante : `docs/journal.md` (append au même endroit, conflit
garanti — **remède : `docs/journal-design.md` pour la chaîne `I`**), le tableau d'état de
`PROMPTS.md` (remède : la chaîne `I` a désormais sa propre section, à des centaines de
lignes du chemin critique), le tableau des écarts connus (seul point où un conflit reste
probable — il se résout en gardant les deux lignes), `.swiftlint.yml` (blocs disjoints :
exclusions pour `I`, règles pour `L`), `project.yml` (sources en glob, donc disputé
seulement à l'ajout d'une cible), et la CI.

Deux pièges hors de Git, vérifiés : le glob `DerivedData/CineShelf-*` devient **ambigu**
dès le premier build du second arbre — et c'est précisément la commande qui ouvre le
catalogue, donc le geste de validation de la chaîne `I` ; et le magasin SwiftData est
**commun aux deux arbres**, même bundle ID, donc même `~/Library/Containers`.

Un seul sens de rebase : `chain-i` sur `main`, jamais l'inverse.

### Vérifications

| Contrôle | Résultat |
|---|---|
| `git log --oneline main..origin/main` avant | **34 commits de retard** — fast-forward appliqué |
| `git log --oneline origin/main..main` avant | vide |
| `gh run list` | verte sur `31395e9` |
| Build macOS | `** BUILD SUCCEEDED **` |
| `git worktree list` | 2 arbres, `main` et `chain-i` |

Aucun code touché, donc aucune suite de tests relancée : les chiffres de la clôture
précédente (414 tests Core, 67 macOS) tiennent.

**Suite : `L12`, l'archive `.cineshelfarchive`. Rigueur maximale** — c'est de l'écriture
de données, et c'est le format qui portera les sauvegardes.

---

## 2026-08-04 — `L12` : l'archive `.cineshelfarchive`

Première tâche menée sous le nouveau régime. **Rigueur maximale** : c'est de l'écriture de
données, et c'est le format qui portera les sauvegardes.

### Le format

Un **paquet de dossier**, pas un `.zip` (`docs/04` §7) : `manifest.json`, dix-neuf
`entities/*.json`, `media/<uuid>.bin`. Le motif est celui qui a fait retirer l'archive du
handoff de design — un binaire ne se diffe pas, ne s'inspecte pas, et ne se répare pas à la
main. Une sauvegarde dont on ne peut pas ouvrir un fichier pour vérifier ce qu'elle contient
n'inspire aucune confiance au moment précis où on en a besoin.

Quatre décisions de format, chacune contre une perte identifiée :

1. **Les dérivés ne sont pas écrits.** `sortName`, `searchText`, `filterKeys`, `nameKey`,
   `displayName`, `ageAtDeath` sont absents des fichiers et **recalculés** à la
   restauration. Les écrire créerait une seconde source de vérité qui divergerait de la
   fonction au premier changement de règle de repliage — et il y en a déjà eu un
   aujourd'hui. Comme `filterKeys` dérive des identifiants des relations, préservés tels
   quels, le recalcul rend exactement la même valeur, et un test le vérifie.
2. **Les énumérations sont en `rawValue`, jamais typées.** Décoder en `TitleKind`
   remplacerait par `.movie` un enregistrement écrit par une version future et rapatrié par
   CloudKit. Une sauvegarde conserve ce qu'elle trouve ; elle ne normalise pas.
3. **Les fichiers de `media/` sont nommés par l'identifiant de l'asset, pas par son
   `checksum`.** Le checksum vaut `""` sur tout asset dont personne ne l'a calculé — le cas
   de `DemoCatalog`, écart connu — donc nommer par checksum aurait écrit deux assets dans le
   même fichier, le second écrasant le premier **sans qu'aucun compte ne bouge**.
4. **Le manifeste porte les comptes, et la relecture les vérifie.** C'est ce qui distingue
   « ce catalogue n'a pas de collections » de « le fichier des collections a été perdu ».
   Sans ça, un fichier vidé se restaure en silence, amputé — la forme exacte du défaut du
   lecteur CSV, qui annonçait 7 lignes sur 15.

`ArchiveEntityFile` est une énumération de dix-neuf cas, et les trois `switch` qui la
parcourent sont **exhaustifs sans `default`** : ajouter une entité au schéma sans lui donner
son fichier cesse de compiler. C'est le filet qui remplace la vigilance, et le seul qui
tienne — le manifeste étant écrit depuis cette même liste, une entité oubliée ne ferait
bouger aucun compte. `cyclomatic_complexity` est désactivée sur ces trois-là, comme sur
`ColorTokens.generated.swift` : la complexité mesurée est celle des dix-neuf cas, pas celle
du code, et les découper détruirait la propriété qui les justifie.

### Les deux arbitrages

**L'archive contient tout, y compris la corbeille et le fil.** Les dix-neuf entités, dont
les `deletedAt`, les `ActivityEntry` avec leur `payload` de diff, et les `LegacyRecord`. Une
sauvegarde qui perdrait la corbeille supprimerait définitivement, à la restauration, ce que
l'utilisateur avait seulement jeté ; une qui perdrait le fil rendrait inannulable tout lot
antérieur, sans le dire.

**La relecture fusionne par identifiant, elle ne remplace pas.** Une entité déjà en base est
laissée **intacte** : rien n'est jamais écrasé, et rejouer la même archive ne change rien la
seconde fois. Ça rend l'opération sûre sur une base non vide — récupérer trois fiches
perdues n'oblige pas à tout effacer d'abord. La contrepartie est écrite noir sur blanc :
**ce n'est pas un « restaurer la sauvegarde »**, qui se fait en repartant d'un magasin vide.

### Les deux défauts que la sonde a trouvés

Aucun n'était visible depuis la suite : tous deux rendaient un bilan **plausible et faux**.
C'est le troisième cas du dépôt, après le lecteur CSV et l'écriture d'import, et le motif
est chaque fois le même — la sonde imprime, le test assène.

| # | Défaut | Effet mesuré |
|---|---|---|
| 1 | Les douze entités de la passe 2 étaient sautées par un `where !exists(…)`, qui ne note rien | Bilan « 0 créé, **15** ignoré » sur une archive de **26** entités : onze manquaient, donc le bilan laissait croire à onze disparitions — sur l'opération dont le seul rôle est de rassurer |
| 2 | `mediaSource: nil` ne comptait **rien** | Catalogue complet restauré **sans une seule image**, en annonçant zéro anomalie |

Le second était documenté comme un raccourci de test, ce qui est exactement ce qui l'a rendu
invisible : un paramètre dont l'abus est décrit comme un usage légitime ne se relit plus.
Correction : un seul compteur pour les deux façons de finir sans octets — fichier absent, ou
source non fournie. L'état final est le même, une fiche sans image, donc les distinguer
n'aiderait personne.

Les deux corrections sont **prouvées par injection**, la faute constatée présente avant de
conclure : la première fait mordre le test en nommant `import_mappings` (1 en archive, 0
compté), la seconde en rendant 0 au lieu de 3. Puis retour au vert après restauration du
code sain.

### Ce que la sonde a validé, et qui n'allait pas de soi

- **Deux écritures du même catalogue sont identiques octet pour octet**, 19 fichiers sur 19
  — clés JSON triées, et identifiants de genres triés parce que SwiftData ne garantit pas
  l'ordre d'un `to-many`. C'est ce qui rend une archive diffable.
- **Les inverses de relations se repeuplent seuls**, y compris `Library.importMappings`, qui
  est déclaré **sans** `@Relationship(inverse:)` et n'existe que pour que le miroir CloudKit
  accepte le schéma. La restauration n'a donc pas à écrire les deux côtés.
- **`updatedAt` survit.** `refreshDerived()` pose `updatedAt = .now`, et la passe des
  dérivés l'appelle : la date de l'archive est reposée **après** chaque appel. Sans ça, un
  catalogue restauré daterait entièrement du jour de sa restauration, et « trié par date de
  modification » deviendrait faux partout — sans qu'aucun test de compte ne le voie. Dérive
  mesurée : **0,8 ms**, la troncature de l'ISO 8601 à trois décimales.
- Les six refus de format, chacun avec son injection vérifiée : manifeste absent, version
  inconnue, fichier d'entité absent, fichier illisible, compte faux, date illisible.
- Références pendantes comptées (4 sur 4), média manquant compté sans annuler la
  restauration, octets orphelins de `media/` comptés, rattachement à deux propriétaires
  compté sans être corrigé (`L16` nettoie).

### Trois passes, et pourquoi

Créer, relier, dériver. La séparation n'est pas un goût : `Title.collection` et
`TitleCollection.titles` se pointent mutuellement, donc trier les dix-neuf entités par
dépendance n'a pas de solution. Et `Title.refreshDerived()` lit `collection`, `genres` et
`credits` pour composer `filterKeys` : l'appeler avant que les relations existent rendrait
un filtre vide, et le titre serait **introuvable par tout critère** — muet, puisque sa fiche
s'afficherait parfaitement. C'est la même famille de défaut que la grille vide derrière 42
tests verts.

### Mesures

Sur ma machine, magasin sur disque :

| Opération | 2 000 titres |
|---|---|
| Écriture de l'archive | **136 ms** |
| Relecture (format seul, aucun magasin) | **12 ms** |
| Restauration | **2 416 ms** |

La restauration est superlinéaire pour la raison déjà mesurée à `L11b` : `save()` sur une
table qui grossit. Ce n'est pas le résolveur. Conséquence pour `L13`, qui restaurera des
volumes réels : prévoir la durée, et mesurer sur appareil avant de promettre quoi que ce
soit.

### `Transferable`

`ArchiveFile` conforme à `Transferable` par `FileRepresentation` — un chemin, pas un
contenu : une archive avec ses affiches pèse des dizaines de mégaoctets, et une
représentation par `Data` obligerait à tout lire pour un AirDrop. À l'import, le fichier reçu
est **déplacé** avant que la valeur soit rendue : l'emplacement temporaire du système est
reprisdès le retour de la fermeture, et l'URL portée pointerait vers un fichier disparu —
erreur qui ne se verrait qu'à la relecture, loin de là.

Le type est déclaré dans `Info.plist`, dans les **deux** sections. `UTExportedTypeDeclarations`
dit « cette app produit ce type », `UTImportedTypeDeclarations` « elle sait le lire » : sans
la seconde, une archive reçue par AirDrop n'aurait pas CineShelf comme destination possible,
et le partage ne servirait qu'à sortir des données, jamais à les faire revenir. Conformité à
`com.apple.package`, plus `LSTypeIsPackage`, pour que le Finder l'affiche comme un fichier
unique.

`UTType` est construit par extension de nom de fichier et **non** par `UTType(exportedAs:)`,
qui *piège le processus* quand le type n'est pas déclaré dans le bundle courant — donc sous
`swift test`, où le binaire n'en a pas. Même piège que CloudKit, qui termine le processus
faute d'identifiant de paquet.

### Vérifications

| Contrôle | Résultat |
|---|---|
| `swift test` CineShelfCore | **441 tests**, dont 27 d'archive |
| `swiftlint --strict` | 0 violation |
| `xcrun swift-format lint` | 0 avertissement |
| `plutil -lint Info.plist` | OK |
| Preuve d'échec, défaut 1 | mord, en nommant `import_mappings` |
| Preuve d'échec, défaut 2 | mord, 0 au lieu de 3 |

### Écarts que `L12` laisse

- **Pas de progression ni d'annulation.** `ArchiveRestorer` est synchrone. `docs/04` §7 ne
  demande la progression que pour l'import, et 2 000 titres prennent 2,4 s — mais un
  catalogue réel de 10 000 titres gèlera l'interface. À reprendre avec `V8`, sur le modèle
  d'`ImportActor` : le verrou de réentrance et le patron par lots existent déjà.
- **La passe des dérivés ne sauvegarde pas par lots**, contrairement aux deux premières :
  tout est accumulé et sauvegardé une fois. Sans effet mesurable à 2 000 titres, à surveiller
  au-delà.
- **Aucun test ne tourne contre un `Info.plist`.** La déclaration du type de fichier n'est
  vérifiée que par `plutil`, et `UTType(filenameExtension:)` fabrique un type dynamique
  quand la déclaration manque : une faute de frappe dans l'identifiant passerait tous les
  tests. La vérification appartient à `Tests/CineShelfTests`, qui a un bundle — non fait.

---

## 2026-08-04 — La revue de `L12` : sept défauts, et une correction que les tests ont rejetée

Sous-agent de revue adverse, comme la rigueur maximale l'exige. Il a construit sa propre
sonde hors dépôt et **trouvé sept défauts de plus** après les deux de la mienne, chacun
reproduit et chiffré avant d'être affirmé. Tous corrigés, tous avec un test.

### Ce qu'ils avaient en commun, et pourquoi je ne les voyais pas

**Tous les sept vivent dans la restauration sur un magasin qui n'est pas vide.** Or mes
tests restauraient sur une cible vide et comparaient des comptes ; le seul qui touchait à
une base peuplée vérifiait que l'archive **n'écrase pas** — jamais que ce qu'elle
**ajoute** est cohérent. La fusion partielle est pourtant le mode d'emploi que j'ai moi-même
écrit sur le type : « récupérer trois fiches perdues n'oblige pas à tout effacer d'abord ».

C'est un angle mort de suite de tests, pas une inattention : j'avais testé le chemin que
j'avais conçu, et le chemin que j'avais **annoncé** restait nu.

| # | Défaut | Effet mesuré |
|---|---|---|
| 1 | Un crédit rendu à un titre déjà en base laissait `filterKeys` périmé | **0 titre trouvé au lieu de 1** par le prédicat SQL, la fiche affichant la personne |
| 2 | Rejouer l'archive ne reposait jamais les octets d'un asset présent mais vide | Asset vide **pour toujours**, bilan « ignoré », zéro anomalie |
| 3 | Des octets tronqués étaient restaurés en silence | **7 octets** posés pour 4 096 annoncés, zéro compteur |
| 4 | `manifest.schemaVersion` était écrite et relue par **personne** | Archive de schéma 9.9.9 acceptée sans un mot |
| 5 | Un fichier de `entities/` inconnu était invisible | `episodes.json` d'un schéma V2 ignoré sans trace |
| 6 | `mediaFileCount` n'était vérifié par personne | `media/` entièrement perdu, relu sans erreur |
| 7 | Deux erreurs avalées (`?? []` et `try?`) | `media/` illisible → **0 orphelin**, soit la réponse d'une archive saine |

**Le premier est le plus grave, et c'est la classe de défaut de `L1`** : le titre s'affiche
parfaitement et n'existe pour aucun critère. `Title.refreshDerived()` compose `filterKeys`
depuis `credits`, et ma passe des dérivés ne traitait que ce qu'elle venait de créer. La
correction rafraîchit tout titre touché, créé ou non, **en gardant son `updatedAt` de
base** — la fiche appartient à l'utilisateur, seul son index était périmé, et le redater
serait le même défaut à l'envers.

Le septième mérite d'être noté pour lui-même : le `try?` de `exists()` faisait lire « n'existe
pas » à une erreur de `fetch`, donc **insérait un doublon d'identifiant** dans une base sans
`@Attribute(.unique)`, que le dédoublonnage applicatif ne regarde pas pour ces tables. Une
erreur de magasin doit interrompre, pas se transformer en écriture.

### La correction que les tests ont rejetée

Pour le sixième, ma première correction faisait de l'écart de `mediaFileCount` une **erreur
de relecture**. Deux tests existants ont rougi immédiatement — et ils avaient raison :
refuser contredit deux décisions déjà prises et écrites, « un média manquant n'annule pas la
restauration » (sinon on perd neuf cent quatre-vingt-dix-neuf affiches pour une absente) et
« un orphelin n'est pas une erreur ».

Ce qui manquait n'était pas un refus, c'était **l'information avant d'écrire**. D'où
`mediaFilesFound` et `mediaFileDelta`, relevés à la relecture et reportés au bilan.

C'est le premier cas du dépôt où un test existant attrape une **régression de décision**
plutôt qu'une régression de code. Ça vaut d'être dit : les deux tests en question ne
vérifiaient pas un comportement subtil, ils encodaient un arbitrage — et c'est ce qui les a
rendus utiles trois heures plus tard.

### Le défaut d'interruption, corrigé au passage

La revue a aussi mesuré, avec un observateur concurrent sur le même fichier de magasin, que
`checkpoint()` commettait **700 titres sur 700** avec `sortName` et `searchText` vides
pendant la restauration : introuvables en recherche, et une interruption — `save()` qui lève,
jetsam iOS — les y laisse pour de bon. Les dérivés sont désormais posés dès la passe 1, puis
reposés en passe 3 avec les relations. Aucun état commis n'est plus vide.

### Ce que la revue a vérifié et trouvé correct

Utile à savoir, parce que ça ferme des questions : **couverture champ par champ des
dix-neuf `@Model`, aucun champ manquant** ; aucune relation du schéma qui tombe entre les
deux conventions ; `exists()` voit les insertions en attente, donc deux enregistrements de
même identifiant dans un fichier donnent une ligne et non deux ; l'ordre est préservé partout
où un champ le porte (`orderIndex`, `pinIndex`, `sortIndex`, `roleValues`).

Un point relevé et **assumé** : `sorted(_:)` normalise l'ordre de `Title.genres`, et sa
justification — « SwiftData ne garantit pas l'ordre d'un `to-many` » — est **fausse**, il le
préserve. Le tri reste nécessaire à la diffabilité de l'archive, et `filterKeys` est
insensible à l'ordre, donc rien de fonctionnel ne casse : c'est l'ordre d'affichage des
genres d'une fiche qu'une sauvegarde réécrit. Inscrit aux écarts.

### Vérifications après correction

| Contrôle | Résultat |
|---|---|
| `swift test` CineShelfCore | **450 tests** (36 d'archive) |
| `xcodebuild test` macOS | **67 tests** |
| Builds macOS et iOS | `** BUILD SUCCEEDED **` |
| `swiftlint --strict` | 0 violation |
| `xcrun swift-format lint` | 0 avertissement |
| Preuve d'échec, défaut 1 | mord : prédicat SQL à **0 au lieu de 1** |
| Remesure des 7 sur la sonde | tous fermés |

---

## 2026-08-04 (2) — Trois corrections de plan, et `P0` : la signature

### `L13` et le prompt 2 sortent du chemin critique

Le raisonnement qui les y avait mis était explicite dans le document : « la nouvelle
direction artistique ne pourra être jugée que sur les vraies affiches, donc le chemin le
plus court vers `L13` est le chemin le plus court vers la capacité à valider le design ».
**Il ne tient plus** : le catalogue de tokens est validé, et les 120 titres de
`DemoCatalog` suffisent pour le reste.

`L13` reste sur le chemin, mais **en dernière position avant CloudKit**, pour la raison
qui n'a pas bougé : elle déclenche le gel de `versionIdentifier`, donc tout ce qui touche
au schéma doit passer avant elle — `L20` en particulier. Ce qui a disparu est le *motif*,
pas la contrainte.

**Ce que j'ai trouvé en cherchant le nouvel ordre.** Le plan confondait deux jalons :

- **utilisable** — l'app s'installe et se manipule. `DemoCatalog` se peuple depuis les
  Réglages et le banc d'essai des prompts 10-11 l'affiche déjà : il ne manque **que la
  signature**. Ni composant, ni écran ;
- **présentable** — la nouvelle direction est à l'écran, ce qui demande `I2`…`I10` puis
  les `V`.

Ça inverse l'ordre attendu : la signature d'abord, les composants ensuite. Les `V` sont
dégelées au passage — leur condition de départ n'était pas « attendre le design », qui
est livré, mais « attendre les composants », ce que la colonne « S'appuie sur » disait
déjà. `CLAUDE.md` est repris en conséquence : ce qui reste interdit est de **retoucher
l'esthétique du banc d'essai**, qui sera remplacé et non amendé.

### L'organisation à deux arbres est retirée

`CineShelf-design` et `chain-i` supprimés après contrôle : 0 commit propre, 0 modification
en attente. Deux dossiers et deux branches à synchroniser ne se justifiaient que par deux
chaînes parallèles, et il n'en reste qu'une sur le chemin. `docs/journal-design.md` part
avec — sa seule raison d'être était le conflit d'append entre les deux arbres, et il ne
contenait qu'une note d'ouverture. Le laisser aurait été pire qu'inutile : il disait
« écris ici pour la chaîne `I` ».

### Le remote du clone web, et la leçon qui va avec

Corrigé vers `CineShelf_old`, vérifié par `git ls-remote` (`refs/heads/main → 56ed7a7`).

**La leçon vaut d'être retenue, parce qu'elle est muette :** renommer un dépôt GitHub et
réutiliser son nom laisse tous les clones existants pointer vers **le nouvel occupant**.
GitHub ne redirige que tant que l'ancien nom reste libre. Ici, l'app web s'appelait
`CineShelf`, elle est devenue `CineShelf_old`, et l'app native a repris le nom : le clone
web pointait donc sur le dépôt natif, avec lequel il n'a **aucun commit commun**. Un
`git pull` y ramenait l'app native ; un `git push --force` écrasait l'app native.

Inscrit sur la fiche du prompt 2, avec l'emplacement du clone — il n'est suivi par aucun
dépôt (imbriqué dans `ControlHub`, zéro fichier suivi), donc sa seule sauvegarde est
`CineShelf_old`.

### `P0` — la signature passe par un `xcconfig` local

`DEVELOPMENT_TEAM` était vide dans `project.yml`. Le poser en dur était exclu : **le
dépôt est public**, et un identifiant d'équipe est personnel. Second motif, moins évident
et plus décisif à l'usage : `xcodegen generate` réécrit le `.xcodeproj` à chaque ajout de
fichier, donc **une équipe choisie dans l'interface d'Xcode serait perdue à la
régénération suivante**.

Trois fichiers : `Signing.xcconfig` versionné pose le défaut vide puis
`#include? "Local.xcconfig"` ; `Local.xcconfig` gitignoré porte la valeur ; un `.example`
documente. Le **point d'interrogation** de `#include?` rend l'inclusion optionnelle —
sans lui, un clone neuf et la CI échoueraient sur un fichier absent.

**Le piège du mécanisme, et pourquoi je l'ai mesuré au lieu de le supposer.** Un build
setting du projet **écrase** un `xcconfig`. Laisser `DEVELOPMENT_TEAM: ""` dans
`settings.base` aurait donc rendu `Local.xcconfig` inopérant *alors qu'il est là et
correctement rempli* — tout aurait eu l'air juste. J'ai donc fait le contre-test :

| Mesure | Résultat |
|---|---|
| Sans `Local.xcconfig` | aucune valeur — le défaut vide |
| Avec `Local.xcconfig = SONDE12345` | **`SONDE12345`** |
| **Faute réintroduite** dans `project.yml`, fichier toujours rempli | valeur **vide** — l'écrasement est réel |
| Build appareil sans équipe | `error: Signing for "CineShelf" requires a development team.` |
| Builds macOS et simulateur iOS | `** BUILD SUCCEEDED **` |

Rigueur légère, mais le contre-test n'est pas du zèle : il vérifie l'affirmation que
portent les commentaires du fichier, et cette affirmation est la seule chose qui empêchera
quelqu'un de remettre la valeur dans `project.yml` dans six mois.

**Ce qui reste à faire à la main**, parce que c'est interactif : ajouter le compte Apple
dans Xcode. Mesuré, `security find-identity -v -p codesigning` rend **0 identité** et
aucune équipe n'est enregistrée. Un Apple ID gratuit suffit.

### Suite

`I2` — carte affiche (les 6 variantes), carte paysage, carte personne. Rigueur légère.

---

## 2026-08-04 (3) — Cap recentré sur le Mac, et `I2`

**Trois corrections de plan.** `L13` et le prompt 2 sortent du chemin critique ; `P0`
passe « configurée, non vérifiée sur appareil » et en sort aussi — ni le Mac ni le
simulateur ne demandent de signature. Le chemin est réécrit en **trois paliers** autour du
Mac : belle et navigable, utilisable au quotidien, complète. Écart inscrit sur ce que le
simulateur ne peut pas mesurer — il décode les images avec le processeur du Mac, donc les
budgets de `04 §4` restent des **intentions** tant que `P0` n'est pas vérifiée, et il est
plus traître qu'un runner partagé parce qu'il est *plus rapide* que l'appareil : il rassure.

**Trois tâches `V` manquaient au plan.** Les prompts 10 et 11 sont ✅ mais en banc d'essai,
et le tableau des `V` est indexé sur les prompts 12 à 24 : personne ne portait « refaire la
grille des titres contre le nouveau design ». D'où `V0` (chrome) et `V0 bis` (titres), plus
`V5a` qui détache l'accueil de `V5`.

**`I2` — les trois tuiles.** Rigueur légère. Trois choses valent d'être notées.

*J'ai d'abord lu la mauvaise direction.* Le premier bloc du prototype qui rend une carte
est `1a` ; la direction retenue est **`2a` Plein cadre**. L'écart n'est pas cosmétique :
`1a` entoure la carte d'un liseré d'accent au survol, `2a` l'agrandit de 6 % sans liseré.
Sans la relecture, j'aurais livré un composant fidèle à une direction écartée.

*Le brief compte deux composants là où il en faut un.* « Carte affiche · carte paysage » :
la différence est le ratio, et le ratio est déjà `CardLayout`. Deux vues auraient dupliqué
le remplissage, le recadrage, le masque privé et le survol — et la matrice
`disposition × taille` est une **fonctionnalité mémorisée par contexte**, pas une variante
de dessin. Le lot garde trois composants parce que la tuile détaillée en est un vrai.

*Un défaut de `P0` trouvé au passage, et c'est le plus utile de la session.* Les tests du
catalogue ont échoué sur `No signing certificate "Mac Development" found`, cible
`DesignSystemAssetTests`. Cause : `REMPLACE_MOI` était une valeur **active** dans
`Local.xcconfig.example`, donc copier le fichier sans l'éditer — le geste exact que le
`README` recommande — cassait le build. Mesuré : 52 tests verts → build cassé.

Ce que ça apprend sur mon contre-test de `P0` : il vérifiait `-showBuildSettings`, donc la
**lecture** de la valeur, et jamais un build de test complet avec le fichier en place.
J'avais mesuré la bonne chose au mauvais endroit. Corrigé en commentant la clé dans le
`.example` — un exemple dont la copie casse le build est un piège, pas un exemple — et en
inscrivant ce que je n'avais pas vu : `DEVELOPMENT_TEAM` s'applique à **toutes** les
cibles, y compris les bundles de test, qu'aucune raison n'oblige à signer.

| Contrôle | Résultat |
|---|---|
| `swift test` DesignSystem · Core · MediaKit | 51 · 450 · 38 |
| `xcodebuild test` DesignSystemCatalog | **52 tests** |
| Builds macOS · simulateur iOS · catalogue | `** BUILD SUCCEEDED **` |
| `swiftlint --strict` · `swift-format` | 0 · 0 |
| Copie du `.example` sans édition, rejouée | `DEVELOPMENT_TEAM` vide, 52 tests verts |

**Suite : `I3`** — carte collection, vignette de galerie, avatar de profil.

---

## 2026-08-04 (4) — Le piège des directions fermé, et `I3`

**Trois corrections de méthode**, toutes destinées à ne plus dépendre de ma mémoire.

*Le piège des directions est fermé par un document, pas par une intention.* `docs/design/README.md`
gagne un §0 « Comment lire les planches » qui **nomme** les cinq blocs abandonnés — `1a`
Salle obscure, `1b` Rayonnage, `1c` Console, `2b` Soixante-cinq, `2c` Paysage — et donne le
point qui rend la règle utilisable : **tout ce qui porte un numéro de bloc `3` ou plus est
déjà dans la direction retenue**, donc le doute ne porte que sur `1x` et `2x`. Renvoi dans
`CLAUDE.md`, à la liste des documents de référence.

Deux pièges de plus, trouvés en inventoriant : `Directions.dc.html` est un **agrégat de
307 Ko** où une direction abandonnée voisine une planche finale, et `Tokens.dc.html` comme
`États.dc.html` sont des **versions courtes** de leurs planches (32 Ko contre 89, cinq blocs
contre onze). Les quatorze fichiers sont arrivés dans le même commit, donc la date ne tranche
pas ; ce qui tranche est que la planche numérotée contient tout ce que la version courte a,
et davantage.

*Une règle nouvelle dans `CLAUDE.md`, et c'est celle qui compte le plus.* Un tableau de
vérification ne porte que des commandes **réellement passées**. Une commande non lancée
s'écrit « non lancée », jamais ✅ ; un sous-ensemble le dit ; un chiffre repris d'une session
précédente est marqué comme tel ; aucune inférence. C'est le seul risque qui soit
indétectable de l'autre côté.

*Son corollaire, tiré du défaut de `P0` :* **une preuve exerce le geste, pas la valeur.** Le
contre-test lisait `DEVELOPMENT_TEAM` ; le bug était dans le fait de **copier** le fichier.
Trois mesures vertes, et le défaut passait entre elles. `P0` est remise à jour : elle
désignait `9984a52`, le commit qui portait le défaut, sans mentionner le correctif
`faf07cd`.

### `I3` — et le §0 a servi tout de suite

Le premier composant que j'ai cherché est l'avatar de profil. Le bloc `1a` en montre un —
**rond, 28 px, initiale en Archivo**. Le bloc `7f`, retenu, en montre un autre — **carré,
46 px, initiale en Bebas Neue, texte sombre sur la couleur du profil**. J'aurais dessiné le
rond, et il aurait été le **seul arrondi de toute l'interface** : la direction `2a` n'a aucun
rayon, nulle part. Le piège s'est donc rejoué exactement comme prévu, un lot après avoir
mordu — et cette fois la règle l'a arrêté.

Deux autres relevés qui ne se devinent pas :

- **La mosaïque de collection n'a pas de gouttière.** Le `grid` du prototype n'a pas de
  `gap` : les quatre jaquettes se touchent, ce qui fait **une** image. Une gouttière en
  aurait fait quatre vignettes. Et le survol y est à 1,03, pas 1,06 — la collection est plus
  large, donc le même facteur la ferait déborder davantage.
- **La vignette de galerie porte le ratio de l'image**, pas un ratio imposé. C'est toute la
  différence entre une galerie et une grille, et c'est pour ça qu'elle ne prend pas de
  `CardLayout` : lui en donner un l'aurait transformée en `PosterTile`.

**Une question laissée ouverte par le report de `L6` se referme ici.** Le report annonçait
« reste en v1 : un repli calculé à l'affichage ». Ce repli **est** le design retenu — le
sous-titre du bloc `4e` dit « couverture générée en mosaïque quand elle manque ». La mosaïque
se compose à l'écran depuis les jaquettes déjà chargées et n'écrit rien ; `L6` n'ajoutera que
la possibilité d'en faire un asset exportable.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` (DesignSystem) | ✅ **51 tests** |
| `xcodebuild build -scheme DesignSystemCatalog -destination macOS` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild test -scheme DesignSystemCatalog -destination macOS` | ✅ **52 tests** |
| `xcodebuild build -scheme CineShelf -destination macOS` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild build -scheme CineShelf -destination iOS Simulator` | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| `swift test` CineShelfCore · MediaKit | **non lancées** — aucun de leurs fichiers n'est touché par `I3` |
| `xcodebuild test -scheme CineShelf` (macOS) | **non lancée** — `I3` ne touche ni `App/` ni `Tests/` |

Les deux dernières lignes sont l'application de la règle du jour : je ne les ai pas lancées,
donc elles ne sont pas vertes. Leur dernier passage connu date de la session précédente
(450 · 38 · 67).

**Suite : `I4`** — rail horizontal, grille adaptative, squelette de chargement. C'est le lot
qui débloque les écrans : sans lui, aucune `V` ne peut être posée.

---

## 2026-08-04 (5) — `I4`, et une constante retirée plutôt que documentée

Rail horizontal, grille adaptative, squelette de chargement. Rigueur légère.

**`Breakpoint.columns` est supprimée, pas annotée.** Le tableau des points de rupture de
`docs/design/README.md` §4.6 donne une colonne « Colonnes » que `I1` avait transcrite en
constante. Elle n'avait aucun lecteur hors du catalogue et d'un test, et elle contredit la
règle arrêtée par l'addendum 2 bloc `13c` — « le nombre de colonnes n'est pas un réglage :
la largeur de carte est fixe, la grille prend ce qui rentre ». Le seul écart réel est à
1280 pt, où la table dit 6 et le calcul donne 7 ; à 1680 la table dit « 7+ », que 9
satisfait. Une constante morte qui contredit le code vivant finit par se faire respecter
par quelqu'un qui croit corriger un oubli, et c'est le troisième motif du genre. Le compte
n'existe donc plus qu'en un endroit, `GridMetrics.columnCount`, qui sert aussi le masonry
de la galerie — `I3` l'y avait explicitement renvoyé.

**Ce que les tests peuvent réellement assener ici.** Deux largeurs seulement ont été
rendues pour de vrai par le design : 393 px → 2 colonnes et 834 px → 4, dans l'addendum 2.
Ce sont celles-là que `GridMetricsTests` cite avec leur source ; les quatre autres crans du
tableau n'ont aucun rendu qui les vérifie, et le reste est couvert par une propriété — `n`
colonnes tiennent, `n + 1` ne tiennent pas. C'est cette propriété qui a attrapé une
constante fausse que j'avais calculée de tête (`poster.xxl` à 1280 : j'attendais 3, la
réponse est 4).

**Un cran de gouttière que la densité seule ne donne pas.** Le §4.6 écrit « ≥ 1680 : marges
64, gouttière 24 » alors que la densité par défaut du Mac est dense, donc 16. D'où
`Breakpoint.gridGutter(_:)`, sur le modèle de `screenMargin` : ces deux mesures sont données
par point de rupture, pas seulement par densité.

**Deux dettes nommées plutôt que devinées.** La couleur dominante du squelette (planche 7)
se déduit de la première composante du `blurHash` — un décodeur, pas un champ, donc rien à
demander au schéma fermé — et son producteur est assigné à `L5`, inscrit sur sa fiche.
`ShelfRailModel.counter(visible:)` et `.progress(visible:)` deviennent morts : leur filet
compteur était de la pagination déguisée, que le §7 interdit. Ils sont au point 8 de la
procédure de suppression de `Legacy/`, à `V12` — le seul point de cette procédure qui vise
un fichier hors du dossier, et c'est pour ça qu'il y est écrit.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` (DesignSystem) | ✅ **57 tests** (51 avant `I4`) |
| `xcodebuild test -scheme DesignSystemCatalog -destination macOS` | ✅ **58 tests** (52 avant) |
| `xcodebuild build -scheme DesignSystemCatalog -destination macOS` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild build -scheme CineShelf -destination macOS` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild build -scheme CineShelf -destination iOS Simulator` | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 239 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| `swift test` CineShelfCore · MediaKit | **non lancées** — `I4` ne touche aucun de leurs fichiers |
| `xcodebuild test -scheme CineShelf` (macOS) | **non lancée** — `I4` ne touche ni `App/` ni `Tests/` |
| `xcodebuild test -scheme CineShelfUITests` | **non lancée** |

Les trois dernières lignes ne sont pas vertes : je ne les ai pas lancées. Leur dernier
passage connu date de deux sessions plus tôt (450 · 38 · 67).

**Suite : `I6`** — badge d'état, barre de notation, indicateur de progression.

> **Cette ligne disait d'abord « Suite : `I5` », et c'était faux.** `I5` porte la ligne de
> tableau, le jeton de filtre et la pastille de compteur — les composants de la **console
> de gestion**, palier 3. Le chemin critique dit `I4` → `I6` → `V0`. L'erreur vient de la
> table « Les neuf lots », qui était triée par **numéro** et se lisait comme un ordre de
> travail ; elle est désormais triée par ordre de travail et porte une colonne « Quand ».

---

## 2026-08-04 (6) — `I6`, et un crash de suite qui ne nommait aucun test

Badge d'état, barre de notation, indicateur de progression. Rigueur légère.

**Le piège de la notation était armé, et il n'a pas mordu.** « Cinq étoiles pleines, pas
de demi-étoile » est une règle de **rendu** : le modèle note sur 10 (`docs/02` §3.3,
`CatalogBounds.ratings`), et `TitleFormat.fiveStarRating` divise déjà par deux. `RatingBar`
vit donc entièrement dans l'espace d'affichage — elle reçoit une note **déjà convertie sur
5** et ne décide rien de ce qui s'écrit en base. Deux conséquences qui ne se devinent pas :
la version éditable n'émet que **sur un geste**, donc ouvrir un éditeur ne réécrit pas une
note impaire venue d'un import ; et une note fractionnaire garde son affichage de référence
ailleurs — « 4,5 ★ » sur la tuile détaillée, comme la planche 3 le montre. La barre
arrondit pour choisir son nombre d'étoiles, et son en-tête dit qu'elle n'est pas
l'affichage de référence.

**Le test qu'on n'a pas écrit, et pourquoi.** Il aurait été tentant d'assener ici « le
modèle note sur 10 ». C'est `CatalogBounds.ratings`, dans `CineShelfCore`, que
`DesignSystem` ne peut pas importer — le recopier aurait produit une seconde source de
vérité pour une valeur qui n'en a qu'une, exactement ce qu'on venait de retirer de
`Breakpoint.columns`. La frontière est déjà tenue ailleurs.

**Une heure perdue sur un crash, et la leçon vaut d'être écrite.** `swift test` sortait en
`signal code 5` sans nommer un seul test — y compris avec un filtre qui ne sélectionnait
*rien*, ce qui m'a fait croire à un problème de chargement de bundle. Le rapport système a
tranché : `_swift_task_checkIsolatedSwift`, dans la clôture d'un `map` porté par
`ProgressTrack`. **`View` est `@MainActor`**, donc tout membre d'une vue l'est aussi, et une
clôture qui capture `self` depuis un test non isolé fait sauter le processus au lieu
d'échouer proprement.

Deux façons de traiter ça, et j'ai utilisé les deux à bon escient : l'arithmétique pure
**sort** de la vue (`ProgressMetrics`, même forme que `GridMetrics` pour `I4`) ; les jetons
d'une teinte, qui n'ont rien à extraire, se testent en `@MainActor`. Ce qu'il faut retenir :
sur ce projet, **une suite qui saute sans nommer de test se diagnostique par
`~/Library/Logs/DiagnosticReports`**, pas en bissectant à l'aveugle — j'ai bissecté
d'abord, et ça m'a coûté six exécutions pour arriver là où la pile menait directement.

**Deux corrections de méthode, demandées et faites.** La table « Les neuf lots » était triée
par **numéro** et se lisait comme un ordre de travail : après `I4` on y lit `I5`, alors que
le chemin critique dit `I6` — `I5` porte la console, palier 3. Elle est désormais triée par
ordre de travail, avec une colonne « Quand ». Et la précédence de la gouttière de grille est
écrite à un seul endroit : `Density.gridGutter` devient `Density.baseGridGutter`, le nom
porte la règle, et la raison du désaccord de `macWide` est sur la fonction qui l'applique.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` (DesignSystem) | ✅ **63 tests** (57 après `I4`) |
| `xcodebuild test -scheme DesignSystemCatalog -destination macOS` | ✅ **64 tests** (58 après `I4`) |
| `xcodebuild build -scheme DesignSystemCatalog -destination macOS` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild build -scheme CineShelf -destination macOS` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild build -scheme CineShelf -destination iOS Simulator` | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 244 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| `swift test` CineShelfCore · MediaKit | **non lancées** — `I6` ne touche aucun de leurs fichiers |
| `xcodebuild test -scheme CineShelf` (macOS) | **non lancée** — `I6` ne touche ni `App/` ni `Tests/` |
| `xcodebuild test -scheme CineShelfUITests` | **non lancée** |

Les trois dernières ne sont pas vertes : elles ne sont pas mesurées. Dernier passage connu,
trois sessions plus tôt : 450 · 38 · 67.

**Suite : `V0`** — le chrome. C'est la première tâche `V` du palier 1, et elle s'appuie sur
`I2` `I3` `I4`, tous les trois faits.

---

## 2026-08-04 (7) — `V0`, et la barre latérale qui n'existait pas

Le chrome. Rigueur légère. C'est la première tâche qui touche `App/`.

**La direction retenue n'a pas de barre latérale, et je ne l'ai su qu'en lisant la légende
d'un bloc.** Le §4.6 en annonce une à quatre crans sur six — « en superposition »,
« permanente », « + inspecteur simultanés ». Aucun écran rendu n'en montre. Le bloc `3b` le
dit en toutes lettres : « même navigation régulière, **sans barre latérale** ». Mac et iPad
partagent une **barre horizontale en haut**. C'est le même résidu que la colonne
« Colonnes » du même tableau : une table de synthèse qui décrit une intention antérieure,
contredite par tout ce qui a été dessiné ensuite. Douze écrans contre quatre mots.

`Sidebar.swift` est supprimée. Ses deux contenus ne se sont pas évaporés pour autant, et
c'est le point de méthode de la session : **supprimer un point d'accès crée une lacune de
design, pas un retard.** Les genres épinglés n'ont plus aucune porte d'entrée — inscrit en
question ouverte, avec la piste que l'accueil affichant déjà des rails par genre, les genres
épinglés pourraient cesser d'être de la navigation pour devenir la *configuration de
l'accueil*. Les bibliothèques, elles, ont une destination vérifiée : **pas le menu de
profil**, contrairement à l'hypothèse naturelle — le design met le sujet dans un menu
`Bibliothèque` de la barre de menus et dans l'écran `7f`, donc `V7`.

**Ma prédiction sur `NavigationModelTests` était fausse, et je le savais avant de la
tester.** J'avais annoncé « douze tests verts sans y toucher ». Ils n'ont pas compilé : le
bloc `3c` donne cinq onglets — Accueil · Titres · Recherche · Ma liste · Gérer — là où la
coquille en avait cinq autres avec un « Catalogue » segmenté. `CatalogueSegment` disparaît,
et six tests avec lui. La prédiction était faite **avant** d'avoir lu la planche du chrome
compact : ce n'était pas une erreur de raisonnement, c'était une affirmation sur du code que
je n'avais pas encore confronté au design. Les quatre tests réécrits ont gagné un invariant
qui n'existait pas : **toute section a un onglet propre ou figure dans `CompactTab.managed`**
— sans lui, ajouter une section la rendrait inatteignable sur iPhone en silence.

**Une seconde lacune, trouvée en écrivant ce test.** Les cinq onglets du design ne couvrent
que cinq sections sur onze : Personnes, Collections, Galerie et Signets n'ont pas d'onglet,
et le handoff ne dit nulle part où on les atteint sur iPhone — son §6 ne parle que de la
*mise en page* des écrans non dessinés. Elles sont derrière « Gérer », qui est un défaut de
mieux et pas une lecture du design. Inscrit.

**Un jeton legacy attrapé au passage.** L'avatar de la barre tirait sa teinte de
`ProfileSession.accentColor`, qui rend `accentSolid` — un jeton de l'ancienne direction. La
couleur *par profil* est une vraie fonctionnalité, mais sa palette arrive avec `I9` et `V7` ;
d'ici là c'est l'accent unique. **`CompactRootView` et `ProfileMenu` sortent de la liste
d'exclusion de `no_legacy_design_system`**, et le lint vert le prouve — c'est la vérification
qui compte, pas l'intention.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **67 tests**, 9 suites |
| `xcodebuild test -scheme CineShelfUITests -destination iOS Simulator` | ✅ **1 test** (`testAppLaunches`, 72,9 s) |
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **450 · 63 · 38** |
| `xcodebuild test -scheme DesignSystemCatalog -destination macOS` | ✅ **64 tests** |
| `xcodebuild build -scheme CineShelf -destination macOS` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild build -scheme CineShelf -destination iOS Simulator` | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 245 fichiers, **liste d'exclusion réduite de deux** |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| Lancement réel sur Mac | ✅ processus `CineShelf` vivant après `open` |

Aucune ligne « non lancée » cette fois : `V0` touche `App/`, donc tout est concerné.

**Suite : `V0 bis`** — les titres : grille, fiche, éditeur. L'éditeur attend `I7`–`I9` ; la
grille et la fiche non.

---

## 2026-08-04 (8) — La grille des titres, et trois choses que le prototype ne tranche pas

`V0 bis`, **partiel** : la grille. La fiche et l'éditeur ne sont pas faits, donc la tâche
n'est pas cochée — elle porte un 🔶 et la liste de ce qui reste.

**Ce que le banc d'essai perd, et ce n'est pas rien.** La grille du prompt 11 posait sous
chaque carte un titre, une ligne de méta et trois pastilles d'action au survol. La direction
retenue n'a **rien** sous les affiches au repos — c'est arrêté au §10 — donc `CatalogGrid`,
`PosterCard` et `DisplayMenu` cessent d'être lus par cet écran, et les gestes passent au menu
contextuel. Ce n'est pas une simplification : c'est la différence entre une grille de
productivité et une grille où l'image parle seule.

**Une correction reçue et vérifiée avant d'écrire.** La consigne disait « la barre d'outils
d'écran existe depuis `V0`, la grille doit s'y brancher ». Elle n'existait pas : `V0` avait
livré `ScreenHeader` avec le titre seul, et documenté qu'il laissait l'emplacement d'actions
vide parce qu'un menu « Trier » posé par le chrome trierait quoi. L'intention était juste —
ne pas faire de seconde barre — mais le point de départ non. `V0 bis` **ouvre** cet
emplacement, et déplace le *placement* de l'en-tête du chrome vers l'écran : le poser au
niveau du chrome aurait donné deux en-têtes à tout écran ayant des actions.

**Trois choses que les planches ne tranchent pas, inscrites au lieu d'être devinées.**

- Le bloc `4a` montre **deux survols différents dans la même grille** : ses cartes en
  `sc-for` portent `scale(1.06)`, la règle du §7, mais la première y est dessinée à 1,1 avec
  titre, méta et actions — un `PosterTileDetail`. J'ai implémenté le survol **arrêté**, parce
  que c'est la règle écrite ; l'échange vers la carte détaillée serait un comportement
  qu'aucune phrase ne décrit. Conséquence à assumer : `PosterTileDetail`, livré par `I2`, n'a
  aujourd'hui **aucun appelant**.
- La rangée de filtres actifs est en **lecture seule** : les jetons cliquables à croix du
  bloc `4a` sont le composant de `I5`, palier 3. En écrire une version ici l'aurait fait
  exister en double le jour où `I5` arrive.
- L'état vide utilise encore `StateView`, du banc d'essai. La vue vide paramétrée est `I10`.

**Le store d'affichage change de type et de clé.** `CardDisplaySetting` cède la place à
`PosterSetting` — le couple `disposition × taille` de la matrice. Le préfixe de clé passe de
`display.` à `poster.` : sans ça, un ancien instantané se décoderait de travers, et un défaut
de contexte vaut mieux qu'une conversion approximative.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **67 tests**, 9 suites |
| `xcodebuild test -scheme CineShelfUITests -destination iOS Simulator` | ✅ **1 test**, 32,7 s |
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **450 · 63 · 38** |
| `xcodebuild test -scheme DesignSystemCatalog -destination macOS` | ✅ **64 tests** |
| `xcodebuild build -scheme CineShelf -destination macOS` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild build -scheme CineShelf -destination iOS Simulator` | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 246 fichiers, **liste d'exclusion réduite de deux de plus** |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| Lancement réel sur Mac | ✅ processus `CineShelf` vivant après `open` |

**Aucun test neuf.** La grille est une composition de composants déjà couverts, et son seul
calcul — le compte de colonnes — est testé dans `GridMetricsTests`. Le dire plutôt que de
laisser croire qu'un écran réécrit s'accompagne toujours de tests.

**Suite : `V0 bis`, la suite** — la fiche titre (hero, affiche, métadonnées, casting,
galerie, liens). L'éditeur attend `I7`–`I9`.

---

## 2026-08-04 (9) — La fiche titre, un composant supprimé et un autre corrigé

`V0 bis` avance : la fiche est faite. **L'éditeur ne l'est pas, et il est bloqué** — ses
champs sont ceux de `I7`–`I9`, palier 3, et le plan le disait déjà. Ce n'est pas un
renoncement, c'est la dépendance qui était inscrite.

**`PosterTileDetail` est supprimé.** La consigne était nette : soit il a un foyer, soit il
part. Recherche faite dans les onze planches — Recherche (`5b`), Ma liste (`5c`) et Signets
(`5d`) montrent des affiches **nues** ; le Fil (`5e`) et la console utilisent des **lignes**
de 38 pt, qui sont `I5` ; le seul rendu d'une carte « affiche + métadonnées » est dans le
bloc **`2b`**, direction abandonnée. Il n'avait donc pas de foyer. Le coût est réel — `I2`
l'avait livré deux jours plus tôt — mais un composant orphelin « au cas où » finit branché
par quelqu'un qui croit corriger un oubli, et sa reprise depuis `8262878` coûte moins cher
que ce faux branchement.

**`PersonTile` était fausse, et c'est un défaut de `I2` trouvé par la fiche.** Elle rendait
un rectangle 2:3, comme une affiche. Les **quatre** rendus de personne de la direction
retenue sont des **cercles en 1:1** : casting du bloc `4b` (96 pt), grille `4c`
(`aspect-ratio:1` + `border-radius:50%`), portrait `4d` (230 pt) et son rail « Souvent
avec » (84 pt).

Ça oblige à préciser une règle que j'avais énoncée trop largement à `I3` : « la direction
`2a` n'a aucun rayon, nulle part » est **faux**. Ce qui n'a jamais de coin arrondi, c'est ce
qui est **photographique et rectangulaire** — affiches, jaquettes, images. Une personne n'est
pas une affiche. Et l'avatar de **profil** du bloc `7f` reste carré non pas malgré la règle
mais **parce qu'il n'est pas un portrait** : c'est une pastille de couleur avec une
initiale, qui désigne un compte. Mon raisonnement d'`I3` arrivait à la bonne conclusion par
un motif trop large ; il aurait donné une réponse fausse ici.

**Un écart connu se referme.** « Sans média `backdrop`, la fiche n'affiche aucun hero » —
en réserve depuis le prompt 11. Le design tranche : le bloc `4b` pose la **même source** en
fond flouté et en affiche nette, et le §11 dit qu'aucune image large n'existe encore. La
fiche prend donc `backdrop` s'il existe, la jaquette sinon.

**Ce que le recadrage fait réellement, mesuré et pas supposé.** `DemoCatalog` ne crée que des
pièces jointes `.primary` et **aucune** ligne `MediaCrop`. Le hero emprunte donc le repli —
jaquette 600 × 900 (2:3 exact), contexte `.card`, recadrage `.neutral` — et `MediaFill` la
fait remplir une bande 16:9, ce qui lui coûte le haut et le bas. Sous un flou de 22 pt et un
agrandissement de 1,28, ça ne se voit pas. **Mais le chemin `CropContext.hero` reste non
exercé en pratique** : il le sera à `V2`, quand on pourra attacher une vraie image large.
C'est exactement la nuance que la question posait, et la réponse honnête n'est pas
« ça marche » mais « ça marche par le chemin de repli, l'autre n'est pas emprunté ».

**La lacune de `I6` est traitée là où elle coûtait.** La ligne de métadonnées de la fiche
porte la note **en chiffres** à côté de la barre : 8,4 et 8,0 donnent quatre étoiles et
seraient indistinguables. Le nombre est la forme que le design utilise lui-même ailleurs
(« ★ 4,5 », bloc `4a`), donc rien n'est inventé — seulement remis là où son absence coûtait
une décimale.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **67 tests**, 9 suites |
| `xcodebuild test -scheme CineShelfUITests -destination iOS Simulator` | ✅ **1 test**, 56,5 s |
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **450 · 63 · 38** |
| `xcodebuild test -scheme DesignSystemCatalog -destination macOS` | ✅ **64 tests** |
| `xcodebuild build -scheme CineShelf -destination macOS` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild build -scheme CineShelf -destination iOS Simulator` | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 245 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| Lancement réel sur Mac | ✅ processus `CineShelf` vivant après `open` |

**Aucun test neuf**, et le dire vaut mieux que le laisser croire : la fiche est une
composition de composants déjà couverts, et les deux corrections de composants
(`PersonTile` en cercle, `MediaFill` publique) sont des changements de **forme**, que la
suite existante ne peut pas distinguer — c'est la planche du catalogue qui les juge.

**Suite : `I7`** — champ texte, zone de texte, champ nombre. C'est ce qui débloque
l'éditeur, donc ce qui reste de `V0 bis`.

---

## 2026-08-04 (10) — L'accueil, et une barre qui réservait sa place

`V5a`, dernière tâche du palier « belle et navigable ». Rigueur légère.

**Un défaut de `V0` que seul le hero pouvait révéler.** La barre de navigation était posée
en `safeAreaInset`, qui **réserve** sa hauteur. Sur la grille et la fiche, invisible. Sur
l'accueil, l'image ne pouvait pas passer dessous : il restait une bande noire de 60 pt
au-dessus du hero, et le « plein cadre bord à bord » — ce que la direction a de plus
identifiable — disparaissait. Elle passe en `overlay`, et c'est désormais l'écran qui
décide : l'accueil et la fiche passent dessous, les écrans à en-tête se décalent de
`TopNavigationBar.height` par `ScreenHeader`.

C'est le genre de défaut qu'aucun test n'attrape et qu'aucun des deux écrans précédents ne
montrait. Il a fallu l'écran qui en dépend.

**La question ouverte des genres épinglés se referme, et la piste était la bonne.** Le bloc
`3a` défilé montre trois rails : « Ajoutés cette semaine », « **Mes genres · Drame** »,
« Ma liste · à voir ». Les genres épinglés ne sont donc pas une entrée de navigation
perdue avec la barre latérale — ils sont la **configuration de l'accueil**. Reste ouvert, et
c'est autre chose : **où** on épingle un genre, qui appartient à `V5b`.

**Le troisième voile est celui qu'on oublie.** Le hero en a trois : un dégradé vers le haut,
un vers la droite, et une **trame horizontale à 1,4 %** — une ligne claire tous les 3 pt.
Isolément invisible ; c'est elle qui donne au hero son grain de projection. Les trois sont
des dégradés **posés sur une image**, donc explicitement autorisés par le §4.1 : la règle
« zéro translucidité » ne vaut que pour les surfaces opaques.

**Ce que `V5a` ne fait pas.** `HomeSelection` tient les trois contraintes de la fiche —
stable dans la journée (la graine est le jour, pas l'instant), jamais archivé, jamais privé
si le profil les masque. Mais les **sélections éditoriales** de `L18` n'existent pas : ce
hero est une rotation quotidienne honnête, pas un choix. La tâche reste donc en 🔶.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **67 tests**, 9 suites |
| `xcodebuild test -scheme CineShelfUITests -destination iOS Simulator` | ✅ **1 test**, 26,6 s |
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **450 · 63 · 38** |
| `xcodebuild test -scheme DesignSystemCatalog -destination macOS` | ✅ **64 tests** |
| `xcodebuild build -scheme CineShelf -destination macOS` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild build -scheme CineShelf -destination iOS Simulator` | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 245 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| Lancement réel sur Mac | ✅ processus `CineShelf` vivant après `open` |

**Aucun test neuf** : `HomeSelection` en mériterait — la règle « stable dans la journée » est
exactement ce qui se teste — et je ne l'ai pas écrit. C'est une dette, pas une décision.

**Suite : la revue visuelle du catalogue**, puis `I7`.

---

## 2026-08-04 (11) — Fin de session : palier 1 atteint, et la porte qui manquait

Session de documentation pour clore. Aucun code.

**Le palier « belle et navigable sur Mac » est atteint.** `I2` `I3` `I4` `I6` livrés, `V0`
(chrome), `V0 bis` (grille et fiche) et `V5a` (accueil) faits — les deux derniers en 🔶
assumé : l'éditeur de `V0 bis` est bloqué sur `I7`–`I9`, et le choix **éditorial** du hero de
`V5a` appartient à `L18`. L'app s'ouvre sur Mac avec la nouvelle direction.

**Ce que la session a appris, et qui vaut plus que les écrans.**

*Une porte d'acceptation manquait, et son absence a coûté trois lots.* `PersonTile` a été
livrée fausse à `I2` — un rectangle 2:3 là où la direction montre des cercles — et elle a
passé **tous les tests** *et* la planche du catalogue. Le catalogue montre chaque composant
**seul**, jamais à côté de sa planche : on y vérifie qu'il existe et qu'il tient dans les
quatre apparences, pas qu'il **ressemble** au bloc. D'où la tâche `catalogue-porte`, placée
**avant** les corrections parce qu'elle est ce qui les rendra vérifiables.

*Une revue visuelle a trouvé dix écarts, et le client les a arbitrés.* Quatre à corriger,
six à garder au jeton. L'arbitrage est inscrit dans `docs/PROMPTS.md` — il ne se re-débat
pas. Le principe qui les sépare est passé dans `CLAUDE.md` : **les rendus gagnent quand ils
s'accordent entre eux, le jeton gagne quand ils se contredisent.**

*La vérification demandée sur la gouttière de rail était la bonne question.* Le prototype Mac
ne montre pas la densité ample, mais l'addendum 2 a rendu l'accueil et la fiche en iPhone et
en iPad : gouttière **10** sur iPhone, **14** sur iPad, **14** sur Mac — trois formats
d'accord, et aucun ne suit la densité. Et leurs marges tombent **exactement** sur
`Breakpoint.screenMargin` (20, 28), ce qui confirme *dans le même relevé* que la marge de
rail, elle, reste au jeton. Une seule recherche, deux verdicts opposés, tous deux fondés.

*Deux règles de doctrine ajoutées à `CLAUDE.md`*, toutes deux nées d'une erreur de cette
session : une règle énonce sa **raison** et pas seulement sa conséquence — « aucun rayon
nulle part » avait raison par accident, comme « chaîne `L` = rigueur maximale » avant elle ;
et une affirmation sur du code non confronté à sa source vaut un ✅ sur une commande non
lancée.

**Une dette nommée** : `HomeSelection` n'a aucun test, alors que « stable dans la journée »
est exactement ce qui se teste. Inscrite aux écarts connus, à reprendre avec `L18`.

**Suite : `catalogue-porte`**, puis les corrections 1, 2, 3 et 5. Dans cet ordre — la porte
d'abord, les corrections ensuite, pour qu'elles se constatent au lieu de se déduire.

---

## 2026-08-05 — La porte de bloc, et les quatre corrections qu'elle rend constatables

Reprise sur une autre machine : dépôt **34 commits en retard**, rien en local par-dessus,
donc `git pull --ff-only`. Le réflexe des deux sens a servi une troisième fois.

**La routine locale ne couvrait qu'une des deux plateformes du catalogue.** La CI teste
`DesignSystemCatalog` sur iOS *et* macOS (job `catalog`, matrice) ; `CLAUDE.md` n'en donnait
qu'une. La commande iOS y est inscrite, et elle a tourné : 64 tests verts sur iPhone 17
contre 65 sur macOS — l'écart est un test propre à macOS, pas un manque.

**`catalogue-porte` : onze composants portent désormais leur bloc et ses mesures.** À côté de
chaque composant de `I2` `I3` `I4` `I6`, la valeur attendue du bloc qui le spécifie, et ce
que le code fait quand les deux diffèrent. Les six écarts gardés au jeton s'y lisent sans
ouvrir une planche, et les quatre à corriger y étaient marqués comme tels — c'est ce qui
rendait leur correction constatable au lieu de déductible. Chaque correction a retiré sa
propre ligne, dans son propre commit.

**Aucune assertion, délibérément.** Un test qui comparerait ces nombres recopierait les mêmes
valeurs deux fois : il attraperait un changement de constante, et rien de ce qui a laissé
passer `PersonTile` en rectangle 2:3 — la forme, la police, le poids. Le revers est inscrit
aux écarts connus : **la porte ne mord que si le catalogue est ouvert et lu**, donc elle
appartient à la relecture d'un lot, pas à la suite de tests.

**Les quatre corrections, et les deux choses que les mesures ont changées.**

| Écart | Bloc | Ce qui a été fait |
|---|---|---|
| 1 · 2 | `3a` · `7f` | Barre : 26 pt et `Typo.label` — Archivo Narrow 600 à 11 pt, exactement `3a`. Le prototype **change de police avec la taille** |
| 3 | `2a` · addendum 2 | `Breakpoint.railGutter` : 10 sur iPhone, 14 au-delà. Distinct de `gridGutter(_:)`, qui reste la gouttière de **grille** |
| 5 | `8a` | Jeton `rating/empty`, vingtième rôle |

*La première mesure a corrigé l'arbitrage.* `bgFill` en sombre vaut oklch **0,289**, pas
« ≈ 0,26 » comme la table d'arbitrage l'estimait. L'écart 5 est donc plus petit qu'annoncé
(0,34 contre 0,289, pas un tiers) — il existe et va dans le sens dit, mais la table est
corrigée. Effet de bord utile : l'écart 9, gardé au jeton pour « deux centièmes de
luminance », n'en vaut qu'**un**, ce qui renforce son arbitrage.

*La seconde a tranché jeton contre dérivation.* Un jeton, parce que la barre de notation vit
aussi sur les surfaces de gestion, qui suivent l'apparence système : « éclaircir `bgFill` »
donnerait une étoile **plus claire que sa surface** en apparence claire. Une dérivation
n'est juste que dans une seule des quatre apparences. Seule l'apparence sombre est mesurée ;
les trois autres sont déduites du même rapport (7,5 % du chemin `bg/fill` vers
`text/primary`), comme `bg/inset` avant elle.

**Un filet a mordu, et c'était le bon.** `shapeStyleListIsExhaustive` a signalé que
`rating/empty` manquait à la table des accesseurs `ShapeStyle` du test — sa forme implicite
serait restée non vérifiée en silence. Trois assertions de compte (19 → 20) et
`ImplicitShapeStyleUsage` ont suivi.

**Un écart neuf, assumé.** L'avatar de la fiche garde Bebas à 22 pt là où `7f` pose 20 :
aucun rôle de `Typo` n'est Bebas à 20, et en ajouter un rouvrirait la porte que `Typo` a
fermée — textuellement le motif qui garde l'écart 8 au jeton.

| Commande | Résultat |
|---|---|
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **67 tests**, 9 suites |
| `xcodebuild test -scheme CineShelfUITests -destination iOS Simulator` | ✅ **1 test** |
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **450 · 64 · 38** |
| `xcodebuild test -scheme DesignSystemCatalog -destination macOS` | ✅ **65 tests** |
| `xcodebuild test -scheme DesignSystemCatalog -destination iOS Simulator` | ✅ **64 tests** — la commande qui manquait |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 246 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| Lancement réel du catalogue sur Mac | ✅ processus vivant |
| **Rendu de la porte à l'œil** | ❌ **non vérifié** — `screencapture` refusé (autorisation d'enregistrement d'écran). Le catalogue tourne, les planches compilent, mais je n'ai pas *regardé* la porte |

**La dernière ligne est la limite de cette session.** La porte est une porte **visuelle**, et
je n'ai pas pu la voir : la seule vérification qui compte vraiment pour elle reste à faire,
en ouvrant le catalogue.

**Suite : `I7`–`I9`**, qui débloquent l'éditeur de `V0 bis`.

---

## 2026-08-05 (2) — `L5` : le préchargement, l'échelle, et un écart connu qui n'existait plus

**Deux règles inscrites dans `CLAUDE.md`, symétriques.** Le `git pull --ff-only` entre dans
la routine d'ouverture — le cas normal est un dépôt en retard, trois fois sur trois — et le
`git push` clôt la session sans qu'il faille le demander : un dépôt local en avance n'est
pas un état, c'est un travail qui n'existe que sur une machine. Quatrième oubli.

**`L5`, en trois morceaux.**

*Le préchargement.* `PrefetchWindow` calcule la tranche, hors de toute vue — c'est la
troisième fois que le motif « l'arithmétique sort de la `View` » sert. La fenêtre est
**asymétrique** (24 devant, 8 derrière) : c'est le correctif noté depuis le prompt `13a`, on
défile vers le bas, et une fenêtre symétrique dépenserait la moitié de son budget sur des
vignettes déjà en cache. Côté `ThumbnailCache`, un registre de travail par clé donne
« jamais deux fois le même travail » **pour de vrai** : un affichage qui tombe sur un
préchargement en vol l'**adopte** au lieu de le doubler, et cesse alors de le rendre
annulable. La file borne à deux préchargements simultanés — déclarer une priorité basse ne
suffit pas quand vingt décodages tournent.

*Un défaut trouvé par son test, et il ne se voyait pas sans course.* « Ce qu'un affichage
attend n'est plus annulable » a échoué au premier jet : un affichage **adoptait une tâche
déjà annulée** et n'obtenait jamais d'image. La correction retire l'entrée du registre au
moment de l'annulation, ce qui laisse l'affichage en démarrer une neuve — et impose de
donner une identité à chaque travail, sinon la fin de l'ancienne tâche efface l'entrée de la
nouvelle.

*L'échelle d'écran.* `.displayScale(feeding:)` la renseigne depuis l'environnement, et
`imageLoader()` la **lit à l'appel au lieu de la capturer**. Une capture aurait figé la
valeur de l'évaluation de la scène : déplacer la fenêtre vers un écran @1x aurait continué à
produire du @2x sans que rien le signale.

*La couleur dominante.* Un décodeur d'une vingtaine de lignes, comme annoncé : la composante
continue d'un blurhash **est** la moyenne du signal, quatre caractères base 83 suffisent, et
les trois octets sont déjà en sRGB. Aucun champ, donc rien à migrer — c'est ce qui permet de
l'ajouter après la fermeture du schéma. `TileSkeleton` n'est pas touché : le paramètre de
couleur appartient au travail d'interface.

**Un écart connu était périmé, et c'est une fausse dette.** « `Bootstrap` ne branche pas
`startObservingMemoryPressure()` » : vérifié, le cache est instancié dans
`CineShelfApp.init()` et l'observation est branchée par `.task` sur `RootView` depuis le
prompt 11. La ligne n'avait pas été retirée. Un écart qui n'existe plus envoie chercher un
défaut absent et coûte le même temps qu'un vrai.

**Trois règles de lint et de format ont mordu, toutes utiles.** `no_literal_color` a refusé
un type nommé `RGBColor` — `…Color(red:` contient à la lettre le motif qu'elle cherche, y
compris dans un commentaire — et elle avait raison sur le fond : `MediaKit` ne produit pas
de couleurs mais trois nombres, d'où `RGBComponents`. `file_length` a refusé un fichier de
tests à 551 lignes, scindé en trois. `orphaned_doc_comment` a attrapé la docstring de
`Fixture` restée derrière quand le décor a déménagé.

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **450 · 64 · 54** (+16 sur MediaKit) |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **67 tests** |
| `xcodebuild test -scheme CineShelfUITests -destination iOS Simulator` | ✅ **1 test** |
| `xcodebuild test -scheme DesignSystemCatalog` · macOS et iOS Simulator | ✅ **65** et **64** |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 250 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **Mesure des budgets de `docs/04` §4** | ❌ **non lancée** — ils se vérifient avec Instruments sur appareil, et le simulateur donne des chiffres rassurants qui ne disent rien du matériel (écart connu) |
| **Préchargement en situation réelle** | ❌ **non vérifié** — aucune vue ne l'appelle encore, c'est `V3` et `V6` |

**Ce que `L5` ne prouve pas.** Le préchargement est exercé par ses tests, pas par un
défilement : tant que la grille ne l'appelle pas, « le défilement ne saccade plus » reste une
intention. La ligne du tableau est donc en 🔶, et non ✅.

**Suite : `L1 bis`**, ou `I10` — les deux suivantes du palier 2.
