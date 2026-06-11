import SwiftUI

struct ExchangeRateWidget: View {
    @ObservedObject var rateService: ExchangeRateService
    @State private var showAlertSettings = false

    private var snapshot: ExchangeRateSnapshot? { rateService.snapshot }
    private var isBelowAlert: Bool {
        guard rateService.alertEnabled, let rate = snapshot?.rate else { return false }
        return rate <= rateService.alertThreshold
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(isBelowAlert ? .red : .blue)
                    Text("USD / KRW")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Button { showAlertSettings = true } label: {
                    Image(systemName: rateService.alertEnabled ? "bell.fill" : "bell")
                        .font(.subheadline)
                        .foregroundStyle(rateService.alertEnabled ? .orange : .secondary)
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                if rateService.isLoading {
                    ProgressView().scaleEffect(0.9)
                    Text("조회 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let snap = snapshot {
                    Text(snap.formattedRate)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(isBelowAlert ? .red : .primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(snap.fetchedAt.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if isBelowAlert {
                            Label("매수 타이밍 주의", systemImage: "exclamationmark.circle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    Text("--")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.secondary)
                    if let err = rateService.errorMessage {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    Task { await rateService.fetchRate() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.blue)
                }
                .disabled(rateService.isLoading)
            }

            if rateService.alertEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "bell.badge").font(.caption2).foregroundStyle(.orange)
                    Text(String(format: "알림 기준: %.0f원 이하", rateService.alertThreshold))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
        .sheet(isPresented: $showAlertSettings) {
            ExchangeRateAlertView(rateService: rateService)
        }
    }
}
