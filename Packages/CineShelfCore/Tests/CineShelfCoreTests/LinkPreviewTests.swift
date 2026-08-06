import Foundation
import Testing

@testable import CineShelfCore

// MARK: - L7 · La garde de la seule sortie réseau du projet
//
// **Aucune requête n'est émise par ces tests**, et la fiche l'exige : la frontière est un
// protocole, le test fournit un fournisseur factice. La garde, elle, est **pure** — elle ne
// fait que lire une URL —, donc elle s'assène sur des dizaines d'entrées sans rien ouvrir.

@Suite("Garde des liens")
struct LinkGuardTests {

    private func url(_ text: String) throws -> URL {
        try #require(URL(string: text))
    }

    @Test("Les schémas autres que http et https sont refusés")
    func onlyHTTPSchemes() throws {
        #expect(LinkGuard.refusal(for: try url("https://exemple.fr/a")) == nil)
        #expect(LinkGuard.refusal(for: try url("http://exemple.fr/a")) == nil)
        // `file:` lirait le disque de l'utilisateur ; le schéma interne du cache d'images n'a
        // rien à faire dans un champ de lien.
        #expect(LinkGuard.refusal(for: try url("file:///etc/passwd")) == .unsupportedScheme)
        #expect(LinkGuard.refusal(for: try url("ftp://exemple.fr/a")) == .unsupportedScheme)
        #expect(
            LinkGuard.refusal(for: try url("cineshelf-asset://abc?preset=card"))
                == .unsupportedScheme)
    }

    @Test("Les adresses privées, locales et de lien-local sont refusées")
    func privateAddressesAreRefused() throws {
        // Chacune de ces cibles est joignable depuis la machine de l'utilisateur et depuis
        // nulle part ailleurs — c'est exactement ce qu'une SSRF cherche.
        let refused = [
            "http://127.0.0.1/", "http://127.9.9.9/", "http://10.0.0.5/admin",
            "http://192.168.1.1/", "http://172.16.0.1/", "http://172.31.255.255/",
            "http://169.254.169.254/latest/meta-data/", "http://100.64.0.1/",
            "http://0.0.0.0/", "http://255.255.255.255/", "http://224.0.0.1/",
            "http://[::1]/", "http://[fe80::1]/", "http://[fc00::1]/", "http://[ff02::1]/",
            // L'IPv4 encapsulée : sans le cas dédié, elle rejoindrait la boucle locale.
            "http://[::ffff:127.0.0.1]/", "http://[::ffff:192.168.0.1]/"
        ]
        for text in refused {
            #expect(
                LinkGuard.refusal(for: try url(text)) == .privateAddress,
                "\(text) devrait être refusée")
        }
    }

    @Test("Les adresses publiques passent, y compris voisines des bornes")
    func publicAddressesPass() throws {
        // **Les voisines des bornes sont le vrai test.** 172.15 et 172.32 encadrent le bloc
        // privé 172.16/12 : un masque écrit de travers les refuserait, et l'utilisateur ne
        // pourrait plus coller un lien parfaitement légitime.
        let allowed = [
            "https://exemple.fr/", "http://9.255.255.255/", "http://11.0.0.1/",
            "http://172.15.255.255/", "http://172.32.0.1/", "http://192.167.1.1/",
            "http://192.169.1.1/", "http://100.63.255.255/", "http://100.128.0.1/",
            "http://126.255.255.255/", "http://128.0.0.1/", "http://[2001:4860:4860::8888]/"
        ]
        for text in allowed {
            #expect(LinkGuard.refusal(for: try url(text)) == nil, "\(text) devrait passer")
        }
    }

    @Test("Les noms locaux et les hôtes sans point sont refusés")
    func localNamesAreRefused() throws {
        for text in [
            "http://localhost/", "http://localhost:8080/", "http://imprimante.local/",
            "http://wiki/", "http://nas.internal/", "http://truc.home.arpa/"
        ] {
            #expect(LinkGuard.refusal(for: try url(text)) == .localName, "\(text)")
        }
        // Un domaine complet passe, même court.
        #expect(LinkGuard.refusal(for: try url("https://a.co/")) == nil)
    }

    @Test("Un identifiant dans l'URL est refusé")
    func credentialsAreRefused() throws {
        // `http://exemple.fr@192.168.1.1/` se lit « exemple.fr » d'un coup d'œil et joint
        // 192.168.1.1 : la confusion est le but. La garde attraperait aussi l'adresse, mais le
        // refus est posé plus tôt et pour son propre motif.
        #expect(
            LinkGuard.refusal(for: try url("http://user:pass@exemple.fr/")) == .embeddedCredentials)
        #expect(
            LinkGuard.refusal(for: try url("http://exemple.fr@192.168.1.1/"))
                == .embeddedCredentials)
    }

    @Test("Les bornes de la fiche sont celles annoncées")
    func limitsMatchTheBrief() {
        #expect(LinkGuard.timeout == .seconds(3))
        #expect(LinkGuard.maximumRedirects == 3)
        #expect(LinkGuard.maximumBytes == 512 * 1_024)
    }
}

// MARK: - L'aperçu

@Suite("Aperçu de lien")
struct LinkPreviewTests {

    /// Le fournisseur factice : **aucune sortie réseau**.
    private struct Stub: LinkMetadataFetching {
        let title: String?
        let imageURL: URL?
        let failure: (any Error)?
        let delay: Duration?

        init(
            title: String? = nil,
            imageURL: URL? = nil,
            failure: (any Error)? = nil,
            delay: Duration? = nil
        ) {
            self.title = title
            self.imageURL = imageURL
            self.failure = failure
            self.delay = delay
        }

        func metadata(for url: URL) async throws -> (title: String?, imageURL: URL?) {
            if let delay { try await Task.sleep(for: delay) }
            if let failure { throw failure }
            return (title, imageURL)
        }
    }

    private func url(_ text: String) throws -> URL { try #require(URL(string: text)) }

    @Test("Le libellé déduit vient du dernier segment, décodé et nettoyé")
    func deducedLabelComesFromThePath() throws {
        // Une URL **quelconque** : ni la racine, ni un segment d'un seul mot. Les valeurs
        // remarquables — « / », « /a » — ne départagent pas les implémentations.
        let preview = LinkPreview.deduced(from: try url("https://www.exemple.fr/films/le-conformiste_1970.html"))
        #expect(preview.title == "le conformiste 1970")
        #expect(preview.sourceLabel == "exemple.fr")
        #expect(preview.isDeduced)

        // Les `%` sont décodés.
        #expect(
            LinkPreview.deduced(from: try url("https://exemple.fr/un%20film%20ancien")).title
                == "un film ancien")
        // Sans segment, l'hôte. C'est le cas dégénéré, couvert **en plus** du nominal.
        #expect(LinkPreview.deduced(from: try url("https://exemple.fr/")).title == "exemple.fr")
    }

    @Test("Un aperçu qui aboutit rend le titre distant")
    func successUsesTheRemoteTitle() async throws {
        let service = LinkPreviewService(fetcher: Stub(title: "Le Conformiste — Arte"))
        let preview = await service.preview(of: try url("https://exemple.fr/films/le-conformiste"))
        #expect(preview.title == "Le Conformiste — Arte")
        #expect(!preview.isDeduced)
    }

    @Test("Un échec ne bloque rien et ne remplit rien de faux")
    func failureFallsBack() async throws {
        // La deuxième exigence de la fiche. Le service **ne lève jamais** : un lien reste
        // utilisable sans aperçu, et l'utilisateur n'a rien à réparer.
        let service = LinkPreviewService(fetcher: Stub(failure: LinkPreviewError.unreachable))
        let preview = await service.preview(of: try url("https://exemple.fr/films/le-conformiste"))
        #expect(preview.title == "le conformiste")
        #expect(preview.isDeduced)
    }

    @Test("Un fournisseur qui n'aboutit pas rend la main au bout du délai")
    func timeoutReleasesTheInterface() async throws {
        // Le délai est appliqué par le service, pas délégué : une réponse qui arrive octet par
        // octet resterait « en cours » indéfiniment côté `URLSession`.
        let service = LinkPreviewService(
            fetcher: Stub(title: "Trop tard", delay: .seconds(10)), timeout: .milliseconds(120))

        let started = ContinuousClock.now
        let preview = await service.preview(of: try url("https://exemple.fr/films/le-conformiste"))
        let elapsed = ContinuousClock.now - started

        #expect(preview.isDeduced)
        #expect(elapsed < .seconds(2), "Le délai n'a pas rendu la main : \(elapsed)")
    }

    @Test("Une URL refusée par la garde n'atteint jamais le fournisseur")
    func refusedURLNeverReachesTheFetcher() async throws {
        // Le contrôle est dans le fournisseur : s'il est appelé, il lève, et le test le verrait
        // par un aperçu déduit… ce qui est aussi le résultat d'un refus. D'où le drapeau.
        final class Spy: LinkMetadataFetching, @unchecked Sendable {
            private let lock = NSLock()
            private var _called = false
            var called: Bool { lock.withLock { _called } }
            func metadata(for url: URL) async throws -> (title: String?, imageURL: URL?) {
                lock.withLock { _called = true }
                return ("Ne devrait pas arriver", nil)
            }
        }

        let spy = Spy()
        let service = LinkPreviewService(fetcher: spy)
        let preview = await service.preview(of: try url("http://192.168.1.1/admin/reboot"))

        #expect(!spy.called, "La garde a laissé passer une adresse privée jusqu'au réseau")
        #expect(preview.isDeduced)
    }

    @Test("Une page sans titre garde le libellé déduit mais son image")
    func missingTitleKeepsTheImage() async throws {
        let image = try url("https://exemple.fr/affiche.jpg")
        let service = LinkPreviewService(fetcher: Stub(title: "   ", imageURL: image))
        let preview = await service.preview(of: try url("https://exemple.fr/films/le-conformiste"))
        #expect(preview.title == "le conformiste")
        #expect(preview.imageURL == image)
        #expect(preview.isDeduced)
    }
}

// MARK: - La lecture d'en-tête

@Suite("Lecture d'en-tête HTML")
struct LinkHeadParsingTests {

    private let base = URL(string: "https://exemple.fr/films/")

    @Test("Le titre vient d'og:title, sinon de <title>")
    func titlePrefersOpenGraph() throws {
        let both = """
            <html><head><title>Secondaire</title>
            <meta property="og:title" content="Le Conformiste"></head>
            """
        #expect(URLSessionLinkFetcher.parse(both, relativeTo: try #require(base)).title == "Le Conformiste")

        let onlyTag = "<html><head><title>Le Conformiste</title></head>"
        #expect(
            URLSessionLinkFetcher.parse(onlyTag, relativeTo: try #require(base)).title
                == "Le Conformiste")

        // Les cinq entités qu'un titre porte vraiment.
        let entities = "<html><head><title>Godard &amp; C&#39;ie</title></head>"
        #expect(
            URLSessionLinkFetcher.parse(entities, relativeTo: try #require(base)).title
                == "Godard & C'ie")
    }

    @Test("Une image annoncée vers une adresse privée est écartée")
    func openGraphImagePassesTheGuard() throws {
        // Une page publique peut très bien pointer son `og:image` vers le réseau local : la
        // seconde requête passerait la garde, mais autant ne pas la proposer.
        let hostile = """
            <html><head><meta property="og:image" content="http://192.168.1.1/pixel.png"></head>
            """
        #expect(URLSessionLinkFetcher.parse(hostile, relativeTo: try #require(base)).imageURL == nil)

        let fine = """
            <html><head><meta property="og:image" content="/affiches/conformiste.jpg"></head>
            """
        let resolved = URLSessionLinkFetcher.parse(fine, relativeTo: try #require(base)).imageURL
        #expect(resolved?.absoluteString == "https://exemple.fr/affiches/conformiste.jpg")
    }

    @Test("Une page sans en-tête exploitable ne rend rien plutôt qu'une valeur inventée")
    func unparsablePageYieldsNothing() throws {
        let parsed = URLSessionLinkFetcher.parse("<html><body>rien</body></html>", relativeTo: try #require(base))
        #expect(parsed.title == nil)
        #expect(parsed.imageURL == nil)
    }
}
