"""페이지 분석: 텍스트 레이어 우선, 없으면 OCR. 실패는 반드시 결과에 드러낸다."""
from __future__ import annotations

import logging
from dataclasses import dataclass, field

from .normalize import normalize_table

log = logging.getLogger(__name__)

OCR_OFF = "off"      # OCR 사용 안 함
OCR_AUTO = "auto"    # 텍스트가 없는 페이지만 OCR
OCR_FORCE = "force"  # 모든 페이지 OCR

METHOD_TEXT = "text"            # PDF 텍스트 레이어에서 추출
METHOD_OCR = "ocr"              # OCR로 표 추출 성공
METHOD_FALLBACK = "text_fallback"  # OCR 실패 → 텍스트 추출로 표 확보
METHOD_OCR_FAILED = "ocr_failed"   # OCR 실패 + 폴백에서도 표 0개


@dataclass
class PageResult:
    page_no: int
    method: str
    tables: list[list[list]] = field(default_factory=list)
    lines: list[str] = field(default_factory=list)  # 표가 없을 때 텍스트 줄
    error: str | None = None
    rotation: int = 0


def has_text_layer(page, min_chars: int = 10) -> bool:
    return len(page.chars) >= min_chars


def _text_tables(page) -> list[list[list]]:
    return [t for t in page.extract_tables() if t and any(any(c for c in r) for r in t)]


def analyze_page(page, page_no: int, *, pdf_path=None, password=None,
                 ocr: str = OCR_AUTO, engine=None,
                 engine_error: str | None = None) -> PageResult:
    """pdfplumber 페이지 1장을 분석한다.

    engine: extract_ocr.OcrEngine (OCR 필요 시에만 사용). None이면 OCR 불가로 처리하고
    engine_error 를 실패 사유로 남긴다.
    """
    need_ocr = ocr == OCR_FORCE or (ocr == OCR_AUTO and not has_text_layer(page))
    if not need_ocr:
        text = page.extract_text() or ""
        return PageResult(page_no, METHOD_TEXT, tables=_text_tables(page),
                          lines=[ln for ln in text.splitlines() if ln.strip()])

    ocr_error = None
    ocr_text = ""
    try:
        if engine is None:
            from .extract_ocr import OcrError
            raise OcrError(engine_error or "OCR 엔진이 준비되지 않았습니다.")
        from .extract_ocr import ocr_page, render_page
        result = ocr_page(engine, render_page(pdf_path, page_no - 1, password))
        if result.tables:
            err = None
            if result.cell_errors:  # 일부 셀만 실패: 표는 살리고 실패 셀을 알린다
                err = (f"셀 {len(result.cell_errors)}개 인식 오류(빈칸 처리): "
                       + "; ".join(result.cell_errors[:5]))
            return PageResult(page_no, METHOD_OCR, rotation=result.rotation, error=err,
                              tables=[normalize_table(t.rows) for t in result.tables])
        ocr_text = result.text
        ocr_error = "OCR 결과에서 표(괘선)를 찾지 못했습니다."
    except Exception as e:  # noqa: BLE001 - 원인을 결과로 전달
        log.warning("%d쪽 OCR 실패: %s", page_no, e)
        ocr_error = f"OCR 실패: {e}"

    # 폴백: PDF 텍스트 레이어로 다시 시도
    tables = _text_tables(page)
    if tables:
        return PageResult(page_no, METHOD_FALLBACK, tables=tables, error=ocr_error)
    lines = [ln for ln in (page.extract_text() or ocr_text).splitlines() if ln.strip()]
    return PageResult(page_no, METHOD_OCR_FAILED, lines=lines,
                      error=f"{ocr_error} 텍스트 폴백에서도 표가 0개입니다.")
