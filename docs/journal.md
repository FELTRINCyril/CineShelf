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

**Post-scriptum du même jour — la CI, deux fois rouge, puis réparée.**

Le premier rouge (`30985835698`, job `Catalogue iOS`) ressemblait à un flake : le même code
a passé le run suivant, et je l'ai inscrit « à surveiller » avec la consigne explicite de ne
pas corriger le spécificateur en réaction. **Le second est arrivé une heure plus tard**
(`30989335077`, job `Build iOS`), et mon propre seuil — « deux occurrences suffiront à
trancher » — était atteint.

Cause commune, lisible dans les deux logs : le runner `macos-latest` arrive parfois sans
**aucun** appareil simulé créé. La liste des destinations qu'`xcodebuild` imprime ne contient
que des placeholders. Le runtime iOS est présent, les appareils ne le sont pas.

Deux corrections, et elles ne sont pas de la même nature :

- **Les builds n'avaient jamais eu besoin d'un appareil.** `generic/platform=iOS Simulator`
  est le spécificateur correct pour compiler — un SDK suffit. Ce n'est pas un contournement,
  c'est la suppression d'une dépendance qui n'aurait pas dû exister.
- **Les tests en ont besoin.** `scripts/ci-destination.sh` résout la destination par
  **identifiant** au lieu de nom + version, et crée l'appareil s'il manque. Il ne masque
  rien : un runtime iOS réellement absent le fait sortir en erreur avec la liste de ce qui
  existe.

Et une correction de ma propre journée : la commande locale que j'avais inscrite dans
`CLAUDE.md` omettait `OS=latest`, donc elle n'exerçait pas le chemin de résolution de la CI.
C'est textuellement la règle « une preuve doit exercer le geste, pas seulement la valeur »,
et je l'ai enfreinte le matin même où je citais son corollaire.

| Commande | Résultat |
|---|---|
| `./scripts/ci-destination.sh 'platform=macOS'` | ✅ rendue inchangée |
| `./scripts/ci-destination.sh 'generic/platform=iOS Simulator'` | ✅ rendue inchangée |
| `./scripts/ci-destination.sh 'platform=iOS Simulator,name=iPhone 17,OS=latest'` | ✅ `id=812EA5E5-…` |
| `./scripts/ci-destination.sh '…name=iPhone 99…'` | ✅ repli sur un iPhone existant, pas d'échec |
| `xcodebuild build -destination 'generic/platform=iOS Simulator'` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild test -scheme DesignSystemCatalog -destination '…iPhone 17,OS=latest'` | ✅ **64 tests**, spécificateur exact de la CI |
| `shellcheck scripts/ci-destination.sh` | ❌ **non lancée** — `shellcheck` n'est pas installé sur cette machine, malgré la liste d'outils de `CLAUDE.md` |
| Validation YAML du workflow | ❌ **non lancée** — `pyyaml` absent ; la structure est relue à l'œil, la vraie preuve est le run |
| **Branche « aucun appareil » du script** | ❌ **non exercée** — elle demanderait de supprimer tous mes simulateurs. Le repli sur modèle absent, lui, est exercé |

**La seule preuve qui compte pour cette correction est le run lui-même**, puisque la panne
n'est pas reproductible localement.

---

## 2026-08-05 (3) — La relecture des écarts, shellcheck, et `L1 bis`

**`shellcheck` installé, et le seul script du dépôt est propre.** `brew install shellcheck`
puis `shellcheck scripts/ci-destination.sh` : **zéro violation**. Un script de CI jamais
linté était bien le seul endroit du dépôt sans filet ; il coûtait une commande, pas une
correction.

### La relecture des 86 écarts — neuf lignes ne disaient plus la vérité

| Verdict | Compte |
|---|---:|
| Lignes relues | **86** |
| **Résolues**, trouvées par cette relecture | **2** |
| Résolues aux sessions précédentes, déjà rayées | 6 |
| **Devenues sans objet**, retirées | **3** |
| **Toujours valables** | **75** |
| dont **destination périmée**, corrigée | **4** |

**Les deux résolues qui traînaient.** « Grille non navigable au clavier sur Mac » nommait
`PosterCard` et son `onTapGesture` — mais `TitlesGrid` pose des `PosterTile` depuis `V0 bis`,
et `PosterTile` est un `Button` avec `.focusable(action != nil)`. Et « Réalisation,
Distribution et Ajouté le ne s'importent pas encore » : `L11b` a livré `attachCredits` pour
les deux rôles, `added_at` restant ignoré volontairement.

**Les trois sans objet nommaient des symboles disparus** : `Typo.sectionTitle`, passé dans
`Legacy/`, et deux lignes qui décrivaient `Sidebar.swift`, supprimée par `V0`. Leur motif est
conservé sous le tableau — un retrait sans trace se relit comme un oubli.

**Les quatre destinations périmées sont l'angle mort que je n'avais pas vu.** La ligne est
vraie, mais sa colonne « Où ça se règle » pointe vers rien : deux vers « 11 bis », un
découpage par numéro de prompt remplacé par les tâches `V` ; une vers `L11b`, close — elle a
bien livré une clé de doublon, **mais à l'écriture seulement**, l'aperçu ne compte toujours
rien ; une vers `L5`, close aussi, donc les vignettes Spotlight ne sont plus bloquées, juste
pas faites. **Un écart valable dont le pointeur est mort est aussi trompeur qu'un écart
périmé**, et c'est plus fréquent.

Le motif utile pour la prochaine fois : **les lignes qui rouillent sont celles qui nomment un
symbole**. Une ligne de doctrine ne rouille pas. Commencer par un `grep` de chaque symbole
cité, plutôt que relire dans l'ordre. Inscrit dans `CLAUDE.md`, à faire à chaque fin de
palier.

### `L1 bis` — les deux moitiés

**Le magasin de préférences.** `DisplayPreferenceStore` vit dans `CineShelfCore`, avec les
huit contextes **de la v1** — `movies`, `actors`, `collections`, `social`, `home_movies`,
`home_actors`, `home_collections`, `home_social`. Le jeu que portait l'intégration comptait
bien huit entrées mais inventait `gallery`, `bookmarks`, `genre`, `filmography` et perdait
les quatre rails d'accueil : ce n'était pas une reprise. Charge utile `layout` + `size`
seulement.

*Une collision de clés trouvée avant de livrer.* Trois jeux de clés ont existé pour la même
préférence : `display.` au prompt 11, `poster.` à `I1`, et celui-ci. **Deux se recouvrent** —
`CardDisplaySetting` et `DisplayPreference` ont les mêmes noms de champs *et* les mêmes
`rawValue`, et `collections` appartient aux trois jeux de contextes. Un
`display.<profil>.collections` laissé par un ancien build se serait décodé **sans erreur**.
Les valeurs auraient été équivalentes par chance ; le préfixe est donc versionné en
`display.v1.`, qui dit quel vocabulaire la valeur parle.

*Le test d'accord des vocabulaires* vit dans la cible de test de l'app, le seul endroit qui
voit les deux paquets. Il assène quatre choses qu'aucun `switch` ne peut porter : les huit
`rawValue` persistés, la bijection dans les **deux** sens (deux tables exhaustives peuvent se
contredire), l'égalité des `rawValue` de disposition et de taille — ce qui rend le repli
`?? .portrait` du pont inatteignable —, et l'égalité des **défauts** des deux côtés.

**Le filtre de galerie, et une mesure qui contredit la fiche.** La fiche annonçait que
« orphelin » écrit `asset.attachments?.isEmpty ?? true` ferait sauter le budget de
vérification de types, et demandait de trancher par la mesure. La sonde a trouvé autre chose,
et de pire :

| Route | Compile ? | Type-check | Au `fetch` |
|---|---|---|---|
| `#Predicate<MediaAsset>` sur `attachments` | **oui** | **sous 200 ms** | **tue le processus** |
| `MediaAttachment` puis différence d'ensembles | oui | négligeable | 50 orphelins sur 50 attendus |

`Keypath containing KVC aggregate where there shouldn't be one; failed to handle
attachments.@count`, puis **signal 6**. Le `do/catch` de la sonde n'a jamais été atteint. Le
piège annoncé ne se reproduit pas ; celui qui existe est invisible à la compilation, au lint
et au type-check. **C'est le cas le plus dur de la règle « tout `#Predicate` passe par le
magasin »** — et le seul de ce dépôt où la preuve d'un défaut ne peut pas devenir un test,
puisque le test tuerait la suite au lieu d'échouer.

*Le mélange à graine stable* utilise un SplitMix64 écrit à la main : la bibliothèque standard
n'a pas de générateur reproductible, et c'est la graine qui est la fonctionnalité.

**Une affirmation de ma part corrigée par ma propre sonde.** J'avais écrit « ne compile pas »
dans un commentaire avant de vérifier. C'est exactement l'affirmation déguisée en constat que
`CLAUDE.md` interdit, et la sonde l'a démentie en trois minutes.

| Commande | Résultat |
|---|---|
| `brew install shellcheck` puis `shellcheck scripts/ci-destination.sh` | ✅ **0 violation** |
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **461 · 64 · 54** (+11 sur Core) |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **75 tests** (+8) |
| `xcodebuild test -scheme CineShelfUITests -destination iOS Simulator` | ✅ **1 test** |
| `xcodebuild test -scheme DesignSystemCatalog` · macOS et iOS | ✅ **65** et **64** |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 254 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| Sonde des deux routes d'orphelin, via le magasin | ✅ mesurée, puis retirée |
| **Budget de requête sur une galerie de 10 000 médias** | ❌ **non mesuré** — les tests portent sur des centaines de lignes, pas des milliers. La route retenue fait deux `fetch` complets pour les orphelins, ce qui est linéaire et non indexé |
| **Le filtre et le magasin en situation** | ❌ **non vérifié** — aucune vue ne les appelle : la galerie est `V3`, et le magasin n'est branché que sur la grille des titres |

**Ce que `L1 bis` ne prouve pas.** La galerie n'existe pas encore comme écran, donc le filtre
est exercé par ses tests et par rien d'autre. Et la différence d'ensembles des orphelins
charge **tous** les identifiants de médias : correct, mesuré juste sur des centaines, non
mesuré sur des dizaines de milliers. Inscrit aux écarts.

**Suite : `I10`**, la dernière du palier 2 à ne dépendre de rien.

---

## 2026-08-05 (4) — `I10` et `V1`, groupées : les états vides et la recherche

Groupées parce que la recherche a besoin de l'état vide, et que les deux composants de `I10`
se valident au catalogue d'un coup d'œil. `V2` et `V3` restent séparées, et pas pour une
question de rigueur : ce sont les deux endroits du parcours restant où on ne sait pas ce
qu'on va trouver.

### `I10` — deux composants, deux écarts de jeton

**`EmptyState`, bloc `9a`.** Cinq emplacements — titre, corps, action principale, action
secondaire, indice — et **un seul obligatoire**, le titre. Les six écrans du bloc les
remplissent tous, mais un écran qui n'a rien à proposer ne doit pas inventer une action : le
cas nu est celui qu'on oublie de dessiner, et il est sur la planche du catalogue.

*Ce qu'il remplace, et pourquoi ce n'était pas un renommage.* `StateView` prenait un `case`
par situation — `noTitles`, `noResults`, `syncFailed` — donc son texte vivait dans
`DesignSystem`. Un état vide sur six écrans avec six messages différents ne peut pas être une
énumération fermée : seul l'écran sait qu'il y a « deux filtres actifs » ou « 1 284 titres au
total ». `TitlesGrid` pose maintenant **deux** `EmptyState` distincts, ce que l'`enum` ne
savait pas exprimer — « Importe un CSV » n'a aucun sens quand la collection est pleine mais
que le filtre ne laisse rien passer.

*La carte fantôme reste un aplat.* Le bloc rend un 2:3 en trame rayée à 45°, `oklch(0.185)`
et `oklch(0.15)`. La bande claire tombe **exactement** sur `bg/surface` (mesuré `#131313`,
soit 0,187) ; la sombre n'est aucun jeton. La trame demanderait d'en inventer un, et le
§écart de la planche 7 dit lui-même de ses rayures qu'elles remplacent ce que l'app fera
autrement. Ce qui compte est conservé : la forme est un **2:3**, l'affiche absente, et non un
SF Symbol — un pictogramme dirait « voici une catégorie », le pavé dit « il devrait y avoir
une affiche ici ».

**`Banner`, bloc `9c`.** Sa légende porte la règle : « posés **sous la barre**, le contenu
reste utilisable ». Ni modal, ni alerte, ni toast qui recouvre — il pousse le contenu, et la
planche du catalogue le montre au-dessus d'une vraie grille pour que ça se voie. Le seul
écran plein que la direction autorise est le verrouillage biométrique, et il appartient à
`V7`.

*Les quatre tons tombent sur les jetons existants*, ce qui n'était pas garanti : hors ligne =
`bg/fill`, synchronisation = accent, quota = danger, import = success. Aucun jeton neuf, et
la même palette que `StateBadge` — un badge « 417 en erreur » et un bandeau de quota parlent
de la même chose. Les opacités du bloc divergent (12, 13, 11 %) sans règle qui les sépare :
jamais contrôlées, donc **12 % pour les trois**, et l'écart s'inscrit.

*La pastille est ronde, et ce n'est pas une entorse.* Le motif est « rien de photographique
et rectangulaire n'a de coin arrondi » : un point de 8 pt n'est ni l'un ni l'autre — la même
raison qui rend les personnes circulaires.

### `V1` — la recherche, et une portée que le modèle ne peut pas servir

**Les deux branches sont écrites, et le compilateur les a imposées.** `.idle` rend les
recherches récentes — effaçables une à une, via le `RecentSearchStore` de `L2` — et `.results`
vide rend l'`EmptyState` avec le terme dans le titre. Le premier lancement a son propre état
vide, **sans action** : la seule issue est de taper, et le champ a déjà le focus.

**L'anti-rebond est dans la vue, et il ne coûte aucun objet.** `.task(id:)` annule et relance
à chaque frappe, donc le `sleep` de 250 ms n'aboutit qu'à la pause : pas de `Timer`, pas de
`DispatchWorkItem` à invalider, rien à nettoyer. La clé combine le terme **et** la portée —
changer d'onglet sans retaper doit relancer, et son séparateur est un caractère de contrôle
pour que « portée `titles` + terme vide » et « portée vide + terme `titles` » ne collisionnent
pas. C'est testé.

**L'écart de couverture, et c'est la vraie trouvaille de la tâche.** Le bloc `5b` montre
**six** portées, dont « Images · 21 ». `SearchScope` en a cinq, et ce n'est pas un oubli de
`L2` : **`MediaAsset` n'a ni nom ni `searchText`**. Un checksum, un blurhash, des dimensions
— rien qu'un terme puisse matcher. Les deux issues sont hors de `V1` : une légende sur
`MediaAsset` touche le **schéma fermé** et exige une migration ; chercher dans le nom du
propriétaire rendrait les images d'un titre que le terme trouve déjà. Cinq portées livrées, et
la consigne inscrite : ne pas ajouter une portée qui rendrait toujours zéro.

**Deux modèles de présentation créés au passage.** Ni `Person` ni `TitleCollection` n'en
avaient — l'accueil et la grille ne rendent que des titres, et `V1` est le premier écran qui
montre les quatre types côte à côte. Ils ne portent aucune trace de la recherche, donc `V4` et
`V5b` les reprendront par un déplacement de fichier, pas une réécriture.

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **461 · 64 · 54** |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **82 tests** (+7) |
| `xcodebuild test -scheme CineShelfUITests -destination iOS Simulator` | ✅ **1 test** |
| `xcodebuild test -scheme DesignSystemCatalog` · macOS et iOS | ✅ **65** et **64** |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 258 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **Le rendu des deux composants à l'œil** | ❌ **non vérifié** — `screencapture` reste refusé sur cette machine (autorisation d'enregistrement d'écran). La planche « Vide · Bandeau · I10 » existe et compile ; je ne l'ai pas *regardée* |
| **L'écran de recherche en usage** | ❌ **non essayé** — le build passe et la logique est testée, mais je n'ai pas tapé dans le champ. L'anti-rebond, le focus au premier affichage et le défilement des rangées ne sont pas constatés |
| **Le seuil de 250 ms** | ❌ **non mesuré** — choisi par raisonnement. À confirmer sur appareil, où le coût des huit requêtes de la portée `.all` est réel |

**Ce que ces deux tâches ne prouvent pas.** Le bandeau n'est posé sur **aucun** écran : ses
quatre cas appartiennent à `V10` et `V8`. Et la porte de bloc, qui rend les écarts
constatables, ne mord que si on ouvre le catalogue — ce que je n'ai pas pu faire.

**Suite : `V2`**, seule — la première rencontre du pipeline d'images avec l'interface.

---

## 2026-08-05 (5) — `V2` : quatre sessions sans qu'une seule affiche s'affiche

**Une règle d'abord.** « Le composant possède la forme, l'écran possède le texte » entre dans
`CLAUDE.md`, juste après « les documents de design contraignent le rendu, jamais le modèle » :
même famille, même symptôme — ça compile, ça s'affiche, et c'est faux là où on ne regarde pas.

### Le défaut, et pourquoi rien ne pouvait le montrer

**`MediaFill` chargeait ses images avec `AsyncImage(url:)`.** C'est le point de passage des
sept composants d'image de la nouvelle direction — tuile d'affiche, personne, collection,
galerie, accueil, fiche, recherche. Or `AssetURL` fabrique des URL au schéma interne
`cineshelf-asset://`, une convention qui porte un `UUID` du modèle jusqu'au `ThumbnailCache`.

Sonde, hors dépôt, trois minutes :

```
URLSession.shared.dataTask(with: "cineshelf-asset://<uuid>?preset=card")
-> ERREUR : unsupported URL
```

`phase.image` était donc **toujours `nil`**. Depuis `I2`, c'est-à-dire depuis quatre sessions,
**aucune affiche ne s'est jamais affichée** : tout rendait l'aplat de fond.

**Ce qui a permis à ça de durer est plus intéressant que le défaut.** Les échantillons du
catalogue ont `imageURL: nil` — une tuile **sans** image y rend exactement le même aplat
qu'une tuile dont le chargement **échoue**. Deux causes, une apparence. La porte de bloc
validait la forme d'une tuile vide et ne pouvait rien dire du chargement ; le journal notait
« lancement réel sur Mac, processus vivant », ce qui était vrai et ne prouvait rien.
`MediaThumbnail`, lui, lisait bien `\.imageLoader` depuis le prompt 11 — c'est en réécrivant
la direction que le chemin s'est perdu, et le composant correct est resté là, sans appelant.

**Le test verrouille la propriété, pas le composant** : une URL d'asset n'est pas chargeable
par le réseau. Un test de rendu n'aurait rien attrapé, puisque le rendu était « correct » : un
aplat.

### Le reste de `V2`

**`MediaRepository` gagne le rattachement et le recadrage.** `attach` en **trois surcharges**
— titre, personne, collection — plutôt qu'une méthode à trois optionnels : l'invariante
`hasExactlyOneOwner` devient impossible à violer depuis l'appelant. `setSingle` remplace au
lieu d'ajouter sur `.primary`, `.portrait` et `.backdrop`, sans quoi deux pièces jointes
rendraient `TitleFormat.primaryAsset` indéterminé — une jaquette qui change d'un lancement à
l'autre. `setCrop` cherche avant d'insérer : une ligne par couple (média, contexte).

**Les quatre gestes d'import convergent sur un seul chemin.** PhotosPicker, `.fileImporter`,
dépôt et collage rendent tous des octets, et `MediaImportService` fait le reste une fois pour
les quatre. Le dédoublonnage est gratuit et global — même image depuis Photos puis depuis le
Finder, un seul asset — et le rapport **distingue** l'ajout du doublon retrouvé, sans quoi
l'écran annoncerait des images que l'utilisateur n'a pas ajoutées.

**Le bandeau de `I10` a trouvé son premier appelant réel** : un import est bien une
interruption qui laisse le contenu utilisable. Il nomme les fichiers refusés un par un — « 2
refusées » ne dit pas quoi refaire.

### Les deux questions posées, répondues

**1. `CropContext.hero` est-il enfin emprunté ? Oui.** `DemoCatalog` crée un `backdrop` sur un
titre sur quatre et des `MediaCrop` réels pour `card` et `hero`. Aucun n'est neutre : un
`50/50/100` serait indistinguable du repli, donc ne prouverait rien. `DemoCropCoverageTests`
refuse que l'un des chemins redevienne mort, **et** que le repli cesse d'être majoritaire —
`V0 bis` l'a tranché, il doit rester visible.

**2. Le préchargement trouve-t-il son foyer ici ? Non, et j'ai trouvé pourquoi c'est plus
gênant que prévu.** Un import est une image immédiate, et la galerie d'un titre compte une
poignée d'entrées : rien à précharger. Mais en cherchant le foyer, un défaut d'API est
apparu — `PrefetchWindow.indices(visible:count:)` demande une `Range<Int>`, et **aucun
conteneur paresseux de SwiftUI ne rapporte cette tranche**. `LazyVGrid` ne notifie qu'élément
par élément, par `onAppear`. `V3` devra soit ajouter une variante pilotée par `onAppear`, soit
dériver la tranche d'un `ScrollPosition`. Inscrit.

| Commande | Résultat |
|---|---|
| Sonde `URLSession` sur le schéma d'asset | ✅ « unsupported URL » — le défaut prouvé, puis retirée |
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **461 · 64 · 54** |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **96 tests** (+14) |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 265 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **`CropEditor`** | ❌ **non livré** — voir plus bas |
| **Les quatre gestes essayés à la main** | ❌ **non essayés** — le code compile et le service est testé de bout en bout, mais je n'ai déposé aucun fichier, collé aucune image, ouvert aucun sélecteur. `PhotosPicker` en particulier n'a jamais été présenté |
| **L'affiche vue à l'écran** | ❌ **non vérifié** — c'est la correction la plus importante de la session et je ne peux pas la constater : `screencapture` reste refusé sur cette machine. Le chemin est prouvé par la sonde et par le test, pas par l'œil |
| **Le préchargement en situation** | ❌ toujours aucun appelant de vue |

**Un troisième défaut, trouvé par le build iOS.** `onPasteCommand` est **indisponible sur
iOS** : le build macOS passait, le build iOS non. C'est bien ainsi — sur iOS le collage passe
par le menu d'édition du système, pas par un raccourci capté par une vue. Le geste reste offert
sur les deux plateformes, par deux chemins : `⌘V` capté sur Mac, et une action explicite du
déclencheur sur iOS, qui lit `UIPasteboard`. Un `PasteButton` aurait uniformisé au prix d'un
bouton visible que la direction ne dessine nulle part. **La routine des deux builds a servi** —
c'est la troisième fois cette journée qu'un build de plateforme attrape ce qu'un seul aurait
laissé passer.

**`CropEditor` n'est pas livré, et `V2` est donc partielle.** L'écriture des `MediaCrop`
existe, est testée, et la fiche les applique — ce qui manque est le **geste** : l'écran qui
laisse déplacer et agrandir une image dans son cadre, avec ses deux ratios. C'est un écran à
lui seul, et je préfère le dire que le bâcler à la fin d'une tâche déjà large. Inscrit en
`V2 bis`.

**Ce que `V2` ne prouve pas.** Que les images s'affichent. Le chemin est correct — sonde,
test, build — mais la seule vérification qui compte pour une image est de la voir, et elle
reste à faire en ouvrant l'app.

**Suite : `V2 bis`** (`CropEditor`), ou `V3`.

---

## 2026-08-05 (6) — `catalogue-images` et `V2 bis` : rendre la porte voyante

### La leçon d'abord, parce qu'elle dépasse le cas

**Deux états qui rendent la même chose rendent toute porte aveugle.** C'est dans `CLAUDE.md`.
Les échantillons du catalogue avaient `imageURL: nil` : une tuile **sans** image et une tuile
dont le chargement **échoue** rendaient le même aplat, donc la porte de bloc était aveugle sur
les deux — et elle passait au vert, ce qui est pire que de ne pas exister.

La règle : **tout échantillon exerce le chemin réel, jamais le cas nul.** Et son corollaire,
qui a coûté une correction de plus : **compter les apparences, pas les états.** Trois états qui
donnent deux apparences valent deux états pour une porte visuelle.

### `catalogue-images`

**Un seul générateur, pas deux.** `PosterArtwork` vivait dans `App/DemoData`, invisible depuis
le catalogue. Il devient `SampleArtwork` dans `DesignSystem`, aux côtés de
`PosterCardModel.samples` et `ImageLoader.stubbed` — le package portait déjà tout le matériel
d'échantillon, il lui manquait la seule chose qui compte dans un catalogue de films. `DemoCatalog`
l'utilise désormais, et l'ancien fichier est supprimé : deux générateurs auraient divergé, et le
catalogue aurait fini par valider des images que l'app ne produit pas.

**Dessinées, jamais embarquées.** Aucun binaire au dépôt, et une image déterministe — la même
graine donne le même pixel, donc deux captures se comparent.

**Les quatre cas, côte à côte sur la planche `I2`** : chargée, en cours, en échec, sans image.
Le chargeur du catalogue les sert avec 400 ms de délai, sans lequel on ne verrait jamais le
blurhash ni la transition.

**Il a fallu ajouter un rendu d'échec à `MediaFill`**, et c'est le corollaire en action : sans
lui, « en cours » et « en échec » restaient indistinguables, et la porte serait restée à moitié
aveugle après correction. Un symbole discret en `text.tertiary` — **aucun bloc ne le dessine**,
la planche 7 traitant l'erreur par rangée et jamais par tuile. Le précédent repris est
`MediaThumbnail`, de l'ancienne direction. Inscrit comme question ouverte au design.

**Les personnes n'ont pas d'image, et c'est délibéré.** Le §11 du handoff : « Portraits de
personnes : aucun. » Les habiller ici ferait valider un rendu que l'app ne produira jamais.

### `V2 bis` — `CropEditor`

**Il ne calcule rien.** Toute la géométrie est `CropGeometry`, écrite et testée par `L4` six
tâches plus tôt, sans rendu. L'écran montre, transmet le geste, enregistre.

**Deux cadres côte à côte**, 16:9 et 2:3. La même image sert aux deux, et un réglage qui va bien
dans l'un coupe souvent mal dans l'autre : les voir ensemble est la seule façon de s'en
apercevoir. C'est aussi pourquoi `MediaCrop` est stocké par contexte.

**Les neuf cas de `CropContext` sont couverts sans `default`, et le compilateur l'a exigé.**
J'en avais écrit quatre. La garde a mordu : un contexte oublié aurait pris le ratio du
`default` et produit un recadrage qu'aucun écran ne sait afficher.

**Un défaut de ma première version, trouvé en relisant pour l'inscrire.** `DragGesture` et
`MagnifyGesture` rendent des valeurs **cumulées** depuis le début du geste ; je repartais du
recadrage courant, donc le mouvement se composait — le doigt avance de 10 pt et l'image de 10,
puis 30, puis 60. Le champ `gestureStart` existait et n'était pas lu. J'allais l'inscrire comme
écart ; il était corrigible en dix lignes, donc il est corrigé, et `CropGestureTests` le
verrouille — y compris un test qui **démontre le défaut inverse**, sans quoi le premier ne
prouverait rien.

**`ActionButtonStyle` devient public.** Il s'appelait `EmptyStateButtonStyle` et était interne :
`CropEditor` a besoin des mêmes boutons, et un second style aurait donné deux boutons primaires
qui ne se ressemblent pas. C'est le corollaire de la règle du jour — l'écran ne possède pas la
forme.

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **461 · 64 · 54** |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **99 tests** (+3) |
| `xcodebuild test -scheme CineShelfUITests -destination iOS Simulator` | ✅ **1 test** |
| `xcodebuild test -scheme DesignSystemCatalog` · macOS et iOS | ✅ **65** et **64** |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 267 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **Les quatre cas de chargement vus à l'œil** | ❌ **non vérifié** — c'est le cœur de `catalogue-images` et je ne peux pas le constater : `screencapture` reste refusé. La planche existe, compile et les quatre cas y sont posés côte à côte ; qu'ils se **distinguent** reste à confirmer en ouvrant le catalogue |
| **`CropEditor` essayé au doigt ou à la souris** | ❌ **non essayé** — le calcul est testé, la sensation ne l'est pas : latence, vitesse, pincement au trackpad |
| **Le préchargement** | ❌ toujours aucun appelant de vue |

**Ce que ces deux tâches ne prouvent pas.** Que les quatre cas se distinguent. C'est
précisément ce que la tâche existe pour rendre vérifiable, et la vérification est à toi — ce
qui est déjà mieux qu'avant, où il n'y avait rien à regarder.

**Suite : `V3`**, la galerie — où le préchargement devra trouver son foyer, et où
`PrefetchWindow` devra apprendre à connaître sa tranche visible.

## 2026-08-05 (7) — `V3` : la galerie, et une signature qu'aucun appelant ne pouvait remplir

### La leçon d'abord, parce qu'elle ne parle pas de galerie

**« Aucun appelant » peut vouloir dire « aucun appelant *possible* », et alors ce n'est pas la
liste des appelants qu'il faut regarder mais l'API.**

`PrefetchWindow` a été livrée par `L5` le 2026-08-05 (2). Son écart a ensuite été réinscrit
trois fois de suite, toujours dans les mêmes termes : « `prefetch` n'a toujours aucun appelant
de vue ». La formulation portait une cause implicite — *il manque un écran* — et elle était
fausse. L'API prenait `visible: Range<Int>`, et **aucun conteneur paresseux de SwiftUI ne
rapporte cette tranche** : un `LazyVStack` notifie élément par élément, par `onAppear`, et il
notifie **un** index. Trois écrans se sont succédé sans que le défaut se voie, parce qu'aucun
n'était censé s'en servir.

Ce qui l'a fait apparaître : l'écran qui *devait* s'en servir. Et à ce moment-là, la question
« quel écran manque ? » s'est transformée en « pourquoi aucun écran ne peut ? ».

**Le réflexe à garder** : quand un écart se réinscrit à l'identique d'une session sur l'autre,
relire sa **cause** avant sa conséquence. Une conséquence stable est normale ; une cause qu'on
recopie sans la revérifier finit par être fausse sans qu'il n'y paraisse rien.

### `PrefetchWindow`, corrigée et non contournée

L'ancienne signature est **supprimée**, pas doublée. La garder aurait laissé au prochain
lecteur le choix entre une API utilisable et une API qui ne l'est pas, et rien n'aurait dit
laquelle.

**La route `ScrollPosition` est écartée, et le motif est écrit** : elle ne rend qu'un
identifiant d'ancrage pour toute la vue de défilement — donc rien des trois autres colonnes
d'une maçonnerie à quatre — et rien du tout **au repos**, c'est-à-dire au premier affichage,
qui est précisément le moment où précharger l'écran suivant sert le plus.

**`PrefetchScheduler` porte les deux décisions qui restaient dans la vue** : comment une
frontière se déduit d'apparitions individuelles, et quand une nouvelle commande vaut la peine
d'être passée. Les deux sont de l'arithmétique, donc les deux sortent de la vue.

**L'agrégation entre colonnes est le maximum, et le motif est écrit** — c'était la première des
trois précisions demandées. Un index qui a **apparu** a déjà été réclamé par le chemin
d'affichage : sa vignette est en cours ou en cache. Donc tout ce qui est sous le maximum est
déjà demandé, et **seul l'au-delà du maximum n'est réclamé par personne**. Le minimum ferait
précharger du travail déjà fait ; la moyenne n'a de sens géométrique nulle part.

**Et c'est pour ça qu'il n'y a pas d'heuristique de demi-tour.** « Un index nettement sous la
frontière signale une remontée, donc on se réancre » paraît meilleur et se casse sur le cas
même qui motive la règle : avec 40 et 25 sur deux colonnes, l'écart **entre colonnes** dépasse
déjà le seuil qu'un tel test devrait employer, et la colonne en retard serait lue comme un
demi-tour à chaque passe de rendu. Les deux sont indiscernables depuis ce type, donc il ne
tranche pas. `PrefetchSchedulerTests` porte les deux cas, dont celui-là nommément.

### Le préchargement fait-il quelque chose ? Oui, et voici les chiffres

Quatre sessions durant, il n'était qu'une intention. Premier endroit où la question se pose
pour de vrai, donc première mesure :

| Régime | Affichages trouvant leur image déjà en mémoire |
|---|---|
| sans préchargement | **0 sur 24** |
| avec, défilement plus lent que le décodage | **23 sur 24** |
| avec, défilement à 5 ms par élément | **12 sur 24** |

**Les deux premiers sont assénés, le troisième seulement imprimé**, et la coupure suit la
doctrine des seuils de performance : le mécanisme (« un affichage qui suit un préchargement
terminé trouve son image ») est un **rapport**, indépendant de la machine ; le recouvrement
dépend d'une horloge, et sur un runner GitHub le décodage peut être vingt fois plus lent.

La ligne de base compte autant que le reste : sans le « 0 sur 24 », le « 23 sur 24 » ne dirait
pas si le préchargement y est pour quelque chose.

### Les rendus divergent — et j'avais raison par accident

C'était la troisième précision demandée, et elle a mordu. J'avais écrit que la planche 4 bloc
`6b` « diverge » de l'addendum 2 bloc `13c` en comparant 3/5/8 colonnes à 2/4 — sans vérifier
que les largeurs étaient comparables. Vérification faite :

| Bloc | Largeurs rendues | Colonnes | Largeur de carte implicite |
|---|---|---|---|
| `6b` | 393 · 1194 · 1920 | 3 · 5 · 8 | 116 · 222 · 223 |
| `13c` | 393 · 834 | 2 · 4 | `poster.l` (140), **nommé** aux deux formats |

Les deux blocs rendent **393 px**, et ils s'y contredisent : 3 colonnes contre 2, soit 116 pt de
carte contre 140. Ce sont donc bien des valeurs comparables, et la contradiction est réelle. Et
`6b` se contredit lui-même — 116 puis 222 — donc il encode un **compte de colonnes par format**
et non une carte constante, ce qui est exactement la règle que `I4` avait déjà arbitrée à
l'envers.

Verdict inchangé, mais pour la bonne raison cette fois : les rendus divergent → le jeton fait
foi, et `13c` est le seul bloc qui nomme un cran. `PosterScale.l` avec les jetons de marge et de
gouttière redonne **exactement** 2 colonnes à 393 pt et 4 à 834.

**La leçon de méthode** : « compter les blocs » ne suffit pas, il faut d'abord vérifier que les
blocs parlent de la même chose. Une conclusion juste par accident est une conclusion qu'on
reproduira mal ailleurs.

### `DemoCatalog` était le cas nul, et c'est la troisième fois

Avant cette tâche : **aucune** pièce jointe `.gallery`, aucune image sur une personne ou une
collection, **aucun orphelin**, et une seule proportion — 2:3, la même pour toutes. Donc l'écran
de galerie aurait été **vide**, la maçonnerie n'aurait rien eu à répartir, et trois des quatre
branches du filtre par source n'auraient jamais été empruntées.

Les proportions sont choisies pour **casser l'algorithme**, pas pour être variées : la maçonnerie
additionne des hauteurs de colonne, donc un jeu « franchement varié » entre 2:3 et 16:9 ne
prouve rien. 21:9, 9:21 (5,4 fois plus haut à largeur égale), le carré — et un média **sans
dimensions lues**, qui emprunte le repli de `MasonryColumns`. Sans lui, ce repli serait du code
que rien n'exerce, et il existe pour un cas que le schéma rend inévitable : `pixelWidth` vaut 0
par défaut, donc une division 0/0.

Ces images passent par `MediaIngestor`, donc par le chemin réel de l'import : c'est la première
fois que les données de démonstration portent un `blurHash`. Les jaquettes n'en ont toujours pas
— écart inscrit.

### Deux gardes existantes ont mordu, et un test que j'avais écrit faux

- **`Icon.all` a refusé deux constantes de même glyphe.** `nextImage` et `selectionMark`
  deviennent des **alias** de symboles déjà listés : la liste sert à vérifier qu'un symbole
  existe dans SF Symbols, et le vérifier deux fois ne prouve rien de plus.
- **`file_length` a refusé `BlockReference.swift` à 513 lignes**, et la coupure qu'il a imposée
  est meilleure que le fichier : le type et son rendu d'un côté, les valeurs attendues de
  l'autre — elles n'ont pas la même durée de vie.
- **`MasonryColumnsTests` a échoué sur une assertion fausse de ma main** : j'attendais
  `clamped(aspect: .infinity)` à la borne haute. L'infini n'est pas une image très large, c'est
  une division par zéro — donc une dimension inconnue, donc le repli. **Le code avait raison, le
  test avait tort**, et c'est le bon sens de l'erreur.

### Le reste de `V3`

- **`MediaFit`** : l'image en `contain`, seul endroit du système où « remplit et recadre »
  s'inverse — parce que c'est le seul où l'on regarde l'image *pour elle-même*. Elle charge par
  `\.imageLoader` et jamais par `AsyncImage`, qui ne sait pas résoudre `cineshelf-asset://`.
- **`GalleryThumb`** passe du voile d'accent au liseré du bloc `6f`, posé vers l'intérieur, avec
  sa pastille cochée. Le voile teintait l'image qu'on est en train de choisir, et aucun bloc ne
  le dessine.
- **La galerie de la fiche titre est complétée** : elle rendait cinq images au plus, dans un
  cadre 16:9 imposé, et aucune n'était cliquable. Le recadrage d'une image de galerie devient
  donc atteignable — écart ouvert depuis `V2 bis`.
- **`MediaFlag` a son premier écrivain.** Il existait depuis le premier jour et personne ne
  l'écrivait.
- **Le forçage sombre est posé**, sur la galerie et la visionneuse. Les quatre apparences
  existaient depuis `I1` ; aucun écran ne posait celle-ci.
- **La branche « orphelin » n'est plus payée par l'écran par défaut** : un filtre inactif ne
  déclenche aucun `fetch`. Mesurée quand elle est demandée — 12 orphelins en 39 ms sur 205
  médias, contre 25 ms pour la branche « titre ».

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **461 · 70 · 64** |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **114 tests** (99 avant) |
| `xcodebuild test -scheme CineShelfUITests -destination iOS Simulator` | ✅ **1 test** |
| `xcodebuild test -scheme DesignSystemCatalog` · macOS et iOS | ✅ **71** et **70** |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 281 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **La galerie vue à l'œil** | ❌ **non vérifiée** — ni la maçonnerie sur la planche, ni l'écran sur Mac, ni la visionneuse, ni le liseré de sélection. C'est le cœur d'une tâche `V`, et ça reste à toi |
| **Le geste de sélection sur iPhone** | ❌ **non essayé** — le bloc `6f` demande un appui long, le bouton « Sélectionner » est rendu sur les deux plateformes |

**Ce que cette tâche ne prouve pas.** Que la galerie *ressemble* à la planche 4. Elle prouve que
les colonnes se calculent comme `13c` le dit, que les proportions dégénérées ne la cassent pas,
que le préchargement remplit le cache et que les quatre sources ont de quoi filtrer. Le reste se
regarde.

**Post-scriptum du même jour — la CI rouge, et un seuil qui avait tort depuis le début.**

Le run `31021407166` a rougi sur `SearchPerformanceTests` : **80,5 ms** contre un plafond de
40 ms. Diagnostic avant correction, et il est net :

- **le même arbre `CineShelfCore` avait passé le run précédent au vert** (`31020718872`, job à
  3m20s) — donc non déterministe, donc un seuil et non une régression ;
- le rapport runner / local est de **7 à 10**, cohérent avec l'autre mesure connue du dépôt :
  décodage de vignette 15 ms en local contre 266 ms sur le runner ;
- `V3` ne touche pas le chemin de recherche. Ses deux ajouts à `CineShelfCore` sont une fabrique
  de prédicat que la recherche n'appelle pas, et le favori d'un média.

**La faute était dans la calibration, et `CLAUDE.md` la nomme depuis longtemps** : « ne jamais
assener un budget d'expérience utilisateur sur un runner partagé […] des plafonds absolus calés
sur l'environnement **le plus lent** où il tourne ». Or le commentaire du test disait lui-même
« environ quatre fois la mesure haute » — la mesure **locale**. Il documentait proprement
l'erreur qu'il commettait.

Ce n'est donc pas le cas « attendre une deuxième occurrence » : cette règle vaut pour un flake
d'infrastructure dont la cause est inconnue. Ici la cause est écrite, et la première occurrence
suffit. Plafond porté à **300 ms** — 3,7 fois la mesure du runner, 27 fois la locale : il
n'attrape plus qu'un effondrement, ce qui est tout ce qu'un seuil peut honnêtement attraper. La
mesure est désormais **imprimée**, et c'est elle qui porte le sens.

**Un frère jumeau reste en place** : `TitleFilterPerformanceTests` plafonne à 25 ms, calé
localement lui aussi. Il est passé au vert ce jour-là, ce qui est de la chance et non une
preuve. Inscrit comme écart plutôt que corrigé au passage : la tâche soldait un reste-à-faire.

## 2026-08-06 — L'audit des seuils, la règle qui ne s'était pas propagée, et `I5`

### La vraie trouvaille du jour n'est pas un seuil, c'est un motif

**Une règle écrite mais jamais propagée ne protège que le code écrit après elle.** Le
corollaire sur les seuils de performance est né le 2026-08-04 d'un test qui échouait — les
200 vignettes, 15 ms en local contre 266 ms sur le runner. Il a été écrit dans `CLAUDE.md`,
et **il n'a été appliqué qu'au test qui l'avait provoqué.** Deux seuils calés sur une mesure
locale sont restés en place, et le premier a rougi la CI dix-huit heures plus tard.

C'est la même famille que la fausse dette : le document dit vrai, le dépôt dit autre chose. La
différence est qu'ici personne ne le découvre avant que ça casse. La règle a donc gagné une
section : **quand une règle entre dans `CLAUDE.md`, chercher ce qui l'enfreint déjà** — un
`grep` sur le motif interdit, pas une relecture. Corriger sur-le-champ n'est pas obligatoire ;
ne pas regarder, si.

### L'audit — cinq fichiers mesurent, huit assertions de durée, une seule était fausse

| Assertion | Mesure locale | Plafond | Calé sur | Verdict |
|---|---|---|---|---|
| `ThumbnailCacheTests` décodage | 15,2 ms · **266,5 runner** | 800 ms | le **runner**, ×3 | conforme — c'est la référence |
| `ThumbnailCacheTests` disque | 2,5 ms · **15,8 runner** | 60 ms | le **runner**, ×4 | conforme |
| `ThumbnailCacheTests` trois rapports | — | rapport | indépendant de la machine | conforme |
| `BulkEdit` lot scalaire | 0,24 ms / titre | 20 ms | ordre de grandeur, ×83 | conforme |
| `BulkEdit` lot de relation | 0,48 ms / titre | 30 ms | ×62 | conforme |
| `BulkEdit` refus | 29 ms | 2 000 ms | ×69 | conforme |
| `TitleFilter` rapport sélectif | 6,6 contre 240 ms | rapport ×5 | indépendant | conforme |
| `SearchPerformance` | 8 à 11 ms | ~~40~~ → **300 ms** | ~~local ×4~~ → runner ×3,7 | corrigé le 2026-08-05 |
| **`TitleFilter` prédicat complet** | **5,3 à 6,6 ms** | ~~25~~ → **150 ms** | ~~local ×5~~ → runner ×3,7 | **corrigé aujourd'hui** |

**Une seule était sous-dimensionnée, et elle était verte.** C'est ce qui la rend instructive :
rien ne la signalait, et elle l'était par chance. Avec le rapport runner / local mesuré la
veille — 7 à 8 — elle devait rendre ~40 ms sur le runner, donc échouer. **Un test vert n'est
pas une preuve de conformité à une règle qu'il enfreint.**

**Et un manque commun aux deux corrigés** : ni l'un ni l'autre n'imprimait sa mesure. Un
plafond calé sur le pire environnement ne dit plus rien du confort réel — il ne reste que le
chiffre imprimé pour le dire. La règle le demande désormais explicitement.

### La capture d'écran : toujours refusée, mais la cause est identifiée

`screencapture` rend « could not create image from display », y compris hors bac à sable. La
session est bien `Aqua` et l'utilisateur graphique est le bon, donc ce n'est pas un problème de
contexte. **La chaîne de processus dit pourquoi** :

```
/bin/zsh  ←  claude  ←  /Applications/Switchboard.app
```

L'autorisation d'enregistrement d'écran est attribuée par TCC à l'**application responsable**,
et ce n'est pas le terminal : c'est `Switchboard.app`. Deux choses à faire, et la seconde est
celle qu'on oublie : l'autoriser dans Réglages → Confidentialité → Enregistrement de l'écran,
**puis la quitter et la relancer** — une autorisation accordée à une app déjà lancée ne prend
pas effet avant son redémarrage.

Les cinq vérifications visuelles restent donc à faire, et elles restent inscrites comme non
faites.

### `I5` — trois composants, et deux d'entre eux ne sont pas ce que leur nom dit

**La ligne de tableau.** 30 pt en dense (bloc `7a`), 44 en ample (addendum 2 bloc `13d`, et
44 n'est pas un hasard : c'est la cible tactile). Le relevé de la planche 5 écrit « lignes de
28 pt » — c'est faux, ou plutôt c'est la hauteur de l'**en-tête**, qui vaut bien 28 dans le
rendu. Bloc rendu contre prose de synthèse : le bloc gagne.

Le composant porte la géométrie, l'écran porte les colonnes — et c'est plus tranchant ici
qu'ailleurs, parce que les colonnes changent d'une entité à l'autre. `.tableCell(width:)` est
le modificateur qui fait tomber le corps sous l'en-tête sans que personne additionne des marges.

**Une ligne sélectionnée n'est rendue par aucun bloc**, et le fond seul ne suffisait pas : il
est déjà celui du survol, donc les deux états auraient rendu la même chose. Une barre d'accent
de 2 pt les sépare. Déduction inscrite.

**Le jeton de filtre** ferme un écart ouvert deux fois : `V0 bis` et `V3` avaient tous deux
rendu leurs filtres en `StateBadge` faute de ce composant. Un badge *dit* un état, un jeton *se
clique* — d'où la cible de 44 pt, posée **autour** d'un jeton de 25 pt plutôt qu'en le
déformant, et la croix de retrait, qui n'apparaît que là où le filtre est retirable.

**La graisse du prototype est impossible**, et c'est la seule vraie perte : actif en 600,
inactif en 400, or le système n'a pas d'Archivo Narrow 400. Les deux états restent distincts
par le fond et la couleur du texte. Inscrit.

**La « pastille de compteur » n'est pas une pastille.** Le bloc `7a` ne dessine aucun fond : un
nombre en mono, en `text.tertiary`, poussé à droite. Le nom vient de l'inventaire des
composants, écrit **avant** la direction artistique — et la direction « plein cadre » n'a ni
pilule ni badge de compte. Lui dessiner un fond aurait été rattraper un concept que la
direction a supprimé, ce que le lint interdit ailleurs.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **461 · 74 · 64** |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **114 tests** |
| `xcodebuild test -scheme CineShelfUITests -destination iOS Simulator` | ✅ **1 test** |
| `xcodebuild test -scheme DesignSystemCatalog` · macOS et iOS | ✅ **75** et **74** |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 287 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **Les cinq vérifications visuelles de `V3`** | ❌ **non faites** — `screencapture` refusé, cause identifiée ci-dessus |
| **La planche `I5` vue à l'œil** | ❌ **non vue**, pour la même raison |

## 2026-08-06 (2) — La sonde de pixels, le palier 3 compressé, et les neuf champs

### `ImageRenderer` était là depuis `I2`, et la question ne lui était pas posée

**Trois échanges perdus sur `screencapture`, et l'outil était dans le dépôt.** Les tests de
rendu comparent des pixels depuis `I2` sans aucune permission — rendre une vue dans un bitmap
ne passe par aucune API de capture d'écran. Ce qui manquait n'était pas l'accès à l'écran,
c'était **la bonne question** : les empreintes FNV distinguaient deux rendus sans jamais
demander s'il y avait quelque chose dedans.

**Deux aplats de couleurs différentes ont deux empreintes différentes.** C'est tout le défaut,
en une phrase : la porte passait au vert sur une tuile vide.

### La sonde, et ce qu'elle a fallu comprendre

`PixelStats` compte les **couleurs distinctes** sur une grille de 32 × 32 et mesure l'écart de
luminance. Une image en rend des dizaines, un aplat une seule.

**Le piège, et il aurait rendu la sonde inutile** : `ImageRenderer` rend de façon
**synchrone**, donc un `.task` n'a pas tourné au moment du bitmap. Sans attente, « chargée »,
« en cours » et « en échec » rendent tous le même placeholder — exactement l'aveuglement qu'on
venait corriger. La parade tient en trois lignes : lire `cgImage` une première fois pour que la
vue existe et que ses tâches démarrent, laisser tourner la boucle, relire.

**Preuve d'échec, avec injection vérifiée.** J'ai remis la faute historique dans `MediaFill` —
le chargeur remplacé par le stub qui n'aboutit jamais — après avoir vérifié que la substitution
avait bien eu lieu (une ligne, un `grep`). Deux tests rouges, dont le principal.

**Et la mesure a corrigé mon assertion.** J'attendais `isUniform` ; la tuile fautive rend
**deux** couleurs et non une, parce que le symbole d'échec en dessine une seconde. C'est le
seuil `distinctColours > 8` qui mord, pas le booléen. Écrit dans le test, parce que quelqu'un
essaiera de le « simplifier ».

Cinq assertions neuves : la sonde contre son contrôle négatif, la tuile chargée contre l'aplat,
les quatre états **deux à deux**, le liseré de sélection, et les colonnes de la maçonnerie qui
ne finissent pas à la même hauteur — la seule chose qui distingue une maçonnerie d'une grille.

**La règle est dans `CLAUDE.md`** : une tâche `V` se termine par un rendu assené, jamais par
« non vu ». Je ne peux pas juger si c'est beau ; je peux prouver que ce n'est pas vide.

### Le palier 3 — quatorze lignes en douze, et trois prémisses corrigées

**`V8` n'est pas un doublon de `V3`.** `V3` est la galerie ; `V8` est **l'import et
l'export**. La retirer aurait laissé `L11a`, `L11b` et `L12` — trois tâches faites, deux à
rigueur maximale — sans aucun écran, et sept écarts inscrits sans destination. Elle reste.

**`L15` n'est pas dans le palier 3**, elle est reportée en v1.1 : il n'y a que **trois** tâches
à rigueur maximale, pas quatre. Et **`L14` n'est pas maximale** — le classement dit « légère
sauf la portée du déverrouillage », et c'est cette portée qui est une seconde porte.

**Une contrainte d'ordre que « les maximales en fin de palier » violait** : `V6` ne se livre
pas sans `L20`, `V7` pas sans `L14`. Les mettre après le groupe `V6`+`V7` aurait inversé une
dépendance dure. Elles sont donc **juste avant** — isolées et tardives, sans rien casser. Seule
`L16` finit vraiment.

Les quatre regroupements sont faits : `I7`+`I8`+`I9`, `L7`+`L17`, `V4`+`V5b`, `V6`+`V7`.

### `I7` + `I8` + `I9` — neuf composants, une anatomie

**C'est le regroupement qui se justifie le mieux** : les neuf partagent le même libellé, le
même fond, le même trait de focus et les mêmes quatre marques d'erreur. Séparés, cette coquille
s'écrivait trois fois — ou deux fois et demie, avec une divergence au milieu.

**`I9` ne recoupe pas `I10`, et le vérifier valait la peine.** Les deux touchent au refus, et
c'est là que ça se joue : le récapitulatif de refus du bloc `11c` est posé « dans le contenu,
pas en notification ». Réutiliser `Banner` l'aurait posé en interruption — donc exactement ce
que le bloc écarte. `ValidationSummary` est un composant distinct **pour ne pas** partager.

**Une collision de noms, et le compilateur l'a attrapée à la seconde.** Mon `DatePrecision` a
fait cesser de compiler `TitleEditor` : le modèle en porte déjà un, **persisté** dans
`releasePrecisionRaw`. Les deux paquets ne pouvant pas se connaître, le double est inévitable —
comme `CardLayout` / `DisplayLayout` — mais le nom, non. Renommé `DateFieldPrecision`, avec le
test d'accord des `rawValue` dans `DisplayVocabularyTests`, seul endroit qui voie les deux.

Le message d'erreur méritait d'être noté : « ambiguous use of `year` », qui ne nomme ni le
type, ni le module, ni la cause.

**Trois décisions inscrites** : le jour n'est pas borné au mois — un 31 février se **tape** et
se refuse par l'anatomie d'erreur, parce qu'un champ qui refuse la frappe ne dit pas pourquoi ;
les couleurs de profil sont **hors du catalogue d'assets**, puisqu'une couleur qu'on persiste ne
doit pas suivre l'apparence ; et le jeton du multi-sélecteur n'est **pas** `FilterChip` — même
allure, deux gestes différents, et deux relevés différents.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **461 · 85 · 64** |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **115 tests** |
| `xcodebuild test -scheme DesignSystemCatalog` · macOS et iOS | ✅ **86** et **85** |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 296 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **Preuve d'échec de la sonde** | ✅ faute historique réinjectée, substitution vérifiée, deux tests rouges, restauration vérifiée |
| `xcodebuild test -scheme CineShelfUITests` | ❌ **non lancée** — rien de cette session ne touche la navigation, mais ça ne se déduit pas |
| **Les planches vues à l'œil** | ❌ **non vues** — `screencapture` abandonné. Ce qui a changé : ce n'est plus le seul recours, et les cinq points aveugles de `V3` sont désormais assénés au pixel |

## 2026-08-06 (3) — `L18` : le hero se choisit, et le fil trouve son premier lecteur

### Une étiquette ne dit rien de ce qui dépend de quoi

La règle entre dans `CLAUDE.md`, et son motif est celui de « comparer des nombres hors
contexte » : **une valeur lue correctement, rapprochée d'une autre qui ne parle pas de la même
chose.** Réordonner un plan d'après la colonne « Rigueur » ignore le seul classement qui ne se
discute pas — les dépendances. Le geste ajouté à la routine : avant tout réordonnancement,
relire « Ce qu'elle débloque » et les « Ne pas livrer sans » ; avant tout retrait, `grep` sur le
nom de la ligne.

### `HomeSelection` descend de la vue, et le premier test dément mon raisonnement

**Trois raisons de la descendre, et la troisième est la vraie** : pas de test possible dans une
vue ; la règle n'était pas éditoriale mais une rotation ; et surtout **le widget et l'App Intent
de `L19` ne peuvent pas importer une vue**. « Prochain à voir » doit rendre le même titre dans
l'app, dans le widget et dans Siri.

**Le choix éditorial se déduit de ce que l'écran affiche.** Le hero est une image large floutée
sur toute la hauteur (planche 1, bloc `2a`) : un titre qui en a une passe donc devant, puis
celui qui a un synopsis, puis le mieux noté. La rotation quotidienne reste, mais **sur les sept
candidats de tête** — l'accueil change chaque jour sans jamais tomber sur un titre sans image
tant qu'il en existe un.

**Et le premier test a démenti ma justification du jour.** J'avais écrit le quotient d'époque —
« minuit UTC change partout au même instant, donc l'app et le widget s'accordent » — et
l'assertion « le hero ne change pas dans la journée » est tombée : mon instant de référence
tombe à 22 h 13 UTC, donc « huit heures plus tard » changeait de jour.

Le test avait raison, et pour une raison plus profonde que le calcul : **« stable dans la
journée » parle de la journée de l'utilisateur.** À UTC−8, minuit UTC tombe à seize heures
locales — le hero changerait au milieu de l'après-midi. Quant à l'argument du widget, il ne
tient pas : l'app et son widget tournent sur **le même appareil**, donc dans le même fuseau. Ce
que l'époque protégeait est un cas qui n'existe pas ; ce qu'elle cassait arrive tous les jours.

**Ce qui a rendu le test capable de le trouver** : avoir pris un instant **quelconque** du jour,
pas minuit. Un instant rond aurait passé, et laissé le bug.

Curiosité utile : `ActivityFeed.group(_:)`, écrit vingt minutes plus tôt, était **déjà** en
calendrier local — parce que j'y avais écrit « le fil dit ce qu'on a fait aujourd'hui ». Le bon
raisonnement était disponible ; je ne l'ai pas appliqué au hero.

### Le fil d'activité — première lecture depuis le prompt 6

`ActivityRecorder` écrit depuis le prompt 6 et **rien n'avait jamais relu** : aucun `fetch`
d'`ActivityEntry` dans le dépôt avant ce fichier. Une piste d'audit qu'on ne lit jamais est une
piste d'audit qu'on n'a pas.

**Quatre décisions, chacune avec sa raison :**

- **la fenêtre est posée sur le `fetch`**, pas après. Un `fetch` complet suivi d'un `prefix`
  matérialiserait tout — 248 ms pour 5 000 objets rendus, mesuré à `L1` ;
- **un curseur de date, pas un décalage.** Un `offset` se décale dès qu'une entrée s'écrit
  entre deux pages, et le fil saute une ligne. Sur un journal qui s'écrit en continu, ce n'est
  pas un cas rare, c'est le cas. Un test le joue ;
- **le filtre s'applique après le `fetch`**, et c'est assumé : sur une fenêtre de cent lignes la
  différence n'est pas mesurable, sur la lisibilité si. La conséquence est dite — une fenêtre
  filtrée peut rendre moins que `limit` ;
- **`summary` est figé à l'écriture, jamais résolu à la lecture.** C'est ce qui rend lisible
  l'entrée d'un titre supprimé, c'est-à-dire précisément ce qu'on vient consulter après une
  suppression.

Une action inconnue dit « Opération », pas un repli plausible : `action` est déjà `nil` sur un
`rawValue` inconnu, et une piste d'audit dit « je ne sais pas ».

### Les statistiques — trois omissions, toutes comptées

Le fil rouge est : **un chiffre incomplet doit s'annoncer incomplet.** Les titres sans date sont
omis des décennies (« 0 » se lirait comme une décennie sur un axe), les sans-note omis des
étoiles (« pas noté » n'est pas une note basse), et **les séries sont hors du total de durée** —
elles portent `episodeCount` mais aucune durée d'épisode, donc l'estimer produirait un chiffre
plausible et faux. `runtimeExclusions` rend ce que le total ne couvre pas, pour que l'écran
puisse le dire.

Les genres, eux, comptent chaque association : la somme dépasse le nombre de titres, ce qui est
correct pour « combien de drames ai-je ? » et faux pour « quelle part de ma bibliothèque est du
drame ? ». La seconde n'a pas de réponse honnête tant qu'un titre a plusieurs genres, donc on ne
la rend pas.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **484 · 85 · 64** (+23 sur Core) |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **115 tests** |
| `xcodebuild test -scheme DesignSystemCatalog` · macOS et iOS | ✅ **86** et **85** |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 302 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| `xcodebuild test -scheme CineShelfUITests` | ❌ **non lancée** |
| **Le fil et les statistiques vus à l'écran** | ❌ **aucun écran** — c'est `V5b` (fil) et `V11` (statistiques). `L18` livre les séries, pas les graphiques, et la fiche le dit |

## 2026-08-06 (4) — `L7` et `L17` : la seule sortie réseau du projet, et un état qu'on ne peut pas vérifier

### La règle du jour : une entrée de test se prend quelconque

Elle vient de la trouvaille du hero, et elle entre dans `CLAUDE.md` à côté des preuves
d'échec. **Minuit, zéro, la chaîne vide et le premier élément sont les valeurs où plusieurs
implémentations coïncident** — à minuit, « jour UTC » et « jour local » donnent la même
réponse, donc le test ne départage plus rien. Les cas dégénérés gardent leurs propres tests ;
ce qu'ils ne peuvent pas faire, c'est servir de cas nominal.

Elle a servi le jour même : les tests de `L7` prennent une URL à deux segments et une extension
plutôt que `/`, et ceux de `L17` des tailles de fichier de 3 517 et 12 289 octets plutôt que des
puissances de deux — une somme fausse se remarque moins quand tous les nombres sont ronds.

### `L7` — la fiche demande `LPMetadataProvider`, et je ne l'utilise pas

**C'est la seule requête sortante de toute l'app**, et son URL vient de l'utilisateur : la
définition d'une SSRF. Ce qu'elle permet n'est pas théorique sur une machine de bureau — coller
`http://192.168.1.1/admin/reboot`, `http://127.0.0.1:6379/` ou
`http://169.254.169.254/latest/meta-data/` fait émettre la requête depuis le réseau local de
l'utilisateur, avec ses accès. Aucune de ces cibles n'est joignable de l'extérieur ; toutes le
sont depuis l'app.

**Et c'est ce qui écarte `LPMetadataProvider`.** Il va chercher l'URL lui-même — il ouvre la
connexion, suit les redirections, lit la réponse — sans exposer aucun point de contrôle. Or la
protection demandée porte **exactement** sur ces trois choses. Le lui confier reviendrait à
valider l'URL collée puis à laisser un tiers décider de la suite : un serveur public répondant
`302 Location: http://127.0.0.1:6379/` obtiendrait précisément ce que la garde existe pour
empêcher. Le fetch passe donc par `URLSession`, dont le délégué voit chaque redirection
**avant** qu'elle parte. Écart à la fiche, inscrit — ce qu'on perd est l'icône et l'image que
`LPMetadataProvider` rend en plus.

**Trois détails qui décident, et qu'un test rond aurait manqués :**

- **l'IPv4 encapsulée en IPv6.** `::ffff:127.0.0.1` est une adresse IPv6 valide qui joint la
  boucle locale ; sans le cas dédié, elle passe une garde qui refuse pourtant `127.0.0.1` ;
- **les voisines des bornes.** 172.15 et 172.32 encadrent le bloc privé 172.16/12 : un masque
  écrit de travers refuse un lien parfaitement légitime, et c'est ce que le test assène ;
- **un hôte sans point est refusé.** Sur un réseau d'entreprise, `intranet` résout vers
  l'intérieur par suffixe de recherche DNS. Un lien collé depuis un navigateur porte toujours un
  domaine complet.

**Ce qui reste ouvert, et se dit** : un nom d'hôte public qui *résout* vers une adresse privée.
La garde lit le texte de l'URL ; la résolution a lieu dans `URLSession`, qui n'expose pas
l'adresse retenue. Et les formes octales ou hexadécimales d'IPv4 — `0177.0.0.1` — que le
parseur refuse comme adresses et qui repartent sur le chemin des noms. Deux écarts inscrits.

### `L17` — écrite, couverte, et pas vérifiée

**Sa ligne du tableau le dit maintenant en toutes lettres**, parce que c'est le genre de
nuance qui se perd : au vert, elle vaut « écrite et couverte en simulation ». Ce qu'aucun test
local ne produit reste entier — les notifications réelles du coordinateur, leur charge utile,
leur ordre d'arrivée, les cas de compte et de quota.

**Six cas et non cinq, et le document se contredit.** `docs/04` §5 déclare cinq cas dans son
extrait de code et en liste six dans le tableau juste en dessous : le quota manque à
l'énumération alors que le tableau lui donne un message **et** une action. Le tableau est plus
précis, donc il fait foi.

**Ce que la machine assène n'est pas la transition mais la priorité.** Un coordinateur envoie
ses événements dans un ordre qu'on ne contrôle pas : sans priorité, le dernier arrivé gagne et
l'utilisateur voit « envoi en cours » sur un compte qui n'existe pas. Un compte absent survit
donc à une perte de réseau, un quota dépassé survit à un envoi qui démarre, et une progression
hors échange est ignorée plutôt que de fabriquer un état.

**L'espace occupé compte trois emplacements, et se garde d'en compter un deux fois.** Le
magasin, le stockage externe — où vont toutes les images, donc l'essentiel du poids — et le
cache de vignettes. Le dédoublonnage n'est pas théorique : le stockage externe vit à côté du
fichier de magasin, et additionner à l'aveugle doublerait le chiffre annoncé **au moment précis
où l'utilisateur cherche à faire de la place**.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **510 · 85 · 64** (+26 sur Core) |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **115 tests** |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 308 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **Une vraie requête sortante** | ❌ **aucune, et c'est voulu** — la fiche l'exige, les tests fournissent un fournisseur factice. `URLSessionLinkFetcher` n'a donc **jamais tourné contre un serveur réel** : sa garde est testée, son chemin réseau ne l'est pas |
| **`L17` contre un vrai CloudKit** | ❌ **impossible avant le prompt 21**, et sa ligne le dit |
| `xcodebuild test -scheme CineShelfUITests` · catalogue | ❌ **non lancés** — rien de cette session ne touche l'interface |

## 2026-08-06 (5) — `V4` et `V5b` : cinq écrans, et un chemin d'image qui ne menait nulle part

### L'angle mort de `L7` nommait le mauvais exemple

**Mesuré contre un serveur de boucle locale**, parce que la question posée était « est-ce que
`URL` normalise déjà les IPv4 octales ? ». La réponse est non — `url.host()` rend le texte tel
quel — mais ce n'était pas la bonne question. Ce que fait **`URLSession`** :

| Hôte collé | Ce qu'il joint | Ce que la garde en faisait |
|---|---|---|
| `0177.0.0.1` | `177.0.0.1` — publique | acceptée, **et c'est correct** |
| `0300.0250.0.1` | rien, la résolution échoue | acceptée, sans effet |
| **`0x7f.0.0.1`** | **`127.0.0.1`** | **acceptée — la faille était là** |
| `2130706433`, `017700000001`, `0x7f000001` | `127.0.0.1` | déjà refusées, faute de point |

**L'octal n'était donc pas le sujet.** `UInt8("0177")` rend 177, et le résolveur système lit
lui aussi ce segment en décimal — les deux s'accordent, il n'y avait rien à fermer. C'est
l'**hexadécimal par segments** qui passait, parce que `UInt8("0x7f")` rend `nil` : l'hôte
repartait alors sur le chemin des noms, où son point suffisait à le faire accepter.

Le mécanisme, mesuré aussi : `inet_aton` lit `0177` en octal (127), mais le résolveur système
le lit en **décimal** (177) et ne retombe sur l'octal que si le segment dépasse 255 — d'où
`0300` → 192. Deux parseurs qui divergent, et c'est précisément pourquoi la correction **ne
réimplémente pas le résolveur** : `claimsToBeAddress` refuse tout hôte qui a la *forme* d'une
adresse sans en être une que nous sachions lire, quelle que soit la notation. Aucun nom
légitime n'est pris au passage — un domaine de tête ne peut pas être numérique (RFC 3696 §2).

### `docs/04` §5 décrivait cinq cas là où le code en a sept

Corrigé, et **deux écarts de plus se referment au passage** : `syncing` porte sa direction (le
tableau distinguait « premier envoi » et « premier téléchargement », qu'un `syncing(Double?)`
nu ne pouvait pas départager), et le nom réel est `SyncStatus`, pas `SyncState`.

### Le patron d'écran a tenu, et ce qui a manqué était sous la vue

**`V0 bis` a bien généralisé.** `AdaptiveTileGrid`, `PersonTile`, `CollectionTile`,
`ScreenHeader`, `EmptyState`, `PosterSettingStore` sont agnostiques ; `PosterContext` portait
déjà `.people` et `.collections` ; et `SearchPresentation` — écrit par `V1` — annonçait
lui-même « ils seront réutilisés par `V4` et `V5b` ». Changer d'entité s'est fait en changeant
le filtre, la tuile et le menu.

**Ce qui manquait n'était pas la mécanique de vue mais la couche en dessous**, et c'est la
trouvaille utile de la session :

- **`GenreRepository` n'avait aucune méthode d'épinglage.** `isPinned` et `pinIndex` étaient
  posés à la fermeture du schéma, **lus** par `HomeView` depuis `V5a`, et **jamais écrits** :
  l'accueil savait afficher une configuration que l'utilisateur ne pouvait pas faire ;
- **`PersonFilter` n'avait pas de tri**, alors que le bloc `4c` pose un menu « Trier » ;
- **`SavedLink` n'avait ni repository ni conformité à `ActivityDescribing`** — le cas
  `ActivityEntityType.savedLink` existait sans habitant, lisible avant d'être écrivable ;
- **`PrecisionDateRow`, `TokenFieldRow` et `ValidationSummary` n'avaient aucun appelant de
  production.** `TitleEditor` porte encore l'ancienne direction, donc `PersonEditor` est le
  premier — et le branchement a révélé qu'aucune conversion `PrecisionDate` ↔ `Date`
  n'existait.

### Le test qui a démenti mon code : l'épinglage partait à 1

`setPinned` posait `isPinned = true` **avant** de calculer le rang, donc le genre entrait dans
son propre maximum. Le premier épinglage d'une bibliothèque vierge rendait 1 au lieu de 0.

**Invisible sur un genre isolé** — l'ordre reste bon, il commence juste plus haut — et
invisible aussi en retirant le premier ou le dernier. C'est le test qui retire celui du
**milieu** qui l'a trouvé, exactement la règle des entrées quelconques : sur une borne,
« renumérote » et « ne renumérote pas » donnent la même réponse.

### Un chemin mort dans le code de production, pas dans un échantillon

`PosterCardModel(_ person:)` ne passait **aucune** `imageURL`. Une personne à qui
l'utilisateur avait attaché un portrait rendait donc ses initiales — dans la recherche, dans
le casting d'une fiche titre, et elle l'aurait fait dans la grille neuve. Le commentaire
d'origine invoquait le §11 du handoff, « Portraits de personnes : aucun » : c'est vrai des
**échantillons** du paquet de design, pas du modèle — `MediaAttachment` porte un `person`, et
`V2` en attache depuis le glisser-déposer.

**Même famille que `MediaFill`, avec une différence qui compte** : là-bas l'échantillon était
nul, ici c'était le code de production qui court-circuitait le chemin qu'on croyait couvert.
Six tests le couvrent désormais, et la preuve d'échec a été jouée — la ligne retirée, la
substitution vérifiée (une), le test rouge sur `card.imageURL → nil`, puis restauration.

### La porte de rendu n'a pas pu se poser sur les écrans, et voici pourquoi

**La règle « une tâche `V` se termine par un rendu assené » est arrivée à un mur
architectural**, pas à un oubli. La sonde a été écrite, puis retirée : `CineShelfTests` n'a
**aucun `TEST_HOST`** — `project.yml` le documente explicitement, « la lier à la cible app
imposerait de lancer l'interface ». Elle compile des fichiers app choisis, un par un. Rendre
`PeopleView` y demanderait la fermeture transitive de toutes les vues, ou un `TEST_HOST` que
la cible existe pour éviter.

Ce qui a été fait à la place, et qui couvre le risque réel : la présentation des personnes est
entrée dans la cible de test, et le défaut d'`imageURL` — le seul « ça rend du vide sans qu'on
le voie » de cette tâche — est assené par six tests dont une preuve d'échec. **Le rendu des
cinq écrans reste non vu**, et l'écart est inscrit avec sa cause.

### Ce que les planches montrent et que la v1 ne rend pas

Quatre choses, toutes issues de tâches **reportées en v1.1** : « 41 doublons possibles » et
l'écran de fusion (`L8`, dont la fiche du report nomme « l'écran de fusion de `V4` »), la
suggestion de casting (`L9`), la mosaïque de couverture générée (`L6` — le repli calculé
reste, et n'écrit aucun asset), et l'« Annuler » de chaque ligne du Fil (`L20`, tâche 19).
Cette dernière est rendue **sans bouton** plutôt qu'avec un bouton inerte.

Et une cinquième qui n'est pas un report : **« Cork, Irlande »**, le lieu de naissance du bloc
`4d`. `Person` n'a pas de champ pour ça et le schéma est fermé — un écran ne déclenche pas une
migration.

### Où l'on épingle un genre : l'écran Collections

**Une seule occurrence d'« épinglé » dans les onze planches**, et elle décide : l'en-tête du
bloc `4e` compte « 38 rayons · 14 genres épinglés ». Un écran qui compte des objets dans son
sous-titre les possède. Les deux autres candidats ne tiennent pas — la barre de navigation n'a
pas de section « Genres », et la console les liste comme entité (« Genres 62 ») sans rien y
épingler. Ça recoupe la conclusion de `V5a` : un genre épinglé n'est pas une entrée de
navigation, c'est **la configuration de l'accueil**, donc il vit à côté des rayons.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore · DesignSystem · MediaKit | ✅ **517 · 85 · 64** (+7 sur Core) |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **121 tests** (+6) |
| `xcodebuild test -scheme DesignSystemCatalog` · macOS et iOS | ✅ **86** et **85** |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 317 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **Preuve d'échec du portrait** | ✅ ligne retirée, **une** substitution vérifiée, test rouge, restauration vérifiée |
| **Sonde de boucle locale sur la garde de lien** | ✅ serveur local, huit hôtes, `0x7f.0.0.1` atteint 127.0.0.1 — puis refusé après correction |
| `xcodebuild test -scheme CineShelfUITests` | ❌ **non lancée** |
| **Les cinq écrans vus à l'écran** | ❌ **non vus** — pas faute d'outil cette fois : `CineShelfTests` n'a pas de `TEST_HOST`, la sonde d'écran ne peut pas y vivre. Écart inscrit avec sa cause |

## 2026-08-06 (6) — Le `TEST_HOST`, la classe de défaut, et `L20`

### La CI était rouge, et elle avait raison contre moi

`@testable import CineShelf` dans `PersonPresentationTests` : **inutile** — la cible compile
les fichiers de `App/` dont elle a besoin, ils ne sont pas importés — et il **compilait en
local** parce que `DerivedData` gardait le module app d'un build précédent. Sur une machine
propre : « unable to resolve module dependency ». Même famille que les seuils de performance
calés sur la machine locale : vert ici, rouge là-bas, et le local est le mauvais juge. Vérifié
après correction sur un `DerivedData` vidé.

### Le `TEST_HOST` : l'issue retenue, et ce qu'elle a trouvé

**Une seconde cible, pas un `TEST_HOST` sur l'existante.** `CineShelfTests` porte 121 tests qui
tournent sans lancer l'interface et `project.yml` documente ce choix ; lui donner un hôte ferait
payer le lancement de l'app à des tests de prédicat. Les deux autres issues inscrites ne
tiennent pas : extraire les compositions vers `DesignSystem` échoue par construction sur
l'écran qui compte — la console de `V6` extraite du contexte n'est plus la console —, et
accepter laisse `V6` sans porte.

**Deux trouvailles en la branchant, et la première a failli me faire conclure de travers.**

1. **`ImageRenderer` ne met pas en page un `ScrollView`.** Cinq écrans sur sept rendaient
   **une seule couleur**. J'ai failli lire ça comme « cinq écrans cassés » ; le diagnostic
   minimal — `ScrollView { Text("CineShelf") }` contre le même texte nu — donne 1 contre 3.
   C'est la sonde qui était aveugle. Aucun contournement d'enveloppe ne marche : `.fixedSize`,
   `.scrollDisabled`, `.clipped`, hauteur libre ou imposée. D'où `ScreenScroll`, qui s'aplatit
   sur `\.rendersFlat`.
2. **Trois écrans de `V5b` portaient un `ScrollView` redondant.** `RegularRootView` en pose
   déjà un autour de `section.destination` : les sections étaient donc en défilement imbriqué.
   `TitlesView` et `PeopleView` n'en ont pas — c'est la forme correcte, et je ne l'avais pas
   suivie. Les fiches, poussées par `navigationDestination`, sont hors de ce conteneur et
   gardent le leur.

Huit sondes, dont le contrôle négatif et deux écrans sondés **rétroactivement** — la grille des
titres et l'accueil, livrés sans porte, et c'est sur eux que `MediaFill` était passé.

| Écran | vide | peuplé |
|---|---|---|
| Personnes | 17 couleurs | 24 |
| Collections | 16 | 20 |
| Fil | 11 | 28 |
| Fiche personne | 10 (absente) | 21 (trouvée) |
| Fiche collection | 8 (absente) | 10 (trouvée) |
| Titres · Accueil | — | 8 · 133 |

**Ce que la porte ne couvre pas, et c'est écrit dans le fichier** : le *chargement* des images.
`ImageRenderer` rend de façon synchrone et le décor n'attache aucun média. Ce chemin est couvert
par `ContentRenderTests` de `DesignSystem`, qui injecte un chargeur et laisse tourner la boucle.
Croire que cette suite couvre les deux serait l'erreur exacte qui a laissé passer `MediaFill`.

### La classe de défaut entre dans `CLAUDE.md`

« Une capacité lue et jamais écrite est un écran qui ment. » Cinq occurrences dans `V4`/`V5b`,
donc une classe, pas cinq oublis. Le geste ajouté : avant de livrer un écran, `grep` sur chaque
propriété qu'il lit pour trouver qui l'écrit. Le corollaire symétrique est déjà mesuré —
`ActivityEntry`, écrit quinze prompts avant son premier lecteur.

**Propagation, comme la règle l'exige.** Un balayage des propriétés du modèle rend vingt noms
« lus sans écriture hors du modèle ». Dix-neuf sont des faux positifs par construction —
dérivées (`sortName`, `filterKeys`, `nameKey`, `searchText`, maintenues par `refreshDerived`),
calculées (`age`, `isEmpty`, `releaseYear`, `hasExactlyOneOwner`), ou écrites par
initialisation de relation (`attachments`, `flags`, `handles`, `links`, `crops`). **Le vingtième
est réel et déjà connu** : `Profile.accent`, 53 lectures et aucune écriture — l'écran de
profils est `V7`. Inscrit.

### `L20` — l'exécuteur d'annulation

**La fiche est périmée sur un point, et je l'ai vérifié avant d'écrire** : elle dit
« `ActivityEntry.payload` n'existe pas ». Il existe depuis la fermeture du schéma du
2026-08-03, avec `undoneAt`, et `L10` y écrit déjà un `BulkEditDiff` versionné. **Aucun
changement de schéma n'a donc été nécessaire** — ce qui manquait était le lecteur.

**Deux passes et non une** : vérifier tout, puis écrire. Une annulation qui écrirait au fil de
sa vérification laisserait, sur le premier champ divergent, la moitié du lot défaite — le
désordre exact que « tout ou rien » existe pour empêcher.

**La sonde a trouvé un défaut que je ne cherchais pas, et c'est le plus vicieux du lot.**
`isUndoable` répondait « non » au-delà de trente jours pendant qu'`undo` défaisait quand même :
deux réponses à la même question. L'interface aurait grisé le bouton et tout appel
programmatique serait passé outre. La fenêtre est désormais tenue dans `undo`, et `isUndoable`
la lit du même endroit ; la purge de `L16` n'est plus qu'une libération d'espace.

**Le test de purge en a trouvé un second, plus fin.** Une entrée purgée n'a plus de `payload`,
donc elle répondait `notUndoable` — « ce n'était pas une opération de masse », ce qui est faux :
elle l'était, et elle a été annulable pendant trente jours. La fenêtre départage maintenant les
deux causes du même symptôme.

**Le rappel de la fiche est tenu et testé** : `releaseDate` et `releasePrecision` reviennent
**dans la même écriture**. Restaurer en deux passes laisserait entre les deux une date au jour
près sur une précision à l'année — le bug du prompt 11.

**Ce que la sonde a mesuré, quinze scénarios** : aller-retour sur notes, dates, rôles ;
remplacement de genres (attachés *et* détachés) ; vidage ; un genre ajouté après le lot, qui
**survit** — l'annulation défait ce que le lot a fait, rien d'autre ; entité modifiée,
corbeille, supprimée ; entrée inconnue, sans diff, de version inconnue ; double annulation ;
purge rejouable ; lot sans effet.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore | ✅ **531 tests** (+14) |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **121 tests**, dont une passe sur `DerivedData` vidé |
| `xcodebuild test -scheme CineShelfScreenTests -destination macOS` | ✅ **8 tests** — la cible n'existait pas ce matin |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 322 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **Sonde hors dépôt de `L20`** | ✅ 15 scénarios, 2 défauts trouvés, corrigés et remesurés |
| **Preuve d'échec de `L20`** | ✅ garde de champ neutralisée, **une** substitution vérifiée, test rouge sur le bon test, restauration vérifiée |
| `swift test` DesignSystem · MediaKit | ❌ **non relancés depuis `V5b`** — rien de `L20` ni du `TEST_HOST` ne les touche, mais ça ne se déduit pas |
| `xcodebuild test -scheme DesignSystemCatalog` | ❌ **non lancée** cette session |
| `xcodebuild test -scheme CineShelfUITests` | ❌ **non lancée** |
| **Sous-agent de revue** (attendu à rigueur maximale) | ❌ **non lancé** — l'instruction de session interdit d'appeler un agent sans demande explicite. Remplacé par la sonde et la preuve d'échec, pas par rien, mais ce n'est pas le même filet |

## 2026-08-06 (7) — `L20` était sous-exercée, et `L14`

### La question qui a fait tomber deux défauts

« L'annulation a-t-elle été rejouée sur une fusion ? » — non. Et la réponse à « `L20`
était-elle simple ou sous-exercée » est **sous-exercée**, sans ambiguïté.

**Correction de ma propre présentation d'abord.** J'avais bien signalé deux défauts, mais ils
étaient dans du code que je venais d'écrire dix minutes plus tôt. `L11b`, `L12`, `L10` et `L1`
trouvaient des défauts dans du code **déjà là**. Une sonde qui corrige son auteur dans la même
heure est un signal beaucoup plus faible, et je ne l'avais pas dit.

**Ce que la fusion a révélé, et qu'aucune édition en masse ne pouvait montrer :**

1. **La garde « entité à la corbeille » refusait le perdant.** Or sortir le perdant de la
   corbeille *est* ce qu'annuler une fusion veut dire : **aucune fusion n'était annulable**.
   Elle ne mord plus que si le lot n'est pas ce qui a mis l'entité là — le diff le dit, en
   portant un changement sur `deletedAt`.
2. **Le nom de la relation venait de `BulkEditDiff.field`**, global au lot. Pour une édition en
   masse il vaut « genres » ; pour une fusion il vaut « merge », donc `relatedIDs` rendait vide
   et **tout paraissait avoir bougé**.

`currentVersion` ne change pas, et c'est argumenté : un `payload` en base n'a pas la clé
`relationField`, `decodeIfPresent` rend `nil`, et `nil` veut dire « la relation du lot » — soit
exactement la sémantique v1. Un test lit le JSON réellement écrit par `L10` et vérifie que la
clé **n'y est pas**, puis que l'annulation fonctionne quand même.

**Les trois autres questions étaient couvertes** : seize appels passent par un lot réellement
appliqué (seul le test des entrées malformées fabrique un diff, et c'est son sujet) ; le double
appel est refusé par `undoneAt` ; une version inconnue est rejetée.

### `L14` — le verrou, et la portée

**La portée est la seule partie à rigueur maximale, et elle a trouvé un défaut de forme.** Neuf
écrans écrivaient `session.current?.hidesPrivateContent ?? false` : **en l'absence de profil,
montrer le contenu privé**. Le repli va dans le mauvais sens. Il n'est pas atteignable
aujourd'hui — `RootView` pose le sélecteur tant que `current` est `nil` — mais c'est un
invariant tenu **à distance**, par un `if` dans un autre fichier, que rien ne rappelle au
dixième écran. `PrivacyScope` masque par défaut, et c'est le seul point d'entrée.

**`Profile.requiresBiometry` était « affiché mais jamais appliqué » — l'écart se ferme ici.** Un
profil qui exige l'authentification masque tant que l'app est verrouillée. Sans cette clause, le
réglage serait un interrupteur qui ne fait rien, ce qui est pire qu'un réglage absent : il donne
une confiance qu'il ne mérite pas.

**La règle de lint en plus du test**, parce que la propriété à garantir est « ce code passe par
tel point d'entrée » et non « ce code produit telle valeur » : `no_direct_private_flag`. Lancée
sur tout le dépôt **avant** d'être ajoutée — neuf infractions, exactement les neuf sites — puis
prouvée en réinjectant la faute sur un écran.

**Les trois rappels de la fiche sont tenus.** `.deviceOwnerAuthentication` et non
`...WithBiometrics`, avec la raison écrite dans le fichier : la variante biométrique enferme
dehors un utilisateur masqué ou dont Face ID s'est verrouillé, sans recours. Le voile de
confidentialité se pose dès `.inactive`, pas à `.background` — iOS prend la vignette **pendant**
`.inactive`. Et les quatre délais de grâce, avec leur cas dégénéré : `>=` et non `>`, sinon
« immédiat » ne verrouille **jamais**.

**Un défaut trouvé par la sonde d'écran, et il tue le processus.** Ajouter
`@Environment(AppLock.self)` aux neuf écrans a fait rendre « 0 test exécuté, TEST FAILED » à la
suite de rendu, sans nommer un seul test — le symptôme exact que `CLAUDE.md` décrit. Cause : une
valeur d'environnement absente fait mourir SwiftUI à l'évaluation du corps. C'est la porte de
rendu qui l'a attrapé, le jour même où elle a été construite.

**Et un test qui a attrapé mon propre compte faux** : la table des huit combinaisons annonçait
deux cas visibles, il y en a trois. L'assertion est passée d'un nombre à l'énumération — un
nombre nu ne dit pas *lesquels*, donc la prochaine rougeur ne dirait pas si c'est le code ou le
compte qui a bougé.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore | ✅ **554 tests** (+20) |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **121 tests** |
| `xcodebuild test -scheme CineShelfScreenTests -destination macOS` | ✅ **8 tests** — après correction du décor |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 327 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **Sonde de fusion** | ✅ hors dépôt, 2 défauts trouvés, corrigés, remesurés |
| **Preuve d'échec de la garde de corbeille** | ✅ garde neutralisée, une substitution vérifiée, le test de fusion rouge sur ses quatre assertions, restauration vérifiée |
| **Preuve d'échec de `no_direct_private_flag`** | ✅ faute réinjectée sur `TitlesView`, substitution vérifiée, règle déclenchée, restauration vérifiée |
| **Une vraie authentification Face ID / Touch ID** | ❌ **jamais jouée** — aucun test ne peut en déclencher une. `LocalAuthenticationEvaluator` n'a donc **jamais tourné** : sa traduction d'erreurs est écrite contre la documentation, pas contre le système. À vérifier à la main à `V7` |
| `swift test` DesignSystem · MediaKit · `DesignSystemCatalog` | ❌ **non relancés** — rien de cette passe ne les touche, mais ça ne se déduit pas |
| `xcodebuild test -scheme CineShelfUITests` | ❌ **non lancée** |

## 2026-08-06 (8) — Face ID simulé, la règle sur l'âge des défauts, `V6` + `V7`

### La biométrie simulée : ce qui a été joué, et ce qui n'a pas pu

Inscription posée par `notifyutil -s com.apple.BiometricKit.enrollmentChanged 1`, iPhone 17 /
iOS 26.5.

| Ce qui a été joué | Résultat réel |
|---|---|
| `canEvaluate()` | ✅ `true` — le vrai `LAContext` |
| `biometryKind()` | ✅ `.faceID` — ce qui **valide le détail non évident** : `biometryType` n'est renseigné qu'après `canEvaluatePolicy` |
| `evaluate` sans réponse | ✅ `.cancelled` |
| `evaluate` + `fingerTouch.nomatch` | ✅ `.failed("Échec d'authentification.")` |
| `evaluate` + `pearl.match` | ✅ `.failed("L'authentification a expiré.")` |
| **un succès** | ❌ **non reproductible sans app hôte** — le dialogue attend indéfiniment, commande tuée à 170 s |
| `.lockedOut` | ❌ non atteint |

**Ce que ça change quand même** : le chemin atteint le système, et la traduction rend des
`AuthError`. Ce qu'il restait à couvrir — la correspondance **code par code**, qui est le vrai
risque — l'est par cinq tests sur de **vrais `LAError`**, dont le balayage « aucun code ne se
traduit en succès ».

### La règle sur l'âge des défauts

Elle entre dans `CLAUDE.md` : **dire si un défaut trouvé est de la session ou antérieur.** Le
premier dit que je me relis, le second que la passe sert. Avec son corollaire, qui vient du
même incident : une tâche dont la moitié du domaine n'est exercée par aucun test peut être
déclarée finie sans que rien ne proteste — donc relire la fiche **phrase par phrase** et
pointer le test qui couvre chacune.

### `V6` — la console, et l'édition en masse dans l'inspecteur

**L'édition en masse n'est pas un écran.** Le bloc `7b` montre la même colonne de droite que
le `7a`. En faire une feuille demanderait de perdre la sélection des yeux pendant qu'on décide.

**Une mutation à la fois, et c'est une contrainte de `L10`, pas un choix d'écran.**
`BulkEditor.apply` prend une mutation et écrit un diff — c'est ce qui rend le lot annulable
d'un bloc. Appliquer trois champs d'un coup produirait trois lots, donc trois annulations
séparées, et un état intermédiaire que personne n'a voulu.

**Les bascules sont à trois états.** Un `Bool` n'a pas de position « ne pas toucher » : il
affiche forcément vrai ou faux, donc « Appliquer » écrirait toujours — et qui ne voulait
changer que la note passerait cinq titres en « non privé ».

### `V7` — le verrou, les réglages, les profils

**Trois capacités lues et jamais écrites, trouvées par le balayage que tu demandes.**
`requiresBiometry`, `hidesPrivateContent` et `accentRaw` étaient lus — le troisième
cinquante-trois fois — et `ProfileRepository` n'avait **aucun** chemin d'écriture. Trois
réglages que l'utilisateur ne pouvait pas changer, dont deux qui décident de ce qu'il voit.
`ProfileColorPicker`, livré par `I9`, trouve du même coup son premier appelant.

**Un défaut d'ordre de modificateur, attrapé par la porte de rendu.** `.lockGate()` posé
**après** `.environment(appLock)` enveloppe la vue qui porte la valeur, donc ne la voit pas :
SwiftUI tue le processus au lancement. La suite de rendu a rendu « 0 test », l'app hôte n'ayant
jamais démarré. Sans cette porte, le défaut serait apparu au premier lancement réel.

### Deux anomalies mesurées et **non expliquées**, inscrites plutôt que masquées

- **La console rend le même compte de couleurs vide et peuplée** (30 · 30).
- **Les réglages rendent un aplat** (1 couleur).

**Ce n'est pas la limite connue des conteneurs paresseux** : mesuré, un `Table` nu rend 9
couleurs sous `ImageRenderer` et un `Form` nu 3. La cause n'est pas trouvée. Les assertions
correspondantes ont donc été **retirées plutôt que rendues fausses** — affirmer « la table se
peuple » serait affirmer ce que je n'ai pas constaté. Deux écarts inscrits, avec leur mesure.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore | ✅ **559 tests** (+5) |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **121 tests** |
| `xcodebuild test -scheme CineShelfScreenTests -destination macOS` | ✅ **10 tests** (+2) |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 332 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| **Biométrie réelle sur simulateur** | ✅ capacité et chemins d'échec · ❌ succès et `.lockedOut` non atteints |
| **Balayage des capacités lues sans écriture** | ✅ cinq propriétés vérifiées, trois corrigées |
| `swift test` DesignSystem · MediaKit · `DesignSystemCatalog` | ❌ **non relancés** |
| `xcodebuild test -scheme CineShelfUITests` | ❌ **non lancée** |
| **La console et les réglages vus à l'œil** | ❌ **non vus** — et deux mesures de la sonde restent inexpliquées, voir ci-dessus |

## 2026-08-06 (9) — L'angle mort de la porte de rendu, mesuré

### Tu avais raison, et le chiffre invariant est la preuve

**`ImageRenderer` ne capture pas les vues adossées à AppKit.** Le test décisif est la variation
avec les données, pas la valeur absolue :

| Lignes fournies | `Table` | `VStack` des mêmes données | `Form(.grouped)` |
|---|---|---|---|
| 0 | 9 couleurs | 9 | 1 |
| 3 | 9 | 15 | 1 |
| 60 | **9** | 74 | **1** |

Le `Table` ne bouge pas — c'est le chrome, `NSTableView` ne passe pas dans le rendu. Le `Form`
groupé ne rend rien du tout. **Et ma lecture d'hier était fausse** : j'avais pris ces 9 couleurs
pour la preuve que le corps rendait, alors qu'elles disaient l'inverse.

**La règle qui entre dans `CLAUDE.md`** : avant de croire une porte de rendu, vérifier qu'elle
**varie avec ses données**. Deux comptes à deux volumes, et s'ils sont égaux la porte est
aveugle sur ce contenu. C'est la même forme de confiance fausse qui a coûté quatre sessions
d'affiches invisibles.

### Le remplacement est construit, et il bute sur un second obstacle

**Ce qui marche, contre ce que `project.yml` affirmait** : les tests d'interface **tournent sur
macOS**. Le commentaire disait « iOS uniquement, sur macOS ils réclament l'autorisation
d'accessibilité » ; mesuré, `testAppLaunches` passe en 9 s sans rien accorder à la main. La
cible a donc gagné macOS, et c'est nécessaire — la console est un écran Mac, et la sélection
multiple par clic modifié n'a pas d'équivalent iOS.

**Ce qui est en place** : l'amorçage par argument de lancement `-cineshelf-seed <n>` (DEBUG
seulement), trois identifiants d'accessibilité sur la console, et trois tests qui portent les
trois vérifications demandées — table peuplée, contre-cas vide, sélection qui pilote
l'inspecteur.

**Ce qui bloque, et que je n'ai pas résolu** : l'app se lance, `wait(for: .runningForeground)`
passe, et **aucune fenêtre n'apparaît dans l'arbre d'accessibilité**. L'application y figure
« Disabled » et son sous-arbre ne contient que la barre de menus. `console.table` est donc
introuvable pour une raison qui n'est plus l'identifiant.

**Les trois tests sautent plutôt que de rougir**, avec le motif écrit dans le fichier : ils
cherchent une chose et échoueraient sur une autre. **La ligne 21 reste donc en 🔶** — je ne peux
pas la cocher, la porte que tu demandes n'est pas verte, elle est absente.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| **Le test décisif du `Table`** | ✅ 9 · 9 · 9 contre 9 · 15 · 74 — ton hypothèse confirmée |
| `xcodebuild test -scheme CineShelfUITests -destination macOS` | 🔶 **lancée pour la première fois** — 4 tests, 1 passé, **3 sautés** faute de fenêtre dans l'arbre |
| `swift test` CineShelfCore | ✅ **559 tests** |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ **121 tests** |
| `xcodebuild test -scheme CineShelfScreenTests` | ✅ **10 tests** |
| `xcodebuild build` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 333 fichiers |
| `xcrun swift-format lint` | ✅ 0 avertissement |
| **`V8` — import et export** | ❌ **non commencée**. Le budget de la session est passé dans la mesure et l'infrastructure ; commencer `V8` maintenant produirait un écran à moitié écrit, ce qui est pire que rien |
| `swift test` DesignSystem · MediaKit · `DesignSystemCatalog` | ❌ **non relancés** |

## 2026-08-06 (10) — L'arbre d'accessibilité, et l'audit de `project.yml`

### CI rouge d'abord, et la cause était ma garde de saut

`be3aaec` a rougi. Ma garde sautait sur « aucune fenêtre dans l'arbre » — un raisonnement
**macOS** — dans une suite qui tourne sur **les deux** plateformes depuis que la cible a gagné
macOS. Sur iOS une fenêtre existe toujours, donc le saut ne déclenchait pas et les trois tests
cherchaient un écran Mac sur un iPhone. `#if os(macOS)`, et le périmètre est de toute façon
celui-là : le bloc `7a` « assume un usage clavier ».

**La leçon : une condition écrite en pensant à une plateforme se borne à elle, elle ne se
devine pas à l'exécution.**

### Ton hypothèse était fausse, et la mienne aussi

**Le voile de confidentialité n'est pas la cause.** Testé avec `-cineshelf-no-lock`, qui
contourne entièrement `LockGate` : l'arbre reste vide. `app.activate()` n'y change rien.

**Ma garde n'était pas la cause non plus** — c'était la première chose à vérifier, parce que
c'était la plus suspecte de mon côté : `windows`, `groups`, `others` **et** `tables` sont tous à
zéro, pas seulement `windows`.

**La cause est une autorisation système.**

```
osascript -e 'tell application "System Events" to return UI elements enabled'  ->  false
```

**Et c'est moi qui avais surinterprété, pas `project.yml`.** Son commentaire disait « sur macOS
les tests UI réclament l'autorisation d'accessibilité ». J'ai écrit hier « mesuré, elle y tourne,
le commentaire était faux » — parce que `testAppLaunches` passe. Il passe parce que
`wait(for: .runningForeground)` lit un **état de processus**, pas l'arbre. C'est exactement le
motif que ce dépôt passe son temps à proscrire : **un test vert qui n'exerce pas ce qu'on
croit.** Le commentaire avait raison sur la permission ; il était imprécis sur la conséquence,
qui n'est pas « ça ne tourne pas » mais « ça tourne et ne voit rien » — c'est-à-dire pire.

À accorder à la main : Réglages Système → Confidentialité et sécurité → Accessibilité, pour
Xcode. D'ici là la suite **saute**, et ne rougit pas : un défaut de droits ne doit pas se lire
comme un défaut de code.

### L'audit des commentaires de `project.yml`

Deux affirmations vérifiables, deux résultats.

- **« Aucune dépendance externe »** — ✅ vérifiée : aucun `url:` dans `project.yml` ni dans les
  trois `Package.swift`.
- **Le bug XcodeGen sur `SUPPORTED_PLATFORMS` / `TARGETED_DEVICE_FAMILY`** — ⚠️ **la
  reproduction documentée ne reproduit plus**, sur la **même version** que celle incriminée
  (2.46.0) : le spec minimal n'écrit aucun `= "";`.

  **Ce que ça prouve et ce que ça ne prouve pas.** La reproduction est périmée. Ça ne prouve
  **pas** que retirer les réglages explicites soit sans risque — c'est le second temps que le
  commentaire prescrit lui-même (« retirer ces deux réglages de chaque cible puis vérifier le
  build iOS *et* macOS »), et il n'a pas été joué. La contrainte reste donc en place **avec son
  audit inscrit**, plutôt que retirée sur une demi-mesure. C'est la même prudence que pour
  `currentVersion` à `L20`.

Les autres commentaires du fichier énoncent des choix (pourquoi `DEVELOPMENT_TEAM` n'est pas
dans `settings`, pourquoi les entitlements sont macOS seuls) plutôt que des limitations
extérieures : ils ne se « vérifient » pas, ils s'argumentent, et leur argument tient.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `xcodebuild test -scheme CineShelfUITests -destination iOS` | ✅ **1 test** — CI réparée |
| `xcodebuild test -scheme CineShelfUITests -destination macOS` | 🔶 **4 tests, 3 sautés** — autorisation d'accessibilité absente |
| **Hypothèse du voile** | ✅ **écartée par la mesure** — `-cineshelf-no-lock`, arbre toujours vide |
| **Hypothèse de ma garde** | ✅ **écartée** — tous les compteurs à zéro, pas seulement `windows` |
| **Autorisation d'accessibilité** | ❌ **`false`** — c'est la cause, et elle ne se donne qu'à la main |
| **Reproduction du bug XcodeGen** | ⚠️ **ne reproduit plus** sur 2.46.0 · retrait des réglages **non tenté** |
| `swiftlint --strict` | ✅ 0 violation sur 333 fichiers |
| `xcodebuild build -scheme CineShelf -destination macOS` | ✅ `BUILD SUCCEEDED` |
| **`V8` — import et export** | ❌ **non commencée**, pour la seconde fois et pour la même raison : le budget est passé dans le diagnostic et l'audit. Un écran d'import à moitié écrit serait pire que rien |
| `swift test` paquets · `DesignSystemCatalog` · suite app · sondes d'écran | ❌ **non relancés** — rien de cette passe ne les touche, mais ça ne se déduit pas |

## 2026-08-06 (11) — La permission ne suffit pas, et `V8` premier jalon

### Les trois tests ne mordent toujours pas, et j'ai mesuré pourquoi

Autorisation accordée à **Xcode.app**, et l'arbre reste vide : `windows=0`, `groups=0`,
`others=0`, `root=false`. `UI elements enabled` rend encore `false`, et **aucun refus TCC n'est
journalisé** pendant la course.

**L'explication la plus probable, et je la donne pour ce qu'elle est — une hypothèse non
épuisée** : le processus qui pilote ici est `xcodebuild` lancé depuis un terminal, pas
Xcode.app. C'est l'application responsable du terminal qui aurait besoin du droit. Je n'ai pas
pu la vérifier — TCC.db n'est pas lisible sans droits — et je n'ai pas brûlé plus de budget
dessus. **La ligne 21 reste donc en 🔶.**

### La leçon générale entre dans `CLAUDE.md`

« **Infirmer une contrainte documentée demande la même rigueur que l'établir.** » Retirer une
limitation écrite est une écriture, pas une lecture, et on l'aborde avec l'humeur inverse. Trois
gestes : nommer ce que la mesure a réellement exercé, chercher le chemin par lequel la contrainte
se manifesterait, et **si la contrainte prescrit sa propre vérification, la jouer en entier**.

L'ironie est le vrai enseignement : je croyais appliquer la règle sur la fausse dette. Elle vaut,
et son symétrique aussi — **une contrainte déclarée périmée sur une preuve trop faible coûte
davantage**, parce qu'elle transforme un obstacle connu en défaut mystérieux.

### `V8` — premier jalon, découpé plutôt que reporté une troisième fois

**L'interface de `L11a`, `L11b` et `L12`**, trois tâches faites dont deux à rigueur maximale qui
n'avaient jamais eu d'écran. Livré : le parcours `11d` → `11e` → écriture → `11j`, et l'export.

**Ce que le premier jalon tient, et ce qu'il refuse de simuler :**

- **`11d`** — une ligne par colonne avec sa qualité de correspondance, les non reconnues
  **nommées** et non bloquantes, et le seul blocage réel : un champ requis sans colonne. « Aucune
  donnée n'est écrite à cette étape » est affiché parce que c'est vrai ;
- **`11e`** — l'aperçu **groupé par cause**, pas par ligne. Les deux sorties du prototype, et
  chacune n'apparaît que si elle a quelque chose à faire : un fichier sans erreur ne propose pas
  « erreurs en brouillon » ;
- **`11j`** — le bilan chiffré, les causes du rejet, et le cas de l'interruption ;
- **l'export** — titres, personnes, et le **modèle vide**, qui ferme la boucle « exporter,
  remplir dans un tableur, redéposer ».

**`ImportFlow` a changé de maison en cours de route.** Écrit d'abord à côté de l'écran, il était
invisible des tests du paquet. C'est une machine d'états qui n'importe que `Foundation` : sa place
est dans `CineShelfCore`, et c'est ce qui la rend assénable sans monter un rendu. Cinq tests, dont
le singulier sur une ligne et les deux sorties qui suivent les comptes.

**Le second jalon, inscrit et non promis** : la correction en masse depuis l'aperçu (`11f`),
l'abandon avec reprise de brouillon (`11g`), et le rejeu de la correspondance mémorisée — le pont
entre `ImportMapping` du magasin et `ColumnMapping` décodé n'existe pas encore.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| `swift test` CineShelfCore | ✅ **564 tests** (+5) |
| `xcodebuild test -scheme CineShelfScreenTests -destination macOS` | ✅ **11 tests** (+1) — l'écran d'import rend **15 couleurs** |
| `xcodebuild build -scheme CineShelf` · macOS et iOS Simulator | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 336 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| `xcodebuild test -scheme CineShelfUITests -destination macOS` | 🔶 **4 tests, 3 sautés** — cause non épuisée |
| **CI sur `75c519e`** | ❌ **rouge**, et c'est un **échec de lancement du simulateur** à 108 s (« Timed out while launching application via Xcode ») sur `testAppLaunches`, qui passe en local. Je n'ai pas pu relancer le job — droits admin — donc le prochain push tranchera flake ou défaut |
| `xcodebuild test -scheme CineShelf -destination macOS` | ❌ **non relancée** depuis `V8` |
| `swift test` DesignSystem · MediaKit · `DesignSystemCatalog` | ❌ **non relancés** |
| **Un import réel de bout en bout** | ❌ **non joué** — il demande un `fileImporter`, donc un clic. Les transitions sont couvertes par `ImportFlowTests`, l'écriture par `L11b` ; ce qui n'est pas exercé est la **couture** entre les deux |

## 2026-08-06 (12) — La couture d'import, et un genre détruit en silence

### La porte de la console : abandonnée, règle d'arrêt appliquée

Autorisation accordée à Switchboard — `UI elements enabled` rend enfin **`true`** — et l'arbre
reste **vide** : `windows=0`, `groups=0`, `root=false`. **La permission était nécessaire et pas
suffisante**, et la cause reste inconnue. Les trois tests sont **retirés**, avec leur
échafaudage, plutôt que laissés en faux positifs verts. Les identifiants d'accessibilité
restent : ils servent l'accessibilité réelle.

### La CI : variance, pas régression

Deux échecs identiques sur « Timed out while launching application via Xcode » ressemblaient à
une régression. Mesuré : le lancement varie d'un **facteur 3,3 sur le même code** — 18,6 s et
28,5 s à chaud, **61 s à froid**. Chaque runner CI est froid. Le job préchauffe donc le
simulateur et tolère une reprise.

### La couture d'import — et elle a détruit un genre

**Ta priorité était la bonne.** La sonde de bout en bout — lire un vrai fichier, rapprocher,
analyser, écrire, **relire depuis le magasin** — a tourné pour la première fois. Le parcours
tient : 8 lignes lues, 4 prêtes, 4 refusées en 4 causes nommées, 4 titres écrits, relus, et le
rejeu du même fichier rend « 4 inchangés » sans créer de doublon. Le rapport des écartées se
redépose, avec sa colonne `cineshelf_erreur`.

**Et l'aller-retour détruisait des données.** `CSVSchema.multiValueSeparator` valait `/`. Un
genre nommé **« Action/Aventure »** — un nom parfaitement ordinaire — s'exportait dans une liste
jointe par `/` et se réimportait en **deux** genres, `Action` et `Aventure`. Le genre d'origine
disparaissait, sans un mot.

**Aucune moitié ne pouvait le voir** : l'export joignait sur `/`, l'import coupait sur `/`, et
les deux étaient cohérents **entre eux**. C'est exactement le motif de `MediaFill` et de
`PosterCardModel(_ person:)` — deux parties justes, un joint absent. **Le défaut est antérieur
à cette session** : il vient de `L12`, à rigueur maximale, et douze tests verrouillaient le
format destructeur.

Corrigé en `|`, qui est aussi ce que l'échantillon d'export de la planche 5 écrit
(`"Science-fiction|Aventure"`). **Un séparateur qui existe dans les données qu'il sépare n'en
est pas un.** Neuf assertions de tests réécrites — un test qui encode un format destructeur est
pire qu'un test absent — et deux tests de non-régression, dont un qui **nomme la limite** au lieu
de la nier : une valeur contenant une barre verticale ne survit pas davantage, et c'est accepté.

**Une erreur de méthode au passage, à ne pas refaire** : ma première substitution était une
expression régulière large, qui a touché des dates et des chemins d'archive. Dix fichiers
modifiés, quatre tests cassés pour rien. Revenu en arrière et ciblé à la main.

### Vérifications — les commandes réellement passées

| Commande | Résultat |
|---|---|
| **Sonde d'import de bout en bout** | ✅ hors dépôt — **1 défaut de corruption trouvé, antérieur à la session** |
| `swift test` CineShelfCore | ✅ **566 tests** (+2) |
| `xcodebuild build -scheme CineShelf -destination macOS` | ✅ `BUILD SUCCEEDED` |
| `swiftlint --strict` | ✅ 0 violation sur 335 fichiers |
| `xcrun swift-format lint --recursive App Catalog Packages Tests` | ✅ 0 avertissement |
| `xcodebuild test -scheme CineShelfUITests -destination macOS` | ✅ **1 test** — les trois sautés sont retirés |
| `xcodebuild test -scheme CineShelfUITests -destination iOS` | ✅ **1 test**, 18,6 s à chaud |
| `xcodebuild build` iOS · suite app macOS · sondes d'écran · `DesignSystemCatalog` · paquets | ❌ **non relancés après la correction du séparateur** — le format touche l'archive, donc `swift test` de Core couvre l'essentiel, mais les autres cibles ne se déduisent pas |
| **`11f` et `11g`** | ❌ **non commencés** — la couture était la priorité et elle a livré un défaut de données à corriger. C'est le second jalon |

---

## 2026-08-06 — Fin de session · à lire en rouvrant sur l'autre Mac

**Trois choses qui se perdent en changeant de machine. Elles sont ici parce qu'aucune ne se
déduit du code.**

### 1. Une perte de données a été corrigée, et son format a changé

`CSVSchema.multiValueSeparator` est passé de **`/`** à **`|`** (commit `0d2cdd9`).

**Ce que l'ancien séparateur faisait.** Un genre nommé « Action/Aventure » — un nom
parfaitement ordinaire — s'exportait dans une liste jointe par `/`, puis se réimportait en
**deux** genres, `Action` et `Aventure`. Le genre d'origine disparaissait, sans un mot, sans
refus, sans entrée de journal.

**Sa cause est dans `L12`**, à rigueur maximale, et non dans cette session. **Douze tests
verrouillaient le format destructeur** — neuf assertions ont dû être réécrites, dont une dans le
*nom* d'un test (« séparées par une barre oblique »). C'est le motif de `MediaFill` et de
`PosterCardModel(_ person:)` : deux moitiés justes — l'export joignait sur `/`, l'import coupait
sur `/` — et un joint que rien n'exerçait. La sonde d'import de bout en bout est la première
chose à l'avoir traversé.

**Conséquence pratique à ne pas oublier** : tout fichier CSV exporté par une version antérieure
à `0d2cdd9` porte des valeurs multiples jointes par `/`. Réimporté aujourd'hui, il rendra **une
seule valeur** contenant des barres obliques au lieu de plusieurs. Aucun fichier de ce genre
n'existe dans le dépôt ; s'il en existe un sur l'autre machine, il est à convertir à la main.

### 2. Ce qui a été relancé après le changement de format — tout, finalement

Le rapport de session annonçait six cibles « non relancées ». **Elles l'ont été à la clôture, et
elles sont toutes vertes** :

| Cible | Résultat |
|---|---|
| `swift test` CineShelfCore | ✅ 566 |
| `swift test` DesignSystem | ✅ 85 |
| `swift test` MediaKit | ✅ 64 |
| `xcodebuild test -scheme CineShelf -destination macOS` | ✅ 121 |
| `xcodebuild test -scheme CineShelfScreenTests -destination macOS` | ✅ 11 |
| `xcodebuild test -scheme DesignSystemCatalog` · macOS et iOS | ✅ 86 et 85 |
| `xcodebuild build -scheme CineShelf` · macOS et iOS | ✅ |
| `xcodebuild test -scheme CineShelfUITests` · macOS et iOS | ✅ 1 et 1 |
| `swiftlint --strict` | ✅ 0 / 335 |
| `xcrun swift-format lint` | ✅ 0 |

Le format touche aussi l'archive (`ArchiveWriter` / `ArchiveRestorer` passent par
`joinMultiValue`), donc la suite de Core couvre l'essentiel — mais les autres cibles ne se
déduisaient pas, et c'est pour ça qu'elles ont été jouées.

### 3. Ce qui reste, nommément

- **`11f` — la correction en masse depuis l'aperçu** n'existe pas. L'aperçu affiche « à corriger
  dans le fichier » à côté de chaque cause. `ImportCorrection` existe côté cœur ; c'est du
  travail d'écran.
- **`11g` — l'abandon avec reprise de brouillon** n'existe pas. « Abandonner » remet à zéro.
  `ImportDraftStore` existe côté cœur.
- **L'échec bruyant du séparateur n'est pas en place.** C'est le point le plus important des
  trois : le format a été *rendu plus sûr*, il n'a pas été rendu **sûr**. Une valeur qui
  contient une barre verticale se coupe toujours en silence — `MultiValueRoundTripTests` le
  documente au lieu de le corriger. Ce qu'il faudrait : à l'**export**, refuser ou échapper une
  valeur contenant le séparateur, et le **dire** ; à l'**import**, aucune détection n'est
  possible, donc c'est l'export qui doit garantir l'invariant. Tant que ce n'est pas fait, la
  garantie repose sur « aucun nom de genre ne porte de barre verticale », qui est une
  probabilité, pas une invariante.
- **La porte de rendu de la console est abandonnée** — fermée sans solution, décision explicite.
  `ImageRenderer` ne capture pas AppKit, et l'arbre d'accessibilité reste vide même
  l'autorisation accordée. Deux écrans sur dix-neuf ne sont pas couverts par une porte
  automatique.

### État du palier 3

Reste **`L16`** (maintenance et corbeille, rigueur maximale), **`V10`** (synchronisation),
**`V12`** (accessibilité), plus les deux jalons de `V8` ci-dessus et la reprise de `V6` en 🔶.
