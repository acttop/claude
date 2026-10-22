@echo off
REM Build single exe (runs on PCs without Python)
cd /d "%~dp0.."
where python >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Python not found. Install Python 3.10+ with "Add python.exe to PATH" checked.
  pause
  exit /b 1
)
if not exist .venv python -m venv .venv
call .venv\Scripts\activate.bat
if exist wheelhouse (
  python -m pip install --no-index --find-links=wheelhouse -r requirements-build.txt
) else (
  python -m pip install -r requirements-build.txt
)
if errorlevel 1 (
  echo [ERROR] Package install failed.
  pause
  exit /b 1
)
pyinstaller --noconfirm --onefile --windowed --name PDF2Excel --collect-all pdfplumber --collect-all pypdfium2 run_gui.py
if errorlevel 1 (
  echo [ERROR] Build failed.
  pause
  exit /b 1
)
echo.
echo [DONE] Created: %cd%\dist\PDF2Excel.exe
pause
