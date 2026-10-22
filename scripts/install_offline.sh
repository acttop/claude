#!/usr/bin/env bash
# [폐쇄망 PC] wheelhouse 로 오프라인 설치 (Linux는 python3-tk 패키지 필요)
set -e; cd "$(dirname "$0")/.."
python3 -m venv .venv && . .venv/bin/activate
pip install --no-index --find-links=wheelhouse -r requirements.txt
echo "[완료] 실행: . .venv/bin/activate && python run_gui.py"
