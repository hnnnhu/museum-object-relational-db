"""Sinh sơ đồ lớp UML (Graphviz) từ đặc tả bên dưới – đồng bộ với docs/odl_schema.odl.
Chạy: python3 docs/uml.py  → docs/uml.dot, docs/uml.png, docs/uml.svg
"""
import os
import subprocess

LOP = {
    # tên: (trừu tượng?, [thuộc tính], [phương thức])
    "HienVat": (True, ["ma_hv: String {key}", "ten: String", "mo_ta: String", "nien_dai: NienDai",
                       "kich_thuoc: KichThuoc", "trang_thai: TrangThai", "ngay_nhap: Date",
                       "tu_khoa: Set&lt;String&gt;", "ten_goi_khac: List&lt;String&gt;",
                       "thuoc_tinh: Dictionary&lt;String,String&gt;"],
                ["tuoi(): Integer", "the_tich_cm3(): Real", "tong_thanh_phan(): Integer",
                 "cac_chat_lieu(): Bag&lt;String&gt;", "ten_lop(): String", "mo_ta_ngan(): String",
                 "chuyen_phong(ma_phong: String) {raises PhongDaDay}"]),
    "Tranh": (False, ["chat_lieu_nen: String", "truong_phai: String", "co_khung: Boolean"],
              ["ten_lop(): String", "mo_ta_ngan(): String"]),
    "Tuong": (False, ["chat_lieu_chinh: String", "ky_thuat: String", "trong_luong_kg: Real"],
              ["ten_lop(): String", "mo_ta_ngan(): String"]),
    "TaiLieuCo": (False, ["ngon_ngu: String", "loai_chu: String", "so_trang: Integer", "tinh_trang_giay: String",
                          "muc_luc: Array&lt;String&gt;", "con_dau: Bag&lt;String&gt;"],
                  ["ten_lop(): String", "mo_ta_ngan(): String"]),
    "ThanhPhan": (False, ["ten: String", "so_luong: Integer", "chat_lieu: String"],
                  ["muc(): Integer", "tat_ca_hau_due(): Set&lt;ThanhPhan&gt;"]),
    "SangTac": (False, ["vai_tro: String"], []),
    "ThamGiaTrienLam": (False, ["vi_tri: String"], []),
    "TacGia": (False, ["ho_ten: String", "but_danh: String", "nam_sinh: Integer", "nam_mat: Integer",
                       "quoc_tich: String"], []),
    "ChatLieu": (False, ["ten: String {key}"], []),
    "BoSuuTap": (False, ["ten: String {key}", "mo_ta: String"], []),
    "PhongTrungBay": (False, ["ma_phong: String {key}", "ten: String", "tang: Integer", "suc_chua: Integer"], []),
    "TrienLam": (False, ["ten: String", "tu_ngay: Date", "den_ngay: Date"], []),
    "LichSuBaoQuan": (False, ["ngay: Date", "hang_muc: String", "mo_ta: String", "nguoi_thuc_hien: String"], []),
    "TaiNguyenSo": (True, ["uri: String", "dinh_dang: String", "kich_thuoc_byte: Integer", "chu_thich: String",
                           "la_dai_dien: Boolean"], []),
    "Anh": (False, ["rong_px: Integer", "cao_px: Integer", "goc_chup: String",
                    "exif: Dictionary&lt;String,String&gt;"], []),
    "Video": (False, ["thoi_luong_giay: Integer", "do_phan_giai: String"], []),
}
KIEU = {
    "KichThuoc": ("«struct»", ["dai_cm: Real", "rong_cm: Real", "cao_cm: Real"]),
    "NienDai": ("«struct»", ["tu_nam: Integer", "den_nam: Integer", "mo_ta: String"]),
    "TrangThai": ("«enumeration»", ["trung_bay", "luu_kho", "bao_quan", "cho_muon"]),
    "PhongDaDay": ("«exception»", ["ma_phong: String", "suc_chua: Integer"]),
}
KE_THUA = [("Tranh", "HienVat"), ("Tuong", "HienVat"), ("TaiLieuCo", "HienVat"),
           ("Anh", "TaiNguyenSo"), ("Video", "TaiNguyenSo")]
# (toàn thể, bộ phận, bản số phía toàn thể, bản số phía bộ phận, nhãn)
HOP_THANH = [("HienVat", "ThanhPhan", "1", "0..*", "gom_thanh_phan"),
             ("HienVat", "TaiNguyenSo", "1", "0..* {ordered}", "co_tai_nguyen"),
             ("HienVat", "LichSuBaoQuan", "1", "0..* {ordered}", "lich_su"),
             ("ThanhPhan", "ThanhPhan", "0..1", "0..*", "gom_con")]
# (A, B, bản số A, bản số B, nhãn)
KET_HOP = [("HienVat", "SangTac", "1", "0..*", ""), ("SangTac", "TacGia", "0..*", "1", ""),
           ("HienVat", "ThamGiaTrienLam", "1", "0..*", ""), ("ThamGiaTrienLam", "TrienLam", "0..*", "1", ""),
           ("HienVat", "BoSuuTap", "0..*", "0..1", "thuoc_bst"),
           ("HienVat", "PhongTrungBay", "0..*", "0..1", "dat_tai"),
           ("HienVat", "ChatLieu", "0..*", "0..*", "lam_bang")]


def nhan_lop(ten, truu_tuong, tt, pt):
    ten_html = f"<I>{ten}</I>" if truu_tuong else f"<B>{ten}</B>"
    tren = '<TR><TD BGCOLOR="#e8f0fe">' + (("«abstract»<BR/>" if truu_tuong else "") + ten_html) + "</TD></TR>"
    giua = '<TR><TD ALIGN="LEFT" BALIGN="LEFT">' + ("<BR ALIGN='LEFT'/>".join(tt) or " ") + "<BR ALIGN='LEFT'/></TD></TR>"
    duoi = ('<TR><TD ALIGN="LEFT" BALIGN="LEFT">' + "<BR ALIGN='LEFT'/>".join("+ " + p for p in pt)
            + "<BR ALIGN='LEFT'/></TD></TR>") if pt else '<TR><TD> </TD></TR>'
    return f'<<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="4">{tren}{giua}{duoi}</TABLE>>'


def main():
    d = ['digraph UML {',
         '  graph [fontname="DejaVu Sans", fontsize=11, rankdir=TB, nodesep=0.35, ranksep=0.6, '
         'label="Hình 4.2 – Sơ đồ lớp UML (16 lớp, 2 struct, 1 enum, 1 exception)", labelloc=t];',
         '  node [shape=plaintext, fontname="DejaVu Sans", fontsize=9];',
         '  edge [fontname="DejaVu Sans", fontsize=9];']
    for ten, (tt_tr, tt, pt) in LOP.items():
        d.append(f"  {ten} [label={nhan_lop(ten, tt_tr, tt, pt)}];")
    for ten, (st, tt) in KIEU.items():
        d.append(f"  {ten} [label={nhan_lop(st + '<BR/>' + ten, False, tt, [])}];")
    for con, cha in KE_THUA:
        d.append(f"  {cha} -> {con} [dir=back, arrowtail=empty, arrowhead=none];")
    for tt, bp, a, b, nh in HOP_THANH:
        d.append(f'  {tt} -> {bp} [dir=both, arrowtail=diamond, arrowhead=none, '
                 f'taillabel="{a}", headlabel="{b}", label="{nh}", labeldistance=1.6];')
    for a_, b_, ma, mb, nh in KET_HOP:
        d.append(f'  {a_} -> {b_} [arrowhead=none, taillabel="{ma}", headlabel="{mb}", label="{nh}", labeldistance=1.6];')
    for k in ("NienDai", "KichThuoc", "TrangThai"):
        d.append(f"  HienVat -> {k} [style=dashed, arrowhead=vee, label=\"«use»\"];")
    d.append('  HienVat -> PhongDaDay [style=dashed, arrowhead=vee, label="«raises»"];')
    d.append("  {rank=same; Tranh; Tuong; TaiLieuCo; ThanhPhan; TaiNguyenSo; LichSuBaoQuan; SangTac; ThamGiaTrienLam}")
    d.append("  {rank=same; Anh; Video; TacGia; TrienLam; KichThuoc; NienDai; TrangThai; PhongDaDay}")
    d.append("  {rank=same; BoSuuTap; PhongTrungBay; ChatLieu}")
    d.append("}")
    thu_muc = os.path.dirname(os.path.abspath(__file__))
    p = os.path.join(thu_muc, "uml.dot")
    open(p, "w", encoding="utf-8").write("\n".join(d))
    for dinh_dang in ("png", "svg"):
        subprocess.run(["dot", f"-T{dinh_dang}", "-Gdpi=110", p, "-o", os.path.join(thu_muc, f"uml.{dinh_dang}")],
                       check=True)


if __name__ == "__main__":
    main()
