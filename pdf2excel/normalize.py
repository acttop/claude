"""OCR 결과 보정: 금액 열의 구분기호 오인식, 기간 표기 통일."""
from __future__ import annotations

import re

# 헤더에 이 단어가 있으면 금액 열로 본다
AMOUNT_HEADERS = ("금액", "단가", "합계", "비용", "총액", "공급가", "세액", "원")
PERIOD_HEADERS = ("기간", "계약기간", "유지보수기간")

# OCR이 쉼표를 ':' '.' ';' 등으로 잘못 읽은 천 단위 금액: 13,992:000 / 1.200.000
_GROUPED = re.compile(r"^\d{1,3}(?:\s?[,.:;'`]\s?\d{3})+$")
_AMOUNT_CHARS = re.compile(r"^[\d\s,.:;'`]+$")
# 202701-202912 / 2027.01-2029.12 / 2027-01~2029-12 / 2027.01 ~ 2029.12
_PERIOD = re.compile(
    r"^(\d{4})\s*[.\-/]?\s*(\d{2})\s*[-~∼〜–—]\s*(\d{4})\s*[.\-/]?\s*(\d{2})$")


def fix_amount(value: str | None, amount_column: bool = False):
    """금액 문자열을 정수로 보정한다. 보정 대상이 아니면 원래 값을 돌려준다.

    "13,992:000" -> 13992000, "1.200.000" -> 1200000
    amount_column=True 이면 숫자/구분기호로만 된 값은 모두 숫자만 추출한다.
    """
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return value
    if _GROUPED.match(text) or (amount_column and _AMOUNT_CHARS.match(text)):
        digits = re.sub(r"\D", "", text)
        if digits:
            return int(digits)
    return value


_CODE = re.compile(r"^([A-Z]{1,3})\s?-\s?([\dOoIl|]{2,3})$")


def fix_code(value: str | None):
    """일련번호 보정: "N-O7" -> "N-07", "N-1l" -> "N-11"."""
    if value is None:
        return None
    m = _CODE.match(str(value).strip())
    if not m:
        return value
    num = m.group(2).translate(str.maketrans("OoIl|", "00111"))
    return f"{m.group(1)}-{num}"


def fix_period(value: str | None):
    """"202701-202912" -> "2027.01~2029.12". 월이 1~12가 아니면 그대로 둔다."""
    if value is None:
        return None
    m = _PERIOD.match(str(value).strip())
    if not m:
        return value
    y1, m1, y2, m2 = m.groups()
    if not (1 <= int(m1) <= 12 and 1 <= int(m2) <= 12):
        return value
    return f"{y1}.{m1}~{y2}.{m2}"


def _is_header(cell, keywords) -> bool:
    return bool(cell) and any(k in str(cell).replace(" ", "") for k in keywords)


def normalize_table(rows: list[list]) -> list[list]:
    """표 전체 보정. 첫 행을 헤더로 보고 금액/기간 열을 판별한다."""
    if not rows:
        return rows
    header = rows[0]
    amount_cols = {i for i, h in enumerate(header) if _is_header(h, AMOUNT_HEADERS)}
    out = [list(header)]
    for row in rows[1:]:
        fixed = []
        for i, cell in enumerate(row):
            if i == 0:
                cell = fix_code(cell)
            cell = fix_period(cell)
            cell = fix_amount(cell, amount_column=i in amount_cols)
            fixed.append(cell)
        out.append(fixed)
    return out
