import SwiftUI

struct PortfolioSetupView: View {
    @EnvironmentObject var rbVM: RebalancingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddAsset = false
    @State private var editingAsset: PortfolioAsset?

    var body: some View {
        NavigationView {
            Form {
                // 포트폴리오 이름
                Section("포트폴리오 이름") {
                    TextField("예: 연금 포트폴리오", text: Binding(
                        get: { rbVM.portfolio.name },
                        set: { rbVM.updatePortfolioName($0) }
                    ))
                }

                // 목표 비중 합계 검증
                Section {
                    HStack {
                        Text("목표 비중 합계")
                        Spacer()
                        Text(String(format: "%.1f%%", rbVM.portfolio.totalTargetWeight))
                            .fontWeight(.semibold)
                            .foregroundStyle(rbVM.portfolio.isWeightValid ? .green : .red)
                    }

                    if !rbVM.portfolio.isWeightValid {
                        let remaining = 100 - rbVM.portfolio.totalTargetWeight
                        Label(
                            String(format: "합계가 100%%가 되어야 합니다 (현재 %.1f%%, %.1f%% %@)",
                                   rbVM.portfolio.totalTargetWeight, abs(remaining),
                                   remaining > 0 ? "부족" : "초과"),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                } header: {
                    Text("비중 검증")
                }

                // 종목 목록
                Section {
                    ForEach(rbVM.portfolio.assets) { asset in
                        Button { editingAsset = asset } label: {
                            PortfolioAssetRow(asset: asset)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in rbVM.deleteAssets(at: offsets) }

                    Button {
                        showAddAsset = true
                    } label: {
                        Label("종목 추가", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("종목 (\(rbVM.portfolio.assets.count)개)")
                } footer: {
                    Text("왼쪽으로 밀면 삭제, 탭하면 수정합니다")
                        .font(.caption)
                }
            }
            .navigationTitle("포트폴리오 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") { dismiss() }
                        .fontWeight(.semibold)
                        .disabled(!rbVM.portfolio.isWeightValid && !rbVM.portfolio.assets.isEmpty)
                }
            }
            .sheet(isPresented: $showAddAsset) {
                AddPortfolioAssetView { rbVM.addAsset($0) }
            }
            .sheet(item: $editingAsset) { asset in
                AddPortfolioAssetView(editingAsset: asset) { rbVM.updateAsset($0) }
            }
        }
    }
}

private struct PortfolioAssetRow: View {
    let asset: PortfolioAsset

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Text(asset.currency.rawValue)
                    if !asset.symbol.isEmpty { Text("·"); Text(asset.symbol) }
                    if !asset.category.isEmpty { Text("·"); Text(asset.category) }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f%%", asset.targetWeight))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.blue)
                Text("목표")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }
}
