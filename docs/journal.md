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
