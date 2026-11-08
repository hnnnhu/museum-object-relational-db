"""Sinh sơ đồ lược đồ quan hệ của phương án B (schema qh) – đồng bộ với sql/04_schema_B.sql.
Ký pháp: khóa chính gạch chân, in đậm (PK); khóa ngoại (FK) nối bằng mũi tên tới khóa chính được tham chiếu.
Chạy: python3 docs/luoc_do_quan_he.py → docs/luoc_do_quan_he.svg, .png
"""
import os
import subprocess
from PIL import ImageFont

F = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
FB = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
FI = "/usr/share/fonts/truetype/liberation/LiberationSans-Italic.ttf"
_c = {}


def tw(t, s, b=False, i=False):
    p = FB if b else FI if i else F
    if (p, s) not in _c:
        _c[(p, s)] = ImageFont.truetype(p, s)
    return _c[(p, s)].getlength(t)


FS, NS, RH, HH = 13.5, 14, 21, 28
LINE, INK = "#374151", "#1f2937"
FILL = {"chinh": "#dbe7f7", "con": "#e9e3f5", "da_tri": "#e6f4ea", "lien_ket": "#fff4d6"}


class T:
    def __init__(self, name, cols, nhom="chinh"):
        # cols: (tên, "PK" | "FK" | "PK,FK" | "")
        self.name, self.cols, self.nhom = name, cols, nhom
        self.w = max([tw(name, NS, True) + 24] + [tw(c, FS, "PK" in k) + 58 for c, k in cols])
        self.h = HH + len(cols) * RH + 4
        self.x = self.y = 0

    def at(self, x, y):
        self.x, self.y = x, y
        return self

    def ry(self, col):
        i = [c for c, _ in self.cols].index(col)
        return self.y + HH + i * RH + RH / 2 + 2

    @property
    def r(self):
        return self.x + self.w

    @property
    def b(self):
        return self.y + self.h

    def svg(self):
        o = [f'<rect x="{self.x}" y="{self.y}" width="{self.w:.1f}" height="{self.h}" fill="#fff" '
             f'stroke="{LINE}" stroke-width="1.2"/>',
             f'<rect x="{self.x}" y="{self.y}" width="{self.w:.1f}" height="{HH}" fill="{FILL[self.nhom]}" '
             f'stroke="{LINE}" stroke-width="1.2"/>',
             f'<text x="{self.x + self.w / 2:.1f}" y="{self.y + HH - 9}" font-size="{NS}" font-weight="bold" '
             f'text-anchor="middle">{self.name}</text>',
             f'<line x1="{self.x + 40}" y1="{self.y + HH}" x2="{self.x + 40}" y2="{self.b}" stroke="#d1d5db"/>']
        for i, (c, k) in enumerate(self.cols):
            y = self.y + HH + i * RH + RH / 2 + 7
            if k:
                o.append(f'<text x="{self.x + 20}" y="{y:.1f}" font-size="10.5" text-anchor="middle" '
                         f'fill="#6b7280" font-weight="bold">{k.replace(",", "·")}</text>')
            if "PK" in k:
                o.append(f'<text x="{self.x + 48}" y="{y:.1f}" font-size="{FS}" font-weight="bold" '
                         f'text-decoration="underline">{c}</text>')
            else:
                o.append(f'<text x="{self.x + 48}" y="{y:.1f}" font-size="{FS}">{c}</text>')
        return "\n".join(o)


def path(pts):
    d = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    return f'<polyline points="{d}" fill="none" stroke="{LINE}" stroke-width="1.3"/>'


def arrow(p, direction):
    x, y = p
    dx = 9 if direction == "l" else -9   # 'l': mũi tên chỉ sang trái (đến cạnh phải của bảng đích)
    return (f'<polygon points="{x:.1f},{y:.1f} {x + dx:.1f},{y - 4.5:.1f} {x + dx:.1f},{y + 4.5:.1f}" '
            f'fill="{LINE}"/>')


def dot(x, y):
    return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="2.6" fill="{LINE}"/>'


def main():
    S = {}

    def t(name, cols, nhom="chinh"):
        S[name] = T(name, [(c.split(":")[0], c.split(":")[1] if ":" in c else "") for c in cols], nhom)
        return S[name]

    t("HIEN_VAT", ["id:PK", "loai", "ma_hv:UQ", "ten", "mo_ta", "nien_dai_tu", "nien_dai_den", "nien_dai_mo_ta",
                   "dai_cm", "rong_cm", "cao_cm", "trang_thai", "ngay_nhap", "ma_bst:FK", "ma_phong:FK"])
    t("TRANH", ["id:PK,FK", "loai:FK", "chat_lieu_nen", "truong_phai", "co_khung"], "con")
    t("TUONG", ["id:PK,FK", "loai:FK", "chat_lieu_chinh", "ky_thuat", "trong_luong_kg"], "con")
    t("TAI_LIEU_CO", ["id:PK,FK", "loai:FK", "ngon_ngu", "loai_chu", "so_trang", "tinh_trang_giay"], "con")
    t("MUC_LUC", ["id_tl:PK,FK", "thu_tu:PK", "ten_muc"], "da_tri")
    t("CON_DAU", ["id_tl:PK,FK", "stt:PK", "ten_dau"], "da_tri")
    t("HIEN_VAT_TU_KHOA", ["id_hv:PK,FK", "tu_khoa:PK"], "da_tri")
    t("HIEN_VAT_TEN_GOI_KHAC", ["id_hv:PK,FK", "thu_tu:PK", "ten"], "da_tri")
    t("HIEN_VAT_THUOC_TINH", ["id_hv:PK,FK", "khoa:PK", "gia_tri"], "da_tri")
    t("HIEN_VAT_TAC_GIA", ["id_hv:PK,FK", "ma_tac_gia:PK,FK", "vai_tro"], "lien_ket")
    t("HIEN_VAT_CHAT_LIEU", ["id_hv:PK,FK", "ma_chat_lieu:PK,FK"], "lien_ket")
    t("TRIEN_LAM_HIEN_VAT", ["ma_tl:PK,FK", "id_hv:PK,FK", "vi_tri"], "lien_ket")
    t("TAC_GIA", ["ma_tac_gia:PK", "ho_ten", "but_danh", "nam_sinh", "nam_mat", "quoc_tich"])
    t("CHAT_LIEU", ["ma_chat_lieu:PK", "ten"])
    t("TRIEN_LAM", ["ma_tl:PK", "ten", "tu_ngay", "den_ngay"])
    t("BO_SUU_TAP", ["ma_bst:PK", "ten", "mo_ta"])
    t("PHONG_TRUNG_BAY", ["ma_phong:PK", "ten", "tang", "suc_chua"])
    t("THANH_PHAN", ["ma_tp:PK", "id_hv:FK", "ma_tp_cha:FK", "ten", "so_luong", "chat_lieu"])
    t("LICH_SU_BAO_QUAN", ["ma_ls:PK", "id_hv:FK", "ngay", "hang_muc", "mo_ta", "nguoi_thuc_hien"])
    t("TAI_NGUYEN_SO", ["ma_tn:PK", "loai", "id_hv:FK", "thu_tu", "uri", "dinh_dang", "kich_thuoc_byte",
                        "chu_thich", "la_dai_dien"])
    t("ANH", ["ma_tn:PK,FK", "loai:FK", "rong_px", "cao_px", "goc_chup"], "con")
    t("VIDEO", ["ma_tn:PK,FK", "loai:FK", "thoi_luong_giay", "do_phan_giai"], "con")
    t("ANH_EXIF", ["ma_tn:PK,FK", "khoa:PK", "gia_tri"], "da_tri")

    # ---- cột x ----
    G = 26
    x0, x1 = 20, 215
    x2 = 470
    x3 = 760
    x4 = 1035
    top = 20

    def stack(names, x, y, gap=G):
        for n in names:
            S[n].at(x, y)
            y = S[n].b + gap
        return y

    stack(["TRANH", "TUONG", "TAI_LIEU_CO", "THANH_PHAN", "LICH_SU_BAO_QUAN"], x1, top)
    S["MUC_LUC"].at(x0 - 0, S["TAI_LIEU_CO"].y - 40)
    S["CON_DAU"].at(x0, S["MUC_LUC"].b + G)
    stack(["HIEN_VAT", "BO_SUU_TAP", "PHONG_TRUNG_BAY"], x2, top, gap=34)
    stack(["HIEN_VAT_TU_KHOA", "HIEN_VAT_TEN_GOI_KHAC", "HIEN_VAT_THUOC_TINH", "HIEN_VAT_TAC_GIA",
           "HIEN_VAT_CHAT_LIEU", "TRIEN_LAM_HIEN_VAT", "TAI_NGUYEN_SO"], x3, top)
    S["TAC_GIA"].at(x4, S["HIEN_VAT_TAC_GIA"].y - 40)
    S["CHAT_LIEU"].at(x4, S["TAC_GIA"].b + 18)
    S["TRIEN_LAM"].at(x4, S["CHAT_LIEU"].b + 18)
    S["ANH"].at(x4, S["TAI_NGUYEN_SO"].y + 8)
    S["VIDEO"].at(x4, S["ANH"].b + 22)
    S["ANH_EXIF"].at(x4 + S["ANH"].w + 70, S["ANH"].y + 30)

    o = []
    H = S["HIEN_VAT"]
    hid = H.ry("id")

    # Thanh góp trái: các bảng phía trái tham chiếu HIEN_VAT(id)
    bl = x2 - 26
    left_refs = [("TRANH", "id"), ("TUONG", "id"), ("TAI_LIEU_CO", "id"), ("THANH_PHAN", "id_hv"),
                 ("LICH_SU_BAO_QUAN", "id_hv")]
    ys = []
    for n, c in left_refs:
        y = S[n].ry(c)
        ys.append(y)
        o.append(path([(S[n].r, y), (bl, y)]))
        o.append(dot(bl, y))
    o.append(path([(bl, min(ys + [hid])), (bl, max(ys))]))
    o.append(path([(bl, hid), (H.x, hid)]))
    o.append(arrow((H.x, hid), "r"))

    # Thanh góp phải: các bảng phía phải tham chiếu HIEN_VAT(id)
    br = H.r + 44
    right_refs = [("HIEN_VAT_TU_KHOA", "id_hv"), ("HIEN_VAT_TEN_GOI_KHAC", "id_hv"),
                  ("HIEN_VAT_THUOC_TINH", "id_hv"), ("HIEN_VAT_TAC_GIA", "id_hv"),
                  ("HIEN_VAT_CHAT_LIEU", "id_hv"), ("TRIEN_LAM_HIEN_VAT", "id_hv"), ("TAI_NGUYEN_SO", "id_hv")]
    ys = []
    for n, c in right_refs:
        y = S[n].ry(c)
        ys.append(y)
        o.append(path([(S[n].x, y), (br, y)]))
        o.append(dot(br, y))
    o.append(path([(br, min(ys + [hid])), (br, max(ys))]))
    o.append(path([(br, hid), (H.r, hid)]))
    o.append(arrow((H.r, hid), "l"))

    # HIEN_VAT → BO_SUU_TAP, PHONG_TRUNG_BAY (bên phải, trong khe giữa bảng và thanh góp)
    for c, dst, dx in (("ma_bst", "BO_SUU_TAP", 14), ("ma_phong", "PHONG_TRUNG_BAY", 26)):
        y1 = H.ry(c); d = S[dst]; y2 = d.ry(d.cols[0][0]); xx = H.r + dx
        o.append(path([(H.r, y1), (xx, y1), (xx, y2), (d.r, y2)]))
        o.append(arrow((d.r, y2), "l"))

    # MUC_LUC, CON_DAU → TAI_LIEU_CO(id)
    tl = S["TAI_LIEU_CO"]; ty = tl.ry("id"); ch = x1 - 18
    for n in ("MUC_LUC", "CON_DAU"):
        y = S[n].ry("id_tl")
        o.append(path([(S[n].r, y), (ch, y), (ch, ty), (tl.x, ty)]))
    o.append(arrow((tl.x, ty), "r"))

    # THANH_PHAN tự tham chiếu (ma_tp_cha → ma_tp), vòng bên trái
    tp = S["THANH_PHAN"]
    a, b = tp.ry("ma_tp_cha"), tp.ry("ma_tp")
    o.append(path([(tp.x, a), (tp.x - 22, a), (tp.x - 22, b), (tp.x, b)]))
    o.append(arrow((tp.x, b), "r"))

    # Bảng liên kết → TAC_GIA, CHAT_LIEU, TRIEN_LAM
    cx = x4 - 22
    for src, c, dst in (("HIEN_VAT_TAC_GIA", "ma_tac_gia", "TAC_GIA"),
                        ("HIEN_VAT_CHAT_LIEU", "ma_chat_lieu", "CHAT_LIEU"),
                        ("TRIEN_LAM_HIEN_VAT", "ma_tl", "TRIEN_LAM")):
        s, d = S[src], S[dst]
        y1, y2 = s.ry(c), d.ry(d.cols[0][0])
        xx = (s.r + d.x) / 2
        o.append(path([(s.r, y1), (xx, y1), (xx, y2), (d.x, y2)]))
        o.append(arrow((d.x, y2), "r"))

    # ANH, VIDEO → TAI_NGUYEN_SO(ma_tn)
    tn = S["TAI_NGUYEN_SO"]; ty = tn.ry("ma_tn"); xx = (tn.r + x4) / 2
    ys = []
    for n in ("ANH", "VIDEO"):
        y = S[n].ry("ma_tn"); ys.append(y)
        o.append(path([(S[n].x, y), (xx, y)]))
        o.append(dot(xx, y))
    o.append(path([(xx, ty), (xx, max(ys))]))
    o.append(path([(xx, ty), (tn.r, ty)]))
    o.append(arrow((tn.r, ty), "l"))

    # ANH_EXIF → ANH(ma_tn)
    an, ex = S["ANH"], S["ANH_EXIF"]
    y1, y2 = ex.ry("ma_tn"), an.ry("ma_tn"); xx = (an.r + ex.x) / 2
    o.append(path([(ex.x, y1), (xx, y1), (xx, y2), (an.r, y2)]))
    o.append(arrow((an.r, y2), "l"))

    tables = "\n".join(v.svg() for v in S.values())
    W = int(max(v.r for v in S.values()) + 20)
    Hh = int(max(v.b for v in S.values()))

    # Chú giải
    lx, ly = 20, Hh + 30
    leg = [f'<rect x="{lx}" y="{ly}" width="{W - 40}" height="64" fill="#fafafa" stroke="#9ca3af"/>',
           f'<text x="{lx + 12}" y="{ly + 25}" font-size="13"><tspan font-weight="bold">Chú giải:</tspan> '
           f'<tspan dx="6" font-weight="bold" text-decoration="underline">ma_khoa</tspan> khóa chính (PK)   ·   '
           f'FK khóa ngoại   ·   UQ khóa dự tuyển</text>',
           f'<text x="{lx + 12}" y="{ly + 49}" font-size="13">Mũi tên chỉ tới khóa chính được tham chiếu   ·   '
           f'● điểm nhập vào thanh góp chung</text>']
    xs = W - 20 - 440
    for i, (k, ten) in enumerate((("chinh", "Thực thể"), ("con", "Lớp con / tổng quát hóa"),
                                  ("da_tri", "Thuộc tính đa trị"), ("lien_ket", "Liên kết M:N"))):
        x = xs + (i % 2) * 210; y = ly + 12 + (i // 2) * 24
        leg.append(f'<rect x="{x}" y="{y}" width="22" height="14" fill="{FILL[k]}" stroke="{LINE}"/>')
        leg.append(f'<text x="{x + 30}" y="{y + 12}" font-size="13">{ten}</text>')
    Hh = ly + 64 + 16

    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{Hh}" viewBox="0 0 {W} {Hh}" '
           f'font-family="Liberation Sans, Arial, Helvetica, sans-serif" fill="{INK}">'
           f'<rect width="100%" height="100%" fill="#fff"/>\n' + "\n".join(o) + "\n" + tables + "\n"
           + "\n".join(leg) + "\n</svg>")
    out = os.path.dirname(os.path.abspath(__file__))
    p = os.path.join(out, "luoc_do_quan_he.svg")
    open(p, "w", encoding="utf-8").write(svg)
    subprocess.run(["rsvg-convert", "-z", "2.5", p, "-o", os.path.join(out, "luoc_do_quan_he.png")], check=True)


if __name__ == "__main__":
    main()
