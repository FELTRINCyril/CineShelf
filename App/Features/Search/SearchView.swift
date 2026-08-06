import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V1 · L'écran de recherche
//
// Relevé sur la **planche 3, bloc `5b`** — « Recherche · résultats groupés ». Trois étages :
// le champ, la rangée de portées avec leurs compteurs, et une rangée par entité.
//
// **L'anti-rebond est ici, et nulle part ailleurs.** `SearchService` est une fonction pure,
// appelable à chaque frappe : c'est la vue qui décide quand l'appeler. Le mettre dans le
// service le rendrait intestable et imposerait un rythme à des appelants qui n'ont pas de
// frappe à amortir — l'App Intent de `L19` reçoit un terme complet au premier appel et n'a
// aucune raison d'attendre.
//
// **Les deux branches de `SearchOutcome` sont écrites, et le compilateur l'impose.** `.idle`
// n'est pas « zéro résultat » : c'est « aucun terme saisi », et les deux commandent deux
// interfaces différentes.
//
// | Branche | Ce que l'écran montre |
// |---|---|
// | `.idle` | les recherches récentes, effaçables une à une |
// | `.results` dont `isEmpty` | l'état vide de `I10`, avec le terme dans le titre |
// | `.results` | une rangée par groupe non vide |
//
// Les confondre donnerait soit un écran vide inexplicable, soit le catalogue entier sous un
// champ vide — c'est ce que l'`enum` de `L2` existe pour empêcher.
//
// MARK: - ÉCART DE COUVERTURE : la planche montre six portées, le service en sert cinq
//
// Le bloc `5b` rend « Tout · 34 · Titres · 9 · Personnes · 3 · Collections · 1 ·
// **Images · 21** · Signets · 0 ». Or `SearchScope` n'a pas de cas `images`, et ce n'est pas
// un oubli de `L2` : **`MediaAsset` n'a ni nom ni `searchText`**. Il porte un `checksum`, un
// `blurHash`, des dimensions — rien qu'un terme puisse matcher.
//
// Chercher une image demanderait soit une légende sur `MediaAsset`, ce qui **touche le schéma
// fermé** et exige une migration, soit de chercher dans le nom de l'entité propriétaire, ce
// qui rendrait les images d'un titre que le terme trouve déjà. La question part au design et
// à `docs/02` ; cinq portées ici, et l'écart est inscrit. **Ne pas ajouter une portée qui
// rendrait toujours zéro.**

struct SearchView: View {
    @Environment(ProfileSession.self) private var session
    @Environment(AppLock.self) private var appLock
    @Environment(\.modelContext) private var modelContext

    @State private var term = ""
    @State private var scope = SearchScope.all
    @State private var outcome: SearchOutcome = .idle
    @State private var recents: [String] = []
    /// Le compte par portée, pour la rangée d'onglets.
    ///
    /// Calculé sur `.all` et non sur la portée choisie : sinon les compteurs des onglets non
    /// sélectionnés tomberaient à zéro dès qu'on en choisit un, alors que le bloc les montre
    /// tous, tout le temps.
    @State private var counts: [SearchScope: Int] = [:]
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            ScreenHeader(section: .search) {}
            field
            scopes
            results
        }
        .padding(.horizontal, Space.s5)
        .task { refreshRecents() }
        // L'anti-rebond : `task(id:)` annule et relance à chaque frappe, donc le `sleep`
        // n'aboutit qu'à la pause. Pas de `Timer` ni de `DispatchWorkItem` à invalider —
        // l'annulation structurée fait le travail, et il n'y a rien à nettoyer.
        .task(id: debounceKey) { await runSearch() }
        .onAppear { isFieldFocused = true }
    }

    // MARK: Le champ

    private var field: some View {
        HStack(spacing: Space.s3) {
            Image(systemName: Icon.search)
                .foregroundStyle(Color.textSecondary)
            TextField("Rechercher", text: $term)
                .textFieldStyle(.plain)
                .font(Typo.headline)
                .focused($isFieldFocused)
                .submitLabel(.search)
                .onSubmit(recordCurrentTerm)
            if term.isEmpty == false {
                Button {
                    term = ""
                    isFieldFocused = true
                } label: {
                    Image(systemName: Icon.close)
                        .frame(width: Space.minHitTarget, height: Space.minHitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.textSecondary)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.leading, Space.s4)
        .background(.bgFill)
        .frame(maxWidth: Self.fieldWidth, alignment: .leading)
    }

    // MARK: Les portées

    /// La rangée d'onglets et leurs comptes.
    ///
    /// Le filet en accent **sous** l'onglet actif est le seul indicateur du bloc : ni
    /// pastille, ni fond, ni gras.
    private var scopes: some View {
        HStack(spacing: Space.s5 - 2) {
            ForEach(SearchScope.allCases) { candidate in
                Button {
                    scope = candidate
                } label: {
                    VStack(spacing: Space.s1 + 2) {
                        Text(scopeLabel(candidate))
                            .labelStyle()
                            .foregroundStyle(
                                candidate == scope ? Color.textPrimary : Color.textTertiary)
                        Rectangle()
                            .fill(candidate == scope ? Color.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(minHeight: Space.minHitTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(candidate == scope ? [.isSelected] : [])
            }
        }
    }

    /// « Titres · 9 » quand un terme est saisi, « Titres » sinon.
    ///
    /// Sans terme il n'y a rien à compter, et afficher « · 0 » ferait croire à une absence de
    /// correspondance là où la question n'a pas été posée — la même confusion que `.idle`
    /// contre `.results` vide, à l'échelle d'un onglet.
    private func scopeLabel(_ candidate: SearchScope) -> String {
        guard let count = counts[candidate] else { return candidate.label }
        return "\(candidate.label) · \(count)"
    }

    // MARK: Les deux branches

    @ViewBuilder
    private var results: some View {
        switch outcome {
        case .idle:
            recentSearches
        case .results(let found) where found.isEmpty:
            EmptyState(
                title: "Aucun résultat pour « \(term) »",
                message: "Vérifie l'orthographe, ou cherche un autre terme.",
                primary: .init("Effacer") {
                    term = ""
                    isFieldFocused = true
                },
                hint: "recherche insensible aux accents et à la casse")
        case .results(let found):
            groups(of: found)
        }
    }

    /// La branche `.idle`.
    ///
    /// Vide au premier lancement, et c'est un état vide **sans action** : la seule issue est
    /// de taper quelque chose, et le champ a déjà le focus. Inventer un bouton ici serait
    /// remplir un emplacement parce qu'il existe.
    @ViewBuilder
    private var recentSearches: some View {
        if recents.isEmpty {
            EmptyState(
                title: "Rien de cherché pour l'instant",
                message: "Tape un titre, un nom de personne, une collection ou un signet.")
        } else {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack {
                    Text("Recherches récentes")
                        .labelStyle()
                        .foregroundStyle(Color.textTertiary)
                    Spacer()
                    Button("Tout effacer") {
                        store.clear()
                        refreshRecents()
                    }
                    .buttonStyle(.plain)
                    .actionStyle()
                    .foregroundStyle(Color.textSecondary)
                }
                ForEach(recents, id: \.self) { recent in
                    recentRow(recent)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: Self.fieldWidth, alignment: .leading)
        }
    }

    private func recentRow(_ recent: String) -> some View {
        HStack(spacing: Space.s3) {
            Button(recent) { term = recent }
                .buttonStyle(.plain)
                .font(Typo.callout)
                .foregroundStyle(Color.textPrimary)
                .frame(minHeight: Space.minHitTarget)
            Spacer()
            Button {
                store.remove(recent)
                refreshRecents()
            } label: {
                Image(systemName: Icon.close)
                    .frame(width: Space.minHitTarget, height: Space.minHitTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.textTertiary)
            .accessibilityLabel("Oublier « \(recent) »")
        }
    }

    /// La branche `.results` non vide : une rangée par groupe.
    ///
    /// **Les groupes vides sont omis**, pas rendus avec « 0 » : le bloc ne montre que les
    /// rangées qui ont du contenu, et une rangée vide occuperait la hauteur d'un rail pour ne
    /// rien dire. Le compteur d'onglet, lui, garde le zéro — c'est là qu'il informe.
    private func groups(of found: SearchResults) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s6) {
                if found.titles.isEmpty == false {
                    TileRail(label("Titres", found.titles.total)) {
                        ForEach(found.titles.items, id: \.id) { title in
                            PosterTile(PosterCardModel(title, flag: nil), scale: .l) {}
                        }
                    }
                }
                if found.people.isEmpty == false {
                    TileRail(label("Personnes", found.people.total)) {
                        ForEach(found.people.items, id: \.id) { person in
                            PersonTile(PosterCardModel(person), scale: .m) {}
                        }
                    }
                }
                if found.collections.isEmpty == false {
                    TileRail(label("Collections", found.collections.total)) {
                        ForEach(found.collections.items, id: \.id) { collection in
                            CollectionTile(CollectionTileModel(collection), scale: .l) {}
                        }
                    }
                }
                if found.savedLinks.isEmpty == false {
                    savedLinks(found.savedLinks)
                }
            }
            .padding(.bottom, Space.s6)
        }
        // La rangée pose sa propre marge d'écran : celle de la vue la doublerait.
        .padding(.horizontal, -Space.s5)
    }

    /// Les signets n'ont pas de tuile.
    ///
    /// `I5` livrera la ligne de tableau ; d'ici là une liste de libellés dit la vérité sans
    /// inventer un composant que la direction n'a pas dessiné.
    private func savedLinks(_ group: SearchResults.Group<SavedLink>) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(label("Signets", group.total))
                .labelStyle()
                .foregroundStyle(Color.textPrimary)
            ForEach(group.items, id: \.id) { link in
                Text(SavedLinkFormat.label(of: link))
                    .font(Typo.callout)
                    .foregroundStyle(Color.textSecondary)
                    .frame(minHeight: Space.minHitTarget)
            }
        }
        .padding(.horizontal, Space.s5)
    }

    /// « Titres · 9 », et le compte est le **total**, pas la taille de la tranche.
    ///
    /// C'est pour ça que `SearchResults.Group` porte les deux : la rangée montre dix cartes
    /// et le libellé annonce trente-quatre, ce qui est l'information utile.
    private func label(_ name: String, _ total: Int) -> LocalizedStringKey {
        LocalizedStringKey("\(name) · \(total)")
    }

    // MARK: La recherche

    /// Ce qui déclenche une recherche : le terme **et** la portée. Changer de portée sans
    /// retaper doit relancer.
    private var debounceKey: String { "\(scope.rawValue)\u{1F}\(term)" }

    private func runSearch() async {
        // Le rebond. Annulé dès la frappe suivante, donc un terme tapé d'un trait ne coûte
        // qu'un seul appel au service.
        do {
            try await Task.sleep(for: .milliseconds(Self.debounce))
        } catch {
            return
        }

        let service = SearchService(context: modelContext)
        let hidingPrivate = appLock.scope(for: session.current).hidesPrivateContent
        let libraryID = session.current?.library?.id

        do {
            outcome = try service.search(
                term, scope: scope, hidingPrivate: hidingPrivate, libraryID: libraryID)
            counts = try scopeCounts(
                using: service, hidingPrivate: hidingPrivate, libraryID: libraryID)
        } catch {
            // Une recherche qui échoue laisse l'écran tel quel plutôt que de le vider : un
            // échec transitoire ne doit pas ressembler à « aucun résultat », qui est une
            // information, elle.
            return
        }
    }

    /// Les comptes des cinq portées, en une seule passe `.all`.
    private func scopeCounts(
        using service: SearchService, hidingPrivate: Bool, libraryID: UUID?
    ) throws -> [SearchScope: Int] {
        guard
            case .results(let all) = try service.search(
                term, scope: .all, hidingPrivate: hidingPrivate, libraryID: libraryID)
        else { return [:] }

        return [
            .all: all.total,
            .titles: all.titles.total,
            .people: all.people.total,
            .collections: all.collections.total,
            .savedLinks: all.savedLinks.total
        ]
    }

    // MARK: Les recherches récentes

    private var store: RecentSearchStore {
        RecentSearchStore(profileID: session.current?.id)
    }

    private func refreshRecents() {
        recents = store.terms
    }

    /// Enregistrée à la **validation**, pas à la frappe : mémoriser chaque état intermédiaire
    /// remplirait la liste de « v », « vi », « vil ».
    private func recordCurrentTerm() {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        store.record(trimmed)
        refreshRecents()
    }

    /// 250 ms : assez pour qu'une frappe continue ne déclenche rien, assez court pour que la
    /// pause entre deux mots rende déjà des résultats. **À confirmer par une mesure sur
    /// appareil**, pas au simulateur — voir l'écart sur les budgets de `docs/04` §4.
    static let debounce = 250
    /// 520 pt, la largeur du champ du bloc `5b`.
    static let fieldWidth: CGFloat = 520
}

#Preview("Recherche") {
    NavigationStack {
        SearchView()
    }
}
