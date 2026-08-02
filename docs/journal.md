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
