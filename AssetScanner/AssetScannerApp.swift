import SwiftUI

@main
struct AssetScannerApp: App {
    @StateObject private var vm = AssetViewModel()
    @StateObject private var rbVM = RebalancingViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .environmentObject(rbVM)
        }
    }
}
