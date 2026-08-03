import Foundation
import Testing

@testable import CineShelfCore

// Les recherches récentes : bornées, dédoublonnées, par profil, jamais synchronisées.
//
// Chaque test travaille dans son propre domaine `UserDefaults` : sans ça, la suite
// écrirait dans celui de l'application et laisserait des recherches fictives dans
// l'app installée — et les tests se contamineraient entre eux selon leur ordre.

struct RecentSearchStoreTests {

    private func makeStore(profileID: UUID? = UUID()) -> RecentSearchStore {
        let suite = "recent.tests.\(UUID().uuidString)"
        return RecentSearchStore(
            profileID: profileID, defaults: UserDefaults(suiteName: suite) ?? .standard)
    }

    @Test("Le plus récent passe en tête")
    func mostRecentComesFirst() {
        let store = makeStore()
        store.record("alien")
        store.record("brazil")
        store.record("chinatown")

        #expect(store.terms == ["chinatown", "brazil", "alien"])
    }

    @Test("Retaper une recherche la remonte sans la dupliquer")
    func recordingAgainMovesItUp() {
        let store = makeStore()
        store.record("alien")
        store.record("brazil")
        store.record("alien")

        #expect(store.terms == ["alien", "brazil"])
    }

    @Test("Le dédoublonnage ignore les accents et la casse, mais garde la saisie")
    func deduplicationFoldsButKeepsWhatWasTyped() {
        // « Amélie » et « amelie » sont la même recherche. C'est la dernière saisie
        // qui est conservée : réafficher une version décapitalisée de ce que
        // l'utilisateur vient de taper ferait douter que la suggestion soit la sienne.
        let store = makeStore()
        store.record("Amélie")
        store.record("amelie")

        #expect(store.terms == ["amelie"])

        store.record("AMÉLIE")
        #expect(store.terms == ["AMÉLIE"])
    }

    @Test("La liste est bornée, et ce sont les plus anciennes qui tombent")
    func theListIsBounded() {
        let store = makeStore()
        for index in 0..<(RecentSearchStore.limit + 5) {
            store.record("terme \(index)")
        }

        #expect(store.terms.count == RecentSearchStore.limit)
        #expect(store.terms.first == "terme \(RecentSearchStore.limit + 4)")
        #expect(store.terms.contains("terme 0") == false)
    }

    @Test("Un terme vide ou blanc n'est pas enregistré")
    func blankTermsAreNotRecorded() {
        // Même règle que `SearchOutcome.idle` : il n'y a rien à retenir d'une
        // recherche qui n'a pas eu lieu.
        let store = makeStore()
        store.record("")
        store.record("   ")
        store.record("\n\t")

        #expect(store.terms.isEmpty)
    }

    @Test("Les espaces autour du terme sont retirés avant enregistrement")
    func termsAreTrimmed() {
        let store = makeStore()
        store.record("  alien  ")

        #expect(store.terms == ["alien"])
    }

    @Test("Retirer et vider fonctionnent")
    func removeAndClear() {
        let store = makeStore()
        store.record("alien")
        store.record("brazil")

        store.remove("ALIEN")
        #expect(store.terms == ["brazil"])

        store.clear()
        #expect(store.terms.isEmpty)
    }

    @Test("Chaque profil a son casier, et « aucun profil » aussi")
    func profilesAreIsolated() {
        // Deux profils partagent l'appareil : les recherches de l'un ne doivent pas
        // apparaître dans les suggestions de l'autre. Et le cas « aucun profil
        // ouvert » — le sélecteur n'a pas encore tranché — a son propre casier plutôt
        // que de polluer celui d'un profil réel.
        let suite = "recent.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let first = UUID()
        let second = UUID()

        RecentSearchStore(profileID: first, defaults: defaults).record("chez moi")
        RecentSearchStore(profileID: second, defaults: defaults).record("chez l'autre")
        RecentSearchStore(profileID: nil, defaults: defaults).record("sans profil")

        #expect(RecentSearchStore(profileID: first, defaults: defaults).terms == ["chez moi"])
        #expect(RecentSearchStore(profileID: second, defaults: defaults).terms == ["chez l'autre"])
        #expect(RecentSearchStore(profileID: nil, defaults: defaults).terms == ["sans profil"])
    }
}
