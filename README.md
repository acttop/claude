# PDF → Excel 변환기 (폐쇄망용)

PDF 안의 **표**와 **텍스트**를 엑셀(.xlsx)로 변환하는 파이썬 앱입니다.
실행 중에 **외부와 통신하지 않으며**, 의존 패키지 2개(pdfplumber, openpyxl)만 오프라인으로 반입하면 동작합니다.

## 주요 기능
- 추출 방식: 자동(표가 있으면 표, 없으면 텍스트) / 표만 / 텍스트만
- 시트 구성: 표·페이지별 시트 / 한 시트로 합치기
- 페이지 범위 지정(`1-3,5`), 암호 걸린 PDF, 여러 파일 일괄 변환
- 숫자 자동 변환: `1,200,000` → `1200000`, `(500)` → `-500`, `60%` → `0.6`(백분율 서식)
- 한글 열 너비 자동 맞춤, 헤더 강조, 틀 고정

## 폐쇄망 배포 방법 (2가지 중 택1)

### A. exe 하나로 배포 (권장 · 폐쇄망 PC에 Python 불필요)
1. 인터넷 PC에서 `scripts\3_build_exe.bat` 실행
2. 생성된 `dist\PDF2Excel.exe` 를 폐쇄망 PC로 복사 후 더블클릭

### B. Python이 설치된 폐쇄망 PC에 소스로 설치
1. 인터넷 PC(폐쇄망과 **같은 Python 버전·64bit**)에서 `scripts\1_download_packages.bat` → `wheelhouse\` 생성
2. 프로젝트 폴더 전체를 폐쇄망으로 반입
3. 폐쇄망 PC에서 `scripts\2_install_offline.bat` → 이후 `scripts\run.bat` 으로 실행

> Linux는 `scripts/download_packages.sh`, `scripts/install_offline.sh` 사용 (GUI는 `python3-tk` 필요)

## 사용법
- GUI: `python run_gui.py` (또는 exe 실행)
- CLI:
  ```
  python -m pdf2excel 보고서.pdf                       # 보고서.xlsx 생성
  python -m pdf2excel 보고서.pdf -o 결과.xlsx -p 1-3   # 1~3쪽만
  python -m pdf2excel D:\pdf폴더 -o D:\엑셀폴더 -l single  # 폴더 일괄, 한 시트로
  ```

## 변환 예시
`samples/sample.pdf`(1쪽: 표, 2쪽: 텍스트) → `samples/sample.xlsx`

| 시트 | 내용 |
|---|---|
| P1_표1 | 품목 / 수량 / 단가 / 금액 / 비율 → `노트북, 10, 1200000, 12000000, 60%` (숫자 셀) |
| P2_텍스트 | 줄 단위로 A열에 입력 |

## 제약 사항
- **스캔(이미지) PDF는 텍스트가 없어 추출되지 않습니다.** → 결과에 경고 표시. 필요 시 OCR(Tesseract 오프라인 설치) 확장 가능
- 테두리 없는 표나 셀 병합이 복잡한 표는 열이 어긋날 수 있습니다 → "텍스트만" 모드로 대체 확인

## 개발/테스트
```
pip install pytest reportlab
python -m pytest tests
```
