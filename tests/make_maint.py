"""실제 유지보수 목록 스캔과 같은 조건의 테스트 PDF 생성기.

PM님 제보 화면(2026-10-23) 기준 재현 요소
- 헤더 회색 배경, 얇은 회색 괘선
- 한 셀에 여러 줄 (제품명 + "-" 로 시작하는 구성품 줄)
- 영문/숫자 모델명 (Gen9, 8SFF, C-3850-12S, E.E)
- 표 위에 겹친 옅은 회색 대형 워터마크 글자
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from make_scan import FONT

HEADER = ["품번", "구분", "품명", "수량"]
COL_W = [190, 230, 1250, 170]
ROWS = [
    ["N-01", "주전산기", "EMC VNX 5200\n-600GB*12\n-EMC DS-6510 48Port SAN스위치 *2대 포함", "1"],
    ["N-02", "주전산기", "HP DL380 Gen9 8SFF CTO Server", "2"],
    ["N-03", "네트워크", "Cisco C-3850-12S\n- 광부품(G-bic)등 일체 포함", "1"],
    ["N-04", "SW", "COREBLIDE(코어브릿지)\n- REDHAT LINUX E.E * 6식 라이선스 갱신 포함", "6"],
    ["N-05", "보안장비", "AXGATE 2300", "1"],
]
LINE_H = 46


def draw_maint_page(rows=ROWS, watermark: bool = True, page_no: int = 1) -> Image.Image:
    img = Image.new("L", (2480, 3508), 255)
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(str(FONT), 34)
    x0, y = 160, 400
    width = sum(COL_W)
    table = [HEADER] + rows
    heights = [max(len(c.split("\n")) for c in r) * LINE_H + 24 for r in table]
    d.rectangle([x0, y, x0 + width, y + heights[0]], fill=205)  # 헤더 회색 배경
    ys = [y]
    for h in heights:
        ys.append(ys[-1] + h)
    for r, row in enumerate(table):
        x = x0
        for c, val in enumerate(row):
            lines = val.split("\n")
            ty = ys[r] + (heights[r] - len(lines) * LINE_H) // 2 + 4
            for i, line in enumerate(lines):
                if r == 0 or c != 2:  # 헤더/짧은 열은 가운데 정렬
                    tw = d.textlength(line, font=font)
                    tx = x + (COL_W[c] - tw) // 2
                else:
                    tx = x + 14
                d.text((tx, ty + i * LINE_H), line, font=font, fill=0)
            x += COL_W[c]
    for yy in ys:
        d.line([(x0, yy), (x0 + width, yy)], fill=90, width=2)
    x = x0
    for w in COL_W + [0]:
        d.line([(x, ys[0]), (x, ys[-1])], fill=90, width=2)
        x += w
    if watermark:  # 옅은 회색 대형 글자 (굵은 가로/세로 획이 괘선처럼 보임)
        wm = Image.new("L", img.size, 0)
        ImageDraw.Draw(wm).text((1350, ys[0] + 60), "표준", font=ImageFont.truetype(str(FONT), 330),
                                fill=255)
        arr = np.array(img)
        arr[np.array(wm) > 128] = np.minimum(arr[np.array(wm) > 128], 215)
        img = Image.fromarray(arr)
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    arr = np.array(img).astype(np.int16)
    arr += np.random.default_rng(page_no).integers(-18, 18, arr.shape, dtype=np.int16)
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8))


def make_maint_pdf(path: Path, **kw) -> Path:
    draw_maint_page(**kw).save(path, resolution=300)
    return path


if __name__ == "__main__":
    print(make_maint_pdf(Path("maint_sample.pdf")))
