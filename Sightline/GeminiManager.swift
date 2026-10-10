import Foundation

// Sends one JPEG to the Mac backend and receives a spoken description.
@MainActor
final class GeminiManager {
    private let baseURL: URL
    private let appToken: String
    private let session: URLSession

    init(
        baseURL: URL = BackendConfiguration.baseURL,
        appToken: String = BackendConfiguration.appToken,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.appToken = appToken
        self.session = session
    }

    func describe(jpegData: Data) async throws -> String {
        try Task.checkCancellation()

        guard !appToken.isEmpty, !appToken.contains("PASTE_") else {
            throw SceneDescriptionError.server(
                "Set your backend app token first."
            )
        }

        var request = URLRequest(
            url: baseURL.appendingPathComponent("describe")
        )

        request.httpMethod = "POST"
        request.timeoutInterval = 30

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(
            "Bearer \(appToken)",
            forHTTPHeaderField: "Authorization"
        )

        request.httpBody = try JSONEncoder().encode(
            SceneRequest(
                imageBase64: jpegData.base64EncodedString()
            )
        )

        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()

        guard let response = response as? HTTPURLResponse else {
            throw SceneDescriptionError.invalidResponse
        }

        guard (200...299).contains(response.statusCode) else {
            let message = try? JSONDecoder().decode(
                ServerError.self,
                from: data
            )

            throw SceneDescriptionError.server(
                message?.error
                    ?? "The backend returned HTTP \(response.statusCode)."
            )
        }

        let result = try JSONDecoder().decode(
            SceneResponse.self,
            from: data
        )

        let text = result.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !text.isEmpty else {
            throw SceneDescriptionError.emptyDescription
        }

        return text
    }

    private struct SceneRequest: Encodable {
        let imageBase64: String
    }

    private struct SceneResponse: Decodable {
        let text: String
    }

    private struct ServerError: Decodable {
        let error: String
    }
}

enum SceneDescriptionError: LocalizedError {
    case invalidResponse
    case emptyDescription
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The backend response could not be read."

        case .emptyDescription:
            return "The backend returned an empty description."

        case .server(let message):
            return message
        }
    }
}
