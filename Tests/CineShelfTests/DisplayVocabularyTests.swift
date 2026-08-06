import CineShelfCore
import DesignSystem
import Foundation
import Testing

// L'accord entre les **deux** vocabulaires de la même matrice `disposition × taille`.
//
// `CineShelfCore` porte celui qui va sur le disque — les noms de la v1, `movies`, `actors`,
// `home_movies`… — et `DesignSystem` celui que les vues emploient. La règle de dépendances
// de `docs/04` §1 leur interdit de se connaître, donc les deux jeux sont en double, et le
// double est assumé.
//
// **Ce qui ne l'est pas, c'est la divergence silencieuse.** Ajouter un cas d'un seul côté ne
// casse aucune compilation : la préférence du contexte nouveau tombe simplement sur son
// défaut à chaque lancement, et personne ne le voit. Le pont de l'app a bien un `switch`
// exhaustif, mais un `switch` ne voit que les **cas**, jamais les `rawValue` — renommer
// `portrait` en `vertical` d'un seul côté compilerait, et perdrait la disposition choisie.
//
// C'est le même motif que `CropRenderingAgreementTests` : deux implémentations d'une seule
// vérité, et un test qui les confronte parce que rien d'autre ne le fera.
//
// Ce fichier est le seul endroit du dépôt, hors du pont, qui importe les deux paquets.

@Suite("Accord des vocabulaires d'affichage")
struct DisplayVocabularyTests {

    @Test("Les huit contextes persistés sont ceux de la v1, à la lettre")
    func persistedContextsAreTheV1Names() {
        // `docs/PROMPTS.md`, fiche `L1 bis` : « Réconcilier les huit contextes vers ceux du
        // handoff, qui sont ceux de la v1 ». La liste est citée telle quelle, dans l'ordre
        // du document — c'est une reprise de fonctionnalité, donc les noms font foi.
        let expected: Set<String> = [
            "movies", "actors", "collections", "social",
            "home_movies", "home_actors", "home_collections", "home_social"
        ]

        #expect(Set(DisplayContext.allCases.map(\.rawValue)) == expected)
        #expect(DisplayContext.allCases.count == 8)
    }

    @Test("Chaque contexte persisté a un contexte visuel, et la correspondance est bijective")
    func contextsMapOneToOne() {
        let visual = DisplayContext.allCases.map(\.posterContext)

        #expect(Set(visual).count == DisplayContext.allCases.count, "Deux contextes visés")
        #expect(Set(visual) == Set(PosterContext.allCases), "Un contexte visuel sans casier")

        // Aller puis retour rend le même contexte : c'est ce qui garantit qu'aucune paire
        // n'est croisée. Deux tables écrites à la main peuvent être exhaustives chacune et
        // se contredire — `movies -> .titles` d'un côté, `.titles -> .actors` de l'autre.
        for context in DisplayContext.allCases {
            #expect(context.posterContext.displayContext == context, "\(context.rawValue)")
        }
        for context in PosterContext.allCases {
            #expect(context.displayContext.posterContext == context, "\(context.rawValue)")
        }
    }

    @Test("Les rawValue de disposition et de taille sont identiques des deux côtés")
    func layoutAndSizeRawValuesAgree() {
        // C'est l'assertion que le `switch` du pont ne peut pas porter : les conversions
        // passent par `rawValue`, et leur repli (`?? .portrait`, `?? .medium`) n'est
        // inatteignable que tant que ces deux ensembles coïncident.
        #expect(Set(DisplayLayout.allCases.map(\.rawValue)) == Set(CardLayout.allCases.map(\.rawValue)))
        #expect(Set(DisplaySize.allCases.map(\.rawValue)) == Set(CardSize.allCases.map(\.rawValue)))
    }

    @Test("Le défaut du disque et le défaut de l'écran sont le même réglage")
    func defaultsAgree() {
        // `DisplayContext.defaultPreference` répète la table de
        // `PosterContext.defaultSetting`, faute de pouvoir la lire. Sans ce test, un défaut
        // corrigé d'un seul côté donnerait un premier affichage différent selon qu'une
        // préférence a déjà été écrite ou non — le pire cas, parce qu'il ne se reproduit
        // qu'à froid.
        for context in DisplayContext.allCases {
            let fromCore = context.defaultPreference.posterSetting
            let fromDesign = context.posterContext.defaultSetting
            #expect(fromCore == fromDesign, "\(context.rawValue)")
        }
    }

    @Test("Une préférence écrite se relit, par profil et par contexte")
    func preferencesRoundTripPerProfileAndContext() throws {
        let defaults = try #require(UserDefaults(suiteName: "DisplayVocabularyTests"))
        defer { defaults.removePersistentDomain(forName: "DisplayVocabularyTests") }

        let alice = UUID()
        let bob = UUID()
        let aliceStore = DisplayPreferenceStore(profileID: alice, defaults: defaults)
        let bobStore = DisplayPreferenceStore(profileID: bob, defaults: defaults)

        aliceStore.save(DisplayPreference(layout: .landscape, size: .large), for: .movies)

        #expect(aliceStore.preference(for: .movies) == DisplayPreference(layout: .landscape, size: .large))
        // Le contexte voisin n'est pas touché, et l'autre profil non plus : la clé porte
        // les deux, et une clé qui n'en porterait qu'un ferait fuiter le réglage.
        #expect(aliceStore.preference(for: .actors) == DisplayContext.actors.defaultPreference)
        #expect(bobStore.preference(for: .movies) == DisplayContext.movies.defaultPreference)
    }

    @Test("Un profil absent a son propre casier, il n'emprunte pas celui d'un profil réel")
    func absentProfileHasItsOwnSlot() throws {
        let defaults = try #require(UserDefaults(suiteName: "DisplayVocabularyTests.none"))
        defer { defaults.removePersistentDomain(forName: "DisplayVocabularyTests.none") }

        let anonymous = DisplayPreferenceStore(profileID: nil, defaults: defaults)
        let named = DisplayPreferenceStore(profileID: UUID(), defaults: defaults)

        anonymous.save(DisplayPreference(layout: .landscape, size: .compact), for: .social)

        #expect(anonymous.preference(for: .social).size == .compact)
        #expect(named.preference(for: .social) == DisplayContext.social.defaultPreference)
    }

    @Test("Une valeur illisible rend le défaut du contexte au lieu de propager l'erreur")
    func corruptValueFallsBackToTheDefault() throws {
        let defaults = try #require(UserDefaults(suiteName: "DisplayVocabularyTests.corrupt"))
        defer { defaults.removePersistentDomain(forName: "DisplayVocabularyTests.corrupt") }

        let profileID = UUID()
        // La forme réelle de la clé est vérifiée ici, et c'est délibéré : le préfixe est
        // versionné (`display.v1.`) pour ne pas relire les clés `display.` du prompt 11, qui
        // portaient un autre vocabulaire de contextes avec **les mêmes** noms de champs.
        defaults.set(Data("pas du JSON".utf8), forKey: "display.v1.\(profileID.uuidString).movies")

        let store = DisplayPreferenceStore(profileID: profileID, defaults: defaults)

        #expect(store.preference(for: .movies) == DisplayContext.movies.defaultPreference)
    }

    @Test("reset() efface les huit contextes, et seulement ceux du profil")
    func resetClearsOnlyThisProfile() throws {
        let defaults = try #require(UserDefaults(suiteName: "DisplayVocabularyTests.reset"))
        defer { defaults.removePersistentDomain(forName: "DisplayVocabularyTests.reset") }

        let mine = UUID()
        let other = UUID()
        let mineStore = DisplayPreferenceStore(profileID: mine, defaults: defaults)
        let otherStore = DisplayPreferenceStore(profileID: other, defaults: defaults)

        for context in DisplayContext.allCases {
            mineStore.save(DisplayPreference(layout: .landscape, size: .large), for: context)
            otherStore.save(DisplayPreference(layout: .landscape, size: .large), for: context)
        }

        mineStore.reset()

        for context in DisplayContext.allCases {
            #expect(mineStore.preference(for: context) == context.defaultPreference, "\(context.rawValue)")
            #expect(otherStore.preference(for: context).size == .large, "\(context.rawValue)")
        }
    }
}

// MARK: - I8 · Les deux `DatePrecision`
//
// Le modèle en porte un, persisté dans `Title.releasePrecisionRaw` ; `DesignSystem` en porte un
// second sous le nom `DateFieldPrecision`, parce que les deux paquets ne peuvent pas se
// connaître. **Le double est acceptable, la divergence ne l'est pas** : un cran présent d'un
// seul côté ne casse aucune compilation, il perd simplement la précision saisie au relancement.
//
// Même motif, même remède et même endroit que pour la matrice `disposition × taille`.

@Test("Les deux jeux de précision de date s'accordent sur leurs rawValue")
func datePrecisionVocabulariesAgree() {
    // **Sans qualification de module**, et ce n'est pas un raccourci : les deux paquets
    // exposent un type qui porte le nom du module (`CineShelfCore`, `DesignSystem`), donc
    // `CineShelfCore.DatePrecision` désigne un membre de ce type-là et non du module. Les deux
    // noms diffèrent depuis le renommage, il n'y a donc rien à lever.
    let model = Set(DatePrecision.allCases.map(\.rawValue))
    let visual = Set(DateFieldPrecision.allCases.map(\.rawValue))

    #expect(model == visual, "Un cran de précision existe d'un seul côté : la valeur saisie se perdra")
    #expect(model.count == 3, "Trois crans — année, mois, jour — et le handoff §6 les nomme")
}
