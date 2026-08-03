import CineShelfCore
import DesignSystem
import Foundation
import SwiftUI

/// La couture entre `MediaCrop` et ce qu'une vue sait afficher.
///
/// **C'est le seul appelant de `MediaAsset.crop(for:)` en production**, et c'est ce que
/// `L4` avait pour objet : jusqu'ici la méthode existait sans que personne l'appelle,
/// donc chaque média était affiché centré quel que soit le recadrage choisi, et
/// `CropContext.hero` n'était lu nulle part.
///
/// Le calcul lui-même est dans `CineShelfCore` (`CropGeometry`), où il est testable
/// sans vue. Il ne reste ici que la conversion vers les types de `DesignSystem`, qui ne
/// connaît ni `MediaCrop` ni `CropContext`.
enum CropDisplay {

    /// Le recadrage d'un média pour un contexte d'affichage.
    ///
    /// - Parameters:
    ///   - asset: le média. `nil` rend le recadrage neutre.
    ///   - context: le contexte d'affichage. La résolution
    ///     « contexte demandé → `standard` → neutre » est faite par `crop(for:)`.
    /// - Returns: la position, le zoom et le ratio source, prêts pour `MediaThumbnail`.
    static func of(_ asset: MediaAsset?, in context: CropContext) -> MediaCropDisplay {
        guard let asset else { return .neutral }

        let values = asset.crop(for: context)
        let focus = CropGeometry.unitPoint(values)

        // Sans dimensions enregistrées, le composant retombe sur un remplissage
        // centré : `pixelWidth` et `pixelHeight` valent 0 par défaut, et un média
        // importé de travers peut les garder.
        let aspect: Double? =
            asset.pixelWidth > 0 && asset.pixelHeight > 0
            ? Double(asset.pixelWidth) / Double(asset.pixelHeight)
            : nil

        return MediaCropDisplay(
            focus: UnitPoint(x: focus.x, y: focus.y),
            zoom: CropGeometry.fillScale(values),
            sourceAspect: aspect
        )
    }
}
