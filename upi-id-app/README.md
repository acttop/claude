# UPI ID 생성·검증 앱

인도 UPI 결제 주소(VPA, `사용자명@PSP핸들`)를 **검증·생성**하고 **결제 딥링크**를 만드는 도구.
순수 클라이언트 로직(`lib/upi.ts`)으로 동작하며 외부 API를 호출하지 않는다.

## 실행

```bash
cd upi-id-app
npm install
npm run dev     # http://localhost:3000
npm test        # 단위 테스트 (node:test)
npm run build   # 정적 사이트를 out/ 에 생성 (어떤 정적 호스팅에도 배포 가능)
```

## 배포 (GitHub Pages)

- 주소: https://acttop.github.io/claude/upi/
- `gh-pages` 브랜치의 `upi/` 폴더에 정적 빌드 결과물을 올리는 방식 (다른 앱과 동일)

```bash
PAGES_BASE_PATH=/claude/upi npm run build   # out/ 생성
# out/ 내용을 gh-pages 브랜치 upi/ 폴더에 복사 후 커밋·푸시
```

## 기능

| 탭 | 기능 | 예시 |
| --- | --- | --- |
| 검증 | 단건/일괄(줄바꿈·쉼표·세미콜론) 형식 검증, 오류·경고 구분, 제공사 표시 | `9876543210@ybl` → 유효, PhonePe (Yes Bank) |
| 생성 | 휴대폰번호(+91/0 자동 제거)·영문 이름·사용자 지정 값으로 후보 생성, QA용 랜덤 데이터(최대 100건) | `Rahul Kumar Sharma` + `okaxis` → `rahul.sharma@okaxis` 외 4개 |
| 결제 링크 | NPCI UPI Linking Spec 기반 딥링크 | `shop@ybl`, 150 → `upi://pay?pa=shop%40ybl&am=150.00&cu=INR` |

### 검증 규칙

- **오류**: `@` 없음/중복, 사용자명 3~50자·허용문자(`a-z 0-9 . - _`)·영숫자 시작/끝·`..` 금지, 핸들 영소문자 시작·영숫자만, 전체 255자 이하
- **경고**(유효 판정): 대문자 포함(소문자로 정규화), 알려진 PSP 핸들 목록에 없음, 6~9로 시작하지 않는 10자리 번호

## 범위

- 형식(syntax) 검증만 수행. 실제 존재·예금주 확인은 NPCI/PSP VPA 조회 API 영역으로 범위 밖
- 알려진 PSP 핸들 목록은 `lib/upi.ts`의 `KNOWN_HANDLES`에서 관리
