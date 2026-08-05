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

        return display(of: values, sourceAspect: aspect)
    }

    /// La même conversion, depuis des valeurs **non encore enregistrées**.
    ///
    /// C'est ce dont `CropEditor` a besoin : il pilote un `CropValues` en cours d'édition, qui
    /// n'existe dans aucune ligne `MediaCrop`. Sans cette porte, l'éditeur aurait dû refaire
    /// la conversion `unitPoint` / `fillScale` de son côté — deux chemins vers la même
    /// sémantique, donc deux occasions de diverger, et un aperçu qui ne montrerait pas ce que
    /// la grille montrera.
    static func display(of values: CropValues, sourceAspect: Double?) -> MediaCropDisplay {
        let focus = CropGeometry.unitPoint(values)
        return MediaCropDisplay(
            focus: UnitPoint(x: focus.x, y: focus.y),
            zoom: CropGeometry.fillScale(values),
            sourceAspect: sourceAspect
        )
    }
}
