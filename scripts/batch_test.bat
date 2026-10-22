@echo off
REM Convert all PDFs in D:\pdftoexcel -> D:\pdftoexcel\results + test report
cd /d "%~dp0.."
if exist .venv call .venv\Scripts\activate.bat
python batch_test.py "D:\pdftoexcel" "D:\pdftoexcel\results"
pause
