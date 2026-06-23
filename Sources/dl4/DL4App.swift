import SwiftUI

/// SwiftUI app. Launched via `DL4App.main()` from the dispatcher in `main.swift`
/// (not `@main`, so the CLI entry point can coexist).
struct DL4App: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("DL4 Conductor") {
            ContentView().environmentObject(model)
        }
        .windowResizability(.contentSize)
    }
}
