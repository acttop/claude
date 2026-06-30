# 자산 리밸런싱 (Asset Rebalancing)

개인 자산 포트폴리오의 **리밸런싱**을 지원하는 Flutter 크로스플랫폼 앱 (iPhone 우선 최적화).
오프라인 우선(offline-first)·로컬 저장·로그인 불필요.

## 핵심 기능

1. **분석 결과 붙여넣기 파싱** — AI 챗봇(Claude 등) 분석 결과를 클립보드에서 붙여넣으면
   마크다운 표 / CSV / JSON 3가지 형식을 자동 인식해 자산 목록을 생성·갱신합니다.
2. **리밸런싱 계산** — 추가 투자금/목표 비중을 입력하면 상품별 매수·매도 금액을 자동 계산.
   `전체 재배분`과 `추가금 매수만(No-Sell)` 두 모드를 지원합니다.
3. **자산별 변동 이력** — 매수/매도/비중변경/평가금액갱신/신규등록 이력을 누적, 추이 라인차트 제공.
4. **대시보드/스냅샷** — 자산 구성 도넛차트, 괴리도 정렬, 시점별 스냅샷 추이.

## 프로젝트 구조

```
asset_rebalancing/
├── pubspec.yaml                      # 의존성
├── analysis_options.yaml
├── lib/
│   ├── main.dart                     # 앱 진입점 (테마/다크모드, ProviderScope)
│   ├── models/
│   │   ├── enums.dart                # AssetCategory / HistoryType / RebalanceMode
│   │   ├── asset.dart                # 자산 모델
│   │   ├── history.dart              # 변동 이력 모델
│   │   ├── snapshot.dart             # 포트폴리오 스냅샷 모델
│   │   └── rebalance_result.dart     # 리밸런싱 결과 모델
│   ├── services/
│   │   ├── rebalance_service.dart    # ⭐ 리밸런싱 계산 로직 (순수 함수, 테스트 대상)
│   │   ├── parser_service.dart       # ⭐ 붙여넣기 파서 (마크다운/CSV/JSON)
│   │   ├── database_service.dart     # SQLite 영구 저장 + JSON 백업/복원
│   │   ├── format_utils.dart         # 원화/퍼센트 포맷, 숫자 파싱
│   │   └── id_gen.dart               # ID 생성
│   ├── providers/
│   │   ├── portfolio_provider.dart   # Riverpod: 자산/이력/스냅샷 상태
│   │   └── settings_provider.dart    # Riverpod: 테마/수수료/거래단위/위험상한
│   ├── screens/
│   │   ├── main_tab_screen.dart      # 하단 탭 4개
│   │   ├── home_screen.dart          # 홈(대시보드)
│   │   ├── rebalance_screen.dart     # 리밸런싱
│   │   ├── assets_screen.dart        # 자산 관리
│   │   ├── paste_import_screen.dart  # 붙여넣기 미리보기
│   │   ├── asset_edit_screen.dart    # 자산 추가/수정
│   │   ├── asset_detail_screen.dart  # 자산 상세 + 이력 타임라인
│   │   ├── history_screen.dart       # 이력/리포트 + 내보내기
│   │   └── settings_screen.dart      # 설정/백업
│   └── widgets/
│       ├── donut_chart.dart          # 도넛 차트(fl_chart)
│       └── value_line_chart.dart     # 추이 라인 차트(fl_chart)
└── test/
    ├── rebalance_service_test.dart   # 리밸런싱 계산 단위 테스트
    └── parser_service_test.dart      # 파서 단위 테스트
```

## 실행 방법 (iOS 시뮬레이터 / 실기기)

> iOS 빌드는 **macOS + Xcode**가 필요합니다.

```bash
# 0) Flutter 설치 확인 (3.19+ 권장)
flutter --version

# 1) 플랫폼 폴더(ios/ android/) 생성
#    이 저장소에는 lib/ 와 test/ 만 포함되어 있으므로,
#    프로젝트 루트에서 아래를 실행해 ios/android 러너를 생성합니다.
cd asset_rebalancing
flutter create .

# 2) 의존성 설치
flutter pub get

# 3-a) iOS 시뮬레이터 실행
open -a Simulator         # 시뮬레이터 띄우기
flutter run                # 연결된 시뮬레이터에서 실행

# 3-b) iPhone 실기기 실행
#  - Xcode에서 ios/Runner.xcworkspace 열어 Signing & Capabilities에 Apple ID 팀 설정
flutter run -d <device-id>   # flutter devices 로 id 확인

# (참고) Android 에뮬레이터
flutter run -d emulator-5554
```

### 단위 테스트 실행

```bash
cd asset_rebalancing
flutter pub get
flutter test
```

`test/rebalance_service_test.dart`는 두 리밸런싱 모드, 반올림, 수수료, 비중 검증을,
`test/parser_service_test.dart`는 마크다운/CSV/JSON 파싱과 오류 처리를 검증합니다.

## 붙여넣기 입력 포맷 예시

**(A) 마크다운 표**
```
| 상품명 | 카테고리 | 평가금액 | 목표비중 |
|--------|----------|----------|----------|
| TIGER 미국S&P500 | 해외주식 | 5,000,000 | 40 |
| KODEX 200 | 국내주식 | 3,000,000 | 25 |
| 현금 | 현금 | 2,000,000 | 35 |
```

**(B) CSV**
```
상품명,카테고리,평가금액,목표비중
TIGER 미국S&P500,해외주식,5000000,40
KODEX 200,국내주식,3000000,25
```

**(C) JSON**
```json
[{"name":"TIGER 미국S&P500","category":"해외주식","currentValue":5000000,"targetWeight":40}]
```

- 금액의 `,` `₩` `원`, 비중의 `%`는 자동 제거됩니다.
- 동일 상품명이 있으면 갱신(`평가금액갱신` 이력), 없으면 신규 등록(`신규등록` 이력).

## 리밸런싱 계산 예시 (샘플 데이터)

샘플 포트폴리오 (전체 평가금액 10,000,000원):

| 상품 | 현재금액 | 현재비중 | 목표비중 |
|------|---------:|--------:|--------:|
| TIGER 미국S&P500 | 5,000,000 | 50.0% | 40% |
| KODEX 200 | 3,000,000 | 30.0% | 25% |
| 현금 | 2,000,000 | 20.0% | 35% |

### 예시 1 — 전체 재배분, 추가금 0원

```
신규 총액 = 10,000,000
목표금액  : S&P 4,000,000 / KODEX 2,500,000 / 현금 3,500,000
조정금액  : S&P -1,000,000(매도) / KODEX -500,000(매도) / 현금 +1,500,000(매수)
검증      : 매수합(1,500,000) = 매도합(1,500,000)  → 순현금흐름 0
```

| 상품 | 구분 | 거래금액 | 거래 후 |
|------|------|--------:|-------:|
| TIGER 미국S&P500 | 매도 | 1,000,000 | 4,000,000 |
| KODEX 200 | 매도 | 500,000 | 2,500,000 |
| 현금 | 매수 | 1,500,000 | 3,500,000 |

### 예시 2 — 전체 재배분, 추가금 5,000,000원

```
신규 총액 = 15,000,000
목표금액  : S&P 6,000,000 / KODEX 3,750,000 / 현금 5,250,000
조정금액  : S&P +1,000,000 / KODEX +750,000 / 현금 +3,250,000  (모두 매수)
검증      : 조정금액 합 = 5,000,000 = 추가 투자금
```

### 예시 3 — 추가금 매수만(No-Sell), 추가금 3,000,000원

```
신규 총액 = 13,000,000
목표금액  : S&P 5,200,000 / KODEX 3,250,000 / 현금 4,550,000
부족분    : S&P 200,000 / KODEX 250,000 / 현금 2,550,000  (합 3,000,000)
→ 추가금 3,000,000을 부족분에 배분(매도 없음)
매수      : S&P +200,000 / KODEX +250,000 / 현금 +2,550,000
```

가장 저평가(현금)에 매수가 집중되어, 기존 보유분을 팔지 않고 비중 격차를 줄입니다.

## 옵션

- **최소 거래단위**: 1,000 / 10,000 / 100,000원 단위 반올림 (설정)
- **수수료·세금율**: 거래금액 × 비율로 예상 비용 표시 (기본 0%)
- **위험자산 비중 상한**: 국내/해외주식·ETF 합산이 상한 초과 시 경고 (예: DC형 연금 70%)
- **다크모드**, **JSON 백업/복원**(설정 화면), **CSV/JSON 내보내기**(이력 화면)

## 기술 스택

- Flutter (Material 3) · Riverpod · sqflite · fl_chart · intl
