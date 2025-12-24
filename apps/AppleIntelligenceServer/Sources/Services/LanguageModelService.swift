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

#if canImport(FoundationModels)
import FoundationModels
#endif

@available(macOS 26, *)
class RealLanguageModelService: LanguageModelService, @unchecked Sendable {
    #if canImport(FoundationModels)
    private let models: [String: SystemLanguageModel] = [
        "base": SystemLanguageModel.default,
        "permissive": SystemLanguageModel(guardrails: .permissiveContentTransformations)
    ]
    #endif
    
    func generateResponse(messages: [LanguageModelMessage], model: String) async throws -> String {
        #if canImport(FoundationModels)
        let context = try makeSession(from: messages, model: model)
        do {
            let response = try await context.session.respond(to: context.prompt, options: context.options)
            return response.content
        } catch {
            throw mapGenerationError(error)
        }
        #else
        throw foundationModelsUnavailableError()
        #endif
    }
    
    func streamResponse(messages: [LanguageModelMessage], model: String) async throws -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        #if canImport(FoundationModels)
        let context = try makeSession(from: messages, model: model)
        let id = "chatcmpl-" + UUID().uuidString
        
        return AsyncThrowingStream { continuation in
            Task.detached { @Sendable in
                do {
                    // Send an initial delta with the assistant role to match OpenAI streams
                    continuation.yield(ChatCompletionChunk(
                        id: id,
                        object: "chat.completion.chunk",
                        created: Int(Date().timeIntervalSince1970),
                        model: context.modelID,
                        choices: [.init(index: 0, delta: .init(role: "assistant"), finish_reason: nil)]
                    ))
                    
                    var previousSnapshot = ""
                    let stream = context.session.streamResponse(to: context.prompt, options: context.options)
                    
                    for try await snapshot in stream {
                        let deltaContent = String(snapshot.content.dropFirst(previousSnapshot.count))
                        previousSnapshot = snapshot.content
                        
                        if !deltaContent.isEmpty {
                            continuation.yield(ChatCompletionChunk(
                                id: id,
                                object: "chat.completion.chunk",
                                created: Int(Date().timeIntervalSince1970),
                                model: context.modelID,
                                choices: [.init(index: 0, delta: .init(content: deltaContent), finish_reason: nil)]
                            ))
                        }
                    }
                    
                    // Finish chunk
                    continuation.yield(ChatCompletionChunk(
                        id: id,
                        object: "chat.completion.chunk",
                        created: Int(Date().timeIntervalSince1970),
                        model: context.modelID,
                        choices: [.init(index: 0, delta: .init(), finish_reason: "stop")]
                    ))
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: self.mapGenerationError(error))
                }
            }
        }
        #else
        throw foundationModelsUnavailableError()
        #endif
    }
    
    #if canImport(FoundationModels)
    private func makeSession(from messages: [LanguageModelMessage], model: String) throws -> GenerationContext {
        guard !messages.isEmpty else {
            throw Abort(.badRequest, reason: "At least one message is required.")
        }
        
        guard let selectedModel = models[model] else {
            let supported = models.keys.sorted().joined(separator: ", ")
            throw Abort(.badRequest, reason: "Unsupported model '\(model)'. Supported models: \(supported).")
        }
        
        let prompt = Prompt(messages.last?.content ?? "")
        let options = GenerationOptions(sampling: nil, temperature: nil, maximumResponseTokens: nil)
        
        // If there is only one message, we do not need transcript history
        guard messages.count > 1 else {
            return GenerationContext(modelID: model, session: LanguageModelSession(model: selectedModel), prompt: prompt, options: options)
        }
        
        let transcriptEntries = try messages.dropLast().map { message -> Transcript.Entry in
            switch message.role {
            case "user":
                return .prompt(.init(segments: [.text(.init(content: message.content))]))
            case "assistant":
                return .response(.init(assetIDs: [], segments: [.text(.init(content: message.content))]))
            case "system":
                return .instructions(.init(segments: [.text(.init(content: message.content))], toolDefinitions: []))
            default:
                throw Abort(.badRequest, reason: "Invalid message role '\(message.role)'. Expected 'system', 'user', or 'assistant'.")
            }
        }
        
        let transcript = Transcript(entries: transcriptEntries)
        return GenerationContext(modelID: model, session: LanguageModelSession(model: selectedModel, transcript: transcript), prompt: prompt, options: options)
    }
    
    private func mapGenerationError(_ error: any Error) -> Error {
        guard let generationError = error as? LanguageModelSession.GenerationError else {
            return error
        }
        
        switch generationError {
        case .exceededContextWindowSize:
            return Abort(.badRequest, reason: "Prompt exceeds the model's context window.")
        case .guardrailViolation:
            return Abort(.init(statusCode: 402, reasonPhrase: "Content filtered"), reason: "Input was flagged by the model's guardrails.")
        default:
            return generationError
        }
    }
    #endif
}

#if !canImport(FoundationModels)
@available(macOS 26, *)
extension RealLanguageModelService {
    private func foundationModelsUnavailableError() -> Abort {
        Abort(
            .failedDependency,
            reason: "FoundationModels framework not available. Make sure you build on macOS 26+ with Xcode 16+ and run the signed binary with the generative models entitlement."
        )
    }
}
#else
@available(macOS 26, *)
private struct GenerationContext {
    var modelID: String
    var session: LanguageModelSession
    var prompt: Prompt
    var options: GenerationOptions
}
#endif
