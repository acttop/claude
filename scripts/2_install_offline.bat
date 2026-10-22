@echo off
REM ============================================================
REM [폐쇄망 PC에서 실행] 인터넷 없이 wheelhouse 로 설치
REM ============================================================
cd /d %~dp0..
python -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --no-index --find-links=wheelhouse -r requirements.txt
if errorlevel 1 (echo [오류] 설치 실패 & pause & exit /b 1)
echo [완료] 설치되었습니다. scripts\run.bat 으로 실행하세요.
pause
