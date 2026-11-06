"""Đo hiệu năng P1–P12 trên CSDL bench (mục 8.5).

Đọc (P1–P11): EXPLAIN (ANALYZE, TIMING OFF, FORMAT JSON), lấy "Execution Time" (thời gian phía server).
Ghi (P12):    thời gian phía client từ INSERT tới khi kiểm tra xong ràng buộc trì hoãn
              (SET CONSTRAINTS ALL IMMEDIATE), sau đó ROLLBACK để dữ liệu không đổi.
Mỗi phép đo: 7 lần, bỏ lần đầu (làm nóng); cả bộ lặp 3 vòng; báo trung vị và min–max của 18 giá trị.
Chạy:  python3 scripts/bench.py  >  results/bench_output.txt   (kèm results/bench.csv)
"""
import csv
import os
import statistics
import time
import psycopg2
from truy_van_ab import CAP, DSN_BENCH, GHI_A, GHI_B

SO_LAN, SO_VONG = 7, 3
THU_MUC_KQ = os.path.join(os.path.dirname(__file__), "..", "results")


def do_doc(cur, sql):
    cur.execute("EXPLAIN (ANALYZE, TIMING OFF, FORMAT JSON) " + sql)
    return cur.fetchone()[0][0]["Execution Time"]


def do_ghi(conn, sql):
    cur = conn.cursor()
    t0 = time.perf_counter()
    cur.execute(sql)
    cur.execute("SET CONSTRAINTS ALL IMMEDIATE")
    t = (time.perf_counter() - t0) * 1000
    conn.rollback()
    return t


def tom_tat(xs):
    return statistics.median(xs), min(xs), max(xs)


def main():
    conn = psycopg2.connect(DSN_BENCH)
    cur = conn.cursor()
    cur.execute("SELECT version()")
    print(cur.fetchone()[0])
    b_p8 = next(b for ma, _, _, b in CAP if ma == "P8")
    ket_qua = {}
    for vong in range(SO_VONG):
        for ma, mo_ta, sql_a, sql_b in CAP:
            for phuong_an, sql in (("A", sql_a), ("B", sql_b or b_p8)):
                if ma == "P9" and phuong_an == "B":
                    continue
                xs = [do_doc(cur, sql) for _ in range(SO_LAN)][1:]
                ket_qua.setdefault((ma, phuong_an), []).extend(xs)
            conn.rollback()
        for phuong_an, sql in (("A", GHI_A), ("B", GHI_B)):
            xs = [do_ghi(conn, sql) for _ in range(SO_LAN)][1:]
            ket_qua.setdefault(("P12", phuong_an), []).extend(xs)
    conn.close()

    mo_ta = {ma: m for ma, m, _, _ in CAP}
    mo_ta["P12"] = "Chèn 5.000 tranh mới (ghi)"
    os.makedirs(THU_MUC_KQ, exist_ok=True)
    dong_csv = []
    print(f"\n{'Mã':<5}{'Nội dung':<56}{'A trung vị (min–max) ms':>28}{'B trung vị (min–max) ms':>28}{'B ÷ A':>8}")
    for ma in [c[0] for c in CAP] + ["P12"]:
        a = tom_tat(ket_qua[(ma, "A")])
        b = tom_tat(ket_qua[(ma, "B")]) if (ma, "B") in ket_qua else tom_tat(ket_qua[("P8", "B")])
        ti_so = b[0] / a[0]
        chu_b = f"{b[0]:.2f} ({b[1]:.2f}–{b[2]:.2f})" + (" [B của P8]" if ma == "P9" else "")
        print(f"{ma:<5}{mo_ta[ma]:<56}{a[0]:>10.2f} ({a[1]:.2f}–{a[2]:.2f}){'':>4}{chu_b:>28}{ti_so:>8.2f}")
        dong_csv.append([ma, mo_ta[ma], round(a[0], 3), round(a[1], 3), round(a[2], 3),
                         round(b[0], 3), round(b[1], 3), round(b[2], 3), round(ti_so, 3)])
    with open(os.path.join(THU_MUC_KQ, "bench.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["ma", "noi_dung", "A_trung_vi_ms", "A_min", "A_max", "B_trung_vi_ms", "B_min", "B_max", "B_chia_A"])
        w.writerows(dong_csv)
    print(f"\n{SO_VONG} vòng × {SO_LAN - 1} lần đo (bỏ lần làm nóng) cho mỗi truy vấn; B ÷ A > 1 nghĩa là A nhanh hơn.")


if __name__ == "__main__":
    main()
