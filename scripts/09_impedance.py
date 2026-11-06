"""Đo lệch pha trở kháng (mục 8.6) trên CSDL bench: nạp 500 tượng ĐẦY ĐỦ thành đối tượng Python theo 3 cách.

B  – quan hệ thuần: 5 lượt gọi/đối tượng (hiện vật+tượng, từ khóa, tác giả, thành phần, tài nguyên)
A  – quan hệ–đối tượng: 4 lượt gọi/đối tượng (kích thước là kiểu phức hợp → namedtuple, từ khóa là mảng → list)
A1 – một lượt gọi/đối tượng: server trả về JSON lồng đúng hình dạng đối tượng
Cả ba cách được kiểm tra cho ra CÙNG đối tượng trước khi so sánh.
Phần ước tính chi phí mạng là PHÂN TÍCH LÝ THUYẾT, không phải số đo.
"""
import inspect
import statistics
import time
from dataclasses import dataclass, field
import psycopg2
from psycopg2.extras import register_composite
from truy_van_ab import DSN_BENCH

DS_ID = list(range(30001, 30501))      # 500 tượng


@dataclass
class TaiNguyen:
    lop: str
    uri: str


@dataclass
class ThanhPhan:
    ten: str
    so_luong: int
    con: list = field(default_factory=list)


@dataclass
class Tuong:
    ma_hv: str
    ten: str
    kich_thuoc: tuple
    tu_khoa: set
    chat_lieu_chinh: str
    tac_gia: set
    thanh_phan: list
    tai_nguyen: list


def dung_cay(dong):
    """dòng (ma_tp, ma_tp_cha, ten, so_luong) → danh sách nút gốc lồng nhau"""
    nut = {m: ThanhPhan(t, s) for m, c, t, s in dong}
    goc = []
    for m, c, t, s in dong:
        (nut[c].con if c in nut else goc).append(nut[m])
    return goc


# ---------------- B: quan hệ thuần ----------------
def nap_B(cur, id_):
    cur.execute("""SELECT h.ma_hv, h.ten, h.dai_cm, h.rong_cm, h.cao_cm, t.chat_lieu_chinh
                   FROM qh.hien_vat h JOIN qh.tuong t ON t.id = h.id WHERE h.id = %s""", (id_,))
    ma, ten, d, r, c, cl = cur.fetchone()
    cur.execute("SELECT tu_khoa FROM qh.hien_vat_tu_khoa WHERE id_hv = %s", (id_,))
    tk = {x for (x,) in cur.fetchall()}
    cur.execute("""SELECT tg.ho_ten FROM qh.hien_vat_tac_gia x JOIN qh.tac_gia tg ON tg.ma_tac_gia = x.ma_tac_gia
                   WHERE x.id_hv = %s""", (id_,))
    tg = {x for (x,) in cur.fetchall()}
    cur.execute("SELECT ma_tp, ma_tp_cha, ten, so_luong FROM qh.thanh_phan WHERE id_hv = %s ORDER BY ma_tp", (id_,))
    tp = dung_cay(cur.fetchall())
    cur.execute("SELECT loai, uri FROM qh.tai_nguyen_so WHERE id_hv = %s ORDER BY thu_tu, ma_tn", (id_,))
    tn = [TaiNguyen(l, u) for l, u in cur.fetchall()]
    return Tuong(ma, ten, (d, r, c), tk, cl, tg, tp, tn)


# ---------------- A: quan hệ–đối tượng ----------------
def nap_A(cur, id_):
    cur.execute("SELECT ma_hv, ten, kich_thuoc, tu_khoa, chat_lieu_chinh FROM bt.tuong WHERE id = %s", (id_,))
    ma, ten, kt, tk, cl = cur.fetchone()
    cur.execute("""SELECT tg.ho_ten FROM bt.hien_vat_tac_gia x JOIN bt.tac_gia tg ON tg.ma_tac_gia = x.ma_tac_gia
                   WHERE x.id_hv = %s""", (id_,))
    tg = {x for (x,) in cur.fetchall()}
    cur.execute("SELECT ma_tp, ma_tp_cha, ten, so_luong FROM bt.thanh_phan WHERE id_hv = %s ORDER BY ma_tp", (id_,))
    tp = dung_cay(cur.fetchall())
    cur.execute("""SELECT (SELECT relname FROM pg_class WHERE oid = t.tableoid), uri
                   FROM bt.tai_nguyen_so t WHERE id_hv = %s ORDER BY thu_tu, ma_tn""", (id_,))
    tn = [TaiNguyen(l, u) for l, u in cur.fetchall()]
    return Tuong(ma, ten, (kt.dai_cm, kt.rong_cm, kt.cao_cm), set(tk), cl, tg, tp, tn)


# ---------------- A1: một lượt gọi, JSON lồng ----------------
SQL_A1 = """
SELECT jsonb_build_object(
  'ma_hv', t.ma_hv, 'ten', t.ten, 'kich_thuoc', to_jsonb(t.kich_thuoc), 'tu_khoa', to_jsonb(t.tu_khoa),
  'chat_lieu_chinh', t.chat_lieu_chinh,
  'tac_gia', (SELECT coalesce(jsonb_agg(tg.ho_ten), '[]') FROM bt.hien_vat_tac_gia x
              JOIN bt.tac_gia tg ON tg.ma_tac_gia = x.ma_tac_gia WHERE x.id_hv = t.id),
  'thanh_phan', (SELECT coalesce(jsonb_agg(jsonb_build_array(p.ma_tp, p.ma_tp_cha, p.ten, p.so_luong) ORDER BY p.ma_tp), '[]')
                 FROM bt.thanh_phan p WHERE p.id_hv = t.id),
  'tai_nguyen', (SELECT coalesce(jsonb_agg(jsonb_build_array((SELECT relname FROM pg_class WHERE oid = r.tableoid), r.uri)
                                           ORDER BY r.thu_tu, r.ma_tn), '[]')
                 FROM bt.tai_nguyen_so r WHERE r.id_hv = t.id))
FROM bt.tuong t WHERE t.id = %s"""


def nap_A1(cur, id_):
    cur.execute(SQL_A1, (id_,))
    j = cur.fetchone()[0]
    k = j["kich_thuoc"]
    from decimal import Decimal
    kt = tuple(Decimal(str(k[x])).quantize(Decimal("0.01")) for x in ("dai_cm", "rong_cm", "cao_cm"))
    return Tuong(j["ma_hv"], j["ten"], kt, set(j["tu_khoa"]), j["chat_lieu_chinh"], set(j["tac_gia"]),
                 dung_cay([tuple(x) for x in j["thanh_phan"]]), [TaiNguyen(l, u) for l, u in j["tai_nguyen"]])


def dem_luot_goi(ham):
    return inspect.getsource(ham).count("cur.execute(")


def main():
    conn = psycopg2.connect(DSN_BENCH)
    conn.set_session(readonly=True, autocommit=True)
    register_composite("bt.kich_thuoc", conn)
    cur = conn.cursor()

    # kiểm tra 3 cách cho cùng đối tượng
    for id_ in DS_ID:
        a, b, a1 = nap_A(cur, id_), nap_B(cur, id_), nap_A1(cur, id_)
        assert a == b == a1, f"Đối tượng {id_} khác nhau giữa các cách nạp"
    print(f"Kiểm tra: 3 cách nạp cho cùng {len(DS_ID)} đối tượng – khớp.")

    # thời gian khứ hồi một lượt gọi rỗng
    rtt = []
    for _ in range(2000):
        t0 = time.perf_counter(); cur.execute("SELECT 1"); cur.fetchone()
        rtt.append((time.perf_counter() - t0) * 1000)
    rtt_ms = statistics.median(rtt)

    print(f"\n{'Cách nạp':<26}{'Lượt gọi/đối tượng':>20}{'Thời gian 500 đối tượng (ms)':>32}{'Dòng mã ánh xạ':>17}")
    ket_qua = []
    for ten, ham in (("B – quan hệ thuần", nap_B), ("A – quan hệ–đối tượng", nap_A), ("A1 – JSON lồng", nap_A1)):
        ts = []
        for vong in range(6):
            t0 = time.perf_counter()
            for id_ in DS_ID:
                ham(cur, id_)
            ts.append((time.perf_counter() - t0) * 1000)
        ts = ts[1:]
        so_dong = len(inspect.getsource(ham).splitlines()) + (len(SQL_A1.strip().splitlines()) if ham is nap_A1 else 0)
        ket_qua.append((ten, dem_luot_goi(ham), statistics.median(ts), min(ts), max(ts), so_dong))
        print(f"{ten:<26}{dem_luot_goi(ham):>20}{statistics.median(ts):>17.0f} ({min(ts):.0f}–{max(ts):.0f}){'':>4}{so_dong:>17}")

    print(f"\nSố đo: thời gian khứ hồi một lượt gọi rỗng (client và server cùng máy) = {rtt_ms:.3f} ms")
    print("\nPhân tích lý thuyết (ƯỚC TÍNH, không đo): nếu CSDL ở máy khác với thời gian khứ hồi 1 ms,")
    for ten, luot, *_ in ket_qua:
        print(f"  {ten:<26} riêng chi phí mạng ≈ {luot} × 500 × 1 ms = {luot * 0.5:.1f} s")
    conn.close()


if __name__ == "__main__":
    main()
