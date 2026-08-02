import CryptoKit
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import MediaKit

@Suite("Ingestion")
struct MediaIngestorTests {
    @Test("Une image trop grande est ramenée à 2 000 px sur le grand côté")
    func oversizedImageIsResized() throws {
        let source = try TestImage.makePNGData(width: 3000, height: 2000)
        let result = try MediaIngestor().ingest(data: source)

        #expect(result.pixelWidth == 2000)
        #expect(result.pixelHeight == 1333)
    }

    @Test("Une image déjà petite n'est pas agrandie")
    func smallImageKeepsItsSize() throws {
        let source = try TestImage.makePNGData(width: 800, height: 600)
        let result = try MediaIngestor().ingest(data: source)

        #expect(result.pixelWidth == 800)
        #expect(result.pixelHeight == 600)
    }

    @Test("La sortie est du HEIC, et byteSize décrit ces octets-là")
    func outputIsHEIC() throws {
        let source = try TestImage.makePNGData(width: 1200, height: 900)
        let result = try MediaIngestor().ingest(data: source)

        #expect(result.mimeType == "image/heic")
        #expect(result.byteSize == result.data.count)

        let imageSource = try #require(CGImageSourceCreateWithData(result.data as CFData, nil))
        let type = try #require(CGImageSourceGetType(imageSource) as String?)
        #expect(type == UTType.heic.identifier)
    }

    @Test("Le HEIC produit pèse moins que la source")
    func heicIsSmallerThanSource() throws {
        let source = try TestImage.makePNGData(width: 2400, height: 1600)
        let result = try MediaIngestor().ingest(data: source)

        #expect(result.byteSize < source.count)
    }

    @Test("Le checksum est le sha256 des octets source")
    func checksumIsSourceSHA256() throws {
        let source = try TestImage.makePNGData(width: 640, height: 480)
        let result = try MediaIngestor().ingest(data: source)
        let expected = SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()

        #expect(result.checksum == expected)
        #expect(result.checksum.count == 64)
    }

    @Test("Deux ingestions de la même source donnent le même checksum et le même blurhash")
    func ingestionIsStable() throws {
        let source = try TestImage.makePNGData(width: 1000, height: 1000)
        let ingestor = MediaIngestor()
        let first = try ingestor.ingest(data: source)
        let second = try ingestor.ingest(data: source)

        #expect(first.checksum == second.checksum)
        #expect(first.blurHash == second.blurHash)
    }

    @Test("Deux images différentes ont des checksums différents")
    func differentImagesDifferentChecksums() throws {
        let ingestor = MediaIngestor()
        let first = try ingestor.ingest(data: try TestImage.makePNGData(width: 400, height: 400))
        let second = try ingestor.ingest(data: try TestImage.makePNGData(width: 401, height: 400))

        #expect(first.checksum != second.checksum)
    }

    @Test("L'ingestion depuis un fichier donne le même résultat que depuis des données")
    func fileAndDataAgree() throws {
        let directory = try TestImage.makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = try TestImage.makePNGData(width: 900, height: 1200)
        let file = directory.appendingPathComponent("source.png")
        try source.write(to: file)

        let ingestor = MediaIngestor()
        let fromData = try ingestor.ingest(data: source)
        let fromFile = try ingestor.ingest(fileURL: file)

        #expect(fromData.checksum == fromFile.checksum)
        #expect(fromData.blurHash == fromFile.blurHash)
        #expect(fromData.pixelWidth == fromFile.pixelWidth)
    }

    @Test("Des octets qui ne sont pas une image sont refusés")
    func garbageIsRejected() {
        let garbage = Data("ceci n'est pas une image".utf8)

        #expect(throws: MediaIngestionError.unreadableSource) {
            try MediaIngestor().ingest(data: garbage)
        }
        #expect(throws: MediaIngestionError.unreadableSource) {
            try MediaIngestor().ingest(data: Data())
        }
    }

    @Test("Le draft reprend tout ce que le modèle doit stocker")
    func draftCarriesEveryField() throws {
        let source = try TestImage.makePNGData(width: 1500, height: 1000)
        let result = try MediaIngestor().ingest(data: source)
        let draft = result.draft

        #expect(draft.kind == .image)
        #expect(draft.data == result.data)
        #expect(draft.mimeType == "image/heic")
        #expect(draft.pixelWidth == result.pixelWidth)
        #expect(draft.pixelHeight == result.pixelHeight)
        #expect(draft.byteSize == result.byteSize)
        #expect(draft.blurHash == result.blurHash)
        #expect(draft.checksum == result.checksum)
    }
}
