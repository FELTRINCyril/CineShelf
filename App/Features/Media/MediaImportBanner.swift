import CineShelfCore
import DesignSystem
import SwiftUI

// MARK: - V2 · Le compte rendu d'un import, en bandeau
//
// **`Banner` trouve ici son premier appelant réel.** `I10` l'avait livré sans foyer : les
// quatre cas de la planche `9c` appartiennent à `V10` (hors ligne, synchronisation, quota) et
// à `V8` (fin d'import CSV). Un import d'images en est un cinquième, et il coche la définition
// du bloc — une interruption qui laisse le contenu utilisable.
//
// Extrait de `TitleDetailView` parce que la règle `type_body_length` l'a refusé à 317 lignes,
// et elle a raison : ce compte rendu n'a rien à voir avec la fiche, il servira à la galerie et
// à l'éditeur de la même façon.

/// Le bandeau qui rend compte d'un import, et disparaît quand on le renvoie.
struct MediaImportBanner: View {
    @Binding var report: MediaImportOutcome?

    var body: some View {
        if let report, report.isEmpty == false {
            Banner(
                kind: report.failures.isEmpty ? "Images" : "Import partiel",
                text: LocalizedStringKey(Self.summary(of: report)),
                tone: report.failures.isEmpty ? .success : .danger,
                dismiss: { self.report = nil })
        }
    }

    /// Le compte rendu, et il **nomme** ce qui a échoué.
    ///
    /// « 2 refusées » ne dit pas quoi refaire. Le bloc `11e` de l'addendum nomme ses causes une
    /// par une, et un import d'images n'a aucune raison d'être moins précis.
    ///
    /// Le dédoublonnage est dit séparément de l'ajout : « 3 images ajoutées » quand deux
    /// existaient déjà ferait croire à cinq nouvelles.
    static func summary(of outcome: MediaImportOutcome) -> String {
        var parts: [String] = []
        let added = outcome.attached.count - outcome.deduplicated
        if added > 0 {
            parts.append(added == 1 ? "1 image ajoutée" : "\(added) images ajoutées")
        }
        if outcome.deduplicated > 0 {
            parts.append(
                outcome.deduplicated == 1
                    ? "1 déjà présente, retrouvée par son empreinte"
                    : "\(outcome.deduplicated) déjà présentes, retrouvées par leur empreinte")
        }
        for failure in outcome.failures {
            parts.append("\(failure.name) : \(failure.reason)")
        }
        return parts.joined(separator: " · ")
    }
}
