import Foundation

// MARK: - L5 · La couleur dominante d'un média
//
// **C'est un décodeur, pas un champ**, et c'est ce qui permet de l'ajouter après la
// fermeture du schéma du 2026-08-03 : la donnée existe déjà dans `MediaAsset.blurHash`, et
// rien n'a besoin d'être écrit en base ni migré.
//
// La planche 7 demande de remplacer la trame rayée des squelettes de chargement par la
// couleur dominante de l'image. Le blurhash porte cette couleur **dans sa première
// composante** : le terme continu d'une transformée en cosinus est, par construction, la
// moyenne du signal. Les quatre caractères qui la codent suffisent, et le reste du hash —
// les composantes alternantes, qui décrivent la structure — n'est pas lu.
//
// Assigné ici par `I4`. `TileSkeleton` gagnera un paramètre de couleur quand le travail
// d'interface l'atteindra ; ce lot ne livre que le producteur.

/// Trois composantes sRGB, sans dépendre de SwiftUI.
///
/// `MediaKit` ne connaît pas `Color` : les composantes traversent la frontière, et c'est
/// l'app qui construit la couleur — même couture que `ProfileAccent` et `MediaCropDisplay`.
///
/// **Nommé « composantes » et non « couleur », et la règle de lint l'a imposé.** Un nom en
/// `…Color` suivi d'un premier paramètre `red:` contient, à la lettre, le motif que
/// `no_literal_color` cherche — la règle mord donc sur le nom de type comme sur une couleur
/// écrite en dur, y compris dans un commentaire, puisqu'elle n'en exclut aucun. Elle a
/// raison sur le fond : ce package ne produit pas de couleurs, il produit trois nombres que
/// `DesignSystem` seul a le droit de changer en couleur.
public struct RGBComponents: Sendable, Equatable {
    /// 0...1, dans l'espace sRGB — donc déjà encodées avec leur gamma, prêtes à afficher.
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

extension BlurHash {

    /// La couleur moyenne codée par la première composante d'un blurhash.
    ///
    /// - Returns: `nil` si la chaîne n'est pas un blurhash exploitable. **Rendre `nil`
    ///   plutôt qu'un gris de secours** : l'appelant a déjà un repli légitime
    ///   (`bg.surface`), et fabriquer une couleur ici rendrait un hash corrompu
    ///   indistinguable d'une image réellement grise.
    public static func dominantColor(of hash: String) -> RGBComponents? {
        // Un blurhash valide fait 6 caractères au minimum : 1 de taille, 1 de maximum, et
        // 4 pour la composante continue. Elle est la seule qu'on lit.
        guard hash.count >= 6 else { return nil }

        let digits = Array(hash)
        guard let packed = decodeBase83(digits[2..<6]) else { return nil }

        // Les trois octets sont déjà en sRGB : l'encodeur les a produits avec
        // `linearTo8Bit`, donc le gamma est appliqué. Pas de conversion au retour.
        return RGBComponents(
            red: Double((packed >> 16) & 0xFF) / 255,
            green: Double((packed >> 8) & 0xFF) / 255,
            blue: Double(packed & 0xFF) / 255
        )
    }

    /// - Returns: `nil` dès qu'un caractère n'appartient pas à l'alphabet base 83.
    private static func decodeBase83(_ digits: ArraySlice<Character>) -> Int? {
        var value = 0
        for digit in digits {
            guard let index = alphabet.firstIndex(of: digit) else { return nil }
            value = value * 83 + index
        }
        return value
    }
}
