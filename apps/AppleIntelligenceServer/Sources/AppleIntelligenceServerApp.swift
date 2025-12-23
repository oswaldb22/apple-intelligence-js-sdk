import SwiftUI
import Vapor

@main
struct AppleIntelligenceServerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var app: Application!
    var serverTask: Task<Void, Error>?
    private var currentPort: Int = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Menu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "Apple Intelligence Server")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Apple Intelligence Server", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Copy Base URL", action: #selector(copyBaseURL), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Start Vapor
        serverTask = Task {
            try await startServer()
        }
    }
    
    @objc func copyBaseURL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("http://127.0.0.1:\(currentPort)/v1", forType: .string)
    }
    
    @objc @MainActor func quit() {
        if let app = app {
            app.shutdown()
        }
        NSApplication.shared.terminate(nil)
    }
    
    func startServer() async throws {
        var env = Vapor.Environment(name: "development", arguments: ["vapor"])
        try LoggingSystem.bootstrap(from: &env)
        
        let fileService = StateFileService()
        
        // Parse CLI Args
        // Simple manual parsing since Vapor's is complex to interleave with SwiftUI wrapper
        let args = ProcessInfo.processInfo.arguments
        var port = 0
        var statePath: String?
        var token: String?
        
        for i in 0..<args.count {
            if args[i] == "--port", i + 1 < args.count {
                port = Int(args[i+1]) ?? 0
            }
            if args[i] == "--state", i + 1 < args.count {
                statePath = args[i+1]
            }
            if args[i] == "--token", i + 1 < args.count {
                token = args[i+1]
            }
        }
        
        app = try await Application.make(env)
        
        if port == 0 {
            // Find free port
            // Note: simple hack, bind and close. logic omitted for brevity, reusing 0 allows Vapor to pick but hard to retrieve.
            // For now, let's pick a random high port to avoid complexity or rely on user passing it from Node (Node can pick port).
            // Actually, Node wrapper design says "0 means auto-pick".
            // Let's rely on Node passing a port or we pick one.
            // Since we can't easily get it back from Vapor 4 without hacking Application, we will try to bind to a random port in range.
            port = Int.random(in: 10000...60000)
        }
        
        // Store selected port
        self.currentPort = port
        
        app.http.server.configuration.port = port
        app.http.server.configuration.hostname = "127.0.0.1"
        
        // Configure logic
        try configure(app)
        
        do {
            try await app.startup()
            print("Server started on port \(port)")
            
            if let statePath = statePath {
                let state = ServerState(
                    ready: true,
                    pid: Int(ProcessInfo.processInfo.processIdentifier),
                    port: port,
                    baseURL: "http://127.0.0.1:\(port)/v1",
                    token: token,
                    version: "1.0.0",
                    startedAt: Int(Date().timeIntervalSince1970)
                )
                try fileService.writeState(state, to: statePath)
            }
        } catch {
            print("Server start error: \(error)")
            // If port conflict, maybe retry if auto-pick?
            // For MVP, just fail.
            throw error
        }
    }
}

struct ServerState: Encodable {
    var ready: Bool
    var pid: Int
    var port: Int
    var baseURL: String
    var token: String?
    var version: String
    var startedAt: Int
}

struct StateFileService {
    func writeState(_ state: ServerState, to path: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        try data.write(to: URL(fileURLWithPath: path))
    }
}
