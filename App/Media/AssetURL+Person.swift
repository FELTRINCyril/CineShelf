import CineShelfCore
import Foundation

extension AssetURL {

    /// L'URL du portrait d'une personne, au cran « carte ».
    ///
    /// **Symétrique de `poster(for:)`**, et écrite par `V4` pour la même raison qu'elle : sans
    /// point d'entrée, chaque appelant recomposerait le choix de la pièce jointe, et les deux
    /// finiraient par diverger.
    static func portrait(for person: Person, preset: AssetPreset = .card) -> URL? {
        PersonFormat.primaryAsset(of: person).map { url(for: $0.id, preset: preset) }
    }
}
