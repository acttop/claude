"""[인터넷 PC] 한글/영문 OCR 학습 데이터를 tessdata 폴더에 받는다 (tessdata_fast)."""
import sys
import urllib.request
from pathlib import Path

BASE = "https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/"
DEST = Path(__file__).resolve().parent.parent / "tessdata"

DEST.mkdir(exist_ok=True)
for lang in ("kor", "eng"):
    target = DEST / f"{lang}.traineddata"
    if target.exists() and target.stat().st_size > 100_000:
        print(f"[skip] {target.name} already exists")
        continue
    print(f"[download] {target.name}")
    try:
        urllib.request.urlretrieve(BASE + target.name, target)
    except Exception as e:  # noqa: BLE001
        sys.exit(f"[ERROR] {target.name} download failed: {e}")
print(f"[DONE] {DEST}")
