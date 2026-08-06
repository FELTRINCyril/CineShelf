import Foundation

// MARK: - L7 · Le seul code du projet qui ouvre une connexion
//
// Trois bornes, et chacune ferme un chemin d'attaque distinct :
//
// | Borne | Ce qu'elle empêche |
// |---|---|
// | l'URL passe `LinkGuard` | joindre le réseau local depuis l'URL collée |
// | **chaque redirection est revalidée** | y arriver par un rebond depuis un serveur public |
// | 512 Ko et 3 s | un flux sans fin, qui n'a pas besoin d'être malveillant pour nuire |
//
// **La deuxième est celle qu'on oublie**, et c'est elle qui interdisait `LPMetadataProvider` :
// il n'expose aucun point de contrôle sur les redirections. Ici le délégué les voit **avant**
// qu'elles partent, et rendre `nil` à `completionHandler` annule le rebond.
//
// **Ce qui reste ouvert, et qui ne se ferme pas à ce niveau** : un nom d'hôte public qui
// *résout* vers une adresse privée. La garde travaille sur le texte de l'URL ; la résolution
// DNS a lieu dans `URLSession`, qui n'expose pas l'adresse retenue. Fermer ce chemin
// demanderait de résoudre soi-même puis de forcer la connexion sur l'adresse validée — ce que
// `URLSession` ne permet pas sans descendre d'un étage. Inscrit comme écart.

/// La source d'aperçus réelle. Rien d'autre du projet ne fait de requête sortante.
public final class URLSessionLinkFetcher: NSObject, LinkMetadataFetching, @unchecked Sendable {

    private let configuration: URLSessionConfiguration

    /// - Parameter configuration: injectée pour que les tests puissent poser un protocole
    ///   d'URL factice. **Par défaut éphémère** : un aperçu n'a aucune raison d'écrire un
    ///   cookie ni un cache sur le disque de l'utilisateur.
    public init(configuration: URLSessionConfiguration = .ephemeral) {
        self.configuration = configuration
        super.init()
    }

    public func metadata(for url: URL) async throws -> (title: String?, imageURL: URL?) {
        if let refusal = LinkGuard.refusal(for: url) { throw LinkPreviewError.refused(refusal) }

        let configuration = self.configuration
        configuration.timeoutIntervalForRequest = 3
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never

        let delegate = RedirectGuard()
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        // Un `User-Agent` honnête plutôt qu'un navigateur imité : un serveur qui refuse un
        // client identifié a le droit de le faire, et se déguiser pour passer serait décider à
        // sa place.
        request.setValue("CineShelf/1.0 (aperçu de lien)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let (bytes, response) = try await session.bytes(for: request)
        if let refusal = delegate.refusal { throw LinkPreviewError.refused(refusal) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LinkPreviewError.unreachable
        }
        // La taille annoncée est un premier filtre, mais elle **ment ou manque** souvent : la
        // borne qui compte est celle qui compte les octets reçus, plus bas.
        if http.expectedContentLength > Int64(LinkGuard.maximumBytes) {
            throw LinkPreviewError.refused(.tooLarge)
        }

        return Self.parse(try await Self.head(of: bytes), relativeTo: http.url ?? url)
    }

    /// Lit au plus 512 Ko, et s'arrête à `</head>` si elle arrive avant.
    ///
    /// **Un flux et non `data(for:)`** : `data(for:)` lit tout avant de rendre la main, donc la
    /// borne n'existerait qu'après coup — sur une réponse de dix gigaoctets, elle arriverait
    /// dix gigaoctets trop tard.
    static func head(of bytes: URLSession.AsyncBytes) async throws -> String {
        var buffer = Data()
        buffer.reserveCapacity(16 * 1_024)

        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= LinkGuard.maximumBytes { break }
            // Tout ce qu'on cherche est dans l'en-tête. S'arrêter là évite de télécharger le
            // corps d'une page de deux cents kilooctets pour en lire les quarante premiers.
            guard buffer.count.isMultiple(of: 512) else { continue }
            let text = String(data: buffer, encoding: .utf8)
            if text?.range(of: "</head>", options: .caseInsensitive) != nil { break }
        }
        return String(data: buffer, encoding: .utf8) ?? ""
    }

    /// Le titre et l'image annoncés par la page.
    ///
    /// **Une lecture d'en-tête, pas un analyseur HTML.** On cherche trois motifs connus dans un
    /// texte : `og:title`, `<title>`, `og:image`. Écrire un analyseur complet pour lire trois
    /// balises serait disproportionné, et une expression régulière sur un HTML arbitraire est
    /// faillible — c'est acceptable ici parce que **l'échec est prévu** : à défaut de titre, le
    /// libellé se déduit de l'URL, et rien ne casse.
    static func parse(_ html: String, relativeTo base: URL) -> (title: String?, imageURL: URL?) {
        let title = meta(html, property: "og:title") ?? tag(html, "title")
        let image = meta(html, property: "og:image").flatMap { URL(string: $0, relativeTo: base) }
        // L'image annoncée passe la **même** garde : une page publique peut très bien pointer
        // son `og:image` vers `http://192.168.1.1/`.
        return (title.map(decodeEntities), image.flatMap { LinkGuard.allows($0) ? $0 : nil })
    }

    static func meta(_ html: String, property: String) -> String? {
        let pattern =
            "<meta[^>]+(?:property|name)=[\"']\(property)[\"'][^>]+content=[\"']([^\"']+)[\"']"
        return firstMatch(html, pattern)
    }

    static func tag(_ html: String, _ name: String) -> String? {
        firstMatch(html, "<\(name)[^>]*>([^<]+)</\(name)>")
    }

    static func firstMatch(_ text: String, _ pattern: String) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            match.numberOfRanges > 1,
            let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Les cinq entités que tout titre HTML contient. Pas plus : `&nbsp;` et les milliers
    /// d'autres ne changent pas la lisibilité d'un libellé.
    static func decodeEntities(_ text: String) -> String {
        var result = text
        for (entity, character) in [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'")
        ] {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result
    }
}

/// Le délégué qui revalide chaque redirection.
private final class RedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var hops = 0
    private var _refusal: LinkRefusal?

    var refusal: LinkRefusal? { lock.withLock { _refusal } }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        lock.withLock { hops += 1 }
        let count = lock.withLock { hops }

        if count > LinkGuard.maximumRedirects {
            lock.withLock { _refusal = .tooManyRedirects }
            return completionHandler(nil)
        }
        guard let url = request.url else {
            lock.withLock { _refusal = .missingHost }
            return completionHandler(nil)
        }
        if let refusal = LinkGuard.refusal(for: url) {
            lock.withLock { _refusal = refusal }
            // **`nil` annule le rebond** : la requête se termine sur la réponse de
            // redirection elle-même, et rien n'est envoyé à la cible refusée.
            return completionHandler(nil)
        }
        completionHandler(request)
    }
}
