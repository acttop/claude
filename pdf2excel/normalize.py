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


_CODE = re.compile(r"^(\S{1,3}?)\s?-\s?([\dOoIlSsBZ|]{2,3})$")
_CODE_OK = re.compile(r"^[A-Z]{1,3}-\d{2,3}$")
_DIGIT_FIX = str.maketrans("OoIl|SsBZ", "001115582")


def fix_code(value: str | None, prefix: str | None = None):
    """일련번호 보정: "N-O7" -> "N-07", "N-0S" -> "N-05".
    prefix 를 주면 앞부분 오인식도 고친다: "시-02", "따-05" -> "N-02", "N-05"."""
    if value is None:
        return None
    m = _CODE.match(str(value).strip())
    if not m:
        return value
    head, num = m.group(1), m.group(2).translate(_DIGIT_FIX)
    if prefix and head != prefix and len(head) <= len(prefix) + 1:
        head = prefix
    elif not re.fullmatch(r"[A-Z]{1,3}", head):
        return value
    return f"{head}-{num}"


def fix_code_column(values: list) -> list:
    """첫 열 일련번호 전체 보정. 다수 접두어(N 등)로 통일하고,
    앞뒤가 연속 번호(N-03, N-05)인데 가운데가 깨졌으면(예: "0") N-04 로 채운다."""
    from collections import Counter
    heads = Counter(v.split("-")[0] for v in values if v and _CODE_OK.match(str(v)))
    if not heads:
        return [fix_code(v) for v in values]
    prefix, count = heads.most_common(1)[0]
    if count < 2:
        return [fix_code(v) for v in values]
    out = [fix_code(v, prefix) for v in values]
    for i in range(1, len(out) - 1):
        cur, a, b = out[i], out[i - 1], out[i + 1]
        if cur is not None and _CODE_OK.match(str(cur)):
            continue
        if a and b and _CODE_OK.match(str(a)) and _CODE_OK.match(str(b)):
            na, nb = a.split("-")[1], b.split("-")[1]
            if int(nb) - int(na) == 2 and len(na) == len(nb):
                out[i] = f"{prefix}-{int(na) + 1:0{len(na)}d}"
    return out


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
    body = [list(r) for r in rows[1:]]
    if body:
        for r, code in zip(body, fix_code_column([r[0] for r in body])):
            r[0] = code
    out = [list(header)]
    for row in body:
        fixed = []
        for i, cell in enumerate(row):
            cell = fix_period(cell)
            cell = fix_amount(cell, amount_column=i in amount_cols)
            fixed.append(cell)
        out.append(fixed)
    return out
