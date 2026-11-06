-- =====================================================================
-- 05_generate.sql – Sinh dữ liệu thực nghiệm (mặc định 30.000 tranh, 15.000 tượng, 15.000 tài liệu cổ)
-- Sinh vào phương án A rồi gọi qh.nap_tu_A() để B nhận ĐÚNG cùng dữ liệu.
-- Tất định: setseed(0.42) + công thức số học, chạy lại cho cùng dữ liệu.
-- Dùng:  psql -d bench -v n_tranh=30000 -v n_tuong=15000 -v n_tlc=15000 -f 05_generate.sql
-- =====================================================================
\if :{?n_tranh} \else \set n_tranh 30000 \endif
\if :{?n_tuong} \else \set n_tuong 15000 \endif
\if :{?n_tlc}   \else \set n_tlc   15000 \endif
SET client_min_messages = warning;
SET search_path = bt, public;
\timing on

BEGIN;
SELECT setseed(0.42) \gset

-- Lớp độc lập
INSERT INTO bo_suu_tap(ma_bst, ten, mo_ta)
SELECT g, 'Bộ sưu tập ' || g, NULL FROM generate_series(1, 20) g;
INSERT INTO phong_trung_bay(ma_phong, ten, tang, suc_chua)
SELECT 'P' || lpad(g::text, 3, '0'), 'Phòng ' || g, 1 + g % 5, 5000 FROM generate_series(1, 30) g;
INSERT INTO tac_gia(ma_tac_gia, ho_ten, nam_sinh)
SELECT g, 'Tác giả ' || g, 1700 + g % 280 FROM generate_series(1, 2000) g;
INSERT INTO chat_lieu(ma_chat_lieu, ten) SELECT g, 'Chất liệu ' || g FROM generate_series(1, 40) g;
INSERT INTO trien_lam(ma_tl, ten, tu_ngay, den_ngay)
SELECT g, 'Triển lãm ' || g, current_date - (g * 20), current_date - (g * 20) + 120
FROM generate_series(1, 50) g;

-- Tranh: id 1 .. n_tranh
INSERT INTO tranh(id, ma_hv, ten, nien_dai, nien_dai_mo_ta, kich_thuoc, trang_thai, ngay_nhap,
                  ma_bst, ma_phong, tu_khoa, ten_goi_khac, thuoc_tinh_mo_rong,
                  chat_lieu_nen, truong_phai, co_khung)
SELECT g, 'HV-' || lpad(g::text, 6, '0'), 'Tranh ' || g,
       int4range(y, y + 1 + (g % 3) * 5), y::text,
       ROW(20 + g % 180, 20 + g % 120, 1 + g % 5)::kich_thuoc,
       tt, DATE '1990-01-01' + (g % 12000),
       1 + g % 20, CASE WHEN tt = 'trung_bay' THEN 'P' || lpad((1 + g % 30)::text, 3, '0') END,
       ARRAY['chu_de_' || g % 60, 'phong_cach_' || g % 40, 'vat_lieu_' || g % 30],
       CASE WHEN g % 4 = 0 THEN ARRAY['Tên khác ' || g] ELSE '{}' END,
       CASE WHEN g % 5 = 0 THEN jsonb_build_object('bao_hiem', jsonb_build_object('gia_tri_usd', g * 10)) ELSE '{}' END,
       (ARRAY['Sơn mài','Sơn dầu','Lụa','Giấy dó','Bột màu'])[1 + g % 5],
       (ARRAY['Hiện thực','Lãng mạn','Biểu hiện','Trừu tượng'])[1 + g % 4], g % 2 = 0
FROM (SELECT g, 1850 + floor(random() * 150)::int AS y,
             (CASE WHEN g % 10 < 3 THEN 'trung_bay' WHEN g % 10 < 8 THEN 'luu_kho' ELSE 'bao_quan' END)::trang_thai_hv AS tt
      FROM generate_series(1, :n_tranh) g) s;

-- Tượng: id n_tranh+1 .. n_tranh+n_tuong
INSERT INTO tuong(id, ma_hv, ten, nien_dai, nien_dai_mo_ta, kich_thuoc, trang_thai, ngay_nhap,
                  ma_bst, ma_phong, tu_khoa, ten_goi_khac, thuoc_tinh_mo_rong,
                  chat_lieu_chinh, ky_thuat, trong_luong_kg)
SELECT g, 'HV-' || lpad(g::text, 6, '0'), 'Tượng ' || g,
       int4range(y, y + 1 + (g % 4) * 25), y::text,
       ROW(10 + g % 90, 10 + g % 60, 20 + g % 200)::kich_thuoc,
       tt, DATE '1990-01-01' + (g % 12000),
       1 + g % 20, CASE WHEN tt = 'trung_bay' THEN 'P' || lpad((1 + g % 30)::text, 3, '0') END,
       ARRAY['chu_de_' || g % 60, 'phong_cach_' || g % 40, 'vat_lieu_' || g % 30],
       CASE WHEN g % 4 = 0 THEN ARRAY['Tên khác ' || g] ELSE '{}' END,
       CASE WHEN g % 3 = 0 THEN jsonb_build_object('nguon_goc',
                jsonb_build_object('hinh_thuc', (ARRAY['khai quật','hiến tặng','mua'])[1 + (g / 3) % 3],
                                   'dia_diem', 'Tỉnh ' || g % 63)) ELSE '{}' END,
       (ARRAY['Đồng','Gỗ mít','Sa thạch','Đá','Gốm'])[1 + g % 5],
       (ARRAY['Đúc','Tạc','Chạm khắc','Nặn'])[1 + g % 4], 1 + (g % 500)
FROM (SELECT g, 900 + floor(random() * 1100)::int AS y,
             (CASE WHEN g % 10 < 3 THEN 'trung_bay' WHEN g % 10 < 8 THEN 'luu_kho' ELSE 'bao_quan' END)::trang_thai_hv AS tt
      FROM generate_series(:n_tranh + 1, :n_tranh + :n_tuong) g) s;

-- Tài liệu cổ
INSERT INTO tai_lieu_co(id, ma_hv, ten, nien_dai, nien_dai_mo_ta, kich_thuoc, trang_thai, ngay_nhap,
                        ma_bst, ma_phong, tu_khoa, ten_goi_khac, thuoc_tinh_mo_rong,
                        ngon_ngu, loai_chu, so_trang, tinh_trang_giay, muc_luc, con_dau)
SELECT g, 'HV-' || lpad(g::text, 6, '0'), 'Tài liệu ' || g,
       int4range(y, y + 1 + (g % 2) * 50), y::text,
       ROW(15 + g % 30, 10 + g % 20, 1 + g % 4)::kich_thuoc,
       tt, DATE '1990-01-01' + (g % 12000),
       1 + g % 20, CASE WHEN tt = 'trung_bay' THEN 'P' || lpad((1 + g % 30)::text, 3, '0') END,
       ARRAY['chu_de_' || g % 60, 'phong_cach_' || g % 40, 'vat_lieu_' || g % 30],
       '{}', '{}',
       (ARRAY['Hán','Việt'])[1 + g % 2], (ARRAY['Hán','Nôm'])[1 + g % 2], 1 + g % 300, 'Giấy dó',
       ARRAY(SELECT 'Mục ' || k FROM generate_series(1, 1 + g % 6) k),
       CASE WHEN g % 3 = 0 THEN ARRAY['Ấn ' || g % 10, 'Ấn ' || g % 10] ELSE '{}' END
FROM (SELECT g, 1400 + floor(random() * 500)::int AS y,
             (CASE WHEN g % 10 < 3 THEN 'trung_bay' WHEN g % 10 < 8 THEN 'luu_kho' ELSE 'bao_quan' END)::trang_thai_hv AS tt
      FROM generate_series(:n_tranh + :n_tuong + 1, :n_tranh + :n_tuong + :n_tlc) g) s;

SELECT setval('seq_hien_vat', (SELECT max(id) FROM dinh_danh_hien_vat)) \gset

-- Tác giả: 2 tác giả khác nhau mỗi hiện vật
INSERT INTO hien_vat_tac_gia(id_hv, ma_tac_gia, vai_tro)
SELECT id, 1 + id % 2000, 'tác giả chính' FROM dinh_danh_hien_vat
UNION ALL
SELECT id, 1 + (id % 2000 + 1 + id % 1999) % 2000, 'đồng tác giả' FROM dinh_danh_hien_vat;

INSERT INTO hien_vat_chat_lieu(id_hv, ma_chat_lieu)
SELECT id, 1 + id % 40 FROM dinh_danh_hien_vat
UNION ALL SELECT id, 1 + (id + 13) % 40 FROM dinh_danh_hien_vat WHERE id % 2 = 0;

-- Thành phần 3 cấp: cấp 1 có 1–2 nút; mỗi nút cấp 1 có 1 con; một nửa nút cấp 2 có 1 con
INSERT INTO thanh_phan(id_hv, ma_tp_cha, ten, so_luong, chat_lieu)
SELECT d.id, NULL, 'Bộ phận ' || k, 1, 'Chất liệu ' || (d.id + k) % 40
FROM dinh_danh_hien_vat d CROSS JOIN LATERAL generate_series(1, 1 + d.id % 2) k;
INSERT INTO thanh_phan(id_hv, ma_tp_cha, ten, so_luong, chat_lieu)
SELECT t.id_hv, t.ma_tp, 'Chi tiết của ' || t.ma_tp, 1 + t.ma_tp % 3, t.chat_lieu
FROM thanh_phan t WHERE t.ma_tp_cha IS NULL;
INSERT INTO thanh_phan(id_hv, ma_tp_cha, ten, so_luong, chat_lieu)
SELECT t.id_hv, t.ma_tp, 'Chốt của ' || t.ma_tp, 2 + t.ma_tp % 4, 'Gỗ lim'
FROM thanh_phan t JOIN thanh_phan c ON c.ma_tp = t.ma_tp_cha
WHERE c.ma_tp_cha IS NULL AND t.ma_tp % 2 = 0;

-- Ảnh: 1–7 ảnh mỗi hiện vật (trung bình 4), ảnh 1 là đại diện; EXIF 3 hãng máy ảnh
INSERT INTO anh(id_hv, thu_tu, uri, dinh_dang, kich_thuoc_byte, la_dai_dien, rong_px, cao_px, goc_chup, exif)
SELECT d.id, k, format('s3://kho-so/%s/%s.jpg', d.ma_hv, k), 'jpg', 1500000 + (d.id * k) % 900000, k = 1,
       4000, 3000, (ARRAY['chính diện','trái','phải','chi tiết'])[1 + k % 4],
       jsonb_build_object('may_anh', (ARRAY['Canon EOS R5','Nikon Z7','Sony A7R'])[1 + (d.id + k) % 3],
                          'iso', 100 * (1 + k % 8), 'tieu_cu_mm', (ARRAY[24, 35, 50, 85])[1 + d.id % 4])
FROM dinh_danh_hien_vat d CROSS JOIN LATERAL generate_series(1, 1 + d.id % 7) k;
-- Video: mỗi hiện vật thứ 10
INSERT INTO video(id_hv, thu_tu, uri, dinh_dang, kich_thuoc_byte, thoi_luong_giay, do_phan_giai)
SELECT id, 9, format('s3://kho-so/%s/video.mp4', ma_hv), 'mp4', 50000000 + id, 60 + id % 600, '1080p'
FROM dinh_danh_hien_vat WHERE id % 10 = 0;

INSERT INTO trien_lam_hien_vat(ma_tl, id_hv, vi_tri)
SELECT 1 + id % 50, id, 'Vị trí ' || id % 30 FROM dinh_danh_hien_vat WHERE id % 20 = 0;
INSERT INTO lich_su_bao_quan(id_hv, ngay, hang_muc, nguoi_thuc_hien)
SELECT id, DATE '2015-01-01' + (id % 4000)::int, 'Kiểm tra định kỳ', 'Tổ ' || id % 5
FROM dinh_danh_hien_vat WHERE id % 3 = 0;
COMMIT;

-- B nhận đúng cùng dữ liệu
CALL qh.nap_tu_A();
VACUUM ANALYZE;
REFRESH MATERIALIZED VIEW bt.mv_thong_ke_lop;

SELECT (SELECT count(*) FROM bt.dinh_danh_hien_vat) AS hien_vat,
       (SELECT count(*) FROM bt.thanh_phan) AS thanh_phan,
       (SELECT count(*) FROM bt.hien_vat_tac_gia) AS lien_ket_tac_gia,
       (SELECT count(*) FROM bt.anh) AS anh, (SELECT count(*) FROM bt.video) AS video,
       pg_size_pretty(sum(pg_total_relation_size(c.oid)) FILTER (WHERE n.nspname = 'bt')) AS dung_luong_A,
       pg_size_pretty(sum(pg_total_relation_size(c.oid)) FILTER (WHERE n.nspname = 'qh')) AS dung_luong_B
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'm');
