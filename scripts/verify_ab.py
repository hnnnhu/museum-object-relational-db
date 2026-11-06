"""Kiểm tra mỗi cặp truy vấn A/B trả CÙNG kết quả trước khi đo thời gian (mục 8.1).

So sánh số dòng và mã băm MD5 của đa tập giá trị cột đầu tiên (đã sắp xếp).
Chạy:  python3 scripts/verify_ab.py   (trên CSDL bench)
"""
import sys
import psycopg2
from truy_van_ab import CAP, DSN_BENCH


def main():
    conn = psycopg2.connect(DSN_BENCH)
    cur = conn.cursor()
    sai = 0
    b_p8 = next(b for ma, _, _, b in CAP if ma == "P8")
    print(f"{'Mã':<5}{'Số dòng A':>11}{'Số dòng B':>11}  {'MD5 khớp':<9} Nội dung")
    for ma, mo_ta, sql_a, sql_b in CAP:
        sql_b = sql_b or b_p8
        # chỉ lấy cột đầu tiên làm khóa so sánh
        cur.execute(f"""SELECT count(*), md5(coalesce(string_agg(k, '|' ORDER BY k), ''))
                        FROM (SELECT (SELECT value FROM json_each_text(row_to_json(t)) LIMIT 1) FROM ({sql_a}) t) x(k)""")
        ra = cur.fetchone()
        cur.execute(f"""SELECT count(*), md5(coalesce(string_agg(k, '|' ORDER BY k), ''))
                        FROM (SELECT (SELECT value FROM json_each_text(row_to_json(t)) LIMIT 1) FROM ({sql_b}) t) x(k)""")
        rb = cur.fetchone()
        ok = ra == rb
        sai += not ok
        print(f"{ma:<5}{ra[0]:>11,}{rb[0]:>11,}  {'có' if ok else 'KHÔNG':<9} {mo_ta}")
    conn.close()
    print("\nKết luận:", "mọi cặp A/B trả cùng kết quả" if sai == 0 else f"{sai} cặp lệch – không được so thời gian")
    sys.exit(1 if sai else 0)


if __name__ == "__main__":
    main()
