"""Sinh hai sơ đồ lớp UML (SVG + PNG) đồng bộ với docs/odl_schema.odl:
  uml_tong_quan.svg/png – 16 lớp và mọi liên kết (bản số, tên vai trò, hợp thành, tổng quát hóa)
  uml_chi_tiet.svg/png  – thuộc tính và phương thức của từng lớp, kiểu dữ liệu, ngoại lệ
Chạy: python3 docs/uml_svg.py   (cần Pillow để đo chữ và rsvg-convert để xuất PNG)
"""
import os
import subprocess
from PIL import ImageFont

FONT = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
FONT_B = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
FONT_I = "/usr/share/fonts/truetype/liberation/LiberationSans-Italic.ttf"
FONT_BI = "/usr/share/fonts/truetype/liberation/LiberationSans-BoldItalic.ttf"
_f = {}


def tw(text, size, bold=False, italic=False):
    path = FONT_BI if bold and italic else FONT_B if bold else FONT_I if italic else FONT
    key = (path, size)
    if key not in _f:
        _f[key] = ImageFont.truetype(path, size)
    return _f[key].getlength(text)


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


INK = "#1f2937"
HEAD = "#dbe7f7"
HEAD_ABS = "#e9e3f5"
HEAD_TYPE = "#fff4d6"
LINE = "#374151"


class Box:
    def __init__(self, name, attrs=(), ops=(), stereo=None, abstract=False, kind="class",
                 fs=13, ms=11.5, minw=0):
        self.name, self.attrs, self.ops = name, list(attrs), list(ops)
        self.stereo, self.abstract, self.kind = stereo, abstract, kind
        self.fs, self.ms = fs, ms
        pad = 10
        ws = [tw(name, fs, True, abstract)]
        if stereo:
            ws.append(tw(stereo, ms))
        ws += [tw(a, ms) for a in self.attrs + self.ops]
        self.w = max(minw, max(ws) + 2 * pad)
        self.lh = ms + 4.5
        self.hh = (fs + 10) + (ms + 3 if stereo else 0)
        self.ah = len(self.attrs) * self.lh + 8 if self.attrs else 0
        self.oh = len(self.ops) * self.lh + 8 if self.ops else 0
        self.h = self.hh + self.ah + self.oh
        self.x = self.y = 0  # góc trên trái

    def at(self, cx, cy=None, top=None):
        self.x = cx - self.w / 2
        self.y = top if top is not None else cy - self.h / 2
        return self

    @property
    def cx(self):
        return self.x + self.w / 2

    @property
    def cy(self):
        return self.y + self.h / 2

    def side(self, s, f=0.5):
        if s == "t":
            return (self.x + self.w * f, self.y)
        if s == "b":
            return (self.x + self.w * f, self.y + self.h)
        if s == "l":
            return (self.x, self.y + self.h * f)
        return (self.x + self.w, self.y + self.h * f)

    def svg(self):
        fill = {"class": HEAD_ABS if self.abstract else HEAD, "type": HEAD_TYPE}[self.kind]
        o = [f'<g><rect x="{self.x:.1f}" y="{self.y:.1f}" width="{self.w:.1f}" height="{self.h:.1f}" '
             f'fill="#ffffff" stroke="{LINE}" stroke-width="1.2"/>',
             f'<rect x="{self.x:.1f}" y="{self.y:.1f}" width="{self.w:.1f}" height="{self.hh:.1f}" '
             f'fill="{fill}" stroke="{LINE}" stroke-width="1.2"/>']
        y = self.y + 4
        if self.stereo:
            y += self.ms
            o.append(f'<text x="{self.cx:.1f}" y="{y:.1f}" font-size="{self.ms}" text-anchor="middle">'
                     f'{esc(self.stereo)}</text>')
            y += 3
        y += self.fs + 2
        st = ' font-style="italic"' if self.abstract else ""
        o.append(f'<text x="{self.cx:.1f}" y="{y:.1f}" font-size="{self.fs}" font-weight="bold"{st} '
                 f'text-anchor="middle">{esc(self.name)}</text>')
        y = self.y + self.hh
        for part, h in ((self.attrs, self.ah), (self.ops, self.oh)):
            if not part:
                continue
            yy = y + 4
            for t in part:
                yy += self.lh
                o.append(f'<text x="{self.x + 8:.1f}" y="{yy - 3.5:.1f}" font-size="{self.ms}">{esc(t)}</text>')
            y += h
            o.append(f'<line x1="{self.x:.1f}" y1="{y:.1f}" x2="{self.x + self.w:.1f}" y2="{y:.1f}" '
                     f'stroke="{LINE}" stroke-width="1"/>') if part is self.attrs and self.ops else None
        return "\n".join(x for x in o if x) + "</g>"


def poly(pts, dash=False):
    d = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    da = ' stroke-dasharray="6,4"' if dash else ""
    return f'<polyline points="{d}" fill="none" stroke="{LINE}" stroke-width="1.3"{da}/>'


def diamond(p, q, filled=True, size=11):
    """Hình thoi tại p, hướng về q (đoạn p→q)."""
    import math
    dx, dy = q[0] - p[0], q[1] - p[1]
    L = math.hypot(dx, dy) or 1
    ux, uy = dx / L, dy / L
    vx, vy = -uy, ux
    a = (p[0] + ux * size, p[1] + uy * size)
    b = (p[0] + ux * size / 2 + vx * size / 3.2, p[1] + uy * size / 2 + vy * size / 3.2)
    c = (p[0] + ux * size / 2 - vx * size / 3.2, p[1] + uy * size / 2 - vy * size / 3.2)
    pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in (p, b, a, c))
    fill = LINE if filled else "#ffffff"
    return f'<polygon points="{pts}" fill="{fill}" stroke="{LINE}" stroke-width="1.2"/>', a


def triangle(p, q, size=13):
    """Tam giác rỗng (tổng quát hóa) có đỉnh tại p, đáy hướng về q."""
    import math
    dx, dy = q[0] - p[0], q[1] - p[1]
    L = math.hypot(dx, dy) or 1
    ux, uy = dx / L, dy / L
    vx, vy = -uy, ux
    base = (p[0] + ux * size, p[1] + uy * size)
    b = (base[0] + vx * size / 1.7, base[1] + vy * size / 1.7)
    c = (base[0] - vx * size / 1.7, base[1] - vy * size / 1.7)
    pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in (p, b, c))
    return f'<polygon points="{pts}" fill="#ffffff" stroke="{LINE}" stroke-width="1.2"/>', base


def label(x, y, t, size=11, anchor="start", italic=False, bold=False, bg=True):
    st = (' font-style="italic"' if italic else "") + (' font-weight="bold"' if bold else "")
    o = []
    if bg:
        w = tw(t, size, bold, italic)
        x0 = x - (w if anchor == "end" else w / 2 if anchor == "middle" else 0)
        o.append(f'<rect x="{x0 - 2:.1f}" y="{y - size:.1f}" width="{w + 4:.1f}" height="{size + 4:.1f}" '
                 f'fill="#ffffff"/>')
    o.append(f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" text-anchor="{anchor}"{st}>{esc(t)}</text>')
    return "".join(o)


def doc(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
            f'font-family="Liberation Sans, Arial, Helvetica, sans-serif" fill="{INK}">'
            f'<rect width="100%" height="100%" fill="#ffffff"/>\n{body}\n</svg>')


def gen_tree(parent, children, bus_y):
    """Tổng quát hóa kiểu cây: một tam giác dưới lớp cha, thanh ngang nối các lớp con."""
    o = []
    p = parent.side("b")
    tri, base = triangle(p, (p[0], p[1] + 50))
    o.append(poly([base, (base[0], bus_y)]))
    xs = [c.cx for c in children] + [base[0]]
    o.append(poly([(min(xs), bus_y), (max(xs), bus_y)]))
    for c in children:
        o.append(poly([(c.cx, bus_y), c.side("t")]))
    o.append(tri)
    return o


# =====================================================================
# Hình A – tổng quan liên kết
# =====================================================================
def tong_quan():
    fs, ms = 14, 12
    B = {}

    def mk(n, stereo=None, abstract=False, key=None, minw=118):
        B[n] = Box(n, [key] if key else [], stereo=stereo, abstract=abstract, fs=fs, ms=ms, minw=minw)
        return B[n]

    mk("HienVat", "«abstract»", True, "ma_hv {key}", minw=230)
    for n in ("Tranh", "Tuong", "TaiLieuCo", "ThanhPhan", "TacGia", "TrienLam", "LichSuBaoQuan", "Anh", "Video"):
        mk(n)
    mk("SangTac", "«association class»")
    mk("ThamGiaTrienLam", "«association class»")
    mk("BoSuuTap", key="ten {key}")
    mk("PhongTrungBay", key="ma_phong {key}")
    mk("ChatLieu", key="ten {key}")
    mk("TaiNguyenSo", "«abstract»", True)

    # --- vị trí (tâm x, đỉnh y) ---
    top, mid, bot = 40, 300, 560
    B["TacGia"].at(95, top=top + 8)
    B["SangTac"].at(285, top=top)
    B["BoSuuTap"].at(470, top=top)
    B["PhongTrungBay"].at(640, top=top)
    B["ChatLieu"].at(810, top=top)
    B["ThamGiaTrienLam"].at(995, top=top)
    B["TrienLam"].at(1180, top=top + 8)
    B["HienVat"].at(640, top=mid)
    B["ThanhPhan"].at(250, top=mid + 8)
    B["TaiNguyenSo"].at(1030, top=mid)
    B["LichSuBaoQuan"].at(330, top=455)
    B["Tranh"].at(500, top=bot)
    B["Tuong"].at(640, top=bot)
    B["TaiLieuCo"].at(780, top=bot)
    B["Anh"].at(960, top=bot)
    B["Video"].at(1100, top=bot)

    H = B["HienVat"]
    o = []

    def assoc(pts, m1, m2, role=None, role_at=None, comp=False, m1_off=(6, -6), m2_off=(6, -6),
              role_anchor="middle"):
        if comp:
            d, a = diamond(pts[0], pts[1])
            o.append(poly([a] + pts[1:]))
            o.append(d)
        else:
            o.append(poly(pts))
        if m1:
            o.append(label(pts[0][0] + m1_off[0], pts[0][1] + m1_off[1], m1, 11.5,
                           "end" if m1_off[0] < 0 else "start"))
        if m2:
            o.append(label(pts[-1][0] + m2_off[0], pts[-1][1] + m2_off[1], m2, 11.5,
                           "end" if m2_off[0] < 0 else "start"))
        if role:
            o.append(label(role_at[0], role_at[1], role, 11.5, role_anchor, italic=True))

    # HienVat – SangTac – TacGia
    p0 = H.side("t", 0.12); s = B["SangTac"]
    assoc([p0, (p0[0], 215), (s.cx, 215), s.side("b")], "1", "0..*", "co_tac_gia", (s.cx + 70, 210),
          m1_off=(-6, -8), m2_off=(6, 16))
    assoc([s.side("l"), B["TacGia"].side("r")], "0..*", "1", m1_off=(-6, -6), m2_off=(6, -6))
    # BoSuuTap, PhongTrungBay, ChatLieu
    p1 = H.side("t", 0.30); b = B["BoSuuTap"]
    assoc([p1, (p1[0], 240), (b.cx, 240), b.side("b")], "0..*", "0..1", "thuoc_bst", (b.cx - 6, 140),
          m1_off=(-6, -8), m2_off=(6, 16), role_anchor="end")
    p2 = H.side("t", 0.5); pt = B["PhongTrungBay"]
    assoc([p2, pt.side("b")], "0..*", "0..1", "dat_tai", (p2[0] + 6, 200), m1_off=(6, -8),
          m2_off=(6, 16), role_anchor="start")
    p3 = H.side("t", 0.70); c = B["ChatLieu"]
    assoc([p3, (p3[0], 240), (c.cx, 240), c.side("b")], "0..*", "0..*", "lam_bang", (c.cx + 6, 140),
          m1_off=(6, -8), m2_off=(6, 16), role_anchor="start")
    # ThamGiaTrienLam – TrienLam
    p4 = H.side("t", 0.88); t = B["ThamGiaTrienLam"]
    assoc([p4, (p4[0], 215), (t.cx, 215), t.side("b")], "1", "0..*", "tham_gia", (t.cx - 75, 210),
          m1_off=(6, -8), m2_off=(6, 16))
    assoc([t.side("r"), B["TrienLam"].side("l")], "0..*", "1", m1_off=(6, -6), m2_off=(-6, -6))
    # Hợp thành: ThanhPhan, LichSuBaoQuan, TaiNguyenSo
    tp = B["ThanhPhan"]
    assoc([H.side("l", 0.35), (tp.x + tp.w, H.y + H.h * 0.35)], "1", "0..*", "gom_thanh_phan",
          ((H.x + tp.x + tp.w) / 2, H.y + H.h * 0.35 - 7), comp=True, m1_off=(-14, -7), m2_off=(6, 17))
    ls = B["LichSuBaoQuan"]
    q = H.side("b", 0.12)
    assoc([q, (q[0], ls.cy), ls.side("r")], "1", "0..* {ordered}", "lich_su", (q[0] - 8, ls.cy - 30),
          comp=True, m1_off=(-8, 18), m2_off=(8, -7), role_anchor="end")
    tn = B["TaiNguyenSo"]
    assoc([H.side("r", 0.35), (tn.x, H.y + H.h * 0.35)], "1", "0..* {ordered}", "co_tai_nguyen",
          ((H.x + H.w + tn.x) / 2, H.y + H.h * 0.35 - 7), comp=True, m1_off=(14, -7), m2_off=(-6, 17))
    # ThanhPhan tự hợp thành (cây)
    a = tp.side("b", 0.72); bpt = tp.side("l", 0.75)
    loop = [a, (a[0], a[1] + 34), (tp.x - 34, a[1] + 34), (tp.x - 34, bpt[1]), bpt]
    d, a2 = diamond(loop[0], loop[1])
    o.append(poly([a2] + loop[1:])); o.append(d)
    o.append(label(a[0] + 6, a[1] + 26, "0..1", 11.5))
    o.append(label(bpt[0] - 6, bpt[1] - 6, "0..*", 11.5, "end"))
    o.append(label(tp.x - 40, a[1] + 52, "gom_con", 11.5, "start", italic=True))
    # Đường nét đứt nối lớp kết hợp (đã vẽ như lớp trung gian ⇒ không cần)
    # Tổng quát hóa
    o += gen_tree(H, [B["Tranh"], B["Tuong"], B["TaiLieuCo"]], bot - 30)
    o.append(label(H.cx + 14, bot - 36, "{complete, disjoint}", 11.5, "start", italic=True))
    o += gen_tree(tn, [B["Anh"], B["Video"]], bot - 30)
    o.append(label(tn.cx + 14, bot - 36, "{complete, disjoint}", 11.5, "start", italic=True))

    body = "\n".join(o + [b.svg() for b in B.values()])
    # chú giải
    lx, ly = 20, 545
    leg = [f'<rect x="{lx}" y="{ly}" width="330" height="74" fill="#fafafa" stroke="#9ca3af"/>',
           label(lx + 10, ly + 18, "Chú giải", 12, bold=True, bg=False)]
    d, a = diamond((lx + 12, ly + 38), (lx + 60, ly + 38))
    leg += [poly([a, (lx + 60, ly + 38)]), d, label(lx + 70, ly + 42, "hợp thành (bộ phận thuộc về toàn thể)", 11.5, bg=False)]
    tri, base = triangle((lx + 12, ly + 60), (lx + 60, ly + 60))
    leg += [poly([base, (lx + 60, ly + 60)]), tri, label(lx + 70, ly + 64, "tổng quát hóa (lớp con → lớp cha)", 11.5, bg=False)]
    W, Hh = 1290, 640
    return doc(W, Hh, body + "\n" + "\n".join(leg))


# =====================================================================
# Hình B – chi tiết thuộc tính, phương thức
# =====================================================================
def chi_tiet():
    fs, ms = 13, 11.5
    S, L, D, Dic = "String", "List", "Date", "Dictionary"
    hv = Box("HienVat", [
        "ma_hv: String {key}", "ten: String", "mo_ta: String", "nien_dai: NienDai",
        "kich_thuoc: KichThuoc", "trang_thai: TrangThai", "ngay_nhap: Date",
        "tu_khoa: Set<String>", "ten_goi_khac: List<String>", "thuoc_tinh: Dictionary<String, String>"],
        ["tuoi(): Integer", "the_tich_cm3(): Real", "tong_thanh_phan(): Integer",
         "cac_chat_lieu(): Bag<String>", "ten_lop(): String", "mo_ta_ngan(): String",
         "chuyen_phong(ma_phong: String) {raises PhongDaDay}"],
        stereo="«abstract»", abstract=True, fs=fs, ms=ms)
    tranh = Box("Tranh", ["chat_lieu_nen: String", "truong_phai: String", "co_khung: Boolean"],
                ["ten_lop(): String", "mo_ta_ngan(): String"], fs=fs, ms=ms, minw=165)
    tuong = Box("Tuong", ["chat_lieu_chinh: String", "ky_thuat: String", "trong_luong_kg: Real"],
                ["ten_lop(): String", "mo_ta_ngan(): String"], fs=fs, ms=ms, minw=165)
    tlc = Box("TaiLieuCo", ["ngon_ngu: String", "loai_chu: String", "so_trang: Integer",
                            "tinh_trang_giay: String", "muc_luc: Array<String>", "con_dau: Bag<String>"],
              ["ten_lop(): String", "mo_ta_ngan(): String"], fs=fs, ms=ms, minw=165)
    tns = Box("TaiNguyenSo", ["uri: String", "dinh_dang: String", "kich_thuoc_byte: Integer",
                              "chu_thich: String", "la_dai_dien: Boolean"],
              stereo="«abstract»", abstract=True, fs=fs, ms=ms, minw=170)
    anh = Box("Anh", ["rong_px: Integer", "cao_px: Integer", "goc_chup: String",
                      "exif: Dictionary<String, String>"], fs=fs, ms=ms, minw=150)
    vid = Box("Video", ["thoi_luong_giay: Integer", "do_phan_giai: String"], fs=fs, ms=ms, minw=150)
    r3 = [Box("ThanhPhan", ["ten: String", "so_luong: Integer", "chat_lieu: String"],
              ["muc(): Integer", "tat_ca_hau_due(): Set<ThanhPhan>"], fs=fs, ms=ms),
          Box("TacGia", ["ho_ten: String", "but_danh: String", "nam_sinh: Integer", "nam_mat: Integer",
                         "quoc_tich: String"], fs=fs, ms=ms),
          Box("SangTac", ["vai_tro: String"], stereo="«association class»", fs=fs, ms=ms),
          Box("ThamGiaTrienLam", ["vi_tri: String"], stereo="«association class»", fs=fs, ms=ms),
          Box("TrienLam", ["ten: String", "tu_ngay: Date", "den_ngay: Date"], fs=fs, ms=ms)]
    r4 = [Box("BoSuuTap", ["ten: String {key}", "mo_ta: String"], fs=fs, ms=ms),
          Box("PhongTrungBay", ["ma_phong: String {key}", "ten: String", "tang: Integer", "suc_chua: Integer"],
              fs=fs, ms=ms),
          Box("ChatLieu", ["ten: String {key}"], fs=fs, ms=ms),
          Box("LichSuBaoQuan", ["ngay: Date", "hang_muc: String", "mo_ta: String", "nguoi_thuc_hien: String"],
              fs=fs, ms=ms)]
    r5 = [Box("KichThuoc", ["dai_cm: Real", "rong_cm: Real", "cao_cm: Real"], stereo="«struct»", kind="type",
              fs=fs, ms=ms),
          Box("NienDai", ["tu_nam: Integer", "den_nam: Integer", "mo_ta: String"], stereo="«struct»",
              kind="type", fs=fs, ms=ms),
          Box("TrangThai", ["trung_bay", "luu_kho", "bao_quan", "cho_muon"], stereo="«enumeration»",
              kind="type", fs=fs, ms=ms),
          Box("PhongDaDay", ["ma_phong: String", "suc_chua: Integer"], stereo="«exception»", kind="type",
              fs=fs, ms=ms)]
    W = 1120
    o = []
    # Hàng 1–2: phân cấp hiện vật (trái) và tài nguyên số (phải)
    y1 = 20
    hv.at(330, top=y1)
    tns.at(905, top=y1 + 40)
    y2 = y1 + hv.h + 55
    tranh.at(130, top=y2); tuong.at(330, top=y2); tlc.at(530, top=y2)
    anh.at(820, top=tns.y + tns.h + 55); vid.at(1000, top=tns.y + tns.h + 55)
    o += gen_tree(hv, [tranh, tuong, tlc], y2 - 25)
    o.append(label(hv.cx + 12, y2 - 31, "{complete, disjoint}", 11.5, italic=True))
    o += gen_tree(tns, [anh, vid], anh.y - 25)
    o.append(label(tns.cx + 12, anh.y - 31, "{complete, disjoint}", 11.5, italic=True))

    def row(boxes, top):
        gap = (W - 40 - sum(b.w for b in boxes)) / (len(boxes) - 1)
        x = 20
        for b in boxes:
            b.x, b.y = x, top
            x += b.w + gap
        return top + max(b.h for b in boxes)

    y3 = max(tlc.y + tlc.h, vid.y + vid.h, anh.y + anh.h) + 40
    y4 = row(r3, y3) + 30
    y5 = row(r4, y4) + 50
    # khung nhóm kiểu dữ liệu
    yend = row(r5, y5 + 10)
    o.append(f'<rect x="10" y="{y5 - 22}" width="{W - 20}" height="{yend - y5 + 42}" fill="none" '
             f'stroke="#9ca3af" stroke-dasharray="5,4"/>')
    o.append(label(20, y5 - 6, "Kiểu dữ liệu và ngoại lệ dùng trong lược đồ", 12, bold=True))
    boxes = [hv, tranh, tuong, tlc, tns, anh, vid] + r3 + r4 + r5
    return doc(W, int(yend + 22), "\n".join(o + [b.svg() for b in boxes]))


def main():
    out = os.path.dirname(os.path.abspath(__file__))
    for ten, f in (("uml_tong_quan", tong_quan), ("uml_chi_tiet", chi_tiet)):
        svg = os.path.join(out, ten + ".svg")
        open(svg, "w", encoding="utf-8").write(f())
        subprocess.run(["rsvg-convert", "-z", "2.5", svg, "-o", os.path.join(out, ten + ".png")], check=True)


if __name__ == "__main__":
    main()
