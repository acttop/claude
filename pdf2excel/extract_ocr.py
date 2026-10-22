"""스캔(이미지) PDF 페이지의 표를 OCR로 추출한다. (Tesseract, 오프라인 동작)

처리 순서
 1. 페이지를 300DPI 이미지로 변환
 2. 방향 판별: 0도/180도 각각 OCR → 첫 열 "N-01" 패턴 수, 평균 신뢰도가 높은 쪽 채택
 3. 괘선(가로/세로 선)으로 표 영역과 셀 경계 검출 → 표 밖 텍스트(제목, 쪽번호)는 제외
 4. 셀 단위 OCR, 잉크는 있는데 결과가 빈 셀은 2배 확대 후 재인식
"""
from __future__ import annotations

import logging
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

from .normalize import AMOUNT_HEADERS, PERIOD_HEADERS

log = logging.getLogger(__name__)

DPI = 300
LANG = "kor+eng"
# 첫 열 일련번호 패턴: N-01, A-12, NW-003 등
FIRST_COL = re.compile(r"^[A-Z]{1,3}\s?-\s?[\dOoIl]{2,3}$")
# 열 종류별 허용 문자 (헤더로 판별). 숫자 열에서 '7'→'/' 같은 오인식을 막는다.
QTY_HEADERS = ("수량", "개수", "대수", "건수")
DIGITS = "0123456789"
WHITELIST = {"qty": DIGITS, "amount": DIGITS + ",", "period": DIGITS + ".~-"}


class OcrError(RuntimeError):
    """OCR 엔진 미설치, 학습 데이터 없음 등 OCR 자체를 수행할 수 없는 경우."""


@dataclass
class OcrTable:
    rows: list[list[str | None]]
    bbox: tuple[int, int, int, int]  # x, y, w, h (페이지 이미지 기준)


@dataclass
class OcrPage:
    tables: list[OcrTable]
    rotation: int            # 채택한 회전 각도 (0 또는 180)
    confidence: float        # 방향 판별 시 평균 신뢰도
    text: str                # 페이지 전체 OCR 텍스트 (표 미검출 시 참고용)


def find_tessdata() -> Path:
    """학습 데이터 위치: TESSDATA_PREFIX → exe 내장 → 프로젝트 tessdata/ 순."""
    candidates = []
    if os.environ.get("TESSDATA_PREFIX"):
        candidates.append(Path(os.environ["TESSDATA_PREFIX"]))
    if getattr(sys, "_MEIPASS", None):
        candidates.append(Path(sys._MEIPASS) / "tessdata")
    candidates.append(Path(__file__).resolve().parent.parent / "tessdata")
    for c in candidates:
        if (c / "kor.traineddata").exists():
            return _ascii_path(c)
    raise OcrError("한글 OCR 학습 데이터(kor.traineddata)를 찾을 수 없습니다. "
                   "scripts/fetch_tessdata.py 로 받은 뒤 tessdata 폴더에 두세요.")


def _ascii_path(tessdata: Path) -> Path:
    """Windows의 Tesseract는 한글 경로(예: C:\\Users\\홍길동\\...)를 못 여는 경우가 있어
    경로에 비ASCII 문자가 있으면 C:\\ProgramData\\PDF2Excel\\tessdata 로 복사해 쓴다."""
    if os.name != "nt" or str(tessdata).isascii():
        return tessdata
    import shutil
    dest = Path(os.environ.get("PROGRAMDATA", r"C:\ProgramData")) / "PDF2Excel" / "tessdata"
    try:
        dest.mkdir(parents=True, exist_ok=True)
        for f in tessdata.glob("*.traineddata"):
            target = dest / f.name
            if not target.exists() or target.stat().st_size != f.stat().st_size:
                shutil.copy2(f, target)
        return dest
    except OSError as e:
        raise OcrError(f"OCR 학습 데이터를 영문 경로로 복사하지 못했습니다: {e}") from e


class OcrEngine:
    """tesserocr 래퍼. 한 번 만들어 여러 페이지에 재사용한다."""

    def __init__(self, tessdata: Path | None = None, lang: str = LANG):
        try:
            import tesserocr
        except ImportError as e:
            raise OcrError("OCR 엔진(tesserocr)이 설치되어 있지 않습니다.") from e
        self._t = tesserocr
        self.api = tesserocr.PyTessBaseAPI(path=str(tessdata or find_tessdata()), lang=lang)

    def close(self):
        self.api.End()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def read(self, img: np.ndarray, psm: int, whitelist: str = "") -> tuple[str, float]:
        self.api.SetPageSegMode(psm)
        self.api.SetVariable("tessedit_char_whitelist", whitelist)
        self.api.SetImage(Image.fromarray(img))
        text = self.api.GetUTF8Text().strip()
        return text, float(self.api.MeanTextConf())


# ---------- 이미지 처리 ----------
def render_page(pdf_path: str | Path, page_index: int, password: str | None = None,
                dpi: int = DPI) -> np.ndarray:
    import pypdfium2 as pdfium
    doc = pdfium.PdfDocument(str(pdf_path), password=password)
    try:
        pil = doc[page_index].render(scale=dpi / 72, grayscale=True).to_pil()
    finally:
        doc.close()
    return np.array(pil.convert("L"))


def _binarize(gray: np.ndarray) -> np.ndarray:
    """글자/선=255, 배경=0 인 이진 이미지."""
    return cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_MEAN_C,
                                 cv2.THRESH_BINARY_INV, 25, 15)


def _line_positions(profile: np.ndarray, min_len: int, gap: int = 4) -> list[int]:
    """선 마스크의 투영값에서 선 위치(중심)를 구한다."""
    idx = np.where(profile >= min_len)[0]
    if idx.size == 0:
        return []
    groups, start, prev = [], idx[0], idx[0]
    for i in idx[1:]:
        if i - prev > gap:
            groups.append((start + prev) // 2)
            start = i
        prev = i
    groups.append((start + prev) // 2)
    return groups


def detect_tables(gray: np.ndarray, min_size: int = 80) -> list[tuple[tuple, list[int], list[int]]]:
    """괘선으로 표를 찾는다. [(bbox, 가로선 y목록, 세로선 x목록)]"""
    binary = _binarize(gray)
    h, w = binary.shape
    horiz = cv2.morphologyEx(binary, cv2.MORPH_OPEN,
                             cv2.getStructuringElement(cv2.MORPH_RECT, (max(w // 30, 20), 1)))
    vert = cv2.morphologyEx(binary, cv2.MORPH_OPEN,
                            cv2.getStructuringElement(cv2.MORPH_RECT, (1, max(h // 40, 20))))
    grid = cv2.dilate(cv2.add(horiz, vert), np.ones((3, 3), np.uint8))
    contours, _ = cv2.findContours(grid, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    tables = []
    for c in contours:
        x, y, bw, bh = cv2.boundingRect(c)
        if bw < min_size or bh < min_size:
            continue
        hs = horiz[y:y + bh, x:x + bw]
        vs = vert[y:y + bh, x:x + bw]
        ys = _line_positions((hs > 0).sum(axis=1), int(bw * 0.5))
        xs = _line_positions((vs > 0).sum(axis=0), int(bh * 0.5))
        if len(ys) >= 2 and len(xs) >= 2:
            tables.append(((x, y, bw, bh), [y + v for v in ys], [x + v for v in xs]))
    tables.sort(key=lambda t: (t[0][1], t[0][0]))  # 위→아래
    return tables


def _cell_image(gray: np.ndarray, x0: int, y0: int, x1: int, y1: int,
                margin: int = 5) -> np.ndarray | None:
    """괘선을 피해 셀 내부를 잘라낸다. 너무 작으면 None."""
    x0, y0, x1, y1 = x0 + margin, y0 + margin, x1 - margin, y1 - margin
    if x1 - x0 < 6 or y1 - y0 < 6:
        return None
    return gray[y0:y1, x0:x1]


def _has_ink(cell: np.ndarray, min_pixels: int = 8, min_blob: int = 4) -> bool:
    """셀에 글자가 있는지. 면적 비율이 아니라 '진한 픽셀 덩어리'로 판단해야
    넓은 셀 안의 작은 한 자리 숫자(수량 "3" 등)를 빈 셀로 버리지 않는다.
    min_blob 보다 작은 점(스캔 잡티)은 무시한다."""
    dark = (cell < 180).astype(np.uint8)
    n, _, stats, _ = cv2.connectedComponentsWithStats(dark, connectivity=8)
    areas = stats[1:, cv2.CC_STAT_AREA] if n > 1 else np.array([], dtype=int)
    return int(areas[areas >= min_blob].sum()) >= min_pixels


def _clean_cell(cell: np.ndarray, pad: int = 10) -> np.ndarray:
    """스캔 잡음 제거: 흐림 → Otsu 이진화 → 작은 점 제거 → 흰 여백 추가 (검은 글자/흰 배경)."""
    blur = cv2.GaussianBlur(cell, (3, 3), 0)
    _, ink = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    ink = cv2.morphologyEx(ink, cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
    return cv2.copyMakeBorder(255 - ink, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=255)


def _upscale(cell: np.ndarray, factor: int = 2, pad: int = 20) -> np.ndarray:
    big = cv2.resize(cell, None, fx=factor, fy=factor, interpolation=cv2.INTER_CUBIC)
    return _clean_cell(big, pad)


def _clean_text(text: str) -> str | None:
    text = " ".join(line.strip() for line in text.splitlines() if line.strip())
    return text or None


def read_cell(engine: OcrEngine, cell: np.ndarray | None, kind: str = "") -> str | None:
    """셀 1개 인식. kind: qty/amount/period 이면 허용 문자를 제한한다."""
    if cell is None or not _has_ink(cell):
        return None
    wl = WHITELIST.get(kind, "")
    clean = _clean_cell(cell)
    # 한 줄 모드(psm 7)가 괘선 잔여물에 강하다. 못 읽으면 여러 줄 모드(psm 6)로 한 번 더.
    for psm in (7, 6):
        text = _clean_text(engine.read(clean, psm=psm, whitelist=wl)[0])
        if text:
            return text
    # 잉크는 있는데 못 읽은 셀(예: 수량 "3" 같은 한 자리 숫자) → 2배 확대 후 재인식
    big = _upscale(cell)
    tries = ((10, wl or DIGITS), (7, wl), (10, wl))
    for psm, wl in tries:
        text = _clean_text(engine.read(big, psm=psm, whitelist=wl)[0])
        if text:
            log.debug("재인식 성공(psm=%s): %s", psm, text)
            return text
    return None


def column_kind(header: str | None) -> str:
    h = (header or "").replace(" ", "")
    if any(k in h for k in QTY_HEADERS):
        return "qty"
    if any(k in h for k in PERIOD_HEADERS):
        return "period"
    if any(k in h for k in AMOUNT_HEADERS):
        return "amount"
    return ""


def read_table(engine: OcrEngine, gray: np.ndarray, ys: list[int], xs: list[int]) -> list[list]:
    """첫 행(헤더)을 먼저 읽어 열 종류를 정한 뒤 나머지 셀을 읽는다."""
    ncol = len(xs) - 1
    cell = lambda r, c: _cell_image(gray, xs[c], ys[r], xs[c + 1], ys[r + 1])  # noqa: E731
    header = [read_cell(engine, cell(0, c)) for c in range(ncol)]
    kinds = [column_kind(h) for h in header]
    rows = [header] if any(header) else []
    for r in range(1, len(ys) - 1):
        row = [read_cell(engine, cell(r, c), kinds[c]) for c in range(ncol)]
        if any(v for v in row):
            rows.append(row)
    return rows


# ---------- 방향 판별 ----------
def orientation_score(engine: OcrEngine, gray: np.ndarray) -> tuple[int, float]:
    """(첫 열 패턴 일치 수, 평균 신뢰도). 표가 있으면 첫 열 셀만 읽어 빠르게 판별한다."""
    tables = detect_tables(gray)
    if tables:
        _, ys, xs = tables[0]
        hits, confs = 0, []
        for r in range(len(ys) - 1):
            cell = _cell_image(gray, xs[0], ys[r], xs[1], ys[r + 1])
            if cell is None or not _has_ink(cell):
                continue
            text, conf = engine.read(_clean_cell(cell), psm=7)
            hits += bool(FIRST_COL.match(text.strip()))
            confs.append(conf)
        return hits, (sum(confs) / len(confs) if confs else 0.0)
    # 표가 없으면 페이지 전체 텍스트 기준
    small = cv2.resize(gray, None, fx=0.5, fy=0.5, interpolation=cv2.INTER_AREA)
    text, conf = engine.read(small, psm=3)
    hits = sum(bool(FIRST_COL.match(tok)) for tok in text.split())
    return hits, conf


def choose_orientation(engine: OcrEngine, gray: np.ndarray) -> tuple[np.ndarray, int, float]:
    best = None
    for angle in (0, 180):
        img = gray if angle == 0 else cv2.rotate(gray, cv2.ROTATE_180)
        hits, conf = orientation_score(engine, img)
        log.debug("방향 %d도: 패턴 %d건, 신뢰도 %.1f", angle, hits, conf)
        if best is None or (hits, conf) > (best[3], best[2]):
            best = (img, angle, conf, hits)
    return best[0], best[1], best[2]


def ocr_page(engine: OcrEngine, gray: np.ndarray) -> OcrPage:
    """페이지 이미지 1장을 OCR. 표 영역(괘선 안쪽)만 표로 만든다."""
    img, angle, conf = choose_orientation(engine, gray)
    tables = []
    for bbox, ys, xs in detect_tables(img):
        rows = read_table(engine, img, ys, xs)
        if rows:
            tables.append(OcrTable(rows=rows, bbox=bbox))
    text = "" if tables else engine.read(img, psm=3)[0]
    return OcrPage(tables=tables, rotation=angle, confidence=conf, text=text)
