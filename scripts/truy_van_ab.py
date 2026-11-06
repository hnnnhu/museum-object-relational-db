"""Cặp truy vấn đối chiếu P1–P12 giữa phương án A (bt, quan hệ–đối tượng) và B (qh, quan hệ thuần).

Mỗi cặp trả lời CÙNG một câu hỏi nghiệp vụ. Cột đầu tiên của mỗi truy vấn là khóa so sánh
(dùng trong verify_ab.py để kiểm tra hai phương án trả cùng kết quả).
"""
import os

DSN_BENCH = os.environ.get("DSN_BENCH", "dbname=bench user=postgres password=postgres host=localhost")
DSN_MAU = os.environ.get("DSN_MAU", "dbname=baotang user=postgres password=postgres host=localhost")

ID_TUONG_MAU = 30001   # một tượng trong dữ liệu thực nghiệm (dùng cho P5)

CAP = [
    ("P1", "Đa hình, chỉ thuộc tính chung (Q1)",
     "SELECT h.ma_hv, h.tableoid, h.ten, h.nien_dai FROM bt.hien_vat h",
     "SELECT h.ma_hv, h.loai, h.ten, h.nien_dai_tu, h.nien_dai_den FROM qh.hien_vat h"),

    ("P2", "Đối tượng đầy đủ, đa hình (thuộc tính chung + riêng)",
     """SELECT ma_hv, ten, nien_dai, kich_thuoc, trang_thai, chat_lieu_nen, truong_phai, co_khung,
               NULL::varchar AS chat_lieu_chinh, NULL::varchar AS ky_thuat, NULL::numeric AS trong_luong_kg,
               NULL::varchar AS ngon_ngu, NULL::varchar AS loai_chu, NULL::smallint AS so_trang FROM bt.tranh
        UNION ALL
        SELECT ma_hv, ten, nien_dai, kich_thuoc, trang_thai, NULL, NULL, NULL,
               chat_lieu_chinh, ky_thuat, trong_luong_kg, NULL, NULL, NULL FROM bt.tuong
        UNION ALL
        SELECT ma_hv, ten, nien_dai, kich_thuoc, trang_thai, NULL, NULL, NULL,
               NULL, NULL, NULL, ngon_ngu, loai_chu, so_trang FROM bt.tai_lieu_co""",
     """SELECT h.ma_hv, h.ten, h.nien_dai_tu, h.nien_dai_den, h.dai_cm, h.rong_cm, h.cao_cm, h.trang_thai,
               tr.chat_lieu_nen, tr.truong_phai, tr.co_khung,
               tu.chat_lieu_chinh, tu.ky_thuat, tu.trong_luong_kg,
               tl.ngon_ngu, tl.loai_chu, tl.so_trang
        FROM qh.hien_vat h
        LEFT JOIN qh.tranh tr ON tr.id = h.id
        LEFT JOIN qh.tuong tu ON tu.id = h.id
        LEFT JOIN qh.tai_lieu_co tl ON tl.id = h.id"""),

    ("P3", "Lớp con + thuộc tính riêng: tượng đồng trước 1960 (Q2)",
     "SELECT ma_hv, ten, trong_luong_kg FROM bt.tuong WHERE chat_lieu_chinh = 'Đồng' AND upper(nien_dai) <= 1960",
     """SELECT h.ma_hv, h.ten, t.trong_luong_kg FROM qh.hien_vat h JOIN qh.tuong t ON t.id = h.id
        WHERE t.chat_lieu_chinh = 'Đồng' AND h.nien_dai_den < 1960"""),

    ("P4", "Niên đại giao khoảng 1900–1950 (Q3)",
     "SELECT ma_hv FROM bt.hien_vat WHERE nien_dai && int4range(1900, 1951)",
     "SELECT ma_hv FROM qh.hien_vat WHERE nien_dai_tu <= 1950 AND nien_dai_den >= 1900"),

    ("P5", "Cây thành phần của một tượng (Q4, đệ quy)",
     f"""WITH RECURSIVE cay AS (
            SELECT ma_tp, ten, so_luong, 1 AS muc FROM bt.thanh_phan WHERE id_hv = {ID_TUONG_MAU} AND ma_tp_cha IS NULL
            UNION ALL SELECT t.ma_tp, t.ten, t.so_luong, c.muc + 1 FROM bt.thanh_phan t JOIN cay c ON t.ma_tp_cha = c.ma_tp)
         SELECT ten, muc, so_luong FROM cay""",
     f"""WITH RECURSIVE cay AS (
            SELECT ma_tp, ten, so_luong, 1 AS muc FROM qh.thanh_phan WHERE id_hv = {ID_TUONG_MAU} AND ma_tp_cha IS NULL
            UNION ALL SELECT t.ma_tp, t.ten, t.so_luong, c.muc + 1 FROM qh.thanh_phan t JOIN cay c ON t.ma_tp_cha = c.ma_tp)
         SELECT ten, muc, so_luong FROM cay"""),

    ("P6", "Tác giả × lớp (Q5)",
     """SELECT tg.ho_ten || '/' || (SELECT relname FROM pg_class WHERE oid = h.tableoid) || '/' || count(*)
        FROM bt.tac_gia tg JOIN bt.hien_vat_tac_gia x ON x.ma_tac_gia = tg.ma_tac_gia
        JOIN bt.hien_vat h ON h.id = x.id_hv GROUP BY tg.ho_ten, h.tableoid""",
     """SELECT tg.ho_ten || '/' || h.loai || '/' || count(*)
        FROM qh.tac_gia tg JOIN qh.hien_vat_tac_gia x ON x.ma_tac_gia = tg.ma_tac_gia
        JOIN qh.hien_vat h ON h.id = x.id_hv GROUP BY tg.ho_ten, h.loai"""),

    ("P7", "Trên 3 ảnh và có video (Q6)",
     """SELECT h.ma_hv FROM bt.hien_vat h JOIN bt.tai_nguyen_so t ON t.id_hv = h.id
        GROUP BY h.ma_hv
        HAVING count(*) FILTER (WHERE t.tableoid = 'bt.anh'::regclass) > 3
           AND count(*) FILTER (WHERE t.tableoid = 'bt.video'::regclass) > 0""",
     """SELECT h.ma_hv FROM qh.hien_vat h JOIN qh.tai_nguyen_so t ON t.id_hv = h.id
        GROUP BY h.ma_hv
        HAVING count(*) FILTER (WHERE t.loai = 'anh') > 3 AND count(*) FILTER (WHERE t.loai = 'video') > 0"""),

    ("P8", "Mô tả đa hình – A gọi phương thức từng dòng (Q7)",
     "SELECT ma_hv, bt.mo_ta_ngan(id) FROM bt.dinh_danh_hien_vat",
     """SELECT h.ma_hv, CASE h.loai
            WHEN 'tranh' THEN format('Tranh %s, chất liệu %s', h.ten, tr.chat_lieu_nen)
            WHEN 'tuong' THEN format('Tượng %s, %s, kỹ thuật %s', h.ten, tu.chat_lieu_chinh, coalesce(tu.ky_thuat, '?'))
            ELSE format('Tài liệu %s, chữ %s, %s trang', h.ten, tl.loai_chu, coalesce(tl.so_trang::text, '?')) END
        FROM qh.hien_vat h
        LEFT JOIN qh.tranh tr ON tr.id = h.id
        LEFT JOIN qh.tuong tu ON tu.id = h.id
        LEFT JOIN qh.tai_lieu_co tl ON tl.id = h.id"""),

    ("P9", "Mô tả đa hình – A viết theo tập hợp (so với B của P8)",
     """SELECT ma_hv, format('Tranh %s, chất liệu %s', ten, chat_lieu_nen) FROM bt.tranh
        UNION ALL SELECT ma_hv, format('Tượng %s, %s, kỹ thuật %s', ten, chat_lieu_chinh, coalesce(ky_thuat, '?')) FROM bt.tuong
        UNION ALL SELECT ma_hv, format('Tài liệu %s, chữ %s, %s trang', ten, loai_chu, coalesce(so_trang::text, '?')) FROM bt.tai_lieu_co""",
     None),   # dùng lại truy vấn B của P8

    ("P10", "Tìm theo từ khóa (set<string>)",
     "SELECT ma_hv FROM bt.hien_vat WHERE tu_khoa @> ARRAY['chu_de_7']",
     "SELECT h.ma_hv FROM qh.hien_vat h JOIN qh.hien_vat_tu_khoa k ON k.id_hv = h.id WHERE k.tu_khoa = 'chu_de_7'"),

    ("P11", "Ảnh theo máy ảnh (dictionary EXIF)",
     """SELECT ma_tn FROM bt.anh WHERE exif @> '{"may_anh": "Canon EOS R5"}'""",
     """SELECT a.ma_tn FROM qh.anh a JOIN qh.anh_exif e ON e.ma_tn = a.ma_tn
        WHERE e.khoa = 'may_anh' AND e.gia_tri = 'Canon EOS R5'"""),
]

# P12 – ghi: chèn 5.000 tranh mới (đo thời gian phía client gồm cả kiểm tra ràng buộc trì hoãn, rồi ROLLBACK)
GHI_A = """INSERT INTO bt.tranh(ma_hv, ten, nien_dai, kich_thuoc, ngay_nhap, ma_bst, tu_khoa, chat_lieu_nen, co_khung)
SELECT 'HV-' || (900000 + g), 'Tranh mới ' || g, int4range(1990, 1991), ROW(50, 40, 2)::bt.kich_thuoc,
       current_date, 1, ARRAY['chu_de_1', 'moi'], 'Lụa', false
FROM generate_series(1, 5000) g"""
GHI_B = """WITH cha AS (
    INSERT INTO qh.hien_vat(id, loai, ma_hv, ten, nien_dai_tu, nien_dai_den, dai_cm, rong_cm, cao_cm, ngay_nhap, ma_bst)
    SELECT 900000 + g, 'tranh', 'HV-' || (900000 + g), 'Tranh mới ' || g, 1990, 1990, 50, 40, 2, current_date, 1
    FROM generate_series(1, 5000) g RETURNING id),
  con AS (INSERT INTO qh.tranh(id, chat_lieu_nen, co_khung) SELECT id, 'Lụa', false FROM cha RETURNING id)
INSERT INTO qh.hien_vat_tu_khoa(id_hv, tu_khoa)
SELECT id, k FROM con, unnest(ARRAY['chu_de_1', 'moi']) k"""
