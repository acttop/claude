import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: AssetViewModel
    @EnvironmentObject var rbVM: RebalancingViewModel
    @State private var showScanner = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(showScanner: $showScanner)
                .tabItem { Label("대시보드", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(0)

            HistoryView(showScanner: $showScanner)
                .tabItem { Label("기록", systemImage: "calendar.badge.clock") }
                .tag(1)

            RebalancingView()
                .tabItem { Label("리밸런싱", systemImage: "arrow.triangle.2.circlepath") }
                .tag(2)

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .sheet(isPresented: $showScanner) {
            ScannerView().environmentObject(vm)
        }
    }
}
