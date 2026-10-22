@echo off
REM [Internet PC] Download wheel packages for offline install
REM  - Use the same Python version / 64bit as the offline PC
REM  - Result: wheelhouse\ folder
cd /d "%~dp0.."
python -m pip download -r requirements-build.txt -d wheelhouse
if errorlevel 1 (
  echo [ERROR] Download failed.
  pause
  exit /b 1
)
echo.
echo [DONE] wheelhouse folder created. Copy the whole project folder to the offline PC.
pause
