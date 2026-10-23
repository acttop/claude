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
        self._path = str(tessdata or find_tessdata())
        self.api = tesserocr.PyTessBaseAPI(path=self._path, lang=lang)
        self._extra = {}  # 줄 재인식용 보조 엔진 {"eng": 영문 전용, "kor": 한글 전용}

    def _api(self, lang: str | None):
        if not lang:
            return self.api
        if lang not in self._extra:
            self._extra[lang] = self._t.PyTessBaseAPI(path=self._path, lang=lang)
        return self._extra[lang]

    def close(self):
        self.api.End()
        for api in self._extra.values():
            api.End()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def read(self, img: np.ndarray, psm: int, whitelist: str = "",
             lang: str | None = None) -> tuple[str, float]:
        api = self._api(lang)
        api.SetPageSegMode(psm)
        api.SetVariable("tessedit_char_whitelist", whitelist)
        api.SetImage(Image.fromarray(img))
        text = api.GetUTF8Text().strip()
        return text, float(api.MeanTextConf())

    def words(self, img: np.ndarray, lang: str | None = None) -> tuple[str, list["Word"]]:
        """한 줄 인식 결과 (전체 텍스트, 단어별 위치·신뢰도)."""
        api = self._api(lang)
        api.SetPageSegMode(7)
        api.SetVariable("tessedit_char_whitelist", "")
        api.SetImage(Image.fromarray(img))
        api.Recognize()
        text = api.GetUTF8Text().strip()
        out, it = [], api.GetIterator()
        level = self._t.RIL.WORD
        while it is not None:
            t = it.GetUTF8Text(level)
            if t:
                x0, _, x1, _ = it.BoundingBox(level)
                out.append(Word(t, x0, x1, float(it.Confidence(level))))
            if not it.Next(level):
                break
        return text, out

    def symbols(self, img: np.ndarray, lang: str | None = None) -> list["Word"]:
        """한 줄 인식 결과를 글자(심볼) 단위 위치·신뢰도로 돌려준다."""
        api = self._api(lang)
        api.SetPageSegMode(7)
        api.SetVariable("tessedit_char_whitelist", "")
        api.SetImage(Image.fromarray(img))
        api.Recognize()
        out, it = [], api.GetIterator()
        level = self._t.RIL.SYMBOL
        while it is not None:
            t = it.GetUTF8Text(level)
            if t:
                x0, _, x1, _ = it.BoundingBox(level)
                out.append(Word(t, x0, x1, float(it.Confidence(level))))
            if not it.Next(level):
                break
        return out


@dataclass
class Word:
    text: str
    x0: int
    x1: int
    conf: float


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


def remove_background(gray: np.ndarray, threshold: int = 170) -> np.ndarray:
    """옅은 회색(워터마크, 헤더 음영, 도장 번짐)을 흰색으로 지운다.
    워터마크의 굵은 획이 괘선·글자로 잘못 인식되는 것을 막는다."""
    out = gray.copy()
    out[out > threshold] = 255
    return out


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


def split_lines(clean: np.ndarray, min_height: int = 8) -> list[np.ndarray]:
    """여러 줄이 든 셀을 줄 단위 이미지로 나눈다 (가로 투영의 빈 줄 기준).

    "금", "품" 처럼 위아래로 쌓인 한글은 글자 안에도 빈 줄이 생기므로,
    줄 높이에 비해 좁은 틈이나 너무 낮은 조각은 이웃 줄과 합친다."""
    ink = (clean < 128).sum(axis=1)
    rows = np.where(ink > 0)[0]
    if rows.size == 0:
        return []
    bands, start, prev = [], rows[0], rows[0]
    for r in rows[1:]:
        if r - prev > 1:
            bands.append([start, prev])
            start = r
        prev = r
    bands.append([start, prev])
    merged = True
    while merged and len(bands) > 1:
        merged = False
        tall = max(b - a + 1 for a, b in bands)
        for k in range(len(bands) - 1):
            (a1, b1), (a2, b2) = bands[k], bands[k + 1]
            gap = a2 - b1 - 1
            small = min(b1 - a1 + 1, b2 - a2 + 1) < tall * 0.6
            if gap < tall * 0.3 or (small and gap < tall * 0.6):
                bands[k] = [a1, b2]
                del bands[k + 1]
                merged = True
                break
    strips = []
    for a, b in bands:
        if b - a + 1 < min_height:
            continue
        strip = clean[max(a - 6, 0):b + 7]
        strips.append(cv2.copyMakeBorder(strip, 8, 8, 0, 0, cv2.BORDER_CONSTANT, value=255))
    return strips


_HANGUL = re.compile(r"[\uac00-\ud7a3]")
_JAMO = re.compile(r"[\u3131-\u318e]")
_ALNUM = re.compile(r"[A-Za-z0-9]")
_JUNK = re.compile(r"[|\[\]{}!«»@#\\<>`]")
LOW_CONF = 45      # 이보다 낮은 단어는 다른 엔진 결과와 비교
LATIN_RECHECK = 75  # 한글 없는 단어가 이보다 낮으면 영문 엔진과 비교


_LATIN_WORD = re.compile(r"^[A-Za-z0-9.,*+\-/()]+$")
_LATIN_LETTER = re.compile(r"[A-Za-z]")


def _suspicious(w: Word) -> bool:
    """다른 엔진 결과로 바꿔 볼 단어. 깔끔한 영문/숫자 단어(COREBLIDE 등)는 한글로 덮어쓰지 않는다."""
    if _JUNK.search(w.text) or _JAMO.search(w.text):
        return True
    return w.conf < LOW_CONF and not _LATIN_WORD.match(w.text)


def _kor_candidate_ok(w: Word) -> bool:
    """한글 엔진 단어 중 믿을 만한 것: 영문자가 없고, 숫자가 길게 섞이지 않은 것 ("6식"은 허용)."""
    return not _LATIN_LETTER.search(w.text) and not re.search(r"\d{3,}", w.text)


def _overlapping(words: list[Word], x0: int, x1: int, ratio: float = 0.4) -> list[Word]:
    """x0~x1 구간과 겹치는 단어. 구간보다 훨씬 넓은 단어(줄 전체를 덮는 오인식)와
    중심이 구간 밖인 단어(이웃 글자, 예: 뒤의 "등")는 제외."""
    return [w for w in words
            if (min(w.x1, x1) - max(w.x0, x0)) / max(1, w.x1 - w.x0) >= ratio
            and x0 - 3 <= (w.x0 + w.x1) / 2 <= x1 + 3
            and (w.x1 - w.x0) <= (x1 - x0) * 1.3 + 10]


def _join(words: list[Word], height: int) -> str:
    out = ""
    for i, w in enumerate(words):
        if i and w.x0 - words[i - 1].x1 > height * 0.22:
            out += " "
        out += w.text
    return out


def _reread_region(engine: OcrEngine, strip: np.ndarray, x0: int, x1: int,
                   a_conf: float, max_len: int = 999) -> str | None:
    """의심 구간만 잘라 2배 확대 후 혼합/한글/영문 엔진으로 다시 읽어 가장 신뢰도 높은 결과."""
    pad = 2  # 이웃 글자가 섞이면 "등등" 처럼 중복된다
    crop = strip[:, max(x0 - pad, 0):min(x1 + pad, strip.shape[1])]
    big = _upscale(crop)
    best, best_conf = None, max(a_conf + 15, 50)
    for lang in (None, "kor", "eng"):
        text, conf = engine.read(big, psm=7, lang=lang)
        text = _clean_text(text)
        if text and conf > best_conf and len(text) <= max_len \
                and not (_JUNK.search(text) or _JAMO.search(text)):
            best, best_conf = text, conf
    return best


HANGUL_CONF = 85   # 한글 영역으로 확정할 한글 전용 엔진 글자 신뢰도
_PUNCT = set("()[]-.,·")


SPACE_RATIO = 0.17  # 글자 사이 빈 픽셀 열이 줄 높이의 17% 이상이면 띄어쓰기 (단어 안 2~7px, 단어 사이 13px~ @300DPI)


def _blank_run(strip: np.ndarray, a: int, b: int) -> int:
    """a~b 열 사이에서 가장 긴 '잉크 없는 열'의 길이 = 실제 글자 간격."""
    a, b = max(int(a), 0), min(int(b), strip.shape[1])
    if b <= a:
        return 0
    blank = (strip[:, a:b] < 128).sum(axis=0) == 0
    best = cur = 0
    for c in blank:
        cur = cur + 1 if c else 0
        best = max(best, cur)
    return best


def _syllable_is_latin(w: Word, mixed: list[Word]) -> bool:
    """혼합 엔진이 같은 자리를 영문자로 확실히(70점 이상) 읽었으면 한글이 아니다.
    예) "COREBLIDE" 의 D, H 를 한글 엔진은 "니", "마" 로 읽는다."""
    for m in mixed:
        center = (m.x0 + m.x1) / 2
        if w.x0 - 2 <= center <= w.x1 + 2 and _LATIN_LETTER.match(m.text) and m.conf >= 70:
            return True
    return False


def _hangul_regions(syms: list[Word], mixed: list[Word] | None = None,
                    strip: np.ndarray | None = None) -> list[tuple[int, int, str]]:
    """한글 전용 엔진 글자 중 확실한 한글 음절 구간 [(x0, x1, 텍스트)].

    - 신뢰도 HANGUL_CONF 이상인 음절이 이어진 구간 (사이의 괄호·하이픈도 포함)
    - 음절 1개짜리는 앞뒤 글자와 겹치지 않을 때만 (영문 "8SFF" 의 F 를 "타"로 읽는 경우 제외)
    """
    regions, run = [], []

    def close():
        sy = [w for w in run if _HANGUL.match(w.text)]
        if not sy:
            return
        while run and run[-1].text in _PUNCT and run[-1].text not in ")]":
            run.pop()  # 끝에 붙은 여는 기호/하이픈은 영문 쪽에 남긴다
        while run and run[0].text in _PUNCT and run[0].text not in "([":
            run.pop(0)
        if len(sy) == 1:
            k = syms.index(sy[0])
            prev = syms[k - 1] if k > 0 else None
            nxt = syms[k + 1] if k + 1 < len(syms) else None
            if (prev and prev.x1 > sy[0].x0 + 2) or (nxt and nxt.x0 < sy[0].x1 - 2) \
                    or sy[0].conf < 90:
                return
        text = ""
        for k, w in enumerate(run):
            if k and strip is not None:
                p = run[k - 1]
                gap = _blank_run(strip, (p.x0 + p.x1) / 2, (w.x0 + w.x1) / 2)
                if gap >= strip.shape[0] * SPACE_RATIO:
                    text += " "
            text += w.text
        regions.append((run[0].x0, run[-1].x1, text))

    for w in syms:
        ok_syl = _HANGUL.match(w.text) and w.conf >= HANGUL_CONF \
            and not (mixed and _syllable_is_latin(w, mixed))
        ok_punct = w.text in _PUNCT and w.conf >= 80 and run
        if ok_syl or ok_punct or (w.text in "([" and w.conf >= 80):
            run.append(w)
        else:
            close()
            run = []
    close()
    return regions


def _read_latin(engine: OcrEngine, crop: np.ndarray) -> tuple[str | None, float]:
    """한글 영역 밖(영문/숫자 위주) 조각: 혼합 엔진과 영문 엔진 중 나은 쪽.
    혼합 엔진 결과에 한글이 있으면 그대로 쓴다 (한글 전용 엔진이 놓친 한글)."""
    mixed, mc = engine.read(crop, psm=7)
    mixed = _clean_text(mixed)
    if mixed and len(_HANGUL.findall(mixed)) > 2:
        return mixed, mc
    eng, ec = engine.read(crop, psm=7, lang="eng")
    eng = _clean_text(eng)
    if not eng:
        return mixed, mc
    if not mixed:
        return eng, ec
    mt, et = mixed.split(), eng.split()
    if len(mt) == len(et):
        # 단어별 선택: 혼합 엔진이 숫자만("6609") 또는 한글 섞어("85타") 읽은 단어는 영문 엔진 단어로
        out = []
        for m, e in zip(mt, et):
            use_eng = (m.isdigit() and len(_LATIN_LETTER.findall(e)) >= 2) \
                or (_HANGUL.search(m) and _LATIN_WORD.match(e))
            out.append(e if use_eng else m)
        return " ".join(out), max(mc, ec)
    if _HANGUL.search(mixed):
        return mixed, mc
    return (eng, ec) if ec >= mc - 10 else (mixed, mc)


def _ink_cols(strip: np.ndarray, x0: int, x1: int) -> tuple[int, int] | None:
    cols = np.where((strip[:, x0:x1] < 128).sum(axis=0) > 0)[0]
    if cols.size == 0:
        return None
    return x0 + int(cols[0]), x0 + int(cols[-1]) + 1


def _trim_glyph_tail(strip: np.ndarray, span: tuple[int, int], x0: int,
                     h: int) -> tuple[int, int] | None:
    """한글 엔진의 글자 상자가 실제 잉크보다 좁으면 영문 조각 끝에 다음 한글 글자의
    앞부분이 붙는다. 한글 영역 바로 앞에서 끊기지 않고 이어진 잉크 덩어리는 잘라낸다."""
    a, b = span
    if b < x0 - 2:
        return span
    ink = (strip[:, a:b] < 128).sum(axis=0) > 0
    k = len(ink) - 1
    while k >= 0 and ink[k]:
        k -= 1
    if k < 0 or (len(ink) - 1 - k) > h * 0.6:  # 덩어리가 너무 크면 영문 글자일 수 있음
        return span
    trimmed = _ink_cols(strip, a, a + k + 1)
    return trimmed


def read_line(engine: OcrEngine, strip: np.ndarray) -> str | None:
    """한 줄 인식 (한글/영문 영역 분할 방식).

    1) 한글 전용 엔진이 확실히 읽은 한글 음절 구간을 확정  예) "코어브릿지", "스위치"
    2) 나머지 구간은 이미지를 잘라 혼합/영문 엔진으로 따로 인식  예) "COREBLIDE(", "HP DL380 Gen9"
    3) 조각 사이 간격으로 띄어쓰기 결정
    단어 위치에 의존하지 않아 엔진 버전(Windows/Linux)에 따른 단어 분리 차이에 강하다.
    """
    h, w = strip.shape
    regions = _hangul_regions(engine.symbols(strip, "kor"), engine.symbols(strip), strip)
    pieces: list[tuple[int, int, str]] = []
    cursor = 0
    for x0, x1, text in regions + [(w, w, "")]:
        span = _ink_cols(strip, cursor, max(cursor, x0 - 1))
        if span and x0 < w:
            span = _trim_glyph_tail(strip, span, x0, h)
        if span and span[1] - span[0] >= 3:
            a, b = span
            crop = cv2.copyMakeBorder(strip[:, max(a - 3, 0):b + 3], 0, 0, 12, 12,
                                      cv2.BORDER_CONSTANT, value=255)
            latin, _ = _read_latin(engine, crop)
            if not latin and b - a < h * 0.6:  # 줄 앞 "-" 같은 기호 한 글자
                latin = _clean_text(engine.read(crop, psm=10, whitelist="-~*+().,")[0])
            latin = (latin or "").strip("‘’'`!:;|“”")
            if latin:
                pieces.append((a, b, latin))
        if text:
            pieces.append((x0, x1, text))
        cursor = x1 + 1
    out = ""
    for k, (a, b, t) in enumerate(pieces):
        if k and _blank_run(strip, pieces[k - 1][1] - 4, a + 4) >= h * SPACE_RATIO:
            out += " "
        out += t
    out = re.sub(r"^~\s", "- ", out)  # 줄 앞 글머리 "-" 를 "~" 로 읽는 경우
    return _clean_text(out)


def read_cell(engine: OcrEngine, cell: np.ndarray | None, kind: str = "") -> str | None:
    """셀 1개 인식. kind: qty/amount/period 이면 허용 문자를 제한한다."""
    if cell is None or not _has_ink(cell):
        return None
    wl = WHITELIST.get(kind, "")
    clean = _clean_cell(cell)
    if not wl:
        # 일반 열: 줄 단위로 나눠 읽고 줄바꿈을 유지한다 (제품명 + "-구성품" 여러 줄 셀)
        lines = [t for t in (read_line(engine, s) for s in split_lines(clean)) if t]
        if lines:
            return "\n".join(lines)
    # 숫자 열(또는 줄 분리 실패): 한 줄 모드(psm 7) → 여러 줄 모드(psm 6)
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
    gray = remove_background(gray)
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
    img = remove_background(img)
    tables = []
    for bbox, ys, xs in detect_tables(img):
        rows = read_table(engine, img, ys, xs)
        if rows:
            tables.append(OcrTable(rows=rows, bbox=bbox))
    text = "" if tables else engine.read(img, psm=3)[0]
    return OcrPage(tables=tables, rotation=angle, confidence=conf, text=text)
