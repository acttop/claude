import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var vm: AssetViewModel
    @Binding var showScanner: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    portfolioHeader
                    pnlCards
                    if vm.pnlChartData.count >= 2 { chartSection }
                    if let latest = vm.latestRecord, !latest.assets.isEmpty {
                        holdingsSection(assets: latest.assets)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("자산 현황")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showScanner = true } label: {
                        Image(systemName: "camera.viewfinder")
                            .font(.title2)
                    }
                }
            }
            .refreshable {
                // 당겨서 새로고침 placeholder
            }
        }
    }

    // MARK: - Subviews

    private var portfolioHeader: some View {
        VStack(spacing: 6) {
            Text("총 평가금액")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(vm.totalValue.formattedKRW())
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if let latest = vm.latestRecord {
                Label(latest.date.formatted(date: .abbreviated, time: .omitted) + " 기준",
                      systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var pnlCards: some View {
        HStack(spacing: 12) {
            PnLCard(
                title: "일별 손익",
                subtitle: "전일 대비",
                amount: vm.latestDailyPnL,
                percent: vm.latestDailyPnLPercent
            )
            PnLCard(
                title: "누적 손익",
                subtitle: "매입가 대비",
                amount: vm.cumulativePnL,
                percent: vm.cumulativePnLPercent
            )
        }
        .padding(.horizontal)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("손익 추이")
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 12)

            PnLChartView()
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                .padding(.horizontal)
        }
    }

    private func holdingsSection(assets: [AssetEntry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("보유 종목")
                    .font(.headline)
                Spacer()
                Text("\(assets.count)개")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(assets) { asset in
                    AssetRowView(asset: asset)
                    if asset.id != assets.last?.id {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            .padding(.horizontal)
        }
    }
}
