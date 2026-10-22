"""tkinter 기반 GUI (파이썬 표준 라이브러리만 사용 → 폐쇄망 추가 설치 불필요)."""
from __future__ import annotations

import queue
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from . import __version__
from .analyze import OCR_AUTO, OCR_FORCE, OCR_OFF
from .core import (LAYOUT_PER_PAGE, LAYOUT_SINGLE, MODE_AUTO, MODE_TABLE,
                   MODE_TEXT, ConvertOptions, convert, parse_pages)


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"PDF → Excel 변환기 v{__version__}")
        self.geometry("720x560")
        self.minsize(640, 460)
        self.events: queue.Queue = queue.Queue()
        self.files: list[Path] = []
        self._build()
        self.after(100, self._poll)

    # ---------- UI ----------
    def _build(self):
        pad = {"padx": 8, "pady": 4}

        f_files = ttk.LabelFrame(self, text="1. PDF 파일 선택")
        f_files.pack(fill="both", expand=True, **pad)
        self.listbox = tk.Listbox(f_files, height=8, selectmode="extended")
        self.listbox.pack(side="left", fill="both", expand=True, padx=4, pady=4)
        btns = ttk.Frame(f_files)
        btns.pack(side="right", fill="y", padx=4)
        ttk.Button(btns, text="파일 추가", command=self._add_files).pack(fill="x", pady=2)
        ttk.Button(btns, text="선택 삭제", command=self._remove_selected).pack(fill="x", pady=2)
        ttk.Button(btns, text="전체 삭제", command=self._clear).pack(fill="x", pady=2)

        f_opt = ttk.LabelFrame(self, text="2. 변환 옵션")
        f_opt.pack(fill="x", **pad)
        self.mode = tk.StringVar(value=MODE_AUTO)
        self.layout = tk.StringVar(value=LAYOUT_PER_PAGE)
        self.pages = tk.StringVar()
        self.password = tk.StringVar()
        self.numbers = tk.BooleanVar(value=True)
        self.ocr = tk.StringVar(value=OCR_AUTO)

        ttk.Label(f_opt, text="추출 방식").grid(row=0, column=0, sticky="w", **pad)
        for i, (txt, val) in enumerate([("자동(표 우선)", MODE_AUTO), ("표만", MODE_TABLE),
                                        ("텍스트만", MODE_TEXT)]):
            ttk.Radiobutton(f_opt, text=txt, value=val, variable=self.mode).grid(
                row=0, column=i + 1, sticky="w")
        ttk.Label(f_opt, text="시트 구성").grid(row=1, column=0, sticky="w", **pad)
        ttk.Radiobutton(f_opt, text="표/페이지별 시트", value=LAYOUT_PER_PAGE,
                        variable=self.layout).grid(row=1, column=1, sticky="w")
        ttk.Radiobutton(f_opt, text="한 시트로 합치기", value=LAYOUT_SINGLE,
                        variable=self.layout).grid(row=1, column=2, sticky="w")
        ttk.Label(f_opt, text="페이지 범위").grid(row=2, column=0, sticky="w", **pad)
        ttk.Entry(f_opt, textvariable=self.pages, width=18).grid(row=2, column=1, sticky="w")
        ttk.Label(f_opt, text="예: 1-3,5 (비우면 전체)", foreground="gray").grid(
            row=2, column=2, columnspan=2, sticky="w")
        ttk.Label(f_opt, text="PDF 암호").grid(row=3, column=0, sticky="w", **pad)
        ttk.Entry(f_opt, textvariable=self.password, show="*", width=18).grid(
            row=3, column=1, sticky="w")
        ttk.Checkbutton(f_opt, text="숫자 문자열을 숫자로 변환 (1,234 → 1234)",
                        variable=self.numbers).grid(row=3, column=2, columnspan=2, sticky="w")

        ttk.Label(f_opt, text="OCR(스캔 PDF)").grid(row=4, column=0, sticky="w", **pad)
        for i, (txt, val) in enumerate([("자동(스캔 페이지만)", OCR_AUTO), ("사용 안 함", OCR_OFF),
                                        ("모든 페이지", OCR_FORCE)]):
            ttk.Radiobutton(f_opt, text=txt, value=val, variable=self.ocr).grid(
                row=4, column=i + 1, sticky="w")

        f_out = ttk.LabelFrame(self, text="3. 저장 위치")
        f_out.pack(fill="x", **pad)
        self.out_dir = tk.StringVar(value="")
        ttk.Entry(f_out, textvariable=self.out_dir).pack(side="left", fill="x", expand=True,
                                                         padx=4, pady=4)
        ttk.Button(f_out, text="폴더 선택", command=self._choose_dir).pack(side="right", padx=4)
        ttk.Label(self, text="※ 저장 위치를 비우면 PDF와 같은 폴더에 저장됩니다.",
                  foreground="gray").pack(anchor="w", padx=12)

        f_run = ttk.Frame(self)
        f_run.pack(fill="x", **pad)
        self.progress = ttk.Progressbar(f_run, mode="determinate")
        self.progress.pack(side="left", fill="x", expand=True, padx=4)
        self.run_btn = ttk.Button(f_run, text="변환 시작", command=self._start)
        self.run_btn.pack(side="right", padx=4)
        self.status = tk.StringVar(value="대기 중")
        ttk.Label(self, textvariable=self.status).pack(anchor="w", padx=12, pady=(0, 8))

    # ---------- 이벤트 ----------
    def _add_files(self):
        for p in filedialog.askopenfilenames(filetypes=[("PDF 파일", "*.pdf"), ("모든 파일", "*.*")]):
            path = Path(p)
            if path not in self.files:
                self.files.append(path)
                self.listbox.insert("end", str(path))

    def _remove_selected(self):
        for i in reversed(self.listbox.curselection()):
            self.listbox.delete(i)
            del self.files[i]

    def _clear(self):
        self.listbox.delete(0, "end")
        self.files.clear()

    def _choose_dir(self):
        d = filedialog.askdirectory()
        if d:
            self.out_dir.set(d)

    def _start(self):
        if not self.files:
            messagebox.showwarning("알림", "변환할 PDF 파일을 추가해 주세요.")
            return
        try:
            pages = parse_pages(self.pages.get())
        except ValueError as e:
            messagebox.showerror("입력 오류", f"페이지 범위가 올바르지 않습니다.\n{e}")
            return
        opts = ConvertOptions(mode=self.mode.get(), layout=self.layout.get(), pages=pages,
                              convert_numbers=self.numbers.get(),
                              password=self.password.get() or None, ocr=self.ocr.get())
        self.run_btn.config(state="disabled")
        threading.Thread(target=self._worker, args=(list(self.files), opts,
                                                     self.out_dir.get().strip()),
                         daemon=True).start()

    def _worker(self, files, opts, out_dir):
        ok, failed, warnings = [], [], []
        for n, pdf in enumerate(files, start=1):
            target = (Path(out_dir) / (pdf.stem + ".xlsx")) if out_dir else pdf.with_suffix(".xlsx")
            try:
                res = convert(pdf, target, opts, progress=lambda i, t, n=n: self.events.put(
                    ("progress", n, len(files), i, t, pdf.name)))
                ok.append(res.output)
                warnings += [f"{pdf.name}: {w}" for w in res.warnings]
            except Exception as e:  # noqa: BLE001 - 사용자에게 원인 표시
                failed.append(f"{pdf.name}: {e}")
        self.events.put(("done", ok, failed, warnings))

    def _poll(self):
        try:
            while True:
                ev = self.events.get_nowait()
                if ev[0] == "progress":
                    _, n, nf, i, t, name = ev
                    self.progress["value"] = ((n - 1) + i / max(t, 1)) / nf * 100
                    self.status.set(f"[{n}/{nf}] {name} - {i}/{t}쪽 처리 중")
                else:
                    _, ok, failed, warnings = ev
                    self.run_btn.config(state="normal")
                    self.progress["value"] = 100
                    self.status.set(f"완료: 성공 {len(ok)}건 / 실패 {len(failed)}건")
                    msg = f"성공 {len(ok)}건, 실패 {len(failed)}건"
                    if failed:
                        msg += "\n\n[실패]\n" + "\n".join(failed)
                    if warnings:
                        msg += "\n\n[참고]\n" + "\n".join(warnings[:15])
                    (messagebox.showwarning if failed else messagebox.showinfo)("변환 결과", msg)
        except queue.Empty:
            pass
        self.after(100, self._poll)


def main():
    App().mainloop()


if __name__ == "__main__":
    main()
