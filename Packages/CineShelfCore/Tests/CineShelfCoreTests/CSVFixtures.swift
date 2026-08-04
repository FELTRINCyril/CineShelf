import Foundation

@testable import CineShelfCore

// Les fichiers d'exemple, partagés par toutes les suites de transfert.
//
// Extraits de `CSVMappingTests` quand le fichier a dépassé la limite du lint : ils servaient déjà
// quatre suites, et un montage partagé n'a rien à faire dans la première qui s'en est servie.

/// Un CSV **échappé**, comme un vrai fichier.
///
/// La première version joignait les champs par `;` sans échapper quoi que ce soit. C'était
/// voulu — ne pas dépendre de l'écrivain qu'on éprouve — et c'était un piège : toute valeur
/// contenant le séparateur ou un guillemet était détruite avant d'atteindre le lecteur, donc
/// aucun test employant ce montage ne pouvait exercer ce cas. Une revue l'a montré sur le
/// chemin de reprise d'un brouillon, où « Dune; ou le désert » se coupait en deux.
///
/// Le format brut — BOM, `CRLF`, point-virgule — reste vérifié octet par octet par
/// `CSVWriterTests`, qui n'utilise pas ce montage.
func csv(header: [String], rows: [[String]]) -> Data {
    CSVWriter().data(header: header, rows: rows)
}

/// Un CSV **non échappé et non complété**, pour les cas qu'un écrivain correct ne produit pas.
///
/// `CSVWriter.data(header:rows:)` complète les lignes trop courtes à la largeur de l'en-tête —
/// c'est son contrat — donc il est incapable de fabriquer la ligne à colonnes manquantes dont
/// certains tests ont besoin. Les octets sont alors écrits à la main, et le test le dit.
func rawCSV(_ lines: [String], newline: String = "\r\n") -> Data {
    CSVWriter.byteOrderMark + Data((lines.joined(separator: newline) + newline).utf8)
}
