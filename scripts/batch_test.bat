@echo off
REM D:\pdftoexcel 의 PDF 전체를 변환 -> D:\pdftoexcel\results (작업폴더) 에 저장 + 테스트리포트 생성
cd /d %~dp0..
if exist .venv call .venv\Scripts\activate.bat
python batch_test.py "D:\pdftoexcel" "D:\pdftoexcel\results"
pause
