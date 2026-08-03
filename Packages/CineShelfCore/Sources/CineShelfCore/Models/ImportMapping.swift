import Foundation
import SwiftData

/// Une correspondance mémorisée entre les colonnes d'un fichier et les champs de
/// CineShelf.
///
/// **Ce qui l'a rendue nécessaire.** L'addendum 1 du handoff décrit une correspondance
/// « mémorisable pour les fichiers de même en-tête », et la fiche `L11` demandait déjà
/// « un profil de mappage Movix préconfiguré, et l'enregistrement de mappages
/// personnels ». Ni l'un ni l'autre n'avait de support dans le modèle : c'est la passe
/// de fermeture du schéma qui l'a relevé, et c'était le plus gros manque de
/// l'inventaire.
///
/// **Pourquoi une entité synchronisée et non un réglage local.** Un mappage est un
/// travail de l'utilisateur — il a lu son fichier, décidé quelle colonne va où, et il
/// ne veut pas le refaire sur son autre appareil ni après une réinstallation. Le
/// brouillon d'import, lui, reste local : il référence un fichier de **cet** appareil,
/// et « un seul brouillon à la fois » est une notion d'appareil.
///
/// Aucune logique ne le consomme encore : `L11` l'écrira.
@Model
public final class ImportMapping {
    public var id = UUID()

    /// Le nom montré à l'utilisateur. « Movix », « Mon export Numbers »…
    public var name: String = ""

    /// La signature de l'en-tête auquel ce mappage s'applique.
    ///
    /// Les noms de colonnes du fichier, repliés et joints, de façon à reconnaître « le
    /// même en-tête » d'un fichier à l'autre sans dépendre de l'ordre ni de la casse.
    /// La forme exacte appartient à `L11` ; ce champ ne fait que la porter.
    public var headerSignature: String = ""

    /// La correspondance colonne → champ, encodée en JSON.
    ///
    /// Un `Data` plutôt qu'une entité par ligne : le vocabulaire des champs cibles
    /// changera avec les écrans d'import, et il n'a pas à être interrogeable — on lit un
    /// mappage en entier ou pas du tout.
    public var columnMapData: Data?

    /// Livré avec l'app plutôt que composé par l'utilisateur.
    ///
    /// Un mappage intégré ne se supprime pas et se retrouve après une réinstallation ;
    /// `L11` en fournira au moins un, pour Movix.
    public var isBuiltIn: Bool = false

    public var createdAt = Date()
    public var updatedAt = Date()

    /// La bibliothèque d'accueil. Optionnelle comme toutes les relations — contrainte
    /// CloudKit.
    public var library: Library?

    public init(name: String = "", headerSignature: String = "") {
        self.name = name
        self.headerSignature = headerSignature
    }
}
