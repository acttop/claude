import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var vm: AssetViewModel
    @Binding var showScanner: Bool
    @State private var selectedRecord: ScanRecord?

    var body: some View {
        NavigationView {
            Group {
                if vm.sortedRecords.isEmpty {
                    emptyState
                } else {
                    recordList
                }
            }
            .navigationTitle("일자별 기록")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showScanner = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(item: $selectedRecord) { record in
                RecordDetailView(record: record)
                    .environmentObject(vm)
            }
        }
    }

    private var recordList: some View {
        List {
            ForEach(vm.sortedRecords) { record in
                Button {
                    selectedRecord = record
                } label: {
                    HistoryRowView(
                        record: record,
                        dailyPnL: vm.dailyPnL(for: record),
                        dailyPnLPercent: vm.dailyPnLPercent(for: record)
                    )
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                vm.deleteRecords(at: offsets)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("아직 기록이 없습니다")
                .font(.title3.weight(.semibold))
            Text("카메라로 자산 현황을 스캔하거나\n직접 입력해보세요")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                showScanner = true
            } label: {
                Label("스캔 시작", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
