import Vapor

public func configure(_ app: Application) throws {
    // Basic setup
    app.http.server.configuration.hostname = "127.0.0.1"
    // app.http.server.configuration.port = 0 // Auto-select port
    
    // Register routes
    try routes(app)
}
