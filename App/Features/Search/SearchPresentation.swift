import CineShelfCore
import DesignSystem
import Foundation

// MARK: - V1 · Les modèles de présentation des personnes et des collections
//
// `TitlePresentation` existait déjà pour les titres. Ni les personnes ni les collections
// n'en avaient : l'accueil et la grille ne rendent que des titres, et `V1` est le premier
// écran qui montre les quatre types côte à côte.
//
// **Ils vivent ici et pas dans `DesignSystem`** pour la même raison que
// `TitlePresentation` : le package ne connaît ni `Person` ni `TitleCollection`, et ne
// localise rien. C'est l'app qui formate « 9 titres ».
//
// **Ils seront réutilisés par `V4` et `V5b`**, qui livreront les écrans Personnes et
// Collections. Les y déplacer alors serait un renommage de fichier, pas une réécriture —
// c'est pour ça qu'ils ne portent aucune trace de la recherche.

extension PosterCardModel {

    /// Construit la carte d'une personne.
    ///
    /// **Aucun portrait n'existe encore** : le §11 du handoff dit « Portraits de personnes :
    /// aucun. Les fiches personne utilisent une affiche recadrée. » `PersonTile` se replie
    /// donc sur les initiales, ce qui est son comportement prévu et non un manque.
    init(_ person: Person) {
        self.init(
            id: person.id.uuidString,
            title: person.displayName,
            meta: PersonFormat.creditCount(of: person),
            isPrivate: person.isPrivate,
            isArchived: person.isArchived
        )
    }
}

extension CollectionTileModel {

    /// Construit la tuile d'une collection, mosaïque de repli comprise.
    ///
    /// La mosaïque se compose **à l'affichage**, depuis les jaquettes des titres déjà
    /// présents : `L6` (générer un `MediaAsset` de mosaïque) est reportée en v1.1, et le
    /// repli calculé est le design retenu, pas un pis-aller.
    init(_ collection: TitleCollection) {
        let titles = collection.titles ?? []
        self.init(
            id: collection.id.uuidString,
            name: collection.name,
            countLabel: CollectionFormat.titleCount(of: collection),
            coverURL: nil,
            artwork: titles.prefix(4).compactMap(AssetURL.poster(for:)),
            isPrivate: collection.isPrivate
        )
    }
}

// MARK: - Le formatage

enum PersonFormat {

    /// « 9 titres », comme le bloc `5b` l'écrit sous chaque cercle.
    ///
    /// `nil` quand la personne n'a aucun crédit : une ligne « 0 titre » sous un visage n'est
    /// pas une information, c'est du bruit — et `PersonTile` réserve la place de la légende
    /// même vide, donc la rangée ne se désaligne pas.
    static func creditCount(of person: Person) -> String? {
        let count = person.credits?.count ?? 0
        guard count > 0 else { return nil }
        return count == 1 ? "1 titre" : "\(count) titres"
    }
}

enum CollectionFormat {

    /// « 12 titres ». Même règle que pour les personnes.
    static func titleCount(of collection: TitleCollection) -> String? {
        let count = collection.titles?.count ?? 0
        guard count > 0 else { return nil }
        return count == 1 ? "1 titre" : "\(count) titres"
    }
}

enum SavedLinkFormat {

    /// Le libellé lisible d'un signet.
    ///
    /// `name` quand il existe, sinon l'URL — et jamais une chaîne vide : un signet sans nom
    /// ni URL lisible n'apparaîtrait alors que comme une ligne blanche cliquable. La même
    /// règle de repli que `L7` applique à l'aperçu de lien.
    static func label(of link: SavedLink) -> String {
        if let name = link.name, name.isEmpty == false { return name }
        return link.urlString.isEmpty ? "Lien sans adresse" : link.urlString
    }
}
