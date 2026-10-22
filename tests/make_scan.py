"""OCR 테스트용 '스캔' PDF 생성기 (텍스트 레이어 없는 이미지 PDF).

- 표 위 제목, 표 아래 쪽번호 (표에서 제외되어야 함)
- 수량 열은 한 자리 숫자
- rotate=True 페이지는 180도 뒤집어 저장
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = Path(__file__).parent / "fonts" / "NanumGothic-Regular.ttf"
HEADER = ["번호", "품목", "수량", "금액", "유지보수기간"]
COL_W = [240, 620, 200, 480, 560]
ROW_H = 110


def sample_rows(start: int, n: int) -> list[list[str]]:
    items = ["서버 유지보수", "네트워크 장비", "보안 솔루션", "DB 라이선스", "백업 장비",
             "UPS 점검", "스토리지", "그룹웨어"]
    rows = []
    for i in range(n):
        k = start + i
        rows.append([f"N-{k:02d}", items[(k - 1) % len(items)], str((k * 3) % 9 + 1),
                     f"{(k * 1234567) % 90000000 + 1000000:,}", "2027.01~2029.12"])
    return rows


def draw_page(rows: list[list[str]], page_no: int, title: str = "유지보수 목록") -> Image.Image:
    img = Image.new("L", (2480, 3508), 255)  # A4 @300dpi
    d = ImageDraw.Draw(img)
    big, font, small = (ImageFont.truetype(str(FONT), s) for s in (80, 50, 44))
    x0, y0 = 160, 420
    d.text((x0, 220), title, font=big, fill=0)
    table = [HEADER] + rows
    width = sum(COL_W)
    for r in range(len(table) + 1):
        d.line([(x0, y0 + r * ROW_H), (x0 + width, y0 + r * ROW_H)], fill=0, width=4)
    x = x0
    for w in COL_W + [0]:
        d.line([(x, y0), (x, y0 + len(table) * ROW_H)], fill=0, width=4)
        x += w
    for r, row in enumerate(table):
        x = x0
        for c, val in enumerate(row):
            d.text((x + 30, y0 + r * ROW_H + 28), val, font=font, fill=0)
            x += COL_W[c]
    d.text((1180, y0 + len(table) * ROW_H + 120), f"- {page_no} -", font=small, fill=0)
    # 스캔 느낌: 약간의 흐림 + 잡음
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    arr = np.array(img).astype(np.int16)
    arr += np.random.default_rng(page_no).integers(-25, 25, arr.shape, dtype=np.int16)
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8))


def make_scan_pdf(path: Path, pages: list[tuple[list[list[str]], bool]]) -> Path:
    images = []
    for i, (rows, rotate) in enumerate(pages, start=1):
        img = draw_page(rows, i)
        images.append(img.rotate(180) if rotate else img)
    images[0].save(path, save_all=True, append_images=images[1:], resolution=300)
    return path


if __name__ == "__main__":
    out = make_scan_pdf(Path("scan_sample.pdf"),
                        [(sample_rows(1, 8), False), (sample_rows(9, 6), True)])
    print(out)
