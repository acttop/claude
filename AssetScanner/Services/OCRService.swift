import Vision
import UIKit

class OCRService {
    func recognizeText(from image: UIImage, completion: @escaping ([AssetEntry]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let assets = self.parseAssets(from: lines)
            DispatchQueue.main.async { completion(assets) }
        }

        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // 한국 증권사 앱 스크린샷 파서
    // 종목명, 보유수량, 매입단가, 현재가 순서로 인식 시도
    private func parseAssets(from lines: [String]) -> [AssetEntry] {
        var assets: [AssetEntry] = []
        let numberPattern = #"^[\d,\.]+$"#
        let koreanPattern = #"[가-힣]+"#

        func isNumber(_ s: String) -> Bool {
            let clean = s.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "원", with: "")
            return Double(clean) != nil
        }

        func parseNum(_ s: String) -> Double? {
            let clean = s.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "원", with: "")
            return Double(clean)
        }

        func isStockName(_ s: String) -> Bool {
            guard s.range(of: koreanPattern, options: .regularExpression) != nil else { return false }
            let skipWords = ["매입", "현재", "평가", "수익", "손익", "금액", "단가", "수량", "보유", "종목", "합계", "총액", "잔고"]
            return !skipWords.contains(where: { s.contains($0) }) && !isNumber(s)
        }

        var i = 0
        var currentName = ""
        var numbers: [Double] = []

        func tryFlush() {
            if !currentName.isEmpty && numbers.count >= 3 {
                assets.append(AssetEntry(
                    name: currentName,
                    quantity: numbers[0],
                    averagePrice: numbers[1],
                    currentPrice: numbers[2]
                ))
            }
        }

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if isStockName(line) {
                tryFlush()
                currentName = line
                numbers = []
            } else if let num = parseNum(line), !currentName.isEmpty {
                numbers.append(num)
                if numbers.count == 3 {
                    tryFlush()
                    currentName = ""
                    numbers = []
                }
            }
            i += 1
        }
        tryFlush()

        return assets
    }
}
