-- =====================================================================
-- 06_queries.sql – 14 yêu cầu Q1–Q14: OQL (ODMG 3.0, viết trên giấy) và SQL thực thi trên phương án A
-- Mỗi câu OQL được ghi trong chú thích ngay trên câu SQL tương ứng.
-- =====================================================================
SET search_path = bt, public;
SET client_min_messages = warning;
\pset footer off

\echo '===== Q1 – Mọi hiện vật kèm lớp thực và tuổi (truy vấn đa hình, phương thức) ====='
-- OQL: select struct(ma: h.ma_hv, ten: h.ten, lop: h.ten_lop(), tuoi: h.tuoi())
--      from h in tat_ca_hien_vat order by h.ma_hv
SELECT h.tableoid::regclass AS lop, h.ma_hv, h.ten, h.nien_dai_mo_ta, h.tuoi AS tuoi
FROM hien_vat h ORDER BY h.ma_hv;

\echo '===== Q2 – Tượng bằng đồng có niên đại trước 1960 (lớp con, ép kiểu xuống) ====='
-- OQL (a) duyệt extent lớp con:
--   select t.ma_hv, t.ten, t.trong_luong_kg from t in tat_ca_tuong
--   where t.chat_lieu_chinh = "Đồng" and t.nien_dai.den_nam < 1960
-- OQL (b) ép kiểu xuống từ extent lớp cha:
--   select ((Tuong) h).ma_hv, ((Tuong) h).trong_luong_kg from h in tat_ca_hien_vat
--   where h in tat_ca_tuong and ((Tuong) h).chat_lieu_chinh = "Đồng"
--     and ((Tuong) h).nien_dai.den_nam < 1960
-- Quy ước: den_nam (ODL) là năm cuối, đóng; upper(nien_dai) là cận MỞ = den_nam + 1.
--   den_nam < 1960  ⇔  upper(nien_dai) <= 1960
SELECT ma_hv, ten, chat_lieu_chinh, ky_thuat, trong_luong_kg, (kich_thuoc).cao_cm AS cao_cm
FROM tuong
WHERE chat_lieu_chinh = 'Đồng' AND upper(nien_dai) <= 1960;

\echo '===== Q3 – Hiện vật có niên đại giao với khoảng 1900–1950 (thuộc tính cấu trúc, kiểu khoảng) ====='
-- OQL: select h.ma_hv, h.ten from h in tat_ca_hien_vat
--      where h.nien_dai.tu_nam <= 1950 and h.nien_dai.den_nam >= 1900
SELECT h.tableoid::regclass AS lop, h.ma_hv, h.ten, h.nien_dai
FROM hien_vat h
WHERE h.nien_dai && int4range(1900, 1951)
ORDER BY lower(h.nien_dai);
-- Kế hoạch thực thi: một nhánh Append cho mỗi bảng con
SET enable_seqscan = off;   -- dữ liệu mẫu quá nhỏ; tắt quét tuần tự để thấy chỉ mục GiST được chọn
EXPLAIN (COSTS OFF) SELECT h.ma_hv FROM hien_vat h WHERE h.nien_dai && int4range(1900, 1951);
RESET enable_seqscan;

\echo '===== Q4 – Toàn bộ cây thành phần của Bộ tượng Tam Thế (đệ quy) ====='
-- OQL (a) hai cấp cố định bằng truy vấn lồng:
--   select struct(bo_phan: p.ten, chi_tiet: (select c.ten from c in p.gom_con))
--   from h in tat_ca_hien_vat, p in h.gom_thanh_phan
--   where h.ma_hv = "HV-000004" and p.thuoc_cha = nil
-- OQL (b) độ sâu tùy ý nhờ phương thức đệ quy tat_ca_hau_due() khai báo trong ODL:
--   select struct(goc: p.ten, hau_due: x.ten)
--   from h in tat_ca_hien_vat, p in h.gom_thanh_phan, x in p.tat_ca_hau_due()
--   where h.ma_hv = "HV-000004" and p.thuoc_cha = nil
WITH RECURSIVE cay AS (
    SELECT ma_tp, ten, so_luong, 1 AS muc, ten::text AS duong_dan
    FROM thanh_phan
    WHERE id_hv = (SELECT id FROM dinh_danh_hien_vat WHERE ma_hv = 'HV-000004') AND ma_tp_cha IS NULL
  UNION ALL
    SELECT t.ma_tp, t.ten, t.so_luong, c.muc + 1, c.duong_dan || ' > ' || t.ten
    FROM thanh_phan t JOIN cay c ON t.ma_tp_cha = c.ma_tp
)
SELECT muc, duong_dan, so_luong FROM cay ORDER BY duong_dan;

\echo '----- Q4b – cùng ngữ nghĩa với OQL (b): gọi phương thức tat_ca_hau_due() -----'
SELECT p.ten AS goc, x.ten AS hau_due, x.so_luong
FROM thanh_phan p CROSS JOIN LATERAL tat_ca_hau_due(p.ma_tp) x
WHERE p.id_hv = 4 AND p.ma_tp_cha IS NULL
ORDER BY p.ten, x.ma_tp;

\echo '===== Q5 – Tác giả và số hiện vật theo từng lớp (biểu thức đường dẫn, gom nhóm) ====='
-- OQL: select tac_gia, lop, so: count(partition)
--      from s in tat_ca_sang_tac
--      group by tac_gia: s.cua_tac_gia.ho_ten, lop: s.cua_hien_vat.ten_lop()
SELECT tg.ho_ten AS tac_gia, ten_lop(x.id_hv) AS lop, count(*) AS so_hien_vat,
       string_agg(h.ten || ' (' || x.vai_tro || ')', '; ' ORDER BY h.ten) AS hien_vat
FROM tac_gia tg
JOIN hien_vat_tac_gia x ON x.ma_tac_gia = tg.ma_tac_gia
JOIN hien_vat h ON h.id = x.id_hv
GROUP BY tg.ho_ten, ten_lop(x.id_hv) ORDER BY tg.ho_ten, lop;

\echo '===== Q6 – Hiện vật có trên 3 ảnh và có ít nhất một video (tập hợp lồng, lượng từ ∃) ====='
-- OQL: select h.ma_hv, h.ten from h in tat_ca_hien_vat
--      where count(select a from a in h.co_tai_nguyen where a in tat_ca_anh) > 3
--        and exists v in h.co_tai_nguyen : v in tat_ca_video
SELECT h.ma_hv, h.ten,
       count(*) FILTER (WHERE t.tableoid = 'anh'::regclass)   AS so_anh,
       count(*) FILTER (WHERE t.tableoid = 'video'::regclass) AS so_video
FROM hien_vat h JOIN tai_nguyen_so t ON t.id_hv = h.id
GROUP BY h.ma_hv, h.ten
HAVING count(*) FILTER (WHERE t.tableoid = 'anh'::regclass) > 3
   AND count(*) FILTER (WHERE t.tableoid = 'video'::regclass) > 0
ORDER BY h.ma_hv;

\echo '===== Q7 – Mô tả ngắn đa hình (phương thức đa hình, ràng buộc muộn) ====='
-- OQL: select h.ma_hv, h.mo_ta_ngan() from h in tat_ca_hien_vat
SELECT ma_hv, mo_ta_ngan(id) AS mo_ta FROM dinh_danh_hien_vat ORDER BY ma_hv;

\echo '===== Q8 – Hiện vật đang trưng bày trong triển lãm đang diễn ra (nhiều quan hệ, lớp kết hợp) ====='
-- OQL ($1 = ngày hiện tại):
--   select struct(trien_lam: t.ten, vi_tri: x.vi_tri, hien_vat: x.cua_hien_vat.ten,
--                 phong: x.cua_hien_vat.dat_tai.ten,
--                 anh: (select a.uri from a in x.cua_hien_vat.co_tai_nguyen
--                       where a in tat_ca_anh and a.la_dai_dien))
--   from t in tat_ca_trien_lam, x in t.gom
--   where t.tu_ngay <= $1 and t.den_ngay >= $1 and x.cua_hien_vat.trang_thai = trung_bay
SELECT tl.ten AS trien_lam, x.vi_tri, h.ma_hv, h.ten, p.ten AS phong, a.uri AS anh_dai_dien
FROM trien_lam tl
JOIN trien_lam_hien_vat x ON x.ma_tl = tl.ma_tl
JOIN hien_vat h ON h.id = x.id_hv
LEFT JOIN phong_trung_bay p ON p.ma_phong = h.ma_phong
LEFT JOIN anh a ON a.id_hv = h.id AND a.la_dai_dien
WHERE current_date BETWEEN tl.tu_ngay AND tl.den_ngay AND h.trang_thai = 'trung_bay'
ORDER BY tl.ten, h.ma_hv;

\echo '===== Q9 – Tác giả có tác phẩm thuộc ít nhất hai lớp ====='
-- OQL: select tg.ho_ten from tg in tat_ca_tac_gia
--      where count(select distinct s.cua_hien_vat.ten_lop() from s in tg.sang_tac) >= 2
SELECT tg.ho_ten, count(DISTINCT h.tableoid) AS so_lop,
       string_agg(DISTINCT h.tableoid::regclass::text, ', ') AS cac_lop
FROM tac_gia tg JOIN hien_vat_tac_gia x ON x.ma_tac_gia = tg.ma_tac_gia
JOIN hien_vat h ON h.id = x.id_hv
GROUP BY tg.ho_ten HAVING count(DISTINCT h.tableoid) >= 2;

\echo '===== Q10 – Mức lấp đầy của từng phòng (duyệt quan hệ nghịch đảo) ====='
-- OQL: select struct(phong: p.ten, suc_chua: p.suc_chua,
--                    dang_trung_bay: count(select h from h in p.trung_bay where h.trang_thai = trung_bay))
--      from p in tat_ca_phong order by dang_trung_bay desc
SELECT p.ma_phong, p.ten, p.suc_chua, count(h.id) AS dang_trung_bay,
       round(100.0 * count(h.id) / p.suc_chua, 1) AS ty_le_lap_day
FROM phong_trung_bay p
LEFT JOIN hien_vat h ON h.ma_phong = p.ma_phong AND h.trang_thai = 'trung_bay'
GROUP BY p.ma_phong, p.ten, p.suc_chua ORDER BY ty_le_lap_day DESC;

\echo '===== Q11 – Tài liệu chữ Nôm trên 80 trang và mục lục (kiểu array, chỉ số) ====='
-- OQL: select struct(ma: t.ma_hv, so_trang: t.so_trang, so_muc: count(t.muc_luc), muc_dau: t.muc_luc[0])
--      from t in tat_ca_tai_lieu_co where t.loai_chu = "Nôm" and t.so_trang > 80
-- Lưu ý: chỉ số array của ODMG bắt đầu từ 0, của PostgreSQL bắt đầu từ 1.
SELECT ma_hv, ten, so_trang, muc_luc, array_length(muc_luc, 1) AS so_muc, muc_luc[1] AS muc_dau
FROM tai_lieu_co WHERE loai_chu = 'Nôm' AND so_trang > 80 ORDER BY so_trang DESC;

\echo '===== Q12 – Hiện vật có tổng số thành phần trên mức trung bình (phương thức trong vị từ) ====='
-- OQL: select h.ma_hv, h.ten, h.tong_thanh_phan() from h in tat_ca_hien_vat
--      where h.tong_thanh_phan() > avg(select x.tong_thanh_phan() from x in tat_ca_hien_vat)
SELECT d.ma_hv, h.ten, tong_thanh_phan(d.id) AS tong_tp,
       (SELECT round(avg(tong_thanh_phan(id)), 2) FROM dinh_danh_hien_vat) AS trung_binh
FROM dinh_danh_hien_vat d JOIN hien_vat h ON h.id = d.id
WHERE tong_thanh_phan(d.id) > (SELECT avg(tong_thanh_phan(id)) FROM dinh_danh_hien_vat)
ORDER BY d.ma_hv;

\echo '===== Q13 – Tập mọi từ khóa (flatten) và túi chất liệu (bag), túi con dấu (bag attribute) ====='
-- OQL: flatten(select h.tu_khoa from h in tat_ca_hien_vat)
SELECT count(DISTINCT k) AS so_tu_khoa_khac_nhau, string_agg(DISTINCT k, ', ') AS tu_khoa
FROM hien_vat, unnest(tu_khoa) k;
-- OQL: select h.cac_chat_lieu() from h in tat_ca_hien_vat where h.ma_hv = "HV-000004"
--      (bag đếm theo NÚT thành phần, không nhân số lượng)
SELECT ma_hv, cac_chat_lieu(id) AS bag_chat_lieu,
       cardinality(cac_chat_lieu(id)) AS so_phan_tu,
       (SELECT count(DISTINCT x) FROM unnest(cac_chat_lieu(id)) x) AS so_gia_tri_khac_nhau
FROM dinh_danh_hien_vat WHERE ma_hv = 'HV-000004';
-- OQL: select t.ma_hv, t.con_dau from t in tat_ca_tai_lieu_co where count(t.con_dau) > 0
SELECT ma_hv, con_dau, cardinality(con_dau) AS so_phan_tu
FROM tai_lieu_co WHERE cardinality(con_dau) > 0 ORDER BY ma_hv;

\echo '===== Q14 – Bộ sưu tập mà mọi hiện vật đều có hơn 3 ảnh (lượng từ ∀) ====='
-- OQL: select b.ten from b in tat_ca_bst
--      where for all h in b.gom_hien_vat :
--            count(select a from a in h.co_tai_nguyen where a in tat_ca_anh) > 3
-- SQL không có ∀: dùng ∀x P(x) ⇔ ¬∃x ¬P(x)
SELECT b.ten FROM bo_suu_tap b
WHERE EXISTS (SELECT 1 FROM hien_vat h WHERE h.ma_bst = b.ma_bst)
  AND NOT EXISTS (SELECT 1 FROM hien_vat h
                  WHERE h.ma_bst = b.ma_bst
                    AND (SELECT count(*) FROM anh a WHERE a.id_hv = h.id) <= 3)
ORDER BY b.ten;
