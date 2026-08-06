import Foundation

// MARK: - L7 · L'aperçu de lien
//
// **La fiche demande `LPMetadataProvider`. Je ne l'utilise pas, et il faut le dire.**
//
// `LPMetadataProvider` va chercher l'URL lui-même : il ouvre la connexion, suit les
// redirections et lit la réponse, sans exposer aucun point de contrôle. Or la protection
// demandée porte **exactement** sur ces trois choses — revalider chaque redirection, borner
// leur nombre, borner les octets lus. Le lui confier reviendrait à valider l'URL collée puis à
// laisser un tiers décider de la suite : un serveur public répondant `302 Location:
// http://127.0.0.1:6379/` obtiendrait précisément ce que la garde existe pour empêcher.
//
// Le fetch passe donc par `URLSession`, dont le délégué **voit chaque redirection avant
// qu'elle parte**. Ce qu'on perd est réel et se mesure : `LPMetadataProvider` rend aussi une
// icône et une image de prévisualisation, là où lire l'en-tête HTML donne un titre et une URL
// d'image à récupérer séparément. C'est un écart à la fiche, inscrit ; le rouvrir demanderait
// soit un `LPMetadataProvider` derrière un mandataire local, soit d'accepter le trou.
//
// **La frontière est un protocole**, comme la fiche l'exige : les tests fournissent un
// fournisseur factice et **aucune sortie réseau n'a lieu**.

/// Ce qu'un aperçu rend, au mieux.
public struct LinkPreview: Sendable, Equatable {
    /// Le titre affiché. **Jamais vide** : à défaut de titre distant, il se déduit de l'URL.
    public let title: String
    /// L'URL de l'image de prévisualisation, si la page en annonce une.
    ///
    /// Une URL et non des octets : la récupérer est une seconde requête, qui passe par la même
    /// garde, et son résultat entre dans `MediaIngestor` comme n'importe quelle image — la
    /// fiche insiste, « elle n'est pas un cas à part ».
    public let imageURL: URL?
    /// L'hôte, tel qu'on l'affiche sous le titre.
    public let sourceLabel: String
    /// L'aperçu vient-il du réseau, ou de l'URL seule ?
    public let isDeduced: Bool

    public init(title: String, imageURL: URL? = nil, sourceLabel: String, isDeduced: Bool) {
        self.title = title
        self.imageURL = imageURL
        self.sourceLabel = sourceLabel
        self.isDeduced = isDeduced
    }

    /// Le repli : un libellé déduit de l'URL seule.
    ///
    /// **Il ne bloque jamais et ne remplit jamais rien de faux.** L'ordre suit ce qui informe
    /// le plus : le dernier segment de chemin s'il en existe un — c'est presque toujours le
    /// nom de la chose —, sinon l'hôte. Les `%20` sont décodés, les tirets et soulignés
    /// redeviennent des espaces, et l'extension saute : `mon-film_2021.html` donne
    /// « mon film 2021 ».
    public static func deduced(from url: URL) -> LinkPreview {
        let host = url.host()?.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
        let segment = url.pathComponents.last { $0 != "/" && !$0.isEmpty }

        var label =
            segment.map { component -> String in
                let withoutExtension =
                    component.contains(".")
                    ? String(component[..<(component.lastIndex(of: ".") ?? component.endIndex)])
                    : component
                return withoutExtension.removingPercentEncoding ?? withoutExtension
            } ?? ""
        label = label.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return LinkPreview(
            title: label.isEmpty ? (host ?? url.absoluteString) : label,
            imageURL: nil,
            sourceLabel: host ?? "",
            isDeduced: true)
    }
}

/// Ce que le service attend d'une source d'aperçus.
///
/// **La frontière**, au sens de la fiche : les tests en fournissent une factice, et rien ne
/// sort. L'implémentation réseau est `URLSessionLinkFetcher`.
public protocol LinkMetadataFetching: Sendable {
    /// - Returns: le titre et l'URL d'image annoncés par la page, ou `nil` si la page n'en
    ///   annonce pas. **Lève** si la requête échoue ou si la garde refuse une redirection.
    func metadata(for url: URL) async throws -> (title: String?, imageURL: URL?)
}

public enum LinkPreviewError: Error, Equatable {
    case refused(LinkRefusal)
    case unreachable
    case timedOut
}

/// Le service : une URL, un aperçu, jamais d'attente indéfinie.
public struct LinkPreviewService: Sendable {
    private let fetcher: any LinkMetadataFetching
    private let timeout: Duration

    public init(fetcher: any LinkMetadataFetching, timeout: Duration = LinkGuard.timeout) {
        self.fetcher = fetcher
        self.timeout = timeout
    }

    /// L'aperçu d'une URL. **Ne lève jamais** : au pire, il déduit.
    ///
    /// C'est la deuxième exigence de la fiche — « l'échec ne bloque rien et ne remplit rien ».
    /// Un aperçu est un confort ; un lien reste utilisable sans lui, et l'utilisateur n'a rien
    /// à réparer. La distinction entre « trouvé » et « déduit » est portée par `isDeduced`,
    /// pour que l'écran puisse la montrer s'il le veut.
    public func preview(of url: URL) async -> LinkPreview {
        let fallback = LinkPreview.deduced(from: url)
        guard LinkGuard.allows(url) else { return fallback }

        do {
            let found = try await withTimeout(timeout) { try await fetcher.metadata(for: url) }
            guard let title = found.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                !title.isEmpty
            else {
                // Une page qui répond sans titre n'est pas un échec : on garde le libellé
                // déduit, et l'image si elle existe.
                return LinkPreview(
                    title: fallback.title, imageURL: found.imageURL,
                    sourceLabel: fallback.sourceLabel, isDeduced: true)
            }
            return LinkPreview(
                title: title, imageURL: found.imageURL,
                sourceLabel: fallback.sourceLabel, isDeduced: false)
        } catch {
            return fallback
        }
    }

    /// Le délai, appliqué **ici** et non délégué au fournisseur.
    ///
    /// `URLSession` a bien un `timeoutIntervalForRequest`, mais il ne couvre pas tout : une
    /// réponse qui arrive octet par octet reste « en cours » indéfiniment. La course garantit
    /// que l'appelant reprend la main en trois secondes quoi qu'il arrive — c'est ce que
    /// « ne bloque jamais l'interface » veut dire.
    private func withTimeout<T: Sendable>(
        _ duration: Duration, _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: duration)
                throw LinkPreviewError.timedOut
            }
            guard let first = try await group.next() else { throw LinkPreviewError.unreachable }
            group.cancelAll()
            return first
        }
    }
}
