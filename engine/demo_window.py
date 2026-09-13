from __future__ import annotations

import tkinter as tk
from tkinter import ttk


BG = "#0B0E15"
SURFACE = "#131826"
SURFACE2 = "#1A2133"
TEXT = "#E9EEFB"
MUTED = "#9DB0D4"
DIM = "#6C7EA3"
ACCENT = "#4F8EF7"
LINE = "#242E46"
GREEN = "#3ECF9A"


def card(parent, **kwargs):
    return tk.Frame(parent, bg=SURFACE, highlightbackground=LINE, highlightthickness=1, **kwargs)


def main() -> None:
    root = tk.Tk()
    root.title("Kikoeta Transl")
    root.configure(bg=BG)
    root.geometry("1180x760+80+60")
    root.minsize(900, 600)
    try:
        root.attributes("-topmost", True)
        root.after(800, lambda: root.attributes("-topmost", False))
    except tk.TclError:
        pass

    nav = tk.Frame(root, bg=SURFACE, width=88)
    nav.pack(side="left", fill="y")
    nav.pack_propagate(False)
    tk.Frame(root, bg=LINE, width=1).pack(side="left", fill="y")

    items = [("任务", True), ("模型", False), ("字典", False), ("输出", False), ("设置", False)]
    for label, selected in items:
        color = ACCENT if selected else DIM
        item = tk.Frame(nav, bg=SURFACE)
        item.pack(fill="x", pady=10)
        tk.Label(item, text="●" if selected else "○", fg=color, bg=SURFACE, font=("Segoe UI", 11)).pack()
        tk.Label(item, text=label, fg=color, bg=SURFACE, font=("Segoe UI", 10, "bold" if selected else "normal")).pack()

    body = tk.Frame(root, bg=BG)
    body.pack(side="left", fill="both", expand=True)
    inner = tk.Frame(body, bg=BG)
    inner.pack(fill="both", expand=True, padx=22, pady=16)

    tk.Label(inner, text="Kikoeta Transl", fg=TEXT, bg=BG, font=("Segoe UI", 22, "bold")).pack(anchor="w")
    tk.Label(
        inner,
        text="这是 kikoeta-transl 翻译伴侣 Demo，不是 kikoeta 播放器。",
        fg=GREEN,
        bg=BG,
        font=("Segoe UI", 12),
    ).pack(anchor="w", pady=(4, 14))

    stage = card(inner)
    stage.pack(fill="x", pady=(0, 12))
    rows = [
        ("转码 + ASR", "音频 / 视频必做；字幕输入自动跳过", "固定"),
        ("小模型矫正", "只修听写，不翻译", "关"),
        ("gt 翻译", "进程内调用 GalTransl", "开"),
    ]
    for i, (title, sub, state) in enumerate(rows):
        row = tk.Frame(stage, bg=SURFACE)
        row.pack(fill="x", padx=14, pady=10)
        left = tk.Frame(row, bg=SURFACE)
        left.pack(side="left")
        tk.Label(left, text=title, fg=TEXT, bg=SURFACE, font=("Segoe UI", 11, "bold")).pack(anchor="w")
        tk.Label(left, text=sub, fg=DIM, bg=SURFACE, font=("Segoe UI", 9)).pack(anchor="w")
        tk.Label(row, text=state, fg=ACCENT if state != "关" else DIM, bg=SURFACE, font=("Segoe UI", 10)).pack(side="right")
        if i != len(rows) - 1:
            tk.Frame(stage, bg=LINE, height=1).pack(fill="x")

    drop = card(inner, height=110)
    drop.pack(fill="x", pady=(0, 12))
    drop.pack_propagate(False)
    tk.Label(drop, text="拖入音视频或字幕，或点击选择", fg=MUTED, bg=SURFACE, font=("Segoe UI", 12)).place(relx=0.5, rely=0.5, anchor="center")

    btns = tk.Frame(inner, bg=BG)
    btns.pack(fill="x", pady=(0, 12))
    start = tk.Label(btns, text="  开始  ", fg="white", bg=ACCENT, font=("Segoe UI", 11, "bold"), padx=12, pady=6)
    start.pack(side="left")
    tk.Label(btns, text="  停止  ", fg=MUTED, bg=SURFACE2, font=("Segoe UI", 11), padx=12, pady=6).pack(side="left", padx=8)

    log = card(inner)
    log.pack(fill="both", expand=True)
    tk.Label(log, text="日志", fg=MUTED, bg=SURFACE, font=("Segoe UI", 10, "bold")).pack(anchor="w", padx=12, pady=(10, 4))
    tk.Label(
        log,
        text="engine 未连接时仍可预览界面。\n字幕试跑：python -m kt run file.srt --no-translate",
        fg=DIM,
        bg=SURFACE,
        justify="left",
        font=("Segoe UI", 10),
    ).pack(anchor="w", padx=12, pady=(0, 12))

    root.lift()
    root.focus_force()
    root.mainloop()


if __name__ == "__main__":
    main()
