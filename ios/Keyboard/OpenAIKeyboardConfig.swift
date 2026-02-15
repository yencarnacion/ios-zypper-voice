import Foundation

struct OpenAIKeyboardConfig {
    let apiKey: String
    let baseURL: String
    let model: String
    let language: String
    let prompt: String

    private static let defaultBaseURL = "https://api.openai.com/v1"
    private static let defaultModel = "gpt-4o-mini-transcribe"

    private static let defaultPostProcessPromptEN = "You are an editor whose task is to make the text look good. Preserve meaning, fix punctuation/capitalization, and convert spoken punctuation words (for example: comma, period, left parenthesis, right parenthesis) into symbols."
    private static let defaultPostProcessPromptES = "Eres un editor cuya tarea es hacer que el texto se vea bien. Conserva el significado, corrige puntuacion/mayusculas y convierte palabras de puntuacion habladas (por ejemplo: coma, punto, parentesis izquierdo, parentesis derecho) en simbolos."

    static func load(bundle: Bundle = .main) throws -> OpenAIKeyboardConfig {
        let rawAPIKey = (bundle.object(forInfoDictionaryKey: "ZypperOpenAIAPIKey") as? String) ?? ""
        let apiKey = rawAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKey.isEmpty || apiKey == "YOUR_OPENAI_API_KEY" {
            throw OpenAIKeyboardConfigError.missingAPIKey
        }

        let baseURL = ((bundle.object(forInfoDictionaryKey: "ZypperOpenAIBaseURL") as? String) ?? defaultBaseURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBaseURL = baseURL.isEmpty ? defaultBaseURL : baseURL

        let model = ((bundle.object(forInfoDictionaryKey: "ZypperOpenAIModel") as? String) ?? defaultModel)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = model.isEmpty ? defaultModel : model

        let language = ((bundle.object(forInfoDictionaryKey: "ZypperOpenAILanguage") as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let customPrompt = ((bundle.object(forInfoDictionaryKey: "ZypperOpenAIPrompt") as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return OpenAIKeyboardConfig(
            apiKey: apiKey,
            baseURL: normalizedBaseURL,
            model: normalizedModel,
            language: language,
            prompt: resolvePrompt(customPrompt: customPrompt, language: language)
        )
    }

    private static func resolvePrompt(customPrompt: String, language: String) -> String {
        if !customPrompt.isEmpty {
            return customPrompt
        }

        let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("en") {
            return defaultPostProcessPromptEN
        }
        if normalized.hasPrefix("es") {
            return defaultPostProcessPromptES
        }
        return defaultPostProcessPromptEN + " " + defaultPostProcessPromptES
    }
}

enum OpenAIKeyboardConfigError: LocalizedError {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Set ZypperOpenAIAPIKey in Keyboard Info.plist"
        }
    }
}
