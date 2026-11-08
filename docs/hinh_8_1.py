"""Hình 8.1 – tỉ số thời gian B ÷ A cho P1–P12 (trung vị, từ results/bench_output.txt)."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
for f in ("LiberationSerif-Regular", "LiberationSerif-Bold"):
    fm.fontManager.addfont(f"/usr/share/fonts/truetype/liberation/{f.replace('Serif-','Serif-')}.ttf")
plt.rcParams["font.family"] = "Liberation Serif"
data = [("P1 Đa hình, thuộc tính chung", 9.93, 6.00), ("P2 Đối tượng đầy đủ, đa hình", 12.52, 42.40),
        ("P3 Lớp con + thuộc tính riêng", 0.99, 8.03), ("P4 Niên đại giao 1900–1950", 8.44, 5.02),
        ("P5 Cây thành phần", 0.03, 0.03), ("P6 Tác giả × lớp", 70.32, 58.53),
        ("P7 >3 ảnh và có video", 129.72, 109.37), ("P8 Mô tả đa hình, A từng dòng", 643.20, 49.68),
        ("P9 Mô tả đa hình, A theo tập hợp", 28.70, 49.68), ("P10 Tìm theo từ khóa", 3.95, 7.31),
        ("P11 Ảnh theo máy ảnh (EXIF)", 39.26, 51.17), ("P12 Chèn 5.000 tranh", 202.01, 240.47)]
labels = [d[0] for d in data][::-1]; r = [d[2] / d[1] for d in data][::-1]
A_COL, B_COL = "#2563a8", "#c2410c"
fig, ax = plt.subplots(figsize=(8, 5.2), dpi=200)
cols = [A_COL if v > 1.005 else B_COL if v < 0.995 else "#9ca3af" for v in r]
ax.barh(range(len(r)), [v - 1 for v in r], color=cols, height=0.62, left=1)
ax.set_xscale("log"); ax.set_xlim(0.05, 15)
ax.axvline(1, color="#374151", lw=1)
for i, v in enumerate(r):
    ax.text(v * (1.08 if v >= 1 else 0.92), i, f"{v:.2f}".replace(".", ","), va="center",
            ha="left" if v >= 1 else "right", fontsize=10, color="#1f2937")
ax.set_yticks(range(len(r))); ax.set_yticklabels(labels, fontsize=10.5)
ax.set_xticks([0.1, 0.2, 0.5, 1, 2, 5, 10]); ax.set_xticklabels(["0,1", "0,2", "0,5", "1", "2", "5", "10"])
ax.set_xlabel("Tỉ số thời gian B ÷ A (thang logarit)", fontsize=11)
for s in ("top", "right"): ax.spines[s].set_visible(False)
ax.grid(axis="x", color="#e5e7eb", lw=0.8); ax.set_axisbelow(True)
from matplotlib.patches import Patch
ax.legend(handles=[Patch(color=A_COL, label="> 1: phương án A nhanh hơn"), Patch(color=B_COL, label="< 1: phương án B nhanh hơn")],
          loc="lower right", frameon=False, fontsize=10)
fig.tight_layout(); fig.savefig("docs/hinh_8_1.png", facecolor="white")
