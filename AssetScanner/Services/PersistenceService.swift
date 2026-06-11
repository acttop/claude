import Foundation

class PersistenceService {
    private let fileName = "scan_records.json"

    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    func saveRecords(_ records: [ScanRecord]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("저장 실패: \(error)")
        }
    }

    func loadRecords() -> [ScanRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([ScanRecord].self, from: data)
        } catch {
            print("불러오기 실패: \(error)")
            return []
        }
    }
}
