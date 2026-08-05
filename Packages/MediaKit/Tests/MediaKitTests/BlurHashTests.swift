import CoreGraphics
import Foundation
import Testing

@testable import MediaKit

@Suite("BlurHash")
struct BlurHashTests {
    @Test("Un hash 4×3 fait 28 caractères")
    func fourByThreeHasTwentyEightCharacters() throws {
        let image = try TestImage.make(width: 400, height: 300)
        let hash = try BlurHash.encode(image)

        #expect(hash.count == 28)
    }

    @Test("Le premier caractère encode le nombre de composantes")
    func firstCharacterEncodesTheComponentCount() throws {
        let image = try TestImage.make(width: 200, height: 200)

        // (4 - 1) + (3 - 1) × 9 = 21 → « L » en base 83.
        #expect(try BlurHash.encode(image, componentsX: 4, componentsY: 3).first == "L")
        // (2 - 1) + (2 - 1) × 9 = 10 → « A ».
        #expect(try BlurHash.encode(image, componentsX: 2, componentsY: 2).first == "A")
    }

    @Test("Le hash est stable d'un appel à l'autre")
    func hashIsStable() throws {
        let image = try TestImage.make(width: 640, height: 480)

        let first = try BlurHash.encode(image)
        let second = try BlurHash.encode(image)
        #expect(first == second)
    }

    @Test("Deux images différentes donnent deux hash différents")
    func differentImagesDifferentHashes() throws {
        let plain = try TestImage.makeSolid(red: 0.1, green: 0.1, blue: 0.1)
        let bright = try TestImage.makeSolid(red: 0.9, green: 0.2, blue: 0.4)

        let plainHash = try BlurHash.encode(plain)
        let brightHash = try BlurHash.encode(bright)
        #expect(plainHash != brightHash)
    }

    /// La composante continue est la couleur moyenne : c'est elle qui donne le
    /// placeholder, et elle valide le passage sRGB → linéaire → sRGB.
    @Test("La composante continue encode la couleur moyenne")
    func directComponentIsTheAverageColour() throws {
        for (red, green, blue) in [(0.5, 0.25, 0.75), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (0.2, 0.9, 0.35)] {
            let hash = try BlurHash.encode(try TestImage.makeSolid(red: red, green: green, blue: blue))
            let packed = try #require(Base83.decode(String(hash.dropFirst(2).prefix(4))))

            #expect(abs((packed >> 16) - Int((red * 255).rounded())) <= 2)
            #expect(abs(((packed >> 8) & 255) - Int((green * 255).rounded())) <= 2)
            #expect(abs((packed & 255) - Int((blue * 255).rounded())) <= 2)
        }
    }

    /// Vérifie que les axes ne sont pas inversés : une image coupée
    /// verticalement doit charger la composante horizontale, et l'inverse.
    ///
    /// Dans la grille 4 × 3 rangée par rangée, la première composante
    /// alternative est (colonne 1, rangée 0) — horizontale — et la quatrième est
    /// (colonne 0, rangée 1) — verticale.
    @Test("Les axes ne sont pas inversés")
    func axesAreNotSwapped() throws {
        let horizontal = try BlurHash.encode(try TestImage.makeSplit(vertical: false))
        let vertical = try BlurHash.encode(try TestImage.makeSplit(vertical: true))

        let horizontalFirst = try deviation(of: horizontal, componentIndex: 0)
        let horizontalFourth = try deviation(of: horizontal, componentIndex: 3)
        let verticalFirst = try deviation(of: vertical, componentIndex: 0)
        let verticalFourth = try deviation(of: vertical, componentIndex: 3)

        #expect(horizontalFirst > horizontalFourth)
        #expect(verticalFourth > verticalFirst)
    }

    /// La couleur moyenne d'un aplat ne dépend pas du nombre de pixels : le
    /// drapeau de taille, celui d'amplitude et la composante continue concordent.
    @Test("La composante continue d'un aplat ne dépend pas de la taille")
    func directComponentIsScaleIndependent() throws {
        let small = try BlurHash.encode(try TestImage.makeSolid(red: 0.3, green: 0.6, blue: 0.9, side: 64))
        let large = try BlurHash.encode(try TestImage.makeSolid(red: 0.3, green: 0.6, blue: 0.9, side: 512))

        #expect(small.prefix(6) == large.prefix(6))
    }

    @Test("Un nombre de composantes hors bornes est refusé")
    func componentCountIsValidated() throws {
        let image = try TestImage.make(width: 100, height: 100)

        #expect(throws: BlurHashError.unsupportedComponentCount) {
            try BlurHash.encode(image, componentsX: 0, componentsY: 3)
        }
        #expect(throws: BlurHashError.unsupportedComponentCount) {
            try BlurHash.encode(image, componentsX: 4, componentsY: 10)
        }
    }

    /// Écart au neutre de la composante alternative, sommé sur les canaux.
    private func deviation(of hash: String, componentIndex: Int) throws -> Int {
        let pair = String(hash.dropFirst(6 + componentIndex * 2).prefix(2))
        let packed = try #require(Base83.decode(pair))
        let quanta = [packed / (19 * 19), (packed / 19) % 19, packed % 19]
        return quanta.reduce(0) { $0 + abs($1 - 9) }
    }
}

/// Décodeur base 83, côté test uniquement : l'encodeur ne sait pas relire.
private enum Base83 {
    private static let alphabet = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~"
    )

    static func decode(_ text: String) -> Int? {
        var value = 0
        for character in text {
            guard let digit = alphabet.firstIndex(of: character) else { return nil }
            value = value * 83 + digit
        }
        return value
    }
}

// MARK: - L5 · La couleur dominante

@Suite("Couleur dominante d'un blurhash")
struct BlurHashDominantColorTests {

    @Test("La couleur dominante d'une image uniforme est cette couleur")
    func dominantColourOfAFlatImageIsThatColour() throws {
        // Un aplat n'a aucune structure : toutes ses composantes alternantes sont nulles, et
        // la composante continue vaut exactement la couleur. C'est le seul cas où l'on peut
        // asséner une égalité, et c'est pour ça qu'il sert de test d'ancrage.
        let image = try TestImage.makeSolid(red: 0.2, green: 0.6, blue: 0.9)
        let hash = try BlurHash.encode(image)

        let colour = try #require(BlurHash.dominantColor(of: hash))

        // Tolérance d'un cran de quantification : la composante continue est stockée sur
        // 8 bits par canal, donc 1/255 est le pas, et l'échantillonnage à 64 px du côté
        // long ajoute son propre arrondi.
        #expect(abs(colour.red - 0.2) < 0.02)
        #expect(abs(colour.green - 0.6) < 0.02)
        #expect(abs(colour.blue - 0.9) < 0.02)
    }

    @Test("La couleur ne lit que la composante continue, pas la structure")
    func dominantColourIgnoresTheAlternatingComponents() throws {
        let image = try TestImage.makeSolid(red: 0.5, green: 0.5, blue: 0.5)
        let hash = try BlurHash.encode(image)

        // Les six premiers caractères portent la taille, le maximum et la composante
        // continue. Tout ce qui suit décrit la structure : le remplacer ne doit rien changer
        // à la couleur.
        let truncated = String(hash.prefix(6))

        #expect(BlurHash.dominantColor(of: truncated) == BlurHash.dominantColor(of: hash))
    }

    @Test("Une chaîne inexploitable ne rend pas de couleur de secours")
    func unusableHashesYieldNil() {
        // Rendre nil plutôt qu'un gris : fabriquer une couleur ici rendrait un hash corrompu
        // indistinguable d'une image réellement grise, donc impossible à diagnostiquer.
        #expect(BlurHash.dominantColor(of: "") == nil)
        #expect(BlurHash.dominantColor(of: "L6PZf") == nil, "cinq caractères, un de trop peu")
        // « I » et « l » n'appartiennent pas à l'alphabet base 83 aux positions utiles.
        #expect(BlurHash.dominantColor(of: "L6PZ f") == nil, "espace hors alphabet")
    }

    @Test("Un blurhash réel se décode en une couleur plausible")
    func realHashDecodesToSomethingPlausible() throws {
        // Le hash utilisé par les données de démonstration du catalogue.
        let colour = try #require(BlurHash.dominantColor(of: "L6PZfSjE.A"))

        #expect((0...1).contains(colour.red))
        #expect((0...1).contains(colour.green))
        #expect((0...1).contains(colour.blue))
    }
}
