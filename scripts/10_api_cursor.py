"""Lập trình CSDL qua API gọi hàm (SQL/CLI) – psycopg2, có CON TRỎ PHÍA SERVER (mục 7.2.6).

Khác SQL nhúng (10_ecpg_demo.pgc): câu SQL là chuỗi truyền qua hàm thư viện, tham số đi riêng (%s),
nên không thể bị SQL injection. Ví dụ dùng:
  (1) con trỏ có tên (DECLARE … CURSOR phía server), đọc từng dòng (FETCH NEXT) thay vì kéo cả bảng về client;
  (2) UPDATE … WHERE CURRENT OF trên dòng con trỏ đang đứng;
  (3) ánh xạ kiểu phức hợp kich_thuoc → namedtuple Python, mảng text[] → list.
Mọi thay đổi bị ROLLBACK ở cuối.
"""
import psycopg2
from psycopg2.extras import register_composite
from truy_van_ab import DSN_MAU

conn = psycopg2.connect(DSN_MAU)
register_composite("bt.kich_thuoc", conn)

# (1) con trỏ phía server: DECLARE c_hv CURSOR FOR … (không kéo cả bảng về client)
c_hv = conn.cursor(name="c_hv")
c_hv.execute("""SELECT id, ma_hv, ten, kich_thuoc, tu_khoa
                FROM bt.tranh WHERE kich_thuoc IS NOT NULL ORDER BY ma_hv FOR UPDATE""")
cap_nhat = conn.cursor()
dem = 0
while True:
    dong = c_hv.fetchone()            # FETCH NEXT – con trỏ đứng trên đúng dòng vừa đọc
    if dong is None:
        break
    dem += 1
    id_, ma, ten, kt, tk = dong
    dien_tich = kt.dai_cm * kt.rong_cm
    print(f"{ma} {ten:<18} kích thước={tuple(kt)} (kiểu {type(kt).__name__}), "
          f"từ khóa={tk} (kiểu {type(tk).__name__}), diện tích={dien_tich} cm²")
    # (2) cập nhật đúng dòng con trỏ đang đứng
    cap_nhat.execute("UPDATE bt.tranh SET mo_ta = %s WHERE CURRENT OF c_hv",
                     (f"Đã kiểm kê, diện tích {dien_tich} cm²",))

cap_nhat.execute("SELECT ma_hv, mo_ta FROM bt.tranh WHERE mo_ta LIKE 'Đã kiểm kê%%' ORDER BY ma_hv")
print("Dòng được cập nhật qua WHERE CURRENT OF:", cap_nhat.fetchall())

# (3) truyền tham số tách khỏi câu lệnh – chuỗi độc hại chỉ là một giá trị
cap_nhat.execute("SELECT count(*) FROM bt.hien_vat WHERE %s = ANY (tu_khoa)", ("x' OR '1'='1",))
print("Tìm với chuỗi độc hại làm tham số → số dòng:", cap_nhat.fetchone()[0])

conn.rollback()
conn.close()
