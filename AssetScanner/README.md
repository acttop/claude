# 자산 스캐너 (Asset Scanner)

자산 현황 이미지를 스캔해서 **일별 손익**과 **누적 손익**을 관리하는 아이폰 전용 앱입니다.

## 주요 기능

| 기능 | 설명 |
|------|------|
| 📸 이미지 스캔 | 카메라로 자산현황 촬영 → OCR 자동 인식 |
| 🖼️ 사진 선택 | 갤러리에서 스크린샷 선택 → OCR 분석 |
| ✏️ 직접 입력 | 종목명·수량·매입단가·현재가 수동 입력 |
| 📅 일자별 목록 | 날짜별 스캔 기록 목록 |
| 📊 일별 손익 | 전일 대비 평가금액 변화 |
| 📈 누적 손익 | 매입가 대비 현재 평가손익 |
| 🗃️ 차트 | 일별·누적 손익 추이 차트 |

## 색상 규칙 (한국 주식 기준)
- 🔴 **빨간색** = 수익 (상승)
- 🔵 **파란색** = 손실 (하락)

---

## Xcode 프로젝트 설정 방법

### 방법 1: XcodeGen 사용 (권장)

```bash
# XcodeGen 설치
brew install xcodegen

# 프로젝트 생성
cd AssetScanner
xcodegen generate

# Xcode에서 열기
open AssetScanner.xcodeproj
```

### 방법 2: 수동 설정

1. Xcode → New Project → iOS → App
2. Product Name: `AssetScanner`
3. Interface: SwiftUI, Language: Swift
4. 기존 `ContentView.swift` 삭제
5. 이 폴더의 모든 `.swift` 파일을 프로젝트에 드래그
6. Info.plist에 권한 추가 (아래 참고)
7. Build & Run

### Info.plist 필수 항목
```xml
<key>NSCameraUsageDescription</key>
<string>자산 현황 이미지를 촬영하여 OCR로 자동 인식합니다</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>갤러리에서 자산 현황 스크린샷을 선택합니다</string>
```

---

## 프로젝트 구조

```
AssetScanner/
├── AssetScannerApp.swift          # 앱 진입점
├── Models/
│   ├── AssetEntry.swift           # 개별 종목 모델
│   └── ScanRecord.swift           # 스캔 기록 모델
├── ViewModels/
│   └── AssetViewModel.swift       # 비즈니스 로직, P&L 계산
├── Services/
│   ├── PersistenceService.swift   # JSON 파일 저장/로드
│   └── OCRService.swift           # Vision 프레임워크 OCR
├── Views/
│   ├── ContentView.swift          # 탭 네비게이션
│   ├── DashboardView.swift        # 메인 대시보드
│   ├── HistoryView.swift          # 일자별 기록 목록
│   ├── ScannerView.swift          # 스캔 화면
│   ├── ManualEntryView.swift      # 직접 입력
│   ├── AddAssetView.swift         # 종목 추가
│   ├── RecordDetailView.swift     # 기록 상세
│   ├── SettingsView.swift         # 설정
│   ├── DocumentCameraView.swift   # VisionKit 카메라
│   ├── ImagePickerView.swift      # PhotosUI 선택기
│   └── Components/
│       ├── PnLCard.swift          # 손익 카드
│       ├── AssetRowView.swift     # 종목 행
│       ├── PnLChartView.swift     # 손익 차트
│       ├── HistoryRowView.swift   # 기록 행
│       └── ScanOptionButton.swift # 스캔 옵션 버튼
├── Extensions/
│   └── Double+Extensions.swift   # KRW 포맷 등 확장
└── Resources/
    └── Info.plist
```

---

## 요구 사항

- **iOS 16.0+** (Swift Charts 사용)
- **Xcode 15+**
- **iPhone 전용** (Portrait 고정)

## P&L 계산 로직

```
일별 손익 = 오늘 총 평가금액 - 전날 총 평가금액
누적 손익 = 총 평가금액 - 총 매입금액
누적 손익률 = 누적 손익 / 총 매입금액 × 100
```

## OCR 지원 형식

Apple Vision Framework를 사용하며 한국어/영어 혼합 인식을 지원합니다.
- 키움증권, 대신증권, NH투자증권 등 주요 증권사 앱 스크린샷
- 인식 순서: **종목명 → 보유수량 → 매입단가 → 현재가**
- OCR 실패 시 직접 입력 기능으로 대체 가능
