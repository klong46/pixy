import SwiftUI

@main
struct PixyApp: App {
    init() {
        if CommandLine.arguments.contains("--verify") || CommandLine.arguments.contains("--test") {
            runVerification()
            exit(0)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
