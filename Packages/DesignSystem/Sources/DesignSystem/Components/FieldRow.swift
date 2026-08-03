import SwiftUI

// MARK: - FieldRow — libellé + valeur + validation
//
// Bâti sur `LabeledContent` : alignement, style de formulaire et VoiceOver
// natifs sur les trois plateformes.

public struct FieldValidation: Sendable, Hashable {
    public enum Level: Sendable, Hashable { case info, warning, error }

    public let level: Level
    public let message: String

    public init(_ level: Level, _ message: String) {
        self.level = level
        self.message = message
    }

    public static func error(_ message: String) -> Self { .init(.error, message) }
    public static func warning(_ message: String) -> Self { .init(.warning, message) }
    public static func info(_ message: String) -> Self { .init(.info, message) }

    var tint: Color {
        switch level {
        case .info: .textTertiary
        case .warning: .statusWarning
        case .error: .statusDanger
        }
    }

    var symbol: String {
        switch level {
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "exclamationmark.circle"
        }
    }
}

public struct FieldRow<Content: View>: View {
    private let label: String
    private let validation: FieldValidation?
    private let content: Content

    public init(_ label: String, validation: FieldValidation? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.validation = validation
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            LabeledContent {
                content
                    .font(Typo.body)
                    .foregroundStyle(.textPrimary)
                    .frame(minHeight: Space.minHitTarget)
            } label: {
                Text(label)
                    .font(Typo.fieldLabel)
                    .foregroundStyle(.textSecondary)
            }

            if let validation {
                Label {
                    Text(validation.message)
                        .font(Typo.caption)
                        .foregroundStyle(validation.tint)
                } icon: {
                    Image(systemName: validation.symbol)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(validation.tint)
                }
                .labelStyle(.titleAndIcon)
                .transition(.opacity)
            }
        }
        .padding(.vertical, Space.xxs)
        .dsAnimation(Motion.quick, value: validation)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityValue(validation.map { "\($0.level == .error ? "Erreur" : "Note") : \($0.message)" } ?? "")
    }
}

/// Ligne en lecture seule — la valeur est une donnée, donc monospace.
public struct FieldValueRow: View {
    private let label: String
    private let value: String
    private let validation: FieldValidation?

    public init(_ label: String, value: String, validation: FieldValidation? = nil) {
        self.label = label
        self.value = value
        self.validation = validation
    }

    public var body: some View {
        FieldRow(label, validation: validation) {
            Text(value)
                .font(Typo.dataValue)
                .monospacedDigit()
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

#Preview {
    Form {
        FieldRow("Titre") { TextField("Titre", text: .constant("Stalker")) }
        FieldValueRow("Année", value: "1979")
        FieldRow("Durée", validation: .error("Entre une durée en minutes.")) {
            TextField("Minutes", text: .constant("2 h 41"))
        }
    }
    .background(.bgCanvas)
}
