"""PyInstaller 진입점 겸 GUI 실행 스크립트."""
import sys

from pdf2excel.cli import main as cli_main
from pdf2excel.gui import main as gui_main

if __name__ == "__main__":
    sys.exit(cli_main()) if len(sys.argv) > 1 else gui_main()
