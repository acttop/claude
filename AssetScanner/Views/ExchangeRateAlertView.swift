import SwiftUI

struct ExchangeRateAlertView: View {
    @ObservedObject var rateService: ExchangeRateService
    @Environment(\.dismiss) private var dismiss
    @State private var thresholdStr = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("환율 알림 활성화", isOn: Binding(
                        get: { rateService.alertEnabled },
                        set: {
                            rateService.alertEnabled = $0
                            if $0 { rateService.requestNotificationPermission() }
                        }
                    ))
                } footer: {
                    Text("새로고침 시 기준 환율 이하면 알림을 발송합니다")
                        .font(.caption)
                }

                if rateService.alertEnabled {
                    Section("알림 기준 환율") {
                        HStack {
                            Text("USD/KRW")
                            Spacer()
                            TextField("1300", text: $thresholdStr)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("원 이하")
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("달러 매수 타이밍 판단에 활용하세요. 환율이 낮을수록 달러 자산 매수에 유리합니다.")
                            .font(.caption)
                    }
                }

                if let snap = rateService.snapshot {
                    Section("현재 환율") {
                        labeledRow("USD / KRW", snap.formattedRate)
                        labeledRow("조회 시각", snap.fetchedAt.formatted(date: .abbreviated, time: .shortened))
                        if rateService.alertEnabled {
                            let isBelow = snap.rate <= rateService.alertThreshold
                            HStack {
                                Text("알림 상태")
                                Spacer()
                                Label(isBelow ? "기준 이하" : "정상",
                                      systemImage: isBelow ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isBelow ? .red : .green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("환율 알림 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        if let v = Double(thresholdStr), v > 0 {
                            rateService.alertThreshold = v
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                thresholdStr = String(format: "%.0f", rateService.alertThreshold)
            }
        }
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
