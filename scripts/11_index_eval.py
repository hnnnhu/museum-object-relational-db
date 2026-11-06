"""Thiết kế vật lý: so sánh kế hoạch thực thi và thời gian TRƯỚC / SAU khi có chỉ mục (phương án A, CSDL bench).

Cách làm: trong một giao dịch, đo truy vấn khi có chỉ mục; DROP INDEX; đo lại; ROLLBACK
(chỉ mục được khôi phục nguyên trạng, không phải tạo lại).
Mỗi trạng thái đo 3 vòng × 11 lần (bỏ lần đầu mỗi vòng), xen kẽ có/không chỉ mục, lấy trung vị "Execution Time".
Chạy:  python3 scripts/11_index_eval.py  >  results/index_eval_output.txt
"""
import statistics
import psycopg2
from truy_van_ab import DSN_BENCH

CA = [
    ("I1", "Niên đại giao 1945–1946 (chọn lọc cao)", "GiST int4range",
     "SELECT ma_hv FROM bt.hien_vat WHERE nien_dai && int4range(1945, 1947)",
     ["bt.ix_tranh_nien_dai", "bt.ix_tuong_nien_dai", "bt.ix_tlc_nien_dai"]),
    ("I2", "Niên đại giao 1900–1950 (≈22% số dòng, = P4)", "GiST int4range",
     "SELECT ma_hv FROM bt.hien_vat WHERE nien_dai && int4range(1900, 1951)",
     ["bt.ix_tranh_nien_dai", "bt.ix_tuong_nien_dai", "bt.ix_tlc_nien_dai"]),
    ("I3", "Từ khóa chu_de_7 (≈1,7%, = P10)", "GIN text[]",
     "SELECT ma_hv FROM bt.hien_vat WHERE tu_khoa @> ARRAY['chu_de_7']",
     ["bt.ix_tranh_tk", "bt.ix_tuong_tk", "bt.ix_tlc_tk"]),
    ("I4", "EXIF ISO 800 và Canon (≈4%)", "GIN jsonb_path_ops",
     """SELECT ma_tn FROM bt.anh WHERE exif @> '{"may_anh": "Canon EOS R5", "iso": 800}'""",
     ["bt.ix_anh_exif"]),
    ("I5", "EXIF Canon (≈33%, = P11)", "GIN jsonb_path_ops",
     """SELECT ma_tn FROM bt.anh WHERE exif @> '{"may_anh": "Canon EOS R5"}'""",
     ["bt.ix_anh_exif"]),
    ("I6", "Tượng đồng (= điều kiện của P3)", "B-tree",
     "SELECT ma_hv FROM bt.tuong WHERE chat_lieu_chinh = 'Đồng'",
     ["bt.ix_tuong_cl"]),
]


def cac_nut_quet(plan, acc):
    loai = plan["Node Type"]
    if "Scan" in loai:
        ten = plan.get("Index Name") or plan.get("Relation Name", "")
        acc.append(f"{loai}({ten})" if ten else loai)
    for con in plan.get("Plans", []):
        cac_nut_quet(con, acc)
    return acc


def do(cur, sql):
    ts, plan, so_dong = [], None, None
    for i in range(11):
        cur.execute("EXPLAIN (ANALYZE, TIMING OFF, FORMAT JSON) " + sql)
        kq = cur.fetchone()[0][0]
        if i:
            ts.append(kq["Execution Time"])
        plan, so_dong = kq["Plan"], kq["Plan"]["Actual Rows"]
    nut = cac_nut_quet(plan, [])
    # gộp các nhánh giống nhau của Append cho gọn
    tom = sorted(set(n.split("(")[0] for n in nut))
    return statistics.median(ts), so_dong, ", ".join(tom), nut


def main():
    conn = psycopg2.connect(DSN_BENCH)
    cur = conn.cursor()
    print(f"{'Ca':<4}{'Truy vấn':<46}{'Chỉ mục':<20}{'Dòng':>8}{'Có CM (ms)':>12}{'Không CM (ms)':>15}{'Lợi':>7}")
    chi_tiet = []
    for ma, mo_ta, loai_cm, sql, ds_cm in CA:
        ds_co, ds_khong = [], []
        for vong in range(3):                 # xen kẽ để giảm ảnh hưởng của bộ đệm
            t_co, n, nut_co, nut_co_ct = do(cur, sql)
            for cm in ds_cm:
                cur.execute(f"DROP INDEX {cm}")
            t_khong, _, nut_khong, _ = do(cur, sql)
            conn.rollback()                   # khôi phục chỉ mục
            ds_co.append(t_co); ds_khong.append(t_khong)
        t_co, t_khong = statistics.median(ds_co), statistics.median(ds_khong)
        print(f"{ma:<4}{mo_ta:<46}{loai_cm:<20}{n:>8,}{t_co:>12.2f}{t_khong:>15.2f}{t_khong / t_co:>6.1f}×")
        chi_tiet.append((ma, nut_co, nut_khong, nut_co_ct))
    print("\nKế hoạch thực thi (loại nút quét):")
    for ma, co, khong, ct in chi_tiet:
        print(f"  {ma}: có chỉ mục → {co}\n      không chỉ mục → {khong}\n      chi tiết: {'; '.join(ct)}")
    conn.close()


if __name__ == "__main__":
    main()
