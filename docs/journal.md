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
