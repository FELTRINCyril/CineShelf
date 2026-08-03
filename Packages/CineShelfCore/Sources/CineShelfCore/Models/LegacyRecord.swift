import Foundation
import SwiftData

/// Le lien entre une entité native et l'enregistrement de la version web dont elle
/// vient.
///
/// ## Pourquoi ce n'est pas une précaution
///
/// Le mode de défaillance à couvrir n'est pas « la migration a planté » — ça se voit
/// tout de suite et on recommence. C'est **« trois semaines plus tard, je remarque que
/// les dates de sortie sont toutes au 1er janvier »** : la même classe de bug que celle
/// déjà trouvée dans l'éditeur de la v1. À ce moment-là il faut **réconcilier**, pas
/// réimporter — comparer champ à champ avec la source et corriger ce qui a été traduit
/// de travers, sans toucher à ce que l'utilisateur a saisi depuis.
///
/// Sans ce lien, c'est impossible : rien ne dit quelle `Person` native vient de quel
/// `actor` web, donc rien ne permet de recouper.
///
/// « Effacer et recommencer » n'est une issue que tant que **CloudKit est éteint**.
/// Après le prompt 21, effacer le magasin est une destruction qui se propage à tous les
/// appareils. La fenêtre où l'on peut s'en passer se referme donc avant celle du
/// schéma.
///
/// ## Ce qu'il n'est pas
///
/// Ce n'est pas un identifiant permanent posé sur chaque entité : c'est une table à
/// côté, qui ne pollue aucun modèle métier et qui **se purge par une action
/// explicite**, quand l'utilisateur juge la migration acquise. Jamais automatiquement —
/// une purge silencieuse retirerait le recours au moment précis où l'on en aurait
/// besoin.
///
/// Aucune logique ne l'écrit encore : `L13` s'en chargera, et s'en servira aussi pour
/// rendre le rapport de vérification **spécifique** — nommer les enregistrements
/// manquants au lieu d'annoncer un écart de compte — et pour mécaniser la comparaison
/// champ à champ des cinquante titres de `docs/02` §7 étape 3.
@Model
public final class LegacyRecord {
    public var id = UUID()

    /// Le type d'entité visé, en `rawValue` d'`ActivityEntityType`.
    ///
    /// La même énumération que le fil d'activité : deux vocabulaires pour désigner les
    /// mêmes entités divergeraient, et celui-ci est déjà choisi stable.
    public var entityTypeRaw: String = ""

    /// L'identifiant de l'entité native.
    public var entityID = UUID()

    /// La table et la clé primaire d'origine, telles qu'elles étaient dans le dump web.
    ///
    /// Une chaîne et non un entier : la v1 mêlait des clés numériques et des
    /// identifiants textuels selon les tables, et normaliser à l'import ferait perdre
    /// exactement ce qu'on cherche à conserver — la trace de la source.
    public var legacyTable: String = ""
    public var legacyID: String = ""

    /// Quand l'entité a été importée.
    public var importedAt = Date()

    public init() {}
}

extension LegacyRecord {
    public var entityType: ActivityEntityType? { ActivityEntityType(rawValue: entityTypeRaw) }
}
