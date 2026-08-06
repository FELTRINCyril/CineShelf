import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V4 · La fiche personne
//
// Planche 3 bloc `4d` : portrait, rôles, nom, dates, bio, comptes, filmographie, « souvent
// avec ». **Elle ne pose pas de hero**, et c'est la différence de fond avec la fiche titre :
// le prototype montre un portrait *à côté* du nom, pas une image large *derrière*. Une
// personne n'a donc pas d'emplacement `backdrop`, et `PersonFormat.primaryAsset` ne cherche
// que `primary`.
//
// **Trois choses du bloc `4d` ne sont pas rendues, et aucune n'est un oubli :**
//
// 1. **« Fusionner »**, dans la barre d'actions. C'est `L8`, reportée en v1.1 — et la fiche
//    du report nomme explicitement « l'écran de fusion de `V4` » comme partant avec elle.
// 2. **« Cork, Irlande »**, le lieu de naissance. `Person` n'a **pas** de champ pour ça, et le
//    schéma est fermé depuis le 2026-08-03 : l'ajouter exigerait un `VersionedSchema` et un
//    `MigrationStage`, ce qu'un écran n'a pas à déclencher. Écart inscrit.
// 3. **La suggestion de casting**, qui est `L9`, reportée aussi. Ce qui reste est l'ajout
//    d'un crédit par recherche de nom, et il vit dans l'éditeur du titre, pas ici.

struct PersonDetailView: View {
    let personID: UUID

    @Environment(NavigationModel.self) private var navigation
    @Environment(\.modelContext) private var modelContext

    @Query private var people: [Person]

    @State private var isEditorPresented = false

    init(personID: UUID) {
        self.personID = personID
        _people = Query(filter: PersonQuery.withID(personID))
    }

    private var person: Person? { people.first }

    var body: some View {
        ScrollView {
            if let person {
                content(for: person)
            } else {
                StateView(
                    .empty(
                        symbol: Icon.people,
                        title: "Cette personne n'existe plus.",
                        message: "Elle a peut-être été supprimée depuis un autre appareil."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.bgCanvas)
        // Forçage sombre : l'arbitrage 1 réserve l'apparence claire aux écrans de gestion, et
        // range les fiches parmi les surfaces de visionnage.
        .preferredColorScheme(.dark)
        .navigationTitle(person?.displayName ?? "Personne")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $isEditorPresented) {
            if let person { PersonEditor(person: person) }
        }
    }

    private func content(for person: Person) -> some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            header(for: person)
            filmography(of: person)
            frequentCollaborators(of: person)
        }
        .padding(.top, TopNavigationBar.height + Space.s5)
        .padding(.bottom, Space.s7)
    }

    // MARK: L'en-tête — portrait à gauche, identité à droite

    private func header(for person: Person) -> some View {
        HStack(alignment: .top, spacing: Space.s6) {
            portrait(for: person)
            identity(for: person)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Breakpoint.macStandard.screenMargin)
    }

    /// Le portrait, en cercle comme partout ailleurs.
    ///
    /// **`PersonTile` sans action**, plutôt qu'un dessin propre à cet écran : c'est le même
    /// objet, il doit avoir la même forme, et la tuile porte déjà le repli en initiales. Le
    /// cran `xl` est celui que la fiche titre donne à son affiche sur Mac.
    private func portrait(for person: Person) -> some View {
        PersonTile(PosterCardModel(person), scale: .xl)
    }

    private func identity(for person: Person) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            if let roles = PersonFormat.roleLine(of: person) {
                Text(roles)
                    .labelStyle()
                    .foregroundStyle(Color.accent)
            }

            Text(person.displayName)
                .title1Style()
                .foregroundStyle(Color.textPrimary)

            let life = PersonFormat.lifeParts(of: person)
            if !life.isEmpty {
                Text(life.joined(separator: " · "))
                    .metaStyle()
                    .foregroundStyle(Color.textSecondary)
            }

            if let count = PersonFormat.creditCount(of: person) {
                Text("\(count) dans la collection")
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }

            if let bio = person.bio, !bio.isEmpty {
                Text(bio)
                    .bodyStyle()
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.top, Space.s2)
            }

            accounts(of: person)
            actions(for: person)
        }
    }

    /// Les comptes et les liens — « Instagram · Wikipédia · ＋ Compte » du bloc `4d`.
    ///
    /// Deux sources distinctes que le prototype rend sur une seule ligne : `SocialHandle`
    /// porte une plateforme et un pseudonyme, `ResourceLink` une URL libre. Les mélanger à
    /// l'affichage est correct — l'utilisateur voit des liens — et les confondre dans le
    /// modèle ne le serait pas.
    @ViewBuilder
    private func accounts(of person: Person) -> some View {
        let handles = (person.handles ?? []).sorted { $0.createdAt < $1.createdAt }
        let links = (person.links ?? []).filter { !$0.isArchived }
            .sorted { $0.orderIndex < $1.orderIndex }

        if !handles.isEmpty || !links.isEmpty {
            HStack(spacing: Space.s4) {
                ForEach(handles, id: \.persistentModelID) { handle in
                    accountLink(label: handle.platform, urlString: handle.urlString)
                }
                ForEach(links, id: \.persistentModelID) { link in
                    accountLink(label: link.label ?? link.urlString, urlString: link.urlString)
                }
            }
            .padding(.top, Space.s2)
        }
    }

    /// Un compte cliquable, ou un simple libellé quand l'adresse ne tient pas.
    ///
    /// **Un pseudonyme sans URL n'est pas un lien**, et le rendre cliquable serait un bouton
    /// qui ne mène nulle part. `SocialHandle.urlString` est optionnel exprès : on peut noter
    /// « @cillianmurphy sur Instagram » sans connaître l'adresse.
    @ViewBuilder
    private func accountLink(label: String, urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString), LinkGuard.allows(url) {
            Link(destination: url) {
                Text(label)
                    .calloutStyle()
                    .foregroundStyle(Color.accent)
                    .frame(minHeight: Space.minHitTarget)
            }
        } else {
            Text(label)
                .calloutStyle()
                .foregroundStyle(Color.textTertiary)
                .frame(minHeight: Space.minHitTarget)
        }
    }

    private func actions(for person: Person) -> some View {
        HStack(spacing: Space.s3) {
            Button("Modifier") { isEditorPresented = true }
                .buttonStyle(ActionButtonStyle(rank: .primary))
        }
        .padding(.top, Space.s3)
    }

    // MARK: Filmographie et voisinage

    /// « Filmographie dans la collection » — et le titre dit bien *dans la collection*.
    ///
    /// C'est ce qui distingue CineShelf d'un service : on ne montre pas la filmographie
    /// complète d'un acteur, on montre ce que l'utilisateur possède. Le rail est donc vide
    /// pour une personne créditée sur un titre supprimé, et c'est correct.
    @ViewBuilder
    private func filmography(of person: Person) -> some View {
        let credits = (person.credits ?? [])
            .filter { $0.title?.deletedAt == nil }
            .sorted { ($0.title?.releaseDate ?? .distantPast) > ($1.title?.releaseDate ?? .distantPast) }

        if !credits.isEmpty {
            TileRail("Filmographie dans la collection") {
                ForEach(credits, id: \.persistentModelID) { credit in
                    if let title = credit.title {
                        PosterTile(PosterCardModel(title, flag: nil), scale: .m) {
                            navigation.open(.title(title.id))
                        }
                    }
                }
            }
        }
    }

    /// « Souvent avec » — les personnes le plus souvent créditées sur les mêmes titres.
    ///
    /// **Calculé à l'affichage, et volontairement pas stocké.** C'est une lecture du graphe
    /// existant, pas une donnée : la persister obligerait à la recalculer à chaque crédit
    /// ajouté ou supprimé, et à migrer le schéma pour l'accueillir.
    ///
    /// Le seuil est **deux titres partagés**, pas un : sur un seul film commun, « souvent »
    /// serait un mensonge — tout le casting d'un titre y figurerait.
    @ViewBuilder
    private func frequentCollaborators(of person: Person) -> some View {
        let peers = collaborators(of: person)
        if !peers.isEmpty {
            TileRail("Souvent avec") {
                ForEach(peers, id: \.persistentModelID) { peer in
                    PersonTile(PosterCardModel(peer), scale: .m) {
                        navigation.open(.person(peer.id))
                    }
                }
            }
        }
    }

    private func collaborators(of person: Person) -> [Person] {
        var counts: [UUID: (person: Person, shared: Int)] = [:]
        for credit in person.credits ?? [] {
            guard let title = credit.title, title.deletedAt == nil else { continue }
            for peerCredit in title.credits ?? [] {
                guard let peer = peerCredit.person, peer.id != person.id,
                    peer.deletedAt == nil, !peer.isPrivate
                else { continue }
                counts[peer.id, default: (peer, 0)].shared += 1
            }
        }
        return
            counts
            .values
            .filter { $0.shared >= 2 }
            .sorted {
                // À nombre de titres partagés égal, `sortName` départage — sinon le rail se
                // réordonne à chaque rendu, ce que le dictionnaire garantit presque.
                $0.shared == $1.shared
                    ? $0.person.sortName < $1.person.sortName : $0.shared > $1.shared
            }
            .prefix(12)
            .map(\.person)
    }
}
