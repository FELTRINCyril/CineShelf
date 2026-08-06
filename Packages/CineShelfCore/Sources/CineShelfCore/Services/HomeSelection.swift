import Foundation

// MARK: - L18 · Ce que l'accueil montre, et dans quel ordre
//
// **Descendu de la vue, et c'est la moitié de la tâche.** `HomeSelection` vivait dans
// `App/Features/Home/HomeView.swift` depuis `V5a`, en portant lui-même la note : « provisoire,
// et son propriétaire est `L18` ». Trois conséquences, dont la troisième est la vraie :
//
// 1. aucun test — et « stable dans la journée » est **exactement** ce qui se teste, puisque
//    c'est une propriété d'une fonction du temps ;
// 2. la règle de choix n'était pas éditoriale mais une rotation : `visible[seed % count]`,
//    honnête et arbitraire ;
// 3. **le widget et l'App Intent de `L19` en auront besoin**, et ils ne peuvent pas importer
//    une vue. « Prochain à voir » doit rendre le même titre dans l'app, dans le widget et dans
//    Siri, sinon les trois se contredisent devant l'utilisateur.
//
// **Ce fichier ne connaît pas SwiftUI**, et c'est ce qui rend les trois lecteurs possibles.

/// Ce que l'accueil affiche : un hero, des rayons.
public struct HomeSelection: Sendable {

    /// Un rayon : un identifiant stable, un libellé, des titres.
    public struct Rail: Identifiable, Sendable {
        public let id: String
        public let label: String
        public let titleIDs: [UUID]

        public init(id: String, label: String, titleIDs: [UUID]) {
            self.id = id
            self.label = label
            self.titleIDs = titleIDs
        }
    }

    public let heroID: UUID?
    public let rails: [Rail]

    /// Le nombre de titres d'un rayon. Neuf dans le prototype, dont le dernier coupé.
    public static let railLength = 12

    /// **Le seuil minimal d'un rayon par genre**, demandé par la fiche.
    ///
    /// Trois, et le motif est le rendu : un rayon d'un seul titre laisse une carte perdue dans
    /// une rangée vide, ce qui se lit comme un défaut d'affichage et non comme un genre peu
    /// fourni. Le titre reste atteignable par la grille et par le filtre de genre — il n'est
    /// pas caché, il n'a simplement pas de rayon à lui.
    public static let minimumRailLength = 3

    // MARK: Le hero

    /// Ce qui rend un titre éligible au hero, et ce qui le classe.
    ///
    /// **`V5a` prenait le premier venu d'une rotation ; la fiche demande un choix.** La
    /// différence tient en une question : *qu'est-ce qui mérite le plein cadre ?* Le design y
    /// répond sans le dire — le hero est **une image large floutée sur toute la hauteur**
    /// (planche 1, bloc `2a`). Un titre sans image large y est agrandi et flouté depuis sa
    /// jaquette 2:3, ce qui marche mais reste un repli.
    ///
    /// Le classement suit donc ce que l'écran demande, du plus fort au plus faible :
    ///
    /// 1. **une image large** — c'est ce que le hero affiche ;
    /// 2. **un synopsis** — le bloc en pose un, et un hero sans texte est une image nue ;
    /// 3. **une note haute** — à égalité de matière, montrer ce qu'on aime ;
    /// 4. l'ordre d'ajout, pour que le tri soit total et donc reproductible.
    ///
    /// **La rotation quotidienne reste**, et elle porte sur les **candidats de tête** plutôt
    /// que sur toute la bibliothèque : sans elle, le même titre tiendrait le hero pour
    /// toujours. Avec elle, l'accueil change chaque jour sans jamais tomber sur un titre sans
    /// image tant qu'il en existe un.
    public static let heroCandidateCount = 7

    // MARK: Construction

    /// - Parameters:
    ///   - titles: tous les titres connus. Le filtrage de visibilité est fait ici.
    ///   - pinnedGenres: les genres épinglés, dans leur ordre.
    ///   - collections: les collections manuelles, dans leur ordre.
    ///   - profileID: le profil courant, pour les rayons qui dépendent des flags.
    ///   - hidingPrivate: le réglage du profil. **Porté par le profil, jamais par l'entité** —
    ///     `isPrivate` appartient au titre, `hidesPrivateContent` au profil.
    ///   - libraryID: la bibliothèque courante.
    ///   - day: le jour de référence. **Un paramètre et non `Date()`** : c'est ce qui rend
    ///     « stable dans la journée » testable au lieu d'être une intention.
    public init(
        titles: [Title],
        pinnedGenres: [Genre] = [],
        collections: [TitleCollection] = [],
        profileID: UUID? = nil,
        hidingPrivate: Bool = false,
        libraryID: UUID? = nil,
        day: Date
    ) {
        let visible = titles.filter {
            Self.isVisible($0, hidingPrivate: hidingPrivate, libraryID: libraryID)
        }

        heroID = Self.hero(among: visible, day: day)?.id
        rails = Self.rails(
            visible: visible,
            pinnedGenres: pinnedGenres,
            collections: collections,
            profileID: profileID)
    }

    /// Les trois contraintes de la fiche `V5a`, en un seul endroit.
    static func isVisible(_ title: Title, hidingPrivate: Bool, libraryID: UUID?) -> Bool {
        title.deletedAt == nil
            && !title.isArchived
            && (libraryID == nil || title.library?.id == libraryID)
            && !(hidingPrivate && title.isPrivate)
    }

    /// Le titre du jour, choisi parmi les mieux classés.
    static func hero(among visible: [Title], day: Date) -> Title? {
        guard !visible.isEmpty else { return nil }

        let ranked = visible.sorted { left, right in
            let leftScore = editorialScore(left)
            let rightScore = editorialScore(right)
            if leftScore != rightScore { return leftScore > rightScore }
            // Départage total et déterministe : sans lui, deux titres de même score
            // pourraient permuter d'une exécution à l'autre, et le hero cesserait d'être
            // stable **à jour égal** — ce qui est précisément la propriété à tenir.
            return left.id.uuidString < right.id.uuidString
        }

        let pool = Array(ranked.prefix(heroCandidateCount))
        return pool[dayIndex(day, modulo: pool.count)]
    }

    /// Le score éditorial d'un titre. Voir `heroCandidateCount` pour le raisonnement.
    static func editorialScore(_ title: Title) -> Int {
        var score = 0
        if (title.attachments ?? []).contains(where: { $0.slot == .backdrop }) { score += 100 }
        if !(title.summary ?? "").isEmpty { score += 20 }
        score += Int((title.rating ?? 0).rounded())
        return score
    }

    /// L'index du jour, borné, sur le calendrier **local**.
    ///
    /// **J'avais écrit le quotient d'époque, et le premier test l'a démenti.** Le raisonnement
    /// était : minuit UTC change partout au même instant, donc l'app et un widget s'accordent.
    /// Il est faux là où ça compte — « stable dans la journée » parle de **la journée de
    /// l'utilisateur**, pas d'un fuseau de référence. À UTC−8, minuit UTC tombe à seize heures
    /// locales : le hero changerait au milieu de l'après-midi, pendant qu'on regarde l'écran.
    ///
    /// L'argument du widget ne tient pas non plus à l'examen : l'app et son widget tournent sur
    /// **le même appareil**, donc dans le même fuseau. Ce que l'époque protégeait est un cas
    /// qui n'existe pas ; ce qu'elle cassait arrive tous les jours.
    ///
    /// C'est le même choix que `ActivityFeed.group(_:)`, et pour la même raison — sauf que
    /// là-bas je l'avais eu juste du premier coup, en écrivant que le fil dit « aujourd'hui ».
    static func dayIndex(_ day: Date, modulo count: Int) -> Int {
        guard count > 0 else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let midnight = calendar.startOfDay(for: day)
        let epochDay = Int((midnight.timeIntervalSince1970 / 86_400).rounded(.down))
        // `%` de Swift garde le signe du dividende : une date d'avant 1970 rendrait un index
        // négatif, donc un plantage à l'indexation.
        return ((epochDay % count) + count) % count
    }

    // MARK: Les rayons

    static func rails(
        visible: [Title], pinnedGenres: [Genre], collections: [TitleCollection], profileID: UUID?
    ) -> [Rail] {
        var built: [Rail] = [
            Rail(
                id: "recent",
                label: "Ajoutés cette semaine",
                titleIDs: visible.prefix(railLength).map(\.id))
        ]

        // **Les collections manuelles avant les genres**, et la fiche les nomme dans cet
        // ordre : une collection est un choix de l'utilisateur, un rayon de genre est une
        // déduction. Ce qu'il a rangé lui-même passe devant.
        for collection in collections {
            let inCollection = visible.filter { $0.collection?.id == collection.id }
            guard inCollection.count >= minimumRailLength else { continue }
            built.append(
                Rail(
                    id: "collection-\(collection.id)",
                    label: collection.name,
                    titleIDs: inCollection.prefix(railLength).map(\.id)))
        }

        for genre in pinnedGenres {
            let inGenre = visible.filter { ($0.genres ?? []).contains { $0.id == genre.id } }
            guard inGenre.count >= minimumRailLength else { continue }
            built.append(
                Rail(
                    id: "genre-\(genre.id)",
                    label: "Mes genres · \(genre.name)",
                    titleIDs: inGenre.prefix(railLength).map(\.id)))
        }

        let watchlist = titles(visible, flaggedFor: profileID) { $0.isInWatchlist }
        if !watchlist.isEmpty {
            built.append(
                Rail(
                    id: "watchlist", label: "Ma liste · à voir",
                    titleIDs: watchlist.prefix(railLength).map(\.id)))
        }

        return built.filter { !$0.titleIDs.isEmpty }
    }

    // MARK: « Ma liste » et « Prochain à voir »

    /// Les titres marqués par le profil courant.
    ///
    /// **`profileID` nul rend une liste vide, jamais toute la bibliothèque.** Un flag est une
    /// donnée *par profil* : sans profil, la bonne réponse est « rien », pas « tout ».
    public static func titles(
        _ titles: [Title], flaggedFor profileID: UUID?, matching flag: (TitleFlag) -> Bool
    ) -> [Title] {
        guard let profileID else { return [] }
        return titles.filter { title in
            title.flags?.contains { $0.profile?.id == profileID && flag($0) } ?? false
        }
    }

    /// Le prochain titre à voir : celui de la watchlist qui a la meilleure note.
    ///
    /// **La même règle sert l'accueil, le widget et l'App Intent de `L19`** — c'est écrit dans
    /// la fiche, et c'est pour ça que cette fonction est publique et sans dépendance à une
    /// vue. Trois réponses différentes à « qu'est-ce que je regarde ce soir ? » se
    /// contrediraient devant l'utilisateur.
    ///
    /// **Pas de rotation quotidienne ici**, à la différence du hero : « prochain à voir » est
    /// une recommandation qu'on suit, et elle ne doit pas changer parce qu'on a ouvert l'app le
    /// lendemain. Elle change quand la liste change.
    public static func nextToWatch(
        among titles: [Title], profileID: UUID?, hidingPrivate: Bool = false, libraryID: UUID? = nil
    ) -> Title? {
        let visible = titles.filter {
            isVisible($0, hidingPrivate: hidingPrivate, libraryID: libraryID)
        }
        return Self.titles(visible, flaggedFor: profileID) { $0.isInWatchlist }
            .max { left, right in
                let leftRating = left.rating ?? 0
                let rightRating = right.rating ?? 0
                if leftRating != rightRating { return leftRating < rightRating }
                return left.id.uuidString > right.id.uuidString
            }
    }
}
