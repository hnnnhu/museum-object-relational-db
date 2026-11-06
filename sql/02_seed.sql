-- =====================================================================
-- 02_seed.sql – Dữ liệu mẫu cho phương án A: 9 hiện vật, 10 thành phần, 36 ảnh/video
-- Dữ liệu giả lập ("Bảo tàng Di sản Số"), không lấy từ bảo tàng thật.
-- Triển lãm được đặt theo ngày chạy (current_date) để Q8 luôn có triển lãm đang diễn ra.
-- =====================================================================
SET search_path = bt, public;
BEGIN;

INSERT INTO bo_suu_tap(ma_bst, ten, mo_ta) VALUES
 (1, 'Mỹ thuật hiện đại Việt Nam', 'Tranh thế kỷ XX'),
 (2, 'Điêu khắc cổ', 'Tượng và phù điêu'),
 (3, 'Thư tịch Hán Nôm', 'Sắc phong, gia phả, văn bản Nôm');
DO $$ BEGIN PERFORM setval('bo_suu_tap_ma_bst_seq', 3); END $$;

INSERT INTO phong_trung_bay VALUES
 ('P101', 'Phòng Mỹ thuật hiện đại', 1, 60),
 ('P201', 'Phòng Điêu khắc',         2, 40),
 ('P301', 'Phòng Thư tịch',          3, 80),
 ('P401', 'Phòng chuyên đề nhỏ',     4, 2);

INSERT INTO tac_gia(ma_tac_gia, ho_ten, but_danh, nam_sinh, nam_mat, quoc_tich) VALUES
 (1, 'Nguyễn Văn An',      NULL, 1905, 1975, 'Việt Nam'),
 (2, 'Trần Thị Bình',      NULL, 1910, 1988, 'Việt Nam'),
 (3, 'Lê Quang Cường',     NULL, 1925, 2001, 'Việt Nam'),
 (4, 'Nghệ nhân khuyết danh', NULL, NULL, NULL, NULL),
 (5, 'Phạm Đức Dũng',      NULL, 1832, 1899, 'Việt Nam');
DO $$ BEGIN PERFORM setval('tac_gia_ma_tac_gia_seq', 5); END $$;

INSERT INTO chat_lieu(ma_chat_lieu, ten) VALUES
 (1,'Sơn mài'), (2,'Vàng lá'), (3,'Sơn dầu'), (4,'Gỗ mít'), (5,'Sa thạch'),
 (6,'Đồng'), (7,'Giấy dó'), (8,'Mực tàu');
DO $$ BEGIN PERFORM setval('chat_lieu_ma_chat_lieu_seq', 8); END $$;

-- ---------------- Tranh ----------------
INSERT INTO tranh(id, ma_hv, ten, nien_dai, nien_dai_mo_ta, kich_thuoc, trang_thai, ngay_nhap,
                  ma_bst, ma_phong, tu_khoa, ten_goi_khac, thuoc_tinh_mo_rong,
                  chat_lieu_nen, truong_phai, co_khung) VALUES
 (1, 'HV-000001', 'Vườn xuân', '[1938,1939)', '1938', ROW(120, 240, 3), 'trung_bay', '2001-03-12',
  1, 'P101', '{sơn mài,phong cảnh,mùa xuân}', '{Vườn xuân Trung Nam Bắc}',
  '{"bao_hiem": {"gia_tri_usd": 500000}, "di_san_quoc_gia": true}',
  'Sơn mài', 'Hiện thực', true),
 (2, 'HV-000002', 'Thiếu nữ bên hoa', '[1943,1944)', '1943', ROW(80, 60, 2), 'trung_bay', '2003-07-01',
  1, 'P101', '{chân dung,thiếu nữ,hoa}', '{}', '{}', 'Sơn dầu', 'Lãng mạn', true),
 (3, 'HV-000003', 'Phố cũ', '[1965,1971)', 'Khoảng 1965–1970', ROW(55, 75, 2), 'luu_kho', '2005-11-20',
  1, NULL, '{phố,phong cảnh,Hà Nội}', '{Phố Hà Nội,Góc phố cũ}', '{}', 'Sơn dầu', 'Biểu hiện', false);

-- ---------------- Tượng ----------------
INSERT INTO tuong(id, ma_hv, ten, nien_dai, nien_dai_mo_ta, kich_thuoc, trang_thai, ngay_nhap,
                  ma_bst, ma_phong, tu_khoa, ten_goi_khac, thuoc_tinh_mo_rong,
                  chat_lieu_chinh, ky_thuat, trong_luong_kg) VALUES
 (4, 'HV-000004', 'Bộ tượng Tam Thế', '[1700,1800)', 'Thế kỷ XVIII', ROW(150, 60, 110), 'bao_quan', '1998-05-05',
  2, NULL, '{Phật giáo,gỗ,chùa}', '{Tam Thế Phật}',
  '{"nguon_goc": {"hinh_thuc": "hiến tặng", "dia_diem": "Bắc Ninh"}}', 'Gỗ mít', 'Tạc', 95.00),
 (5, 'HV-000005', 'Tượng vũ nữ Apsara', '[1000,1100)', 'Thế kỷ XI', ROW(40, 30, 120), 'trung_bay', '1995-09-09',
  2, 'P201', '{Chăm Pa,vũ nữ,sa thạch}', '{Apsara Trà Kiệu}',
  '{"nguon_goc": {"hinh_thuc": "khai quật", "dia_diem": "Quảng Nam"}, "di_san_quoc_gia": true}',
  'Sa thạch', 'Chạm khắc', 210.00),
 (6, 'HV-000006', 'Tượng ngựa đồng', '[1950,1951)', '1950', ROW(45, 15, 40), 'trung_bay', '2010-01-15',
  2, 'P401', '{đồng,động vật}', '{}', '{}', 'Đồng', 'Đúc', 12.50);

-- ---------------- Tài liệu cổ ----------------
INSERT INTO tai_lieu_co(id, ma_hv, ten, nien_dai, nien_dai_mo_ta, kich_thuoc, trang_thai, ngay_nhap,
                        ma_bst, ma_phong, tu_khoa, ten_goi_khac, thuoc_tinh_mo_rong,
                        ngon_ngu, loai_chu, so_trang, tinh_trang_giay, muc_luc, con_dau) VALUES
 (7, 'HV-000007', 'Sắc phong thời Lê Trung Hưng', '[1740,1741)', '1740', ROW(130, 50, NULL), 'trung_bay', '2012-04-04',
  3, 'P301', '{sắc phong,Hán,triều Lê}', '{}', '{"xep_hang": "bảo vật"}',
  'Hán', 'Hán', 1, 'Giấy sắc, ố vàng', '{Lời phong}', '{Sắc mệnh chi bảo,Sắc mệnh chi bảo}'),
 (8, 'HV-000008', 'Gia phả họ Phạm', '[1850,1900)', 'Nửa sau thế kỷ XIX', ROW(28, 18, 3), 'luu_kho', '2015-08-08',
  3, NULL, '{gia phả,Nôm,dòng họ}', '{Phạm tộc gia phả}', '{}',
  'Việt', 'Nôm', 86, 'Giấy dó, rách mép', '{Lời tựa,Phả ký,Thế thứ,Phụ chép}', '{Ấn họ Phạm}'),
 (9, 'HV-000009', 'Truyện thơ Nôm', '[1870,1871)', '1870', ROW(25, 16, 2), 'bao_quan', '2016-02-02',
  3, NULL, '{truyện thơ,Nôm,văn học}', '{}', '{}',
  'Việt', 'Nôm', 134, 'Giấy dó, mọt', '{Hồi 1,Hồi 2,Hồi 3}', '{}');
DO $$ BEGIN PERFORM setval('seq_hien_vat', 9); END $$;

-- ---------------- Tác giả (lớp kết hợp SangTac) ----------------
INSERT INTO hien_vat_tac_gia VALUES
 (1, 1, 'tác giả chính'), (1, 2, 'đồng tác giả'),
 (2, 2, 'tác giả chính'),
 (3, 3, 'tác giả chính'),
 (4, 4, 'nghệ nhân'), (5, 4, 'nghệ nhân'),
 (6, 3, 'tác giả chính'),
 (8, 5, 'người chép');

-- Chất liệu (dùng cho ví dụ 4NF: Vườn xuân có 2 tác giả × 2 chất liệu)
INSERT INTO hien_vat_chat_lieu VALUES
 (1,1),(1,2),(2,3),(3,3),(4,4),(5,5),(6,6),(7,7),(7,8),(8,7),(8,8),(9,7),(9,8);

-- ---------------- Thành phần (10 nút) ----------------
INSERT INTO thanh_phan(ma_tp, id_hv, ma_tp_cha, ten, so_luong, chat_lieu) VALUES
 (1, 1, NULL, 'Tấm vóc',            6, 'Gỗ'),
 (2, 4, NULL, 'Tượng Quá khứ',      1, 'Gỗ mít'),
 (3, 4, NULL, 'Tượng Hiện tại',     1, 'Gỗ mít'),
 (4, 4, NULL, 'Tượng Vị lai',       1, 'Gỗ mít'),
 (5, 4, 2,    'Bệ sen',             1, 'Gỗ mít'),
 (6, 4, 2,    'Vầng hào quang',     1, 'Gỗ mít thếp vàng'),
 (7, 4, 3,    'Bệ sen',             1, 'Gỗ mít'),
 (8, 4, 3,    'Vầng hào quang',     1, 'Gỗ mít thếp vàng'),
 (9, 4, 4,    'Bệ sen',             1, 'Gỗ mít'),
 (10,4, 9,    'Chốt gỗ',            4, 'Gỗ lim');
DO $$ BEGIN PERFORM setval('thanh_phan_ma_tp_seq', 10); END $$;

-- ---------------- Tài nguyên số: 33 ảnh + 3 video ----------------
-- Mỗi hiện vật 4 ảnh, riêng Tượng ngựa đồng 1 ảnh; ảnh số 1 là ảnh đại diện.
-- EXIF: 13 ảnh Canon, 20 ảnh Nikon.
INSERT INTO anh(id_hv, thu_tu, uri, dinh_dang, kich_thuoc_byte, la_dai_dien, rong_px, cao_px, goc_chup, exif)
SELECT hv.id, k,
       format('s3://kho-so/%s/%s.jpg', hv.ma_hv, k), 'jpg', 2000000 + 1000 * k, k = 1,
       4000, 3000, (ARRAY['chính diện','trái','phải','chi tiết'])[k],
       jsonb_build_object('may_anh', CASE WHEN row_number() OVER (ORDER BY hv.id, k) <= 13
                                          THEN 'Canon EOS R5' ELSE 'Nikon Z7' END,
                          'iso', 100 * k, 'tieu_cu_mm', 35)
FROM dinh_danh_hien_vat hv
CROSS JOIN LATERAL generate_series(1, CASE WHEN hv.ma_hv = 'HV-000006' THEN 1 ELSE 4 END) k;

INSERT INTO video(id_hv, thu_tu, uri, dinh_dang, kich_thuoc_byte, thoi_luong_giay, do_phan_giai) VALUES
 (1, 5, 's3://kho-so/HV-000001/video.mp4', 'mp4', 150000000, 180, '1080p'),
 (4, 5, 's3://kho-so/HV-000004/video.mp4', 'mp4', 220000000, 300, '4K'),
 (7, 5, 's3://kho-so/HV-000007/video.mp4', 'mp4',  90000000, 120, '1080p');

-- ---------------- Triển lãm (lớp kết hợp ThamGiaTrienLam có vi_tri) ----------------
INSERT INTO trien_lam(ma_tl, ten, tu_ngay, den_ngay) VALUES
 (1, 'Hồn Việt qua sơn mài', current_date - 30, current_date + 60),
 (2, 'Di sản Hán Nôm',       current_date - 10, current_date + 90),
 (3, 'Điêu khắc Chăm Pa (đã kết thúc)', current_date - 400, current_date - 300);
DO $$ BEGIN PERFORM setval('trien_lam_ma_tl_seq', 3); END $$;
INSERT INTO trien_lam_hien_vat VALUES
 (1, 1, 'Sảnh A – vách chính'), (1, 2, 'Sảnh A – vách phải'),
 (2, 7, 'Tủ kính 1'), (2, 8, 'Tủ kính 2'),
 (3, 5, 'Bục trung tâm');

-- ---------------- Lịch sử bảo quản ----------------
INSERT INTO lich_su_bao_quan(id_hv, ngay, hang_muc, mo_ta, nguoi_thuc_hien) VALUES
 (4, '2024-03-01', 'Chống mối mọt', 'Xử lý hóa chất toàn bộ', 'Tổ bảo quản 1'),
 (4, '2026-09-15', 'Tu sửa',        'Gia cố chốt gỗ bệ sen',  'Tổ bảo quản 1'),
 (9, '2026-10-01', 'Khử axit giấy', 'Khử axit 134 trang',     'Tổ bảo quản 2'),
 (1, '2020-06-10', 'Làm sạch bề mặt', NULL,                   'Tổ bảo quản 1');

COMMIT;

REFRESH MATERIALIZED VIEW mv_thong_ke_lop;
ANALYZE;
