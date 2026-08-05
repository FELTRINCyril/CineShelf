import CineShelfCore
import Foundation

// Les deux aides propres aux titres, séparées de la convention d'URL elle-même.
//
// **La séparation n'est pas cosmétique.** `AssetURL` porte une propriété qu'un test doit
// pouvoir verrouiller — le schéma `cineshelf-asset://` n'est pas chargeable par le réseau,
// et c'est le piège qui a rendu toutes les affiches invisibles pendant quatre sessions. Ces
// deux aides, elles, dépendent de `TitleFormat`, donc de la présentation des titres, donc de
// `DesignSystem`. Les garder ensemble obligeait la cible de test à compiler la moitié de la
// fonctionnalité « Titres » pour vérifier une règle d'URL.

extension AssetURL {

    /// L'URL de la jaquette d'un titre, ou `nil` s'il n'en a pas.
    static func poster(for title: Title) -> URL? {
        TitleFormat.primaryAsset(of: title).map { url(for: $0.id, preset: .card) }
    }

    /// L'URL de l'image d'en-tête d'un titre.
    static func backdrop(for title: Title) -> URL? {
        TitleFormat.backdropAsset(of: title).map { url(for: $0.id, preset: .hero) }
    }
}
