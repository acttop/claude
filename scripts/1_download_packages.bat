@echo off
REM ============================================================
REM [인터넷 PC에서 실행] 폐쇄망 반입용 패키지(wheel) 다운로드
REM  - 폐쇄망 PC와 같은 Python 버전/OS(64bit)에서 실행해야 합니다.
REM  - 결과: wheelhouse\ 폴더 -> 이 폴더 전체를 폐쇄망으로 반입
REM ============================================================
cd /d %~dp0..
python -m pip download -r requirements-build.txt -d wheelhouse
if errorlevel 1 (echo [오류] 다운로드 실패 & pause & exit /b 1)
echo.
echo [완료] wheelhouse 폴더가 생성되었습니다. 프로젝트 폴더 전체를 반입하세요.
pause
