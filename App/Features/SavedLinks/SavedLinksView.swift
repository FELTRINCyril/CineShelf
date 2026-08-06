import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V5b · Les signets
//
// Planche 3 bloc `5d` : « Signets · 61 liens · 12 non rattachés · Trier ▾ · Filtres ·
// ＋ Coller un lien ». **Une liste, pas une grille** — le lot 2 de la planche le dit : « pas de
// grille d'affiches là où l'objet n'est pas une affiche ».
//
// **C'est le seul écran de l'app qui déclenche une requête sortante**, et c'est aussi
// l'unique appelant de production de `LinkPreviewService` (`L7`). Trois conséquences que le
// code porte :
//
// 1. **L'aperçu ne bloque jamais.** `preview(of:)` ne lève pas : au pire il déduit le libellé
//    de l'URL. Le signet est écrit **avant** la requête, et l'aperçu ne fait que l'enrichir —
//    un réseau absent ne doit pas empêcher de coller un lien.
// 2. **La garde est vérifiée avant l'écriture**, pas seulement avant le fetch : un lien vers
//    `http://192.168.1.1/` ne mérite pas d'entrer dans la bibliothèque, même sans aperçu.
// 3. **« Déduit » se dit.** `LinkPreview.isDeduced` distingue « la page a répondu » de « j'ai
//    lu l'adresse » ; l'écran le montre, parce qu'un titre déduit peut être faux.

struct SavedLinksView: View {
    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SavedLink.createdAt, order: .reverse) private var allLinks: [SavedLink]

    @State private var isPasting = false
    @State private var draftURL = ""
    @State private var refusal: LinkRefusal?
    @State private var fetching: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            ScreenHeader(section: .savedLinks, count: countLabel) { actions }

            if links.isEmpty {
                EmptyState(
                    title: "Aucun signet",
                    message:
                        "Colle l'adresse d'une critique, d'une fiche ou d'une bande-annonce.",
                    primary: .init("Coller un lien") { isPasting = true }
                )
                .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                ForEach(links, id: \.persistentModelID) { link in
                    row(link)
                }
                .padding(.horizontal, Breakpoint.macStandard.screenMargin)
            }
        }
        .padding(.bottom, Space.s7)
        .alert("Coller un lien", isPresented: $isPasting) {
            TextField("https://…", text: $draftURL)
            Button("Annuler", role: .cancel) { draftURL = "" }
            Button("Ajouter") { addLink() }
        } message: {
            if let refusal {
                Text(message(for: refusal))
            }
        }
    }

    /// « 61 liens · 12 non rattachés », le sous-titre du bloc `5d`.
    ///
    /// « Non rattaché » veut dire : sans genre. C'est la seule relation qu'un `SavedLink`
    /// porte — il n'appartient ni à un titre ni à une personne, c'est ce qui en fait un signet
    /// **autonome** plutôt qu'un `ResourceLink`.
    private var countLabel: String {
        let total = links.count
        let loose = links.count { $0.genre == nil }
        let linkPart = total == 1 ? "1 lien" : "\(total) liens"
        return loose == 0 ? linkPart : "\(linkPart) · \(loose) non rattachés"
    }

    private var links: [SavedLink] {
        let hidesPrivate = session.current?.hidesPrivateContent ?? false
        let libraryID = session.current?.library?.id
        return allLinks.filter { link in
            guard link.deletedAt == nil, !link.isArchived else { return false }
            if hidesPrivate, link.isPrivate { return false }
            if let libraryID, link.library?.id != libraryID { return false }
            return true
        }
    }

    @ViewBuilder
    private var actions: some View {
        Button("Coller un lien") {
            refusal = nil
            isPasting = true
        }
        .buttonStyle(.plain)
        .actionStyle()
        .foregroundStyle(Color.textSecondary)
        .frame(minHeight: Space.minHitTarget)
    }

    // MARK: Une ligne

    private func row(_ link: SavedLink) -> some View {
        HStack(alignment: .top, spacing: Space.s3) {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text(SavedLinkFormat.label(of: link))
                    .headlineStyle()
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Space.s2) {
                    Text(link.urlString)
                        .metaStyle()
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)

                    if fetching.contains(link.id) {
                        Text("Aperçu…")
                            .metaStyle()
                            .foregroundStyle(Color.accent)
                    }
                }

                if let notes = link.notes, !notes.isEmpty {
                    Text(notes)
                        .calloutStyle()
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: Space.s4)

            if let genre = link.genre {
                Text(genre.name)
                    .labelStyle()
                    .foregroundStyle(Color.textTertiary)
            }

            Menu {
                if let url = URL(string: link.urlString), LinkGuard.allows(url) {
                    Link("Ouvrir dans le navigateur", destination: url)
                }
                Button("Rafraîchir l'aperçu") { Task { await refresh(link) } }
                Divider()
                Button("Supprimer", role: .destructive) { delete(link) }
            } label: {
                Image(systemName: Icon.moreActions)
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: Space.minHitTarget, height: Space.minHitTarget)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, Space.s2)
    }

    // MARK: Écriture

    /// Ajoute un signet, **puis** va chercher son aperçu.
    ///
    /// L'ordre compte : écrire d'abord garantit que le lien est conservé même si la requête
    /// échoue, expire ou n'est jamais émise faute de réseau. C'est ce que « l'échec ne bloque
    /// rien et ne remplit rien » veut dire côté écran.
    private func addLink() {
        let trimmed = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let library = session.current?.library else { return }
        guard let url = URL(string: trimmed) else {
            refusal = .missingHost
            isPasting = true
            return
        }
        if let refused = LinkGuard.refusal(for: url) {
            // **Refusé avant l'écriture.** Une adresse que la garde rejette n'a pas à entrer
            // dans la bibliothèque : elle y resterait comme un lien qu'on ne peut jamais
            // ouvrir, et un jour quelqu'un retirerait la garde pour « réparer » l'affichage.
            refusal = refused
            isPasting = true
            return
        }

        // L'écriture passe par le repository : c'est lui qui appelle `refreshDerived()`, donc
        // qui maintient `searchText`. Un signet écrit depuis la vue serait introuvable par la
        // recherche, en silence.
        let link = SavedLinkRepository(context: modelContext)
            .create(urlString: url.absoluteString, in: library)

        draftURL = ""
        refusal = nil
        Task { await refresh(link) }
    }

    /// Va chercher le titre de la page, et ne remplace rien s'il n'apprend rien.
    ///
    /// **Un aperçu déduit n'écrase pas un nom saisi.** `LinkPreview.isDeduced` dit que le
    /// libellé vient de l'adresse et non de la page : l'écrire par-dessus un nom que
    /// l'utilisateur a tapé serait perdre de l'information pour en gagner aucune.
    private func refresh(_ link: SavedLink) async {
        guard let url = URL(string: link.urlString), LinkGuard.allows(url) else { return }
        fetching.insert(link.id)
        defer { fetching.remove(link.id) }

        let service = LinkPreviewService(fetcher: URLSessionLinkFetcher())
        let preview = await service.preview(of: url)
        guard !preview.isDeduced || link.name == nil else { return }

        // `.batched` : l'aperçu arrive quelques centaines de millisecondes après la création,
        // et journaliser « signet modifié » juste après « signet ajouté » raconterait deux
        // gestes là où l'utilisateur n'en a fait qu'un.
        SavedLinkRepository(context: modelContext)
            .update(link, journal: .batched) { $0.name = preview.title }
    }

    private func delete(_ link: SavedLink) {
        SavedLinkRepository(context: modelContext).softDelete(link)
    }

    /// Ce que le refus dit à l'utilisateur. **Il dit quoi faire, pas ce qui est faux** — la
    /// règle du bloc `11a`, et elle vaut aussi pour une adresse.
    private func message(for refusal: LinkRefusal) -> String {
        switch refusal {
        case .unsupportedScheme: "Colle une adresse commençant par http:// ou https://."
        case .missingHost: "Cette adresse est incomplète."
        case .embeddedCredentials: "Retire l'identifiant contenu dans l'adresse."
        case .privateAddress, .localName, .malformedAddress:
            "Cette adresse désigne un appareil de ton réseau local, pas un site web."
        case .tooManyRedirects, .tooLarge: "Cette page n'a pas pu être lue."
        }
    }
}
