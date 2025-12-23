import Vapor

func routes(_ app: Application) throws {
    app.get("health") { req async -> HealthResponse in
        return HealthResponse(
            ok: true,
            server: ServerInfo(version: "1.0.0", pid: Int(getpid())),
            appleIntelligence: AppleIntelligenceStatus(available: true, notes: []),
            models: ["base", "permissive"]
        )
    }

    let admin = app.grouped("admin")
    // TODO: Add auth middleware
    admin.post("shutdown") { req async throws -> String in
        try await req.application.asyncShutdown()
        Task {
            try await Task.sleep(nanoseconds: 500_000_000)
            exit(0)
        }
        return "Shutting down"
    }
    
    let v1 = app.grouped("v1")
    v1.get("models") { req async -> ModelList in
        return ModelList(data: [
            ModelInfo(id: "base"),
            ModelInfo(id: "permissive")
        ])
    }
    
    // Register Chat Controller
    let chatController = ChatController(service: MockLanguageModelService())
    try v1.register(collection: chatController)
}

struct HealthResponse: Content {
    var ok: Bool
    var server: ServerInfo
    var appleIntelligence: AppleIntelligenceStatus
    var models: [String]
}

struct ServerInfo: Content {
    var version: String
    var pid: Int
}

struct AppleIntelligenceStatus: Content {
    var available: Bool
    var notes: [String]
}

struct ModelList: Content {
    var object: String = "list"
    var data: [ModelInfo]
}

struct ModelInfo: Content {
    var object: String = "model"
    var id: String
}
