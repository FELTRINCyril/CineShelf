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
    /// **Le §11 du handoff dit « Portraits de personnes : aucun »**, et c'est vrai des
    /// *échantillons* du paquet de design — pas du modèle. `MediaAttachment` porte un
    /// `person`, donc une personne peut parfaitement avoir une image, et `V2` en attache
    /// depuis le glisser-déposer.
    ///
    /// > **Corrigé par `V4`, et c'était un chemin mort.** Cet initialiseur ne passait aucune
    /// > `imageURL` : une personne dont l'utilisateur avait attaché un portrait rendait quand
    /// > même ses initiales, partout — recherche, casting, grille. Le repli de `PersonTile`
    /// > est prévu pour l'absence d'image, pas pour la masquer. C'est la même famille que
    /// > « tout échantillon exerce le chemin réel » : ici c'était le code de production qui
    /// > court-circuitait le chemin qu'on croyait couvert.
    init(_ person: Person) {
        self.init(
            id: person.id.uuidString,
            title: person.displayName,
            kind: .person,
            meta: PersonFormat.creditCount(of: person),
            imageURL: AssetURL.portrait(for: person),
            blurHash: PersonFormat.primaryAsset(of: person)?.blurHash,
            crop: CropDisplay.of(PersonFormat.primaryAsset(of: person), in: .card),
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

    /// Le portrait d'une personne, s'il en existe un.
    ///
    /// Même règle de choix que `TitleFormat.primaryAsset` : l'emplacement `primary` d'abord,
    /// sinon la pièce jointe de plus petit rang. Une personne n'a pas d'emplacement
    /// `backdrop` — sa fiche ne pose pas de hero, le bloc `4d` montre un portrait à côté du
    /// nom, pas une image large derrière.
    static func primaryAsset(of person: Person) -> MediaAsset? {
        let attachments = person.attachments ?? []
        let primary =
            attachments
            .filter { $0.slot == .primary }
            .min { $0.orderIndex < $1.orderIndex }
        return (primary ?? attachments.min { $0.orderIndex < $1.orderIndex })?.asset
    }

    /// Les rôles d'une personne, dans l'ordre du bloc `4d` : « Interprétation · Réalisation ».
    static func roleLine(of person: Person) -> String? {
        let ordered: [PersonRole] = [.actor, .director, .writer, .crew, .social]
        let names = ordered.filter(person.roles.contains).map(label(for:))
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }

    static func label(for role: PersonRole) -> String {
        switch role {
        case .actor: "Interprétation"
        case .director: "Réalisation"
        case .writer: "Écriture"
        case .crew: "Équipe"
        case .social: "Compte"
        }
    }

    /// « Né le 25 mai 1976 », « 50 ans », et le cas du décès.
    ///
    /// **L'âge d'un vivant se calcule, celui d'un défunt se lit.** `Person.ageAtDeath` est
    /// dénormalisé sans risque parce qu'il est immuable ; l'âge d'un vivant ne l'est pas, et
    /// le dénormaliser le rendrait faux dès le lendemain. C'est le même raisonnement que les
    /// tranches d'âge de `PersonFilter`, et il doit rendre la même réponse.
    static func lifeParts(of person: Person, now: Date = .now) -> [String] {
        var parts: [String] = []
        if let birth = person.birthDate {
            parts.append("Né le \(birth.formatted(.dateTime.day().month(.wide).year()))")
        }
        if let death = person.deathDate {
            parts.append("Mort le \(death.formatted(.dateTime.day().month(.wide).year()))")
            if let age = person.ageAtDeath { parts.append("\(age) ans au décès") }
        } else if let age = person.age {
            parts.append("\(age) ans")
        }
        return parts
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
