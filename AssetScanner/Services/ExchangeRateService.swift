import Foundation
import UserNotifications

// Frankfurter API response: {"amount":1.0,"base":"USD","date":"...","rates":{"KRW":1472.34}}
private struct FrankfurterResponse: Decodable {
    let amount: Double
    let base: String
    let date: String
    let rates: [String: Double]
    var usdKrw: Double { rates["KRW"] ?? 0 }
}

class ExchangeRateService: ObservableObject {
    @Published var snapshot: ExchangeRateSnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var alertThreshold: Double {
        didSet { UserDefaults.standard.set(alertThreshold, forKey: "erAlertThreshold") }
    }
    @Published var alertEnabled: Bool {
        didSet { UserDefaults.standard.set(alertEnabled, forKey: "erAlertEnabled") }
    }

    private let apiURL = "https://api.frankfurter.app/latest?from=USD&to=KRW"

    init() {
        let stored = UserDefaults.standard.double(forKey: "erAlertThreshold")
        alertThreshold = stored > 0 ? stored : 1300.0
        alertEnabled = UserDefaults.standard.bool(forKey: "erAlertEnabled")
    }

    @MainActor
    func fetchRate() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let url = URL(string: apiURL) else { throw URLError(.badURL) }
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
            guard decoded.usdKrw > 0 else { throw URLError(.badServerResponse) }
            snapshot = ExchangeRateSnapshot(rate: decoded.usdKrw, fetchedAt: Date())
            checkAlertThreshold(rate: decoded.usdKrw)
        } catch {
            errorMessage = "환율 조회 실패"
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func checkAlertThreshold(rate: Double) {
        guard alertEnabled, rate > 0, rate <= alertThreshold else { return }
        let content = UNMutableNotificationContent()
        content.title = "환율 알림 💵"
        content.body = String(format: "USD/KRW %.2f원 — 기준(%.0f원) 이하. 달러 매수 타이밍을 확인하세요.",
                              rate, alertThreshold)
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(
            identifier: "er-alert-\(Int(Date().timeIntervalSince1970))",
            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
}
