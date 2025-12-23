import Vapor

struct ChatController: RouteCollection, Sendable {
    let service: LanguageModelService
    
    func boot(routes: RoutesBuilder) throws {
        routes.post("chat", "completions", use: create)
    }
    
    func create(_ req: Request) async throws -> Response {
        let input = try req.content.decode(ChatCompletionRequest.self)
        
        let messages = input.messages.map { msg in
            LanguageModelMessage(role: msg.role, content: msg.content)
        }
        
        if input.stream == true {
            let stream = try await service.streamResponse(messages: messages, model: input.model)
            
            let response = Response(body: .init(stream: { writer in
                Task {
                    do {
                        for try await chunk in stream {
                            let data = try JSONEncoder().encode(chunk)
                            var buffer = ByteBufferAllocator().buffer(capacity: data.count + 100)
                            buffer.writeString("data: ")
                            buffer.writeBytes(data)
                            buffer.writeString("\n\n")
                            _ = try await writer.write(.buffer(buffer)).get()
                        }
                        var doneBuffer = ByteBufferAllocator().buffer(capacity: 20)
                        doneBuffer.writeString("data: [DONE]\n\n")
                        _ = try await writer.write(.buffer(doneBuffer)).get()
                        _ = try await writer.write(.end).get()
                    } catch {
                        _ = try? await writer.write(.error(error)).get()
                    }
                }
            }))
            response.headers.contentType = HTTPMediaType(type: "text", subType: "event-stream")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.headers.add(name: "Connection", value: "keep-alive")
            return response
            
        } else {
            let result = try await service.generateResponse(messages: messages, model: input.model)
            let response = ChatCompletionResponse(
                id: "chatcmpl-" + UUID().uuidString,
                object: "chat.completion",
                created: Int(Date().timeIntervalSince1970),
                model: input.model,
                choices: [
                    .init(index: 0, message: .init(role: "assistant", content: result), finish_reason: "stop")
                ]
            )
            return try await response.encodeResponse(for: req)
        }
    }
}

// Request/Response Models

struct ChatCompletionRequest: Content {
    var model: String
    var messages: [ChatMessage]
    var stream: Bool?
}

struct ChatMessage: Content {
    var role: String
    var content: String
}

struct ChatCompletionResponse: Content {
    var id: String
    var object: String
    var created: Int
    var model: String
    var choices: [Choice]
    
    struct Choice: Content {
        var index: Int
        var message: ChatMessage
        var finish_reason: String?
    }
}

// Streaming Chunk Models
struct ChatCompletionChunk: Content {
    var id: String
    var object: String
    var created: Int
    var model: String
    var choices: [ChunkChoice]
    
    struct ChunkChoice: Content {
        var index: Int
        var delta: Delta
        var finish_reason: String?
    }
    
    struct Delta: Content {
        var role: String?
        var content: String?
    }
}
