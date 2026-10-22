@echo off
REM [Offline PC] Install packages from wheelhouse without internet
cd /d "%~dp0.."
python -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --no-index --find-links=wheelhouse -r requirements.txt
if errorlevel 1 (
  echo [ERROR] Install failed.
  pause
  exit /b 1
)
echo [DONE] Installed. Run scripts\run.bat to start.
pause
