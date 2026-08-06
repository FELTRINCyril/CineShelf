import Foundation

// MARK: - L7 · La seule sortie réseau du projet, et sa garde
//
// **CineShelf ne va nulle part.** Pas de backend, pas d'API, pas de télémétrie : la seule
// requête sortante de toute l'app est celle-ci, et son URL est **fournie par l'utilisateur**.
// C'est la définition d'une SSRF — *Server-Side Request Forgery*, ici côté client : faire
// émettre à l'app une requête vers une cible qu'elle n'aurait jamais choisie.
//
// **Ce que ça permet concrètement, sur une app de bureau.** Coller
// `http://192.168.1.1/admin/reboot` dans le champ « lien » d'un titre, et l'aperçu la
// déclenche depuis le réseau local — depuis la machine de l'utilisateur, avec ses accès.
// Même chose avec `http://127.0.0.1:6379/` (Redis), `http://[::1]:8080/`, ou
// `http://169.254.169.254/latest/meta-data/` (les métadonnées d'instance dans un nuage). Aucune
// de ces cibles n'est joignable depuis l'extérieur ; toutes le sont depuis l'app.
//
// La garde est donc **une liste de refus, pas une liste d'autorisations** — on ne sait pas ce
// que l'utilisateur va légitimement coller —, et elle est **pure** : aucune entrée-sortie, donc
// entièrement testable.

/// Pourquoi une URL est refusée. Un cas par motif, pour que le test dise lequel.
public enum LinkRefusal: String, Sendable, Equatable {
    /// Ni `http` ni `https` — `file:`, `ftp:`, `cineshelf-asset:` et le reste.
    case unsupportedScheme
    /// Aucun hôte : `http:///chemin`.
    case missingHost
    /// `http://utilisateur:motdepasse@hôte` — un identifiant dans une URL collée est soit une
    /// fuite, soit une tentative de confusion sur l'hôte réel.
    case embeddedCredentials
    /// L'hôte est une adresse IP d'un espace non routable sur l'internet public.
    case privateAddress
    /// `localhost`, `*.local`, ou un nom sans point — la machine ou le réseau local.
    case localName
    /// L'hôte se présente comme une adresse IPv4 sans en être une que nous sachions lire —
    /// `0x7f.0.0.1`. Mesuré : le résolveur, lui, la lit, et elle joint la boucle locale.
    case malformedAddress
    /// Plus de redirections que la limite.
    case tooManyRedirects
    /// Réponse plus grosse que la limite.
    case tooLarge
}

/// La politique de sortie réseau. **Aucune entrée-sortie ici** : que des décisions.
public enum LinkGuard {

    /// Le délai d'une requête d'aperçu. Trois secondes, comme la fiche le demande.
    ///
    /// Court exprès : un aperçu est un confort. Au-delà, le repli déduit de l'URL est meilleur
    /// qu'une interface qui attend.
    public static let timeout = Duration.seconds(3)

    /// Le nombre de redirections suivies. **Chacune est revalidée** — c'est tout l'intérêt.
    ///
    /// Sans revalidation, la garde ne servirait à rien : un serveur public qui répond `302
    /// Location: http://127.0.0.1:6379/` obtient exactement ce que le refus des IP privées
    /// voulait empêcher, et l'URL collée, elle, était irréprochable.
    public static let maximumRedirects = 3

    /// La taille maximale d'une réponse : 512 Ko.
    ///
    /// Une page dont on ne lit que l'en-tête `<head>` n'a aucune raison d'être plus lourde, et
    /// la borne protège d'un flux sans fin — un serveur peut répondre indéfiniment.
    public static let maximumBytes = 512 * 1_024

    /// L'URL est-elle acceptable comme cible de requête ?
    ///
    /// - Returns: `nil` si elle est acceptable, le motif de refus sinon.
    public static func refusal(for url: URL) -> LinkRefusal? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return .unsupportedScheme
        }
        guard url.user == nil, url.password == nil else { return .embeddedCredentials }
        guard let host = url.host()?.lowercased(), !host.isEmpty else { return .missingHost }

        if let address = IPAddress(host) {
            return address.isPubliclyRoutable ? nil : .privateAddress
        }
        if isLocalName(host) { return .localName }
        return claimsToBeAddress(host) ? .malformedAddress : nil
    }

    /// L'hôte **prétend** être une adresse IPv4 sans que `IPAddress` ait su la lire.
    ///
    /// **Mesuré le 2026-08-06, contre un serveur de boucle locale**, parce que l'écart inscrit à
    /// `L7` nommait le mauvais exemple. Ce que `URLSession` fait réellement de ces hôtes :
    ///
    /// | Hôte collé | Ce que joint `URLSession` | Ce que la garde en faisait |
    /// |---|---|---|
    /// | `0177.0.0.1` | `177.0.0.1` — publique | acceptée, et **c'est correct** |
    /// | `0300.0250.0.1` | rien, la résolution échoue | acceptée, sans effet |
    /// | `0x7f.0.0.1` | **`127.0.0.1`** | **acceptée — c'était la faille** |
    /// | `2130706433`, `0x7f000001` | `127.0.0.1` | déjà refusées, faute de point |
    ///
    /// L'octal n'était donc pas le sujet : `UInt8("0177")` rend 177, et le résolveur système lit
    /// lui aussi ce segment en décimal. Les deux s'accordent, il n'y avait rien à corriger. C'est
    /// l'**hexadécimal par segments** qui passait, parce que `UInt8("0x7f")` rend `nil` — l'hôte
    /// repartait alors sur le chemin des noms, où son point suffisait à le faire accepter.
    ///
    /// **On ne réimplémente pas le résolveur pour autant** : deux parseurs qui divergent, c'est
    /// la faille suivante. La garde reste une liste de refus — un hôte qui a la *forme* d'une
    /// adresse sans en être une que nous sachions lire est refusé, quelle que soit la notation
    /// qu'il emploie, y compris celles qui n'existent pas encore ici.
    ///
    /// Aucun nom légitime n'est pris au passage : un domaine de tête ne peut pas être
    /// entièrement numérique (RFC 3696 §2), donc `exemple.fr` et `1234.exemple.fr` sortent par
    /// leur dernier segment.
    static func claimsToBeAddress(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        if parts.contains(where: { $0.lowercased().hasPrefix("0x") }) { return true }
        guard let last = parts.last, !last.isEmpty else { return false }
        return last.allSatisfy { $0.isASCII && $0.isNumber }
    }

    public static func allows(_ url: URL) -> Bool { refusal(for: url) == nil }

    /// Les noms qui désignent la machine ou le réseau local sans être des adresses.
    ///
    /// **Un nom sans point est refusé**, et c'est volontairement large : sur un réseau
    /// d'entreprise, `intranet` ou `wiki` résolvent vers l'intérieur par suffixe de recherche
    /// DNS. Un lien légitime collé depuis un navigateur porte toujours un domaine complet.
    static func isLocalName(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".localhost") { return true }
        if host.hasSuffix(".local") || host.hasSuffix(".internal") || host.hasSuffix(".home.arpa") {
            return true
        }
        return !host.contains(".")
    }
}

// MARK: - Les adresses littérales

/// Une adresse IP écrite dans l'URL, et ce qu'on en sait sans réseau.
struct IPAddress {
    enum Family {
        case v4([UInt8])
        case v6([UInt16])
    }
    let family: Family

    /// Reconnaît `192.168.1.1`, `[::1]`, `::ffff:127.0.0.1`. Rend `nil` sur un nom d'hôte.
    init?(_ host: String) {
        // `URL.host()` retire déjà les crochets d'une IPv6, mais pas toutes les sources : on
        // les enlève si elles sont là plutôt que de dépendre de l'appelant.
        let bare = host.hasPrefix("[") && host.hasSuffix("]") ? String(host.dropFirst().dropLast()) : host

        if let v4 = Self.parseIPv4(bare) {
            family = .v4(v4)
        } else if let v6 = Self.parseIPv6(bare) {
            family = .v6(v6)
        } else {
            return nil
        }
    }

    /// L'adresse est-elle sur l'internet public ?
    ///
    /// **Formulée en positif et calculée en négatif** : tout ce qui n'est pas explicitement
    /// écarté passe. L'inverse — une liste d'espaces publics — serait à réviser à chaque
    /// évolution de l'allocation d'adresses, et un oubli y refuserait un lien légitime au lieu
    /// d'ouvrir un trou. Ici un oubli ouvre un trou, ce qui impose d'être exhaustif : les
    /// espaces ci-dessous viennent des registres IANA des adresses à usage spécial.
    var isPubliclyRoutable: Bool {
        switch family {
        case .v4(let bytes): return Self.isPublicIPv4(bytes)
        case .v6(let groups):
            // Une IPv4 encapsulée en IPv6 doit être jugée comme l'IPv4 qu'elle est : sans ce
            // cas, `::ffff:127.0.0.1` passerait la garde et joindrait la boucle locale.
            if let mapped = Self.mappedIPv4(groups) { return Self.isPublicIPv4(mapped) }
            return Self.isPublicIPv6(groups)
        }
    }

    // Un `switch` sur le couple de tête plutôt qu'une suite de `if` : les treize espaces
    // écartés se lisent alors comme le registre IANA dont ils viennent, ligne à ligne.
    // `cyclomatic_complexity` compte les branches et proteste ; la règle est désactivée ici
    // parce que découper la table en deux fonctions la rendrait **moins** lisible, ce qui est
    // le contraire du but sur une liste de refus qu'il faut pouvoir relire d'un bloc.
    // swiftlint:disable:next cyclomatic_complexity
    static func isPublicIPv4(_ bytes: [UInt8]) -> Bool {
        switch (bytes[0], bytes[1]) {
        case (0, _): return false  // 0.0.0.0/8 — « cet hôte »
        case (10, _): return false  // 10/8 — privé
        case (100, 64...127): return false  // 100.64/10 — CGNAT
        case (127, _): return false  // 127/8 — boucle locale
        case (169, 254): return false  // 169.254/16 — lien-local, dont 169.254.169.254
        case (172, 16...31): return false  // 172.16/12 — privé
        case (192, 0): return false  // 192.0.0/24 et 192.0.2/24 — usage spécial et documentation
        case (192, 168): return false  // 192.168/16 — privé
        case (198, 18...19): return false  // 198.18/15 — bancs d'essai
        case (198, 51): return false  // 198.51.100/24 — documentation
        case (203, 0): return false  // 203.0.113/24 — documentation
        case (224...255, _): return false  // multidiffusion, réservé, et 255.255.255.255
        default: return true
        }
    }

    static func isPublicIPv6(_ groups: [UInt16]) -> Bool {
        if groups.allSatisfy({ $0 == 0 }) { return false }  // :: — non spécifiée
        // ::1 — boucle locale. Comparée en bloc plutôt qu'en huit clauses : la forme longue
        // dépassait la ligne et cassait le placement d'accolade que le lint exige.
        if groups == [0, 0, 0, 0, 0, 0, 0, 1] { return false }
        if groups[0] & 0xFE00 == 0xFC00 { return false }  // fc00::/7 — usage local unique
        if groups[0] & 0xFFC0 == 0xFE80 { return false }  // fe80::/10 — lien-local
        if groups[0] & 0xFF00 == 0xFF00 { return false }  // ff00::/8 — multidiffusion
        if groups[0] == 0x2001, groups[1] == 0x0DB8 { return false }  // 2001:db8::/32 — documentation
        return true
    }

    /// Les seize derniers bits d'une `::ffff:a.b.c.d`, ou `nil`.
    static func mappedIPv4(_ groups: [UInt16]) -> [UInt8]? {
        guard groups[0] == 0, groups[1] == 0, groups[2] == 0, groups[3] == 0, groups[4] == 0, groups[5] == 0xFFFF else {
            return nil
        }
        return [UInt8(groups[6] >> 8), UInt8(groups[6] & 0xFF), UInt8(groups[7] >> 8), UInt8(groups[7] & 0xFF)]
    }

    static func parseIPv4(_ text: String) -> [UInt8]? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var bytes: [UInt8] = []
        for part in parts {
            // `UInt8(part)` refuse « 256 », « 01a » et « 0x7f », mais **accepte les zéros
            // initiaux** : `UInt8("0177")` rend 177. Ce n'est pas un défaut — mesuré, le
            // résolveur système lit lui aussi `0177` en décimal, donc les deux s'accordent.
            // Ce que ce parseur ne lit pas repart vers `claimsToBeAddress`, qui le refuse
            // plutôt que de le laisser passer pour un nom.
            guard let value = UInt8(part) else { return nil }
            bytes.append(value)
        }
        return bytes
    }

    static func parseIPv6(_ text: String) -> [UInt16]? {
        guard text.contains(":") else { return nil }

        // Forme mixte `::ffff:192.168.0.1` : la queue IPv4 devient deux groupes.
        var body = text
        if let lastColon = body.lastIndex(of: ":"), body[body.index(after: lastColon)...].contains(".") {
            let tail = String(body[body.index(after: lastColon)...])
            guard let v4 = parseIPv4(tail) else { return nil }
            let high = UInt16(v4[0]) << 8 | UInt16(v4[1])
            let low = UInt16(v4[2]) << 8 | UInt16(v4[3])
            body =
                String(body[..<body.index(after: lastColon)])
                + String(format: "%x:%x", high, low)
        }

        let halves = body.components(separatedBy: "::")
        guard halves.count <= 2 else { return nil }

        func groups(_ part: String) -> [UInt16]? {
            guard !part.isEmpty else { return [] }
            var result: [UInt16] = []
            for chunk in part.split(separator: ":", omittingEmptySubsequences: false) {
                guard !chunk.isEmpty, chunk.count <= 4, let value = UInt16(chunk, radix: 16) else {
                    return nil
                }
                result.append(value)
            }
            return result
        }

        guard let head = groups(halves[0]) else { return nil }
        if halves.count == 1 {
            return head.count == 8 ? head : nil
        }
        guard let tail = groups(halves[1]), head.count + tail.count <= 7 else { return nil }
        return head + Array(repeating: 0, count: 8 - head.count - tail.count) + tail
    }
}
