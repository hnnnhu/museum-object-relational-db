-- =====================================================================
-- 08_sql_nang_cao.sql – 12 câu lệnh SQL nâng cao S1–S12 (mục 7.2), chạy trên phương án A
-- Các lệnh có ghi dữ liệu (S10) được bọc trong giao dịch và ROLLBACK để chạy lại được.
-- =====================================================================
SET search_path = bt, public;
SET client_min_messages = notice;
\pset footer off

\echo '===== S1 – Truy vấn con tương quan: hiện vật có số ảnh vượt trung bình của CHÍNH lớp nó ====='
SELECT h.tableoid::regclass AS lop, h.ma_hv, h.ten,
       (SELECT count(*) FROM anh a WHERE a.id_hv = h.id) AS so_anh
FROM hien_vat h
WHERE (SELECT count(*) FROM anh a WHERE a.id_hv = h.id) >
      (SELECT avg(c) FROM (SELECT count(a2.ma_tn) AS c
                           FROM hien_vat h2 LEFT JOIN anh a2 ON a2.id_hv = h2.id
                           WHERE h2.tableoid = h.tableoid GROUP BY h2.id) t);

\echo '===== S2 – Kết nối ngoài + NOT EXISTS: tác giả không có hiện vật nào đang trưng bày ====='
SELECT tg.ho_ten, count(x.id_hv) AS so_hien_vat
FROM tac_gia tg LEFT JOIN hien_vat_tac_gia x ON x.ma_tac_gia = tg.ma_tac_gia
WHERE NOT EXISTS (SELECT 1 FROM hien_vat_tac_gia y JOIN hien_vat h ON h.id = y.id_hv
                  WHERE y.ma_tac_gia = tg.ma_tac_gia AND h.trang_thai = 'trung_bay')
GROUP BY tg.ho_ten;

\echo '===== S3 – Kết gộp EXCEPT, UNION: danh sách việc cần làm ====='
-- (A EXCEPT B) UNION C – EXCEPT và UNION cùng độ ưu tiên, kết hợp trái sang phải
SELECT h.ma_hv, h.ten, 'cần đưa ra trưng bày' AS viec_can_lam
FROM trien_lam tl JOIN trien_lam_hien_vat x ON x.ma_tl = tl.ma_tl JOIN hien_vat h ON h.id = x.id_hv
WHERE current_date BETWEEN tl.tu_ngay AND tl.den_ngay
EXCEPT
SELECT ma_hv, ten, 'cần đưa ra trưng bày' FROM hien_vat WHERE trang_thai = 'trung_bay'
UNION
SELECT ma_hv, ten, 'đang bảo quản – kiểm tra lại' FROM hien_vat WHERE trang_thai = 'bao_quan'
ORDER BY 1;

\echo '===== S4 – Hàm cửa sổ RANK, FIRST_VALUE: xếp hạng độ cổ trong từng lớp ====='
SELECT h.tableoid::regclass AS lop, h.ma_hv, h.ten, h.tuoi,
       rank() OVER w AS hang_trong_lop, first_value(h.ten) OVER w AS co_nhat_lop
FROM hien_vat h
WINDOW w AS (PARTITION BY h.tableoid ORDER BY lower(h.nien_dai))
ORDER BY lop, hang_trong_lop;

\echo '===== S5 – GROUP BY ROLLUP: số hiện vật theo bộ sưu tập × trạng thái, có tổng phụ ====='
SELECT coalesce(b.ten, '— TỔNG —') AS bo_suu_tap,
       CASE WHEN GROUPING(h.trang_thai) = 1 THEN '(cộng)' ELSE h.trang_thai::text END AS trang_thai,
       count(*) AS so_hien_vat
FROM hien_vat h JOIN bo_suu_tap b ON b.ma_bst = h.ma_bst
GROUP BY ROLLUP (b.ten, h.trang_thai)
ORDER BY b.ten NULLS LAST, GROUPING(h.trang_thai), h.trang_thai;

\echo '===== S6 – WITH RECURSIVE nhân dồn: số chi tiết vật lý thực của Bộ tượng Tam Thế ====='
WITH RECURSIVE cay AS (
    SELECT ma_tp, ten, so_luong, so_luong AS so_thuc, 1 AS muc
    FROM thanh_phan
    WHERE id_hv = (SELECT id FROM dinh_danh_hien_vat WHERE ma_hv = 'HV-000004') AND ma_tp_cha IS NULL
  UNION ALL
    SELECT t.ma_tp, t.ten, t.so_luong, c.so_thuc * t.so_luong, c.muc + 1
    FROM thanh_phan t JOIN cay c ON t.ma_tp_cha = c.ma_tp
)
SELECT coalesce(muc::text, 'Tổng') AS muc, count(*) AS so_nut, sum(so_thuc) AS so_chi_tiet_thuc
FROM cay GROUP BY ROLLUP (muc) ORDER BY cay.muc NULLS LAST;

\echo '===== S7 – JSONB @>, #>>, ->>: hiện vật khai quật; thống kê ảnh theo máy ảnh ====='
SELECT h.ma_hv, h.ten, h.thuoc_tinh_mo_rong #>> '{nguon_goc,dia_diem}' AS dia_diem,
       (h.thuoc_tinh_mo_rong ->> 'di_san_quoc_gia')::boolean AS di_san_qg
FROM hien_vat h
WHERE h.thuoc_tinh_mo_rong @> '{"nguon_goc": {"hinh_thuc": "khai quật"}}';
SELECT exif ->> 'may_anh' AS may_anh, count(*) AS so_anh FROM anh GROUP BY 1 ORDER BY 1;

\echo '===== S8 – Mảng, unnest WITH ORDINALITY: trải mục lục tài liệu có mục "Phả ký" ====='
SELECT t.ma_hv, m.thu_tu, m.ten_muc
FROM tai_lieu_co t
CROSS JOIN LATERAL unnest(t.muc_luc) WITH ORDINALITY AS m(ten_muc, thu_tu)
WHERE 'Phả ký' = ANY (t.muc_luc);

\echo '===== S9 – Hàm PL/pgSQL đệ quy so_chi_tiet_thuc() ====='
SELECT ma_hv, so_chi_tiet_thuc(ma_hv) AS so_chi_tiet_thuc
FROM dinh_danh_hien_vat WHERE ma_hv IN ('HV-000001', 'HV-000004') ORDER BY ma_hv;

\echo '===== S10 – Thủ tục có khóa dòng chuyen_phong() (R12) – chạy rồi ROLLBACK ====='
BEGIN;
CALL chuyen_phong('HV-000003', 'P101');
SELECT ma_hv, ten, trang_thai, ma_phong FROM hien_vat WHERE ma_hv = 'HV-000003';
ROLLBACK;

\echo '===== S11 – SQL động EXECUTE format() và phòng chống SQL injection ====='
SELECT * FROM tim_hien_vat('tuong', '{"den_nam": 1800}');
SELECT * FROM tim_hien_vat('hien_vat', '{"tu_khoa": "Nôm", "tu_nam": 1860}');
SELECT * FROM tim_hien_vat('tranh', $j${"tu_khoa": "x' OR '1'='1"}$j$);
\echo '--- tên lớp ngoài danh sách trắng bị từ chối:'
DO $$ BEGIN
    PERFORM * FROM bt.tim_hien_vat('tranh; DROP TABLE bt.tranh', '{}');
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'Bị từ chối: %', SQLERRM;
END $$;

\echo '===== S12 – View đối tượng (JSON lồng) và view vật chất hóa ====='
SELECT jsonb_pretty(doi_tuong) FROM v_hien_vat_doi_tuong WHERE ma_hv = 'HV-000004';
REFRESH MATERIALIZED VIEW mv_thong_ke_lop;
SELECT * FROM mv_thong_ke_lop ORDER BY lop;
