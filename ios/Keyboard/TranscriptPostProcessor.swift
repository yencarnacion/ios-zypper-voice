import Foundation

enum TranscriptPostProcessor {
    private struct ReplacementRule {
        let pattern: String
        let replacement: String
    }

    private static let englishRules: [ReplacementRule] = [
        ReplacementRule(pattern: "(?i)\\bleft[ \\t]+parenthesis\\b", replacement: "("),
        ReplacementRule(pattern: "(?i)\\bright[ \\t]+parenthesis\\b", replacement: ")"),
        ReplacementRule(pattern: "(?i)\\bcomma\\b", replacement: ","),
        ReplacementRule(pattern: "(?i)\\bperiod\\b", replacement: "."),
    ]

    private static let spanishRules: [ReplacementRule] = [
        ReplacementRule(pattern: "(?i)\\bpar[ée]ntesis[ \\t]+izquierdo\\b", replacement: "("),
        ReplacementRule(pattern: "(?i)\\bpar[ée]ntesis[ \\t]+derecho\\b", replacement: ")"),
        ReplacementRule(pattern: "(?i)\\bcoma\\b", replacement: ","),
        ReplacementRule(pattern: "(?i)\\bpunto\\b", replacement: "."),
    ]

    static func apply(_ rawText: String, language: String) -> String {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return ""
        }

        for rule in rules(for: language) {
            text = text.replacingOccurrences(of: rule.pattern, with: rule.replacement, options: .regularExpression)
        }

        text = text.replacingOccurrences(of: "[ \\t]+([,.;:!?])", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\([ \\t]+", with: "(", options: .regularExpression)
        text = text.replacingOccurrences(of: "[ \\t]+\\)", with: ")", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func rules(for language: String) -> [ReplacementRule] {
        let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("en") {
            return englishRules
        }
        if normalized.hasPrefix("es") {
            return spanishRules
        }
        return englishRules + spanishRules
    }
}
