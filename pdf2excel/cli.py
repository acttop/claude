"""명령줄 실행: python -m pdf2excel.cli input.pdf [-o out.xlsx] ..."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .analyze import OCR_AUTO, OCR_FORCE, OCR_OFF
from .core import (LAYOUT_PER_PAGE, LAYOUT_SINGLE, MODE_AUTO, MODE_TABLE,
                   MODE_TEXT, ConvertOptions, convert, parse_pages)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="pdf2excel", description="PDF를 엑셀(xlsx)로 변환합니다.")
    p.add_argument("inputs", nargs="+", help="PDF 파일 또는 PDF가 들어있는 폴더")
    p.add_argument("-o", "--output", help="출력 파일(단일 입력) 또는 출력 폴더")
    p.add_argument("-m", "--mode", choices=[MODE_AUTO, MODE_TABLE, MODE_TEXT], default=MODE_AUTO)
    p.add_argument("-l", "--layout", choices=[LAYOUT_PER_PAGE, LAYOUT_SINGLE],
                   default=LAYOUT_PER_PAGE)
    p.add_argument("-p", "--pages", default="", help="페이지 범위 예: 1-3,5")
    p.add_argument("--password", help="암호화된 PDF 암호")
    p.add_argument("--keep-text", action="store_true", help="숫자 자동 변환 끄기")
    p.add_argument("--ocr", choices=[OCR_AUTO, OCR_OFF, OCR_FORCE], default=OCR_AUTO,
                   help="auto: 텍스트 없는(스캔) 페이지만 OCR / off / force: 모든 페이지 OCR")
    a = p.parse_args(argv)

    pdfs: list[Path] = []
    for item in map(Path, a.inputs):
        pdfs += sorted(item.glob("*.pdf")) if item.is_dir() else [item]
    if not pdfs:
        print("변환할 PDF가 없습니다.", file=sys.stderr)
        return 1

    opts = ConvertOptions(mode=a.mode, layout=a.layout, pages=parse_pages(a.pages),
                          convert_numbers=not a.keep_text, password=a.password,
                          ocr=a.ocr)
    failed = 0
    for pdf in pdfs:
        if a.output and (len(pdfs) > 1 or Path(a.output).suffix.lower() != ".xlsx"):
            target = Path(a.output) / (pdf.stem + ".xlsx")
        else:
            target = Path(a.output) if a.output else None
        try:
            r = convert(pdf, target, opts)
            tag = "주의" if r.failed_pages else "OK"
            print(f"[{tag}] {pdf} -> {r.output} (페이지 {r.pages}, 표 {r.tables}, "
                  f"텍스트 {r.text_pages}, OCR {r.ocr_pages}, OCR실패 {len(r.failed_pages)})")
            for w in r.warnings:
                print(f"     - {w}")
        except Exception as e:  # noqa: BLE001
            failed += 1
            print(f"[실패] {pdf}: {e}", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
