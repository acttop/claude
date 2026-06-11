import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: AssetViewModel
    @State private var showResetAlert = false
    @State private var showAddSample = false

    var body: some View {
        NavigationView {
            Form {
                // 포트폴리오 통계
                Section("포트폴리오 통계") {
                    statRow("총 기록 수", "\(vm.scanRecords.count)개")

                    if let first = vm.sortedRecords.last, let last = vm.sortedRecords.first {
                        statRow("기록 시작일", first.date.formatted(date: .abbreviated, time: .omitted))
                        statRow("최근 기록일", last.date.formatted(date: .abbreviated, time: .omitted))
                    }

                    if let latest = vm.latestRecord {
                        statRow("보유 종목 수", "\(latest.assets.count)개")
                        statRow("총 투자금액", latest.totalInvestment.formattedKRW())
                        statRow("총 평가금액", latest.totalValue.formattedKRW())
                    }
                }

                // 데이터 관리
                Section("데이터 관리") {
                    Button {
                        showAddSample = true
                    } label: {
                        Label("샘플 데이터 추가", systemImage: "plus.rectangle.on.folder")
                    }

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("모든 데이터 삭제", systemImage: "trash")
                    }
                }

                // 앱 정보
                Section("앱 정보") {
                    statRow("앱 이름", "자산 스캐너")
                    statRow("버전", "1.0.0")
                    statRow("지원 OS", "iOS 16.0 이상")

                    Link(destination: URL(string: "https://developer.apple.com/documentation/vision")!) {
                        Label("OCR 기술: Apple Vision Framework", systemImage: "link")
                            .font(.footnote)
                    }
                }

                // 사용 안내
                Section("사용 안내") {
                    VStack(alignment: .leading, spacing: 6) {
                        guideRow("1. 카메라로 자산현황 스크린샷 촬영")
                        guideRow("2. OCR이 종목·수량·단가 자동 인식")
                        guideRow("3. 인식 실패 시 직접 입력 사용")
                        guideRow("4. 일별·누적 손익 자동 계산")
                        guideRow("※ 수익 = 빨간색, 손실 = 파란색 (한국 기준)")
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("설정")
            .alert("데이터 삭제", isPresented: $showResetAlert) {
                Button("삭제", role: .destructive) { vm.deleteAllRecords() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("모든 자산 기록이 영구 삭제됩니다.")
            }
            .alert("샘플 데이터 추가", isPresented: $showAddSample) {
                Button("추가") {
                    // ViewModel에 샘플 데이터 추가 (AppStorage 초기화 후 재생성)
                    vm.deleteAllRecords()
                    NotificationCenter.default.post(name: .init("ReloadSampleData"), object: nil)
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("기존 데이터를 삭제하고 샘플 데이터를 추가합니다.")
            }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func guideRow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
