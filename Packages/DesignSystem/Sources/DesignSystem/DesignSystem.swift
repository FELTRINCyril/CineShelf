import SwiftUI

/// Point d'entrée du design system.
///
/// Seul package autorisé à déclarer des couleurs littérales et à embarquer des
/// polices : tout le reste de l'app passe par les tokens exposés ici.
public enum DesignSystem {
    /// Bundle du package, pour aller chercher les ressources embarquées.
    public static let bundle = Bundle.module
}
