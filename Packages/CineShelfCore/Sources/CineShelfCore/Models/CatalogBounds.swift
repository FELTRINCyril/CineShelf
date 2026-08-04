import Foundation

/// Les bornes de valeurs du catalogue, en un seul endroit.
///
/// **Pourquoi elles sortent de `BulkEditor`.** Elles y étaient nées avec `L10`, et `L11a`
/// en a besoin pour valider un CSV : deux copies auraient divergé au premier ajustement, et
/// la divergence aurait ce visage-là — l'édition en masse accepte une note de 9, l'import la
/// refuse, et rien ne dit laquelle a raison. Les bornes appartiennent au **catalogue**, pas
/// à l'un de ses écrivains.
///
/// Chaque borne cite sa source, et aucune ne vient de l'intuition.
public enum CatalogBounds {

    /// L'année de sortie. Source : addendum d'import, « Année attendue entre 1888 et 2030 ».
    ///
    /// 1888 est celle de *Roundhay Garden Scene*, le plus ancien film connu. La borne haute
    /// laisse la place aux sorties annoncées.
    public static let years = 1888...2030

    /// La note du catalogue. Source : `docs/02` §3.3, « Note du catalogue, 0–10 ».
    ///
    /// **Sur 10 et non sur 5.** L'affichage en cinq étoiles est une conversion de
    /// présentation (`TitleFormat.fiveStarRating`), pas une contrainte de modèle : la
    /// planche 6 du design décrit le rendu. Borner à `0...5` ici refuserait la moitié de
    /// l'échelle à l'import — c'était un bug de `L10`, corrigé le 2026-08-04.
    public static let ratings = 0.0...10.0

    /// La durée, en minutes. Une au moins.
    ///
    /// Borne haute large et non absente : la validation d'un CSV a besoin d'un intervalle
    /// fermé pour dire « attendu entre tant et tant », et *Logistics* dure 51 420 minutes.
    /// 100 000 laisse la place à plus long sans jamais accepter un nombre qui serait une
    /// autre colonne mal placée.
    public static let runtimeMinutes = 1...100_000

    /// Saisons et épisodes d'une série. Au moins un, sinon ce n'est pas une saison.
    public static let seasonCount = 1...1_000
    public static let episodeCount = 1...100_000
}
