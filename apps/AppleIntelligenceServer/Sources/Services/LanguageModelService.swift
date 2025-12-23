import Vapor

struct LanguageModelMessage {
    var role: String
    var content: String
}

protocol LanguageModelService: Sendable {
    func generateResponse(messages: [LanguageModelMessage], model: String) async throws -> String
    func streamResponse(messages: [LanguageModelMessage], model: String) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error>
}

// Mock Implementation for now
class MockLanguageModelService: LanguageModelService, @unchecked Sendable {
    func generateResponse(messages: [LanguageModelMessage], model: String) async throws -> String {
        return "I am a mocked Apple Intelligence response."
    }
    
    func streamResponse(messages: [LanguageModelMessage], model: String) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let id = "chatcmpl-" + UUID().uuidString
                let words = ["I", " am", " a", " streamed", " mocked", " response."]
                
                // Initial role chunk
                continuation.yield(ChatCompletionChunk(
                    id: id, object: "chat.completion.chunk", created: Int(Date().timeIntervalSince1970), model: model,
                    choices: [.init(index: 0, delta: .init(role: "assistant"), finish_reason: nil)]
                ))
                
                for word in words {
                    try await Task.sleep(nanoseconds: 100_000_000)
                    continuation.yield(ChatCompletionChunk(
                        id: id, object: "chat.completion.chunk", created: Int(Date().timeIntervalSince1970), model: model,
                        choices: [.init(index: 0, delta: .init(content: word), finish_reason: nil)]
                    ))
                }
                
                // Finish chunk
                continuation.yield(ChatCompletionChunk(
                    id: id, object: "chat.completion.chunk", created: Int(Date().timeIntervalSince1970), model: model,
                    choices: [.init(index: 0, delta: .init(), finish_reason: "stop")]
                ))
                
                continuation.finish()
            }
        }
    }
}


