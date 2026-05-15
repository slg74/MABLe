import SwiftUI

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
#endif

@main
 struct MazesAndBigLizardsApp: App {
    @StateObject private var gameState = GameState()
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif

    var body: some Scene {
        WindowGroup("Mazes & Big Lizards") {
            ContentView()
                .environmentObject(gameState)
                .preferredColorScheme(.dark)
                .frame(width: 390, height: 844)
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
