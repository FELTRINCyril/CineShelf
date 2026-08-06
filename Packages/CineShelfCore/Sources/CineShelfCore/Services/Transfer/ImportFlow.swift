import Foundation

// MARK: - V8 · L'état du parcours d'import
//
// **Dans `CineShelfCore` et non dans `App/`.** Première rédaction : à côté de l'écran, où les
// tests du paquet ne pouvaient pas le voir. Or c'est une machine d'états qui n'importe que
// `Foundation` et les types du cœur — sa place est ici, et c'est ce qui la rend testable sans
// monter un rendu.
//
// **Un type nonisolé, hors de toute vue.** Le parcours a cinq étapes et des transitions qui
// dépendent de l'analyse ; les écrire dans un `@State` de vue les rendrait intestables, et
// c'est la règle « l'arithmétique ne vit jamais dans une `View` » appliquée à une machine
// d'états.
//
// **Aucune donnée n'est écrite avant `.running`**, et c'est ce que le bloc `11d` promet en
// toutes lettres : « Aucune donnée n'est écrite à cette étape ».

/// Où en est l'import.
public enum ImportStage: Sendable, Equatable {
    /// Rien d'ouvert.
    case idle
    /// Le fichier est lu, les colonnes rapprochées. Bloc `11d`.
    case mapping
    /// Les lignes sont analysées, groupées par cause. Bloc `11e`.
    case preview
    /// L'écriture est en cours.
    case running(progress: Double)
    /// Le bilan. Bloc `11j`.
    case finished
}

/// Ce que l'écran d'import sait de son fichier, et ce qu'il en déduit.
///
/// **Séparé de la vue pour être assené sans monter un rendu.** Les décisions qui comptent ici
/// sont des transitions — peut-on avancer, quelles sorties propose-t-on — et elles se testent
/// sur des analyses fabriquées.
public struct ImportFlow: Sendable {
    public var stage: ImportStage = .idle
    public var fileName: String = ""
    public var columns: ColumnAnalysis?
    public var analysis: ImportAnalysis?
    public var result: ImportRunResult?
    public var failure: String?

    public init() {}

    /// Peut-on passer de la correspondance à l'aperçu ?
    ///
    /// **Un champ requis sans colonne est le seul blocage de l'étape 1**, et `ColumnAnalysis`
    /// le dit déjà : sans titre, l'aperçu n'annoncerait que « 1 284 lignes en erreur », ce qui
    /// ne renseigne sur rien. Une colonne **non reconnue**, elle, ne bloque pas — le bloc `11d`
    /// l'écrit : « elles ne sont pas une erreur, l'import peut avancer sans y toucher ».
    public var canAnalyze: Bool { columns?.canProceed == true }

    /// Le rapport de l'analyse, s'il y en a une.
    public var report: ImportReport? { analysis.map(ImportReport.init) }

    /// Les deux sorties de l'aperçu — bloc `11e`.
    ///
    /// **Deux, et pas une.** « Importer les lignes prêtes » laisse les fautives dans le fichier
    /// de reprise ; « tout importer, erreurs en brouillon » les écrit quand même. Ne proposer
    /// que la première obligerait à repasser par un tableur pour un fichier à 417 erreurs, ce
    /// qui est exactement le cas que l'addendum a dessiné.
    public var offersReadyOnly: Bool { (report?.readyCount ?? 0) > 0 }
    public var offersDraftAll: Bool { (report?.refusedCount ?? 0) > 0 }

    /// Le libellé de la sortie principale.
    public func readyLabel() -> String {
        let count = report?.readyCount ?? 0
        return count == 1 ? "Importer la ligne prête" : "Importer les \(count) lignes prêtes"
    }
}
