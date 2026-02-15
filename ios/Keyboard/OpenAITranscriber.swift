import Foundation

private struct OpenAITextResponse: Decodable {
    let text: String?
}

enum OpenAITranscriber {
    static func transcribe(fileURL: URL, config: OpenAIKeyboardConfig) async throws -> String {
        let endpoint = try endpointURL(from: config.baseURL)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        request.httpBody = try makeMultipartBody(fileURL: fileURL, config: config, boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAITranscriberError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OpenAITranscriberError.requestFailed(status: httpResponse.statusCode, body: trimmed(body))
        }

        if let parsed = try? JSONDecoder().decode(OpenAITextResponse.self, from: data),
           let text = parsed.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }

        let fallback = extractTextFallback(from: data).trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty {
            return fallback
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        throw OpenAITranscriberError.missingText(body: trimmed(body))
    }

    private static func endpointURL(from baseURL: String) throws -> URL {
        let normalized = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: normalized + "/audio/transcriptions") else {
            throw OpenAITranscriberError.invalidBaseURL
        }
        return url
    }

    private static func makeMultipartBody(fileURL: URL, config: OpenAIKeyboardConfig, boundary: String) throws -> Data {
        var data = Data()

        appendField("model", value: config.model, boundary: boundary, to: &data)
        if !config.language.isEmpty {
            appendField("language", value: config.language, boundary: boundary, to: &data)
        }
        if !config.prompt.isEmpty {
            appendField("prompt", value: config.prompt, boundary: boundary, to: &data)
        }

        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        let mimeType = mimeTypeForFile(at: fileURL)

        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        data.append("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        data.append("\r\n")
        data.append("--\(boundary)--\r\n")

        return data
    }

    private static func appendField(_ name: String, value: String, boundary: String, to data: inout Data) {
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        data.append("\(value)\r\n")
    }

    private static func mimeTypeForFile(at fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "m4a":
            return "audio/m4a"
        case "wav":
            return "audio/wav"
        default:
            return "application/octet-stream"
        }
    }

    private static func extractTextFallback(from data: Data) -> String {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return ""
        }

        guard let payload = jsonObject as? [String: Any] else {
            return ""
        }

        for key in ["text", "transcript", "output_text"] {
            if let raw = payload[key], let value = asString(raw), !value.isEmpty {
                return value
            }
        }

        for key in ["data", "output", "result"] {
            if let nested = payload[key], let value = findTextLike(in: nested), !value.isEmpty {
                return value
            }
        }

        return ""
    }

    private static func findTextLike(in value: Any) -> String? {
        if let dict = value as? [String: Any] {
            for key in ["text", "transcript", "output_text"] {
                if let raw = dict[key], let parsed = asString(raw), !parsed.isEmpty {
                    return parsed
                }
            }
            for nested in dict.values {
                if let found = findTextLike(in: nested), !found.isEmpty {
                    return found
                }
            }
            return nil
        }

        if let list = value as? [Any] {
            for item in list {
                if let found = findTextLike(in: item), !found.isEmpty {
                    return found
                }
            }
            return nil
        }

        return asString(value)
    }

    private static func asString(_ value: Any) -> String? {
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func trimmed(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count <= 500 {
            return value
        }
        return String(value.prefix(500)) + "..."
    }
}

enum OpenAITranscriberError: Error {
    case invalidBaseURL
    case invalidResponse
    case requestFailed(status: Int, body: String)
    case missingText(body: String)
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
