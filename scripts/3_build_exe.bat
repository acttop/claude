@echo off
REM ============================================================
REM 단일 실행파일(exe) 빌드 - 빌드된 exe는 Python 미설치 PC에서도 실행 가능
REM  (인터넷 PC 또는 wheelhouse가 있는 폐쇄망 PC 어디서든 가능)
REM ============================================================
cd /d %~dp0..
if not exist .venv python -m venv .venv
call .venv\Scripts\activate.bat
if exist wheelhouse (
  python -m pip install --no-index --find-links=wheelhouse -r requirements-build.txt
) else (
  python -m pip install -r requirements-build.txt
)
pyinstaller --noconfirm --onefile --windowed --name PDF2Excel ^
  --collect-all pdfplumber --collect-all pypdfium2 run_gui.py
echo [완료] dist\PDF2Excel.exe 를 폐쇄망 PC로 복사해 실행하세요.
pause
