import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

@main
struct CineShelfApp: App {
    @State private var container: ModelContainer
    @State private var navigation = NavigationModel()
    @State private var session = ProfileSession()

    /// Le verrou d'interface de `L14`.
    ///
    /// **Un seul pour toute l'app**, et posé ici : `PrivacyScope` en dérive, donc deux
    /// instances donneraient deux réponses à « ce profil peut-il voir le contenu privé ».
    /// L'évaluateur réel est injecté une fois ; les tests en fournissent un factice.
    @State private var appLock = AppLock(evaluator: LocalAuthenticationEvaluator())
    @State private var media: MediaEnvironment

    init() {
        // Archivo vit dans le bundle de ressources du package DesignSystem, que
        // `UIAppFonts` ne sait pas atteindre : l'enregistrement est explicite.
        // `FontResolutionTests` échoue si une police cesse de se résoudre.
        DesignSystemFonts.register()

        // Le vrai index du système, posé une fois pour toutes : les repositories le
        // lisent par défaut, donc toute écriture le tient à jour sans que le moindre
        // appelant ait à y penser. Tant que cette ligne n'existait pas, l'indexation
        // tournait à vide — c'est voulu, `NullSpotlightIndex` est le défaut sûr pour
        // les tests et pour tout contexte sans Spotlight.
        SpotlightConfiguration.indexer = SpotlightIndexer(index: CoreSpotlightIndex())

        do {
            let container = try Persistence.makeContainer(cloudKit: FeatureFlags.cloudKitEnabled)
            try Bootstrap.ensureDefaults(in: container.mainContext)
            // L'entretien au lancement — la fiche `L16` le veut « appelable au démarrage comme
            // à la demande ». Une passe sur une base saine ne modifie rien : elle rend un
            // rapport `isEmpty`, ce qu'un test assène.
            //
            // **Sautée quand CloudKit est actif, et c'est le point le plus important ici.**
            // Les quatre étapes lisent « relation absente » comme « déchet » — un attachement
            // sans titre, un crédit sans personne. Or c'est exactement le **régime normal d'une
            // importation CloudKit en cours** : le miroir matérialise les enregistrements par
            // lots, et les deux extrémités d'une relation peuvent apparaître dans des
            // transactions distinctes. Lancée avant la fin de l'import, la passe supprimerait
            // des arêtes parfaitement valides — et **exporterait ces suppressions**, donc à tous
            // les appareils. Le paradoxe mérite d'être dit : cette passe existe pour réparer les
            // dégâts d'une fusion CloudKit, et c'est une fusion en cours qui la rend
            // destructrice.
            //
            // La garde saute donc tant que `L17` n'a pas fourni un état de synchronisation
            // permettant d'attendre `upToDate`. Écart inscrit — sans quoi cette ligne
            // deviendrait dangereuse le jour où le drapeau passe à `true`, sans que rien ne
            // change dans ce fichier.
            //
            // **L'échec ne bloque pas le lancement**, et c'est délibéré : perdre l'app parce
            // qu'un ménage a échoué serait hors de proportion. La passe est rejouable et se
            // replie proprement — voir le `rollback` de `run()` —, donc le prochain lancement
            // réessaiera.
            if !FeatureFlags.cloudKitEnabled {
                try? MaintenanceService(context: container.mainContext).run()
            }
            self.container = container
            // Le cache de vignettes n'était instancié par personne jusqu'ici :
            // rien n'était mis en cache, tout était redécodé à chaque affichage.
            media = MediaEnvironment(container: container)
        } catch {
            // Sans magasin, il n'y a pas d'app. Les états de synchronisation
            // auront leur propre interface au prompt « Synchronisation ».
            fatalError("Impossible d'ouvrir la bibliothèque : \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            // **`lockGate()` avant `.environment(appLock)`, et l'ordre est le sujet.** Un
            // modificateur lit l'environnement posé *au-dessus* de lui : appliqué après
            // `.environment(appLock)`, il enveloppe la vue qui porte la valeur, donc il ne la
            // voit pas — et SwiftUI **tue le processus** au lancement, « No Observable object
            // of type AppLock found ». Mesuré : la suite de rendu a rendu zéro test, l'app
            // hôte n'ayant jamais démarré.
            RootView()
                .lockGate()
                .environment(navigation)
                .environment(session)
                .environment(appLock)
                .environment(media)
                .imageLoader(media.imageLoader())
                .displayScale(feeding: media)
                .tint(session.accentColor)
                .task { media.startObservingMemoryPressure() }
        }
        .modelContainer(container)
        .commands {
            CineShelfCommands(navigation: navigation, session: session)
        }

        #if os(macOS)
            Settings {
                SettingsScene()
                    .environment(navigation)
                    .environment(session)
                    .environment(appLock)
                    .modelContainer(container)
            }

            // Fenêtre dédiée plutôt que section : `docs/04` §2. La console de
            // gestion se consulte à côté de la bibliothèque, pas à sa place.
            Window("Gestion", id: Self.managementWindowID) {
                AppSection.libraryAdmin.destination
                    .frame(minWidth: 720, minHeight: 480)
                    .environment(navigation)
                    .environment(session)
                    .environment(appLock)
                    .modelContainer(container)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        #endif
    }

    #if os(macOS)
        static let managementWindowID = "library-admin"
    #endif
}

#if os(macOS)
    /// Fenêtre de réglages macOS, remplie au prompt « Profils & Face ID ».
    struct SettingsScene: View {
        var body: some View {
            AppSection.settings.destination
                .frame(minWidth: 420, minHeight: 260)
        }
    }
#endif
