import Vapor

func routes(_ app: Application) throws {
    app.get("health") { req async -> HealthResponse in
        let aiStatus = currentAppleIntelligenceStatus()
        return HealthResponse(
            ok: true,
            server: ServerInfo(version: "1.0.0", pid: Int(getpid())),
            appleIntelligence: aiStatus,
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
    let service: LanguageModelService
    #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            service = RealLanguageModelService()
        } else {
            service = MockLanguageModelService()
        }
    #else
        service = MockLanguageModelService()
    #endif
    let chatController = ChatController(service: service)
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

private func currentAppleIntelligenceStatus() -> AppleIntelligenceStatus {
    #if canImport(FoundationModels)
    if #available(macOS 26, *) {
        return AppleIntelligenceStatus(available: true, notes: [])
    } else {
        return AppleIntelligenceStatus(
            available: false,
            notes: ["Requires macOS 26 or later to access Apple Intelligence models."]
        )
    }
    #else
    return AppleIntelligenceStatus(
        available: false,
        notes: ["FoundationModels framework missing. Build with Xcode 16+ on macOS 26+ and run the signed binary with generative-models entitlements."]
    )
    #endif
}
