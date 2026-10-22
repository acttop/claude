"""PyInstaller 진입점 겸 GUI 실행 스크립트."""
import os
import sys
import traceback


def _attach_output():
    """창 모드(--windowed) exe는 stdout이 없어 명령줄 실행 시 메시지가 사라진다.
    실행한 콘솔(cmd)에 붙이고, 콘솔이 없으면 로그 파일(PDF2EXCEL_LOG 또는 exe 옆)에 남긴다."""
    if sys.stdout is not None:
        return
    log_path = os.environ.get("PDF2EXCEL_LOG")
    if not log_path and os.name == "nt":
        import ctypes
        if ctypes.windll.kernel32.AttachConsole(-1):  # 부모 콘솔
            sys.stdout = sys.stderr = open("CONOUT$", "w", encoding="utf-8", buffering=1)
            print()
            return
    log_path = log_path or os.path.join(os.path.dirname(sys.executable), "PDF2Excel.log")
    sys.stdout = sys.stderr = open(log_path, "a", encoding="utf-8", buffering=1)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        _attach_output()
        try:
            from pdf2excel.cli import main as cli_main
            code = cli_main()
        except Exception:  # noqa: BLE001
            traceback.print_exc()
            code = 1
        sys.stdout.flush()
        sys.exit(code)
    from pdf2excel.gui import main as gui_main
    gui_main()
