# CineShelf — Modèle de données SwiftData + CloudKit

> **Destinataire : Claude Code.** Remplace `02-BASE-DE-DONNEES.md` (version SQLite). Cible : SwiftData avec miroir CloudKit sur la base **privée**.

---

## 1. Les règles imposées par CloudKit

Avant tout code, les contraintes du miroir SwiftData ↔ CloudKit. Elles ne se contournent pas ; elles se conçoivent.

| Règle | Conséquence |
|---|---|
| **Toute propriété doit avoir une valeur par défaut ou être optionnelle** | Pas de `let` non initialisé, pas de `var x: String` sans `= ""` |
| **`@Attribute(.unique)` est interdit** | Le dédoublonnage (genres, personnes, médias) est **applicatif** |
| **Toutes les relations doivent être optionnelles** | `var titles: [Title]?`, jamais `[Title]` |
| **Chaque relation doit avoir un inverse déclaré** | `@Relationship(inverse:)` d'un seul côté |
| **Règle de suppression `.deny` non supportée** | Seulement `.cascade` et `.nullify` |
| **Aucune contrainte `CHECK`** | Validation dans le modèle Swift + tests |
| **Aucune colonne calculée persistée** | `sortTitle`, `searchText` maintenus **à l'écriture** |
| **Aucun index full-text** | Recherche locale par prédicat, sur un champ dénormalisé |
| **Aucune logique serveur** | Suggestions, doublons, aperçus de liens : sur l'appareil |
| **Cohérence à terme** | L'UI doit tolérer un état pas encore synchronisé |
| **Base privée = quota iCloud de l'utilisateur** | Ne jamais synchroniser ce qui est reconstructible |

Ce que ça **supprime** par rapport à la version web : `users`, `sessions`, mots de passe, JWT, `owner_id` partout, toute la logique de visibilité par propriétaire, CORS, rate limiting, les 13 correctifs de sécurité. La base privée est par construction mono-utilisateur.

---

## 2. Décisions de modélisation

### 2.1 `actors` + `social_profiles` → une seule entité `Person`

Les deux tables étaient identiques et liées 1:1, ce qui générait ~2 600 lignes de code de fusion. Une `Person` porte désormais des **rôles** (`actor`, `social`, `director`…) et une liste de **comptes sociaux**. Lier un profil social à un acteur = ajouter un rôle. La page « fusion acteur ↔ social » disparaît ; il ne reste que la déduplication de personnes, qui reste utile.

### 2.2 Profils **et** bibliothèques — deux notions distinctes

Un seul compte Apple, mais plusieurs **profils**, façon Netflix. Deux concepts séparés, et c'est la séparation qui rend le modèle souple :

| Concept | Ce que c'est | Exemple |
|---|---|---|
| **`Library`** | Un **catalogue** : des titres, des personnes, des collections, des genres | « Catalogue principal », « Bac à sable » |
| **`Profile`** | Une **personne qui consulte** : nom, avatar, ses listes, ses préférences | « Cyril », « Invité », « Kids » |

Un `Profile` pointe vers exactement une `Library`. Ce simple lien couvre les deux usages :

```
Library « Principal » ──┬── Profile « Cyril »       ┐ même catalogue,
                        └── Profile « Invité »      ┘ listes séparées

Library « Bac à sable » ─── Profile « Test »          catalogue isolé
```

- **Deux profils sur la même bibliothèque** = modèle Netflix. Le catalogue est commun, mais chacun a sa watchlist, ses favoris, ses films vus, ses notes perso et ses préférences d'affichage.
- **Un profil sur sa propre bibliothèque** = l'ancien « profil lié / bac à sable » de la version web, avec isolation totale des données.

Le transfert d'entités entre bibliothèques (fonctionnalité v1) reste : c'est un changement de la relation `library`.

> Si tu veux un jour **partager** une bibliothèque avec une autre personne, sur *son* compte iCloud, c'est `CKShare`. Le support du partage côté SwiftData a évolué récemment — à vérifier dans la doc Apple courante avant de t'engager ; `NSPersistentCloudKitContainer` reste la voie la plus établie. Ce n'est pas nécessaire pour la v1, et le système de profils ci-dessus n'en dépend pas.

### 2.3 Favoris / watchlist → rattachés au profil

> ⚠️ **Correction par rapport à une version antérieure de ce document.** J'avais mis `isFavorite`, `isInWatchlist`, `isWatched` et `personalRating` directement sur `Title` et `Person`, en supposant un utilisateur unique. Avec plusieurs profils, c'est faux : la watchlist de Cyril n'est pas celle d'Invité.

Ces états reviennent donc dans des entités de liaison, une par type d'entité concernée :

```
TitleFlag  (profile ↔ title)   favori · watchlist · vu · date de visionnage · note perso
PersonFlag (profile ↔ person)  favori
MediaFlag  (profile ↔ media)   favori de galerie
```

C'est exactement ce que faisaient `user_movie_watchlist`, `user_movie_favorites`, `user_actor_favorites` et `user_social_favorites` en v1 — sauf que la clé n'est plus un compte, c'est un profil. Trois entités typées plutôt qu'une table polymorphe : on garde l'intégrité référentielle et les prédicats restent simples.

Ce qui **reste** sur l'entité elle-même, parce que ça décrit l'objet et non un point de vue : `rating` (la note du catalogue), `isPrivate`, `isArchived`, `deletedAt`.

### 2.3 bis Verrouillage biométrique

Trois niveaux, indépendants, décrits en détail au §9 :

1. **L'app entière** — Face ID / Touch ID à l'ouverture. Réglage local, pas dans le modèle.
2. **Un profil** — `Profile.requiresBiometry`. Le profil « Cyril » demande Face ID, le profil « Invité » non.
3. **Le contenu privé** — les entités `isPrivate` restent floutées tant qu'on n'a pas déverrouillé, même dans un profil déjà ouvert. Réutilise le flag qui existe déjà partout dans ton schéma v1.

### 2.4 Recadrages → entité `MediaCrop`

Les 21 colonnes `*_position_x/_y/_zoom` deviennent des enregistrements `(asset, context, x, y, zoom)`. Résolution : contexte demandé → `default` → `(50, 50, 100)`.

### 2.5 Médias — ne jamais synchroniser les dérivés

Décision opposée à la version web. En base privée, chaque octet compte sur le quota iCloud de l'utilisateur :

- **Synchronisé** : l'original, en `@Attribute(.externalStorage) var data: Data?` → mappé en `CKAsset`.
- **Local uniquement** : les vignettes, générées à la demande par `ImageIO` et mises en cache sur disque, jamais dans le modèle.
- **Dans le modèle mais minuscule** : `blurHash` (~30 octets) et `pixelWidth/Height`, pour l'affichage instantané sans saut de mise en page.

---

## 3. Le modèle

### 3.1 Énumérations

```swift
import Foundation

public enum TitleKind: String, Codable, CaseIterable, Sendable {
    case movie, series, documentary, short, other
}

public enum DatePrecision: String, Codable, CaseIterable, Sendable {
    case year, month, day
}

public enum PersonRole: String, Codable, CaseIterable, Sendable {
    case actor, social, director, writer, crew
}

public enum CreditRole: String, Codable, CaseIterable, Sendable {
    case cast, director, writer, producer, composer, crew
}

public enum GenreTarget: String, Codable, CaseIterable, Sendable {
    case title, person, savedLink, collection
}

public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case image, video, embed
}

public enum MediaSlot: String, Codable, CaseIterable, Sendable {
    case primary, portrait, backdrop, gallery
}

public enum CropContext: String, Codable, CaseIterable, Sendable {
    case standard, card, list, hero, side, detail, coverCard, coverHero, avatar
}

public enum SavedLinkKind: String, Codable, CaseIterable, Sendable {
    case website, video, article, store, social, other
}
```

> Motif employé partout : la propriété **persistée** est le `rawValue` (`String`), l'énumération est exposée en propriété calculée. C'est ce qui rend les `#Predicate` fiables et évite les surprises de miroir CloudKit.

### 3.2 Bibliothèque

```swift
import SwiftData

@Model
public final class Library {
    public var id: UUID = UUID()
    public var name: String = "Ma bibliothèque"
    public var isDefault: Bool = false
    public var isSandbox: Bool = false
    public var sortIndex: Int = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Title.library)
    public var titles: [Title]? = []
    @Relationship(deleteRule: .cascade, inverse: \Person.library)
    public var people: [Person]? = []
    @Relationship(deleteRule: .cascade, inverse: \TitleCollection.library)
    public var collections: [TitleCollection]? = []
    @Relationship(deleteRule: .cascade, inverse: \Genre.library)
    public var genres: [Genre]? = []
    @Relationship(deleteRule: .cascade, inverse: \SavedLink.library)
    public var savedLinks: [SavedLink]? = []

    @Relationship(deleteRule: .nullify, inverse: \Profile.library)
    public var profiles: [Profile]? = []

    public init(name: String = "Ma bibliothèque", isDefault: Bool = false) {
        self.name = name
        self.isDefault = isDefault
    }
}
```

### 3.2 bis Profil

```swift
@Model
public final class Profile {
    public var id: UUID = UUID()
    public var name: String = ""
    public var avatarSymbol: String = "person.crop.circle"   // SF Symbol
    public var avatarEmoji: String?                          // alternative
    public var accentToken: String = "accent/solid"          // jeton, jamais un hex
    public var isDefault: Bool = false
    public var sortIndex: Int = 0

    /// Ce profil exige Face ID / Touch ID pour être ouvert.
    public var requiresBiometry: Bool = false
    /// Ce profil ne voit jamais les entités marquées privées.
    public var hidesPrivateContent: Bool = false

    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    /// Le catalogue que ce profil consulte.
    /// Deux profils sur la même Library = modèle Netflix.
    public var library: Library?

    @Relationship(deleteRule: .cascade, inverse: \TitleFlag.profile)
    public var titleFlags: [TitleFlag]? = []
    @Relationship(deleteRule: .cascade, inverse: \PersonFlag.profile)
    public var personFlags: [PersonFlag]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaFlag.profile)
    public var mediaFlags: [MediaFlag]? = []

    public init(name: String = "", isDefault: Bool = false) {
        self.name = name
        self.isDefault = isDefault
    }
}
```

### 3.2 ter États par profil

```swift
@Model
public final class TitleFlag {
    public var id: UUID = UUID()
    public var isFavorite: Bool = false
    public var isInWatchlist: Bool = false
    public var isWatched: Bool = false
    public var watchedAt: Date?
    public var personalRating: Double?        // note du profil, ≠ Title.rating
    public var updatedAt: Date = Date()

    public var profile: Profile?
    public var title: Title?

    public init() {}

    /// Vrai si l'objet ne porte plus aucune information : à supprimer.
    public var isEmpty: Bool {
        !isFavorite && !isInWatchlist && !isWatched && personalRating == nil
    }
}

@Model
public final class PersonFlag {
    public var id: UUID = UUID()
    public var isFavorite: Bool = false
    public var updatedAt: Date = Date()
    public var profile: Profile?
    public var person: Person?
    public init() {}
    public var isEmpty: Bool { !isFavorite }
}

@Model
public final class MediaFlag {
    public var id: UUID = UUID()
    public var isFavorite: Bool = false
    public var updatedAt: Date = Date()
    public var profile: Profile?
    public var asset: MediaAsset?
    public init() {}
    public var isEmpty: Bool { !isFavorite }
}
```

**Règle d'hygiène** : un flag repassé à `isEmpty` est supprimé, sinon la base se remplit d'enregistrements vides et le quota iCloud avec. Le repository s'en charge :

```swift
@MainActor
public struct FlagRepository {
    let context: ModelContext
    let profile: Profile

    public func flag(for title: Title, createIfNeeded: Bool = false) -> TitleFlag? {
        if let existing = title.flags?.first(where: { $0.profile?.id == profile.id }) {
            return existing
        }
        guard createIfNeeded else { return nil }
        let f = TitleFlag()
        f.profile = profile
        f.title = title
        context.insert(f)
        return f
    }

    public func toggleFavorite(_ title: Title) {
        guard let f = flag(for: title, createIfNeeded: true) else { return }
        f.isFavorite.toggle()
        f.updatedAt = .now
        if f.isEmpty { context.delete(f) }
    }
}
```

Requête « la watchlist du profil courant » :

```swift
let pid = profile.id
var d = FetchDescriptor<TitleFlag>(
    predicate: #Predicate { $0.isInWatchlist && $0.profile?.id == pid },
    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
)
```

### 3.3 Titre (films **et** séries)

```swift
@Model
public final class Title {
    public var id: UUID = UUID()

    // Identité
    public var kindRaw: String = TitleKind.movie.rawValue
    public var name: String = ""
    public var originalName: String?
    public var sortName: String = ""          // maintenu à l'écriture
    public var summary: String?

    // Sortie
    public var releaseDate: Date?
    public var releasePrecisionRaw: String = DatePrecision.day.rawValue

    // Durée
    public var runtimeMinutes: Int?
    public var seasonCount: Int?
    public var episodeCount: Int?

    // Évaluation
    public var rating: Double?                // note du catalogue, 0–10
                                              // la note perso est dans TitleFlag

    // Visibilité
    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    public var deletedAt: Date?               // corbeille

    // Recherche
    public var searchText: String = ""        // maintenu à l'écriture

    // Horodatage
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    // Relations
    public var library: Library?
    public var collection: TitleCollection?
    @Relationship(inverse: \Genre.titles)
    public var genres: [Genre]? = []
    @Relationship(deleteRule: .cascade, inverse: \Credit.title)
    public var credits: [Credit]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.title)
    public var attachments: [MediaAttachment]? = []
    @Relationship(deleteRule: .cascade, inverse: \ResourceLink.title)
    public var links: [ResourceLink]? = []
    @Relationship(deleteRule: .cascade, inverse: \TitleFlag.title)
    public var flags: [TitleFlag]? = []       // un par profil, créé à la demande

    public init(name: String = "", kind: TitleKind = .movie) {
        self.name = name
        self.kindRaw = kind.rawValue
        refreshDerived()
    }
}

public extension Title {
    var kind: TitleKind {
        get { TitleKind(rawValue: kindRaw) ?? .movie }
        set { kindRaw = newValue.rawValue }
    }
    var releasePrecision: DatePrecision {
        get { DatePrecision(rawValue: releasePrecisionRaw) ?? .day }
        set { releasePrecisionRaw = newValue.rawValue }
    }
    var releaseYear: Int? {
        releaseDate.map { Calendar.current.component(.year, from: $0) }
    }

    /// À appeler dans chaque `didSet` métier et avant chaque `save`.
    func refreshDerived() {
        sortName = name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        searchText = [name, originalName, summary]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        updatedAt = .now
    }
}
```

### 3.4 Personne

```swift
@Model
public final class Person {
    public var id: UUID = UUID()

    public var firstName: String = ""
    public var lastName: String = ""
    public var displayName: String = ""       // maintenu
    public var sortName: String = ""          // maintenu
    public var birthDate: Date?
    public var deathDate: Date?
    public var bio: String?

    /// Rôles portés par cette personne. Fusionne les anciennes tables
    /// `actors` et `social_profiles`.
    public var roleValues: [String] = [PersonRole.actor.rawValue]

    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    public var deletedAt: Date?
    public var searchText: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var library: Library?
    @Relationship(deleteRule: .cascade, inverse: \PersonFlag.person)
    public var flags: [PersonFlag]? = []
    @Relationship(deleteRule: .cascade, inverse: \SocialHandle.person)
    public var handles: [SocialHandle]? = []
    @Relationship(inverse: \Genre.people)
    public var genres: [Genre]? = []
    @Relationship(inverse: \Credit.person)
    public var credits: [Credit]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.person)
    public var attachments: [MediaAttachment]? = []
    @Relationship(deleteRule: .cascade, inverse: \ResourceLink.person)
    public var links: [ResourceLink]? = []

    public init(firstName: String = "", lastName: String = "") {
        self.firstName = firstName
        self.lastName = lastName
        refreshDerived()
    }
}

public extension Person {
    var roles: Set<PersonRole> {
        get { Set(roleValues.compactMap(PersonRole.init(rawValue:))) }
        set { roleValues = newValue.map(\.rawValue).sorted() }
    }
    var isActor: Bool { roleValues.contains(PersonRole.actor.rawValue) }
    var isSocial: Bool { roleValues.contains(PersonRole.social.rawValue) }

    var age: Int? {
        guard let birthDate else { return nil }
        let end = deathDate ?? .now
        return Calendar.current.dateComponents([.year], from: birthDate, to: end).year
    }

    func refreshDerived() {
        displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        sortName = "\(lastName) \(firstName)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
        searchText = [displayName, bio]
            .compactMap { $0 }.joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        updatedAt = .now
    }
}

@Model
public final class SocialHandle {
    public var id: UUID = UUID()
    public var platform: String = ""          // instagram, x, tiktok…
    public var handle: String = ""
    public var urlString: String?
    public var createdAt: Date = Date()
    public var person: Person?

    public init(platform: String = "", handle: String = "") {
        self.platform = platform
        self.handle = handle
    }
}
```

### 3.5 Collection & genre

```swift
@Model
public final class TitleCollection {
    public var id: UUID = UUID()
    public var name: String = ""
    public var sortName: String = ""
    public var summary: String?
    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    public var deletedAt: Date?
    public var searchText: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var library: Library?
    @Relationship(inverse: \Title.collection)
    public var titles: [Title]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.collection)
    public var attachments: [MediaAttachment]? = []
    @Relationship(deleteRule: .cascade, inverse: \ResourceLink.collection)
    public var links: [ResourceLink]? = []

    public init(name: String = "") { self.name = name }
}

@Model
public final class Genre {
    public var id: UUID = UUID()
    public var name: String = ""
    public var nameKey: String = ""           // clé de dédoublonnage applicatif
    public var targetRaw: String = GenreTarget.title.rawValue
    public var colorToken: String?            // nom d'un jeu du catalogue, pas un hex
    public var isPinned: Bool = false
    public var pinIndex: Int = 0
    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var library: Library?
    public var titles: [Title]? = []
    public var people: [Person]? = []
    @Relationship(inverse: \SavedLink.genre)
    public var savedLinks: [SavedLink]? = []

    public init(name: String = "", target: GenreTarget = .title) {
        self.name = name
        self.targetRaw = target.rawValue
        self.nameKey = Genre.key(for: name)
    }

    public static func key(for name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

> **Unicité** : CloudKit l'interdit. Passer par un `GenreRepository.findOrCreate(name:target:in:)` qui cherche sur `nameKey` avant d'insérer, et un job de fusion des doublons apparus par sync concurrente (deux appareils créant « Action » en même temps).

### 3.6 Casting

```swift
@Model
public final class Credit {
    public var id: UUID = UUID()
    public var roleRaw: String = CreditRole.cast.rawValue
    public var characterName: String?
    public var orderIndex: Int = 0
    public var createdAt: Date = Date()

    public var title: Title?
    public var person: Person?

    public init(role: CreditRole = .cast, characterName: String? = nil, orderIndex: Int = 0) {
        self.roleRaw = role.rawValue
        self.characterName = characterName
        self.orderIndex = orderIndex
    }
}
```

### 3.7 Médias

```swift
@Model
public final class MediaAsset {
    public var id: UUID = UUID()
    public var kindRaw: String = MediaKind.image.rawValue

    /// Original. `.externalStorage` → mappé en CKAsset par le miroir CloudKit.
    @Attribute(.externalStorage) public var data: Data?
    /// Alternative : média hébergé ailleurs (ancien `medias.url` en http).
    public var externalURLString: String?

    public var mimeType: String?
    public var pixelWidth: Int = 0
    public var pixelHeight: Int = 0
    public var byteSize: Int = 0
    public var blurHash: String?              // ~30 octets, affichage instantané
    public var checksum: String = ""          // dédoublonnage applicatif

    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    public var deletedAt: Date?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \MediaFlag.asset)
    public var flags: [MediaFlag]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaCrop.asset)
    public var crops: [MediaCrop]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.asset)
    public var attachments: [MediaAttachment]? = []

    public init(kind: MediaKind = .image) { self.kindRaw = kind.rawValue }
}

/// Rattachement d'un média à exactement une entité.
/// L'exclusivité était un CHECK SQL ; elle devient une invariante Swift.
@Model
public final class MediaAttachment {
    public var id: UUID = UUID()
    public var slotRaw: String = MediaSlot.gallery.rawValue
    public var orderIndex: Int = 0
    public var createdAt: Date = Date()

    public var asset: MediaAsset?
    public var title: Title?
    public var person: Person?
    public var collection: TitleCollection?

    public init(slot: MediaSlot = .gallery, orderIndex: Int = 0) {
        self.slotRaw = slot.rawValue
        self.orderIndex = orderIndex
    }

    /// Invariante : exactement un parent. Vérifiée en test et avant chaque save.
    public var hasExactlyOneOwner: Bool {
        [title != nil, person != nil, collection != nil].filter { $0 }.count == 1
    }
}

@Model
public final class MediaCrop {
    public var id: UUID = UUID()
    public var contextRaw: String = CropContext.standard.rawValue
    public var positionX: Double = 50         // 0–100
    public var positionY: Double = 50
    public var zoom: Double = 100             // 50–400
    public var updatedAt: Date = Date()

    public var asset: MediaAsset?

    public init(context: CropContext = .standard) { self.contextRaw = context.rawValue }
}

public extension MediaAsset {
    /// Reprend la sémantique v1 : contexte demandé → défaut → neutre.
    func crop(for context: CropContext) -> (x: Double, y: Double, zoom: Double) {
        let all = crops ?? []
        if let c = all.first(where: { $0.contextRaw == context.rawValue }) {
            return (c.positionX, c.positionY, c.zoom)
        }
        if let d = all.first(where: { $0.contextRaw == CropContext.standard.rawValue }) {
            return (d.positionX, d.positionY, d.zoom)
        }
        return (50, 50, 100)
    }
}
```

> **Correction du 2026-08-02.** `TitleCollection.links` manquait ici, alors que
> `ResourceLink.collection` existait déjà en §3.8 : la relation n'avait donc pas
> d'inverse et le miroir CloudKit refusait le schéma entier. `CloudKitConformanceTests`
> l'a relevé au premier lancement, avec le nom de la relation fautive. Le côté
> manquant est désormais déclaré ci-dessus, symétrique de `Title.links` et
> `Person.links`. C'était le **seul** cas du modèle : les 16 autres entités et
> toutes leurs autres relations passent la conformité sans retouche.

### 3.8 Liens

```swift
@Model
public final class ResourceLink {          // lien attaché à une entité
    public var id: UUID = UUID()
    public var urlString: String = ""
    public var label: String?
    public var summary: String?
    public var faviconData: Data?
    public var orderIndex: Int = 0
    public var isArchived: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var title: Title?
    public var person: Person?
    public var collection: TitleCollection?

    public init(urlString: String = "") { self.urlString = urlString }
}

@Model
public final class SavedLink {             // signet autonome
    public var id: UUID = UUID()
    public var urlString: String = ""
    public var name: String?
    public var notes: String?
    public var faviconData: Data?
    public var kindRaw: String = SavedLinkKind.website.rawValue
    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    public var deletedAt: Date?
    public var searchText: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var library: Library?
    public var genre: Genre?

    public init(urlString: String = "") { self.urlString = urlString }
}
```

### 3.9 Journal d'activité

```swift
@Model
public final class ActivityEntry {
    public var id: UUID = UUID()
    public var actionRaw: String = ""         // create, update, delete, merge, import…
    public var entityTypeRaw: String = ""
    public var entityID: UUID = UUID()
    public var summary: String = ""
    public var createdAt: Date = Date()

    public init() {}
}
```

Alimente l'écran « Fil » (aujourd'hui reconstruit à la volée par tri sur `created_at`) et donne une piste d'audit pour les fusions et imports.

### 3.10 Préférences d'affichage

Elles ne concernent qu'un appareil et un utilisateur : **hors du modèle CloudKit**, dans `@AppStorage` ou un petit store local. Une clé par contexte (`movies`, `actors`, `home_movies`…) contenant `{layout, size, pageSize, sort, dir}`.

Exception : si tu veux que les préférences suivent l'utilisateur d'un appareil à l'autre, utilise `NSUbiquitousKeyValueStore` — c'est fait pour ça et ça ne pollue pas le modèle.

---

## 4. Conteneur

```swift
import SwiftData

@MainActor
public enum Persistence {
    public static func makeContainer(cloudKit: Bool) throws -> ModelContainer {
        let schema = Schema([
            Library.self, Profile.self,
            TitleFlag.self, PersonFlag.self, MediaFlag.self,
            Title.self, Person.self, SocialHandle.self,
            TitleCollection.self, Genre.self, Credit.self,
            MediaAsset.self, MediaAttachment.self, MediaCrop.self,
            ResourceLink.self, SavedLink.self, ActivityEntry.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKit ? .private("iCloud.fr.feltrin.CineShelf") : .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

> **Avant l'abonnement Apple Developer** : lance avec `cloudKit: false`. Le modèle est déjà écrit sous les contraintes CloudKit, donc l'activation se fera en changeant un booléen et en ajoutant l'entitlement. C'est le point clé : **concevoir sous contrainte dès maintenant** évite une deuxième migration.

---

## 5. Recherche sans FTS5

Pas de FTS5. Trois niveaux, du plus simple au plus coûteux :

**Niveau 1 — prédicat direct** (suffisant jusqu'à quelques milliers d'entrées) :

```swift
func searchTitles(_ query: String, in context: ModelContext) throws -> [Title] {
    let key = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    var d = FetchDescriptor<Title>(
        predicate: #Predicate { $0.deletedAt == nil && $0.searchText.contains(key) },
        sortBy: [SortDescriptor(\.sortName)]
    )
    d.fetchLimit = 100
    return try context.fetch(d)
}
```

Le champ `searchText` est dénormalisé et **déjà replié** (sans accents, en minuscules) à l'écriture. C'est ce qui remplace `unicode61 remove_diacritics 2`.

**Niveau 2 — Spotlight.** Indexer chaque titre et chaque personne dans `CoreSpotlight` (`CSSearchableItem`). Bénéfice : recherche depuis l'écran d'accueil iOS et Spotlight macOS, en plus de la recherche interne. Gratuit en termes d'effort, très « natif ».

**Niveau 3 — index FTS local**, seulement si le catalogue dépasse ~20 000 entrées : une base SQLite annexe **non synchronisée**, reconstruite localement, avec FTS5. À ne faire que si le niveau 1 devient lent, mesures à l'appui.

---

## 6. Ce qui remplace chaque objet SQL

| Version web | Version native |
|---|---|
| `users`, `sessions`, `password_hash` | ⛔ supprimé — compte iCloud |
| `owner_id` sur chaque table | ⛔ supprimé — base privée |
| profils liés / sandbox | `Library` (catalogue) + `Profile` (personne) |
| `movies` | `Title` (+ `kind`) |
| `movies.duration_kind='series'` | `Title.kind == .series` |
| 21 colonnes `*_position_x/y/zoom` | `MediaCrop` |
| `actors` + `social_profiles` | `Person` + `roleValues` + `SocialHandle` |
| `movie_actor` | `Credit` |
| `movie_genre`, `actor_genre` | relations SwiftData |
| `medias` (4 FK nullables) | `MediaAsset` + `MediaAttachment` |
| `medias.is_main` | `MediaAttachment.slot == .primary` |
| `media_variants` | ⛔ non synchronisé — cache local |
| `is_private` | `isPrivate` |
| `is_hidden` | `isArchived` |
| `user_movie_favorites`, `user_movie_watchlist` | `TitleFlag` (par profil) |
| `user_actor_favorites`, `user_social_favorites` | `PersonFlag` (par profil) |
| favoris de galerie | `MediaFlag` (par profil) |
| ⛔ (n'existait pas) | `Profile.requiresBiometry` — verrouillage Face ID |
| `movies_fts`, `actors_fts` | `searchText` + prédicat + CoreSpotlight |
| `activity` (reconstruit) | `ActivityEntry` |
| `users.display_prefs` | `@AppStorage` / `NSUbiquitousKeyValueStore` |
| index SQL | index SwiftData implicites + `#Index` où mesuré utile |

---

## 7. Migration depuis l'app web

Le web est retiré, donc **une seule passe, un seul sens**.

### Étape 1 — Dump final depuis le serveur Express

Un dernier script Node dans l'app actuelle, `export-native-bundle.mjs`, qui produit un dossier :

```
CineShelfExport/
├── manifest.json          { schemaVersion: 1, exportedAt, counts: {...} }
├── titles.json            tous les champs, y compris les 9 colonnes de recadrage
├── people.json            actors + social_profiles, avec le lien actor_id
├── collections.json
├── genres.json
├── credits.json
├── links.json  saved_links.json
├── flags.json             watchlist + favoris à plat
└── media/
    ├── index.json         { id, ownerType, ownerId, slot, isMain, crops, sha256, file }
    └── files/<id>.<ext>   les originaux, décodés depuis data-URL / disque / R2
```

Le script doit **résoudre les data-URL et télécharger les médias R2**, pour que le dossier soit autonome. Vérifier les compteurs du `manifest` avant de continuer.

### Étape 2 — Importeur natif, à usage unique

Un écran caché (ou une commande `⇧⌘⌥I`) qui prend le dossier via `.fileImporter` et insère dans cet ordre :

1. `Library` par défaut **et** `Profile` par défaut pointant dessus
2. `Genre` (dédoublonnés sur `nameKey`)
3. `TitleCollection`
4. `Title` (`kind` déduit de `duration_kind`)
5. `Person` — **fusion ici** : si un `social_profile` a un `actor_id`, il alimente la même `Person` avec le rôle `.social` en plus ; sinon nouvelle `Person`
6. `SocialHandle`
7. `Credit` depuis `movie_actor`
8. Relations genres
9. `MediaAsset` (avec `checksum`, `blurHash` et dimensions calculés à l'import), puis `MediaAttachment`, puis `MediaCrop` depuis les 21 colonnes
10. `ResourceLink`, `SavedLink`
11. Flags personnels → `TitleFlag` / `PersonFlag` / `MediaFlag` rattachés au profil par défaut
12. Réindexation Spotlight

Import **par lots** avec `try context.save()` tous les 200 objets, barre de progression, reprise possible.

### Étape 3 — Vérification

```
✔ nombre de Title            == manifest.counts.movies
✔ nombre de Person           == actors + social_profiles sans actor_id
✔ nombre de Credit           == movie_actor
✔ nombre de MediaAsset       == fichiers dans media/files
✔ tout MediaAttachment a exactement un parent
✔ nombre de MediaCrop        == triplets non nuls du dump
✔ nombre de TitleFlag        == watchlist + favoris films du dump (dédoublonnés)
✔ nombre de PersonFlag       == favoris acteurs + favoris social
✔ aucun média orphelin, aucune relation cassée
✔ échantillon de 50 titres comparé champ à champ
```

### Étape 4 — Bascule CloudKit

Une fois l'import validé **en local**, activer l'entitlement iCloud et relancer avec `cloudKit: true`. Le premier envoi peut être long (tous les originaux partent en `CKAsset`) : le faire en Wi-Fi, sur secteur, et afficher un état de progression honnête.

Garder le dossier `CineShelfExport/` archivé indéfiniment. C'est ton unique filet.

---

## 8. Points de vigilance

| Sujet | À faire |
|---|---|
| Doublons par sync concurrente | Deux appareils peuvent créer le même genre hors ligne. Prévoir une passe de fusion sur `nameKey` au démarrage. |
| Quota iCloud | Un catalogue de 3 000 jaquettes en 300 Ko = ~900 Mo du quota de l'utilisateur. L'afficher dans les réglages, et proposer une compression HEIC à l'import. |
| Premier chargement | Sur un nouvel appareil, CloudKit rapatrie progressivement. L'UI doit fonctionner à moitié peuplée sans paraître cassée. |
| Suppressions | `deletedAt` (corbeille) plutôt que `context.delete`, avec purge à 30 jours. Une suppression synchronisée est irréversible. |
| Migrations de schéma | `VersionedSchema` + `SchemaMigrationPlan` dès la v1, même si le plan est vide. Ajouter une propriété après publication sans plan de migration casse les installations. |
| Grosses images | Redimensionner à 2 000 px max et ré-encoder en HEIC à l'import. Un original de 8 Mo n'apporte rien à un catalogue. |
| Tests | Tests unitaires sur un `ModelContainer` en mémoire (`isStoredInMemoryOnly: true`), y compris un test qui échoue si une relation devient non optionnelle. |

---

## 9. Verrouillage biométrique (Face ID / Touch ID)

### 9.1 Trois niveaux indépendants

| Niveau | Portée | Où c'est stocké |
|---|---|---|
| **App** | Toute l'app à l'ouverture et après mise en arrière-plan | `@AppStorage` — réglage local, propre à l'appareil |
| **Profil** | Un profil donné exige une authentification pour être ouvert | `Profile.requiresBiometry` — synchronisé |
| **Contenu privé** | Les entités `isPrivate` restent floutées tant qu'on n'a pas déverrouillé, même dans un profil déjà ouvert | `isPrivate` (existe déjà) + `Profile.hidesPrivateContent` |

Le niveau 1 est un réglage d'appareil : verrouiller sur ton Mac de bureau n'a pas le même sens que sur ton iPhone. Les niveaux 2 et 3 décrivent le profil, donc ils suivent l'utilisateur d'un appareil à l'autre.

### 9.2 Service d'authentification

```swift
import LocalAuthentication

public enum BiometryKind { case faceID, touchID, opticID, none }

public enum AuthError: Error, Equatable {
    case cancelled          // l'utilisateur a annulé
    case unavailable        // pas de biométrie ni de code sur l'appareil
    case lockedOut          // trop d'échecs, code requis
    case failed(String)
}

@MainActor
@Observable
public final class AppLock {
    public private(set) var isUnlocked = false
    public private(set) var biometry: BiometryKind = .none

    public func refreshCapability() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            biometry = .none; return
        }
        biometry = switch ctx.biometryType {
        case .faceID:  .faceID
        case .touchID: .touchID
        case .opticID: .opticID
        default:       .none
        }
    }

    /// `.deviceOwnerAuthentication` et non `...WithBiometrics` : le repli sur
    /// le code de l'appareil est automatique, donc jamais d'utilisateur bloqué
    /// parce qu'il porte un masque ou a les mains mouillées.
    public func authenticate(reason: String) async throws {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Annuler"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            throw AuthError.unavailable
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication,
                                                  localizedReason: reason)
            guard ok else { throw AuthError.failed("Authentification refusée") }
            isUnlocked = true
        } catch let e as LAError {
            switch e.code {
            case .userCancel, .appCancel, .systemCancel: throw AuthError.cancelled
            case .biometryLockout:                       throw AuthError.lockedOut
            default: throw AuthError.failed(e.localizedDescription)
            }
        }
    }

    public func lock() { isUnlocked = false }
}
```

### 9.3 Reverrouillage et écran de confidentialité

```swift
@Environment(\.scenePhase) private var scenePhase
@AppStorage("lock.enabled")     private var lockEnabled = false
@AppStorage("lock.graceSeconds") private var graceSeconds = 60
@State private var backgroundedAt: Date?

.onChange(of: scenePhase) { _, phase in
    switch phase {
    case .inactive:
        showPrivacyCover = lockEnabled          // masque l'aperçu du sélecteur d'apps
    case .background:
        backgroundedAt = .now
    case .active:
        showPrivacyCover = false
        if lockEnabled, let t = backgroundedAt,
           Date().timeIntervalSince(t) > Double(graceSeconds) {
            appLock.lock()
        }
    @unknown default: break
    }
}
```

L'**écran de confidentialité** est le détail qu'on oublie : sans lui, la vignette de l'app dans le sélecteur iOS montre ton catalogue en clair. Une vue opaque affichée dès `.inactive` règle le problème.

Délai de grâce configurable : immédiat · 1 min · 5 min · 15 min. Sans délai, l'app redemande Face ID chaque fois que tu changes d'app deux secondes, et le réglage finit désactivé.

### 9.4 Ce que ça protège — et ce que ça ne protège pas

> C'est un **verrou d'interface**, pas du chiffrement. Le magasin SwiftData sur disque est protégé par la protection de fichiers du système (donc par le code de l'appareil), mais pas par Face ID en particulier. Quelqu'un qui a ton appareil déverrouillé et un accès au système de fichiers peut lire la base.

Pour un catalogue de films personnel, c'est très largement suffisant : ça empêche quelqu'un qui prend ton téléphone posé sur la table de fouiller dedans. Si tu voulais du vrai secret sur certains champs, il faudrait chiffrer ces champs avec une clé stockée dans le Trousseau et protégée par `.biometryCurrentSet` — nettement plus lourd, et à ne faire que si le besoin est réel.

### 9.5 Configuration requise

- `NSFaceIDUsageDescription` dans l'Info.plist, avec un texte honnête : « CineShelf utilise Face ID pour protéger l'accès à ta bibliothèque. »
- Sur macOS : la même API fonctionne avec Touch ID et avec le déverrouillage par Apple Watch.
- Toujours prévoir le cas « aucune biométrie disponible » : le réglage doit alors proposer le code de l'appareil, ou se désactiver avec une explication.
