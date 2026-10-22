#!/usr/bin/env bash
# [인터넷 PC] 폐쇄망 반입용 wheel 다운로드 (Linux 대상)
set -e; cd "$(dirname "$0")/.."
python3 -m pip download -r requirements-build.txt -d wheelhouse
echo "[완료] wheelhouse/ 생성"
