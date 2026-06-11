import SwiftUI

@main
struct AssetScannerApp: App {
    @StateObject private var vm = AssetViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
        }
    }
}
