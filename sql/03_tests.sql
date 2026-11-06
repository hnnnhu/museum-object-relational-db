-- =====================================================================
-- 03_tests.sql – Kiểm thử toàn vẹn (mục 8.2)
-- Mỗi ca chạy trong một khối con và luôn bị hoàn tác, nên dữ liệu mẫu không đổi.
-- V1–V2: kế thừa bảng "thuần" (không bù) – chứng minh vấn đề ở mục 6.2.
-- T1–T16: phương án A;  T17–T19: phương án B;  T20: quy tắc sức chứa R12 (một phiên).
-- Ràng buộc trì hoãn được ép kiểm tra ngay bằng SET CONSTRAINTS ALL IMMEDIATE.
-- =====================================================================
SET client_min_messages = warning;
SET search_path = bt, public;
DROP SCHEMA IF EXISTS kt CASCADE;
CREATE SCHEMA kt;
CREATE TABLE kt.ket_qua (stt serial, ma text, noi_dung text, mong_doi text, thuc_te text, thong_bao text);

CREATE PROCEDURE kt.chay(p_ma text, p_noi_dung text, p_mong_doi text, p_sql text)
LANGUAGE plpgsql AS $$
DECLARE v_tt text; v_tb text := '';
BEGIN
    BEGIN
        EXECUTE p_sql;
        EXECUTE 'SET CONSTRAINTS ALL IMMEDIATE';
        RAISE EXCEPTION USING ERRCODE = 'KT001', MESSAGE = 'hoàn tác ca kiểm thử';
    EXCEPTION
        WHEN SQLSTATE 'KT001' THEN v_tt := 'Chấp nhận';
        WHEN OTHERS THEN v_tt := 'Bị từ chối'; v_tb := SQLERRM;
    END;
    INSERT INTO kt.ket_qua(ma, noi_dung, mong_doi, thuc_te, thong_bao)
    VALUES (p_ma, p_noi_dung, p_mong_doi, v_tt, v_tb);
END $$;

-- ---------- V: kế thừa bảng thuần, không có bảng định danh ----------
CALL kt.chay('V1', '[Kế thừa thuần] Trùng mã giữa hai bảng con', 'Bị từ chối', $t$
    CREATE TABLE kt.cha (id int, ma text);
    CREATE TABLE kt.con1 (PRIMARY KEY (id), UNIQUE (ma)) INHERITS (kt.cha);
    CREATE TABLE kt.con2 (PRIMARY KEY (id), UNIQUE (ma)) INHERITS (kt.cha);
    INSERT INTO kt.con1 VALUES (1, 'HV-000777');
    INSERT INTO kt.con2 VALUES (2, 'HV-000777');
$t$);
CALL kt.chay('V2', '[Kế thừa thuần] Khóa ngoại tới bảng cha, đích nằm ở bảng con', 'Chấp nhận', $t$
    CREATE TABLE kt.cha (id int PRIMARY KEY, ma text);
    CREATE TABLE kt.con1 (PRIMARY KEY (id)) INHERITS (kt.cha);
    CREATE TABLE kt.anh (ma_tn int PRIMARY KEY, id_hv int REFERENCES kt.cha);
    INSERT INTO kt.con1 VALUES (1, 'HV-000777');
    INSERT INTO kt.anh VALUES (1, 1);
$t$);

-- ---------- T: phương án A ----------
CALL kt.chay('T1', 'Chèn trực tiếp vào lớp trừu tượng hien_vat', 'Bị từ chối',
    $t$ INSERT INTO bt.hien_vat(ma_hv, ten) VALUES ('HV-000100', 'Hiện vật chung chung') $t$);
CALL kt.chay('T2', 'Trùng mã hiện vật giữa tranh và tuong', 'Bị từ chối',
    $t$ INSERT INTO bt.tuong(ma_hv, ten, chat_lieu_chinh) VALUES ('HV-000001', 'Trùng mã', 'Đồng') $t$);
CALL kt.chay('T3', 'Mã sai định dạng', 'Bị từ chối',
    $t$ INSERT INTO bt.tranh(ma_hv, ten, chat_lieu_nen) VALUES ('HV-12', 'Sai mã', 'Lụa') $t$);
CALL kt.chay('T4', 'Ảnh tham chiếu một tượng (đối tượng ở bảng con)', 'Chấp nhận',
    $t$ INSERT INTO bt.anh(id_hv, uri, dinh_dang, rong_px, cao_px) VALUES (4, 's3://x/5.jpg', 'jpg', 800, 600) $t$);
CALL kt.chay('T5', 'Ảnh tham chiếu hiện vật không tồn tại', 'Bị từ chối',
    $t$ INSERT INTO bt.anh(id_hv, uri, dinh_dang, rong_px, cao_px) VALUES (99999, 's3://x', 'jpg', 800, 600) $t$);
CALL kt.chay('T6', 'CHECK kế thừa: kích thước âm ở lớp con', 'Bị từ chối',
    $t$ INSERT INTO bt.tranh(ma_hv, ten, chat_lieu_nen, kich_thuoc) VALUES ('HV-000100', 'Âm', 'Lụa', ROW(-1, 10, 10)) $t$);
CALL kt.chay('T7', 'CHECK kế thừa: trưng bày mà không có phòng', 'Bị từ chối',
    $t$ UPDATE bt.tuong SET trang_thai = 'trung_bay', ma_phong = NULL WHERE id = 4 $t$);
CALL kt.chay('T8', 'Thành phần cha thuộc hiện vật khác', 'Bị từ chối',
    $t$ INSERT INTO bt.thanh_phan(id_hv, ma_tp_cha, ten) VALUES (1, 2, 'Sai cha') $t$);
CALL kt.chay('T9', 'Tạo chu trình: gắn Tượng Quá khứ dưới Bệ sen của chính nó', 'Bị từ chối',
    $t$ UPDATE bt.thanh_phan SET ma_tp_cha = 5 WHERE ma_tp = 2 $t$);
CALL kt.chay('T10', 'Đổi OID của đối tượng', 'Bị từ chối',
    $t$ UPDATE bt.tranh SET id = 100 WHERE id = 1 $t$);
CALL kt.chay('T11', 'Chèn trực tiếp vào lớp trừu tượng tai_nguyen_so', 'Bị từ chối',
    $t$ INSERT INTO bt.tai_nguyen_so(id_hv, uri, dinh_dang) VALUES (1, 's3://x', 'jpg') $t$);
CALL kt.chay('T12', 'Xóa tượng: thành phần, ảnh, video, tác giả, lịch sử, định danh bị xóa theo', 'Chấp nhận', $t$
    DELETE FROM bt.tuong WHERE id = 4;
    DO $d$ BEGIN
      IF EXISTS (SELECT 1 FROM bt.dinh_danh_hien_vat WHERE id = 4)
         OR EXISTS (SELECT 1 FROM bt.thanh_phan WHERE id_hv = 4)
         OR EXISTS (SELECT 1 FROM bt.tai_nguyen_so WHERE id_hv = 4)
         OR EXISTS (SELECT 1 FROM bt.hien_vat_tac_gia WHERE id_hv = 4)
         OR EXISTS (SELECT 1 FROM bt.lich_su_bao_quan WHERE id_hv = 4) THEN
        RAISE EXCEPTION 'Còn dòng mồ côi sau khi xóa';
      END IF;
    END $d$;
$t$);
CALL kt.chay('T13', 'Đổi mã hiện vật: bảng định danh được đồng bộ', 'Chấp nhận', $t$
    UPDATE bt.tranh SET ma_hv = 'HV-000100' WHERE id = 1;
    DO $d$ BEGIN
      IF (SELECT ma_hv FROM bt.dinh_danh_hien_vat WHERE id = 1) <> 'HV-000100' THEN
        RAISE EXCEPTION 'Bảng định danh không được đồng bộ';
      END IF;
    END $d$;
$t$);
CALL kt.chay('T14', 'Thêm ảnh đại diện thứ hai cho cùng hiện vật', 'Bị từ chối',
    $t$ INSERT INTO bt.anh(id_hv, uri, dinh_dang, rong_px, cao_px, la_dai_dien) VALUES (1, 's3://x', 'jpg', 800, 600, true) $t$);
CALL kt.chay('T15', 'set<string>: từ khóa trùng trong cùng hiện vật', 'Bị từ chối',
    $t$ UPDATE bt.tranh SET tu_khoa = '{sơn mài,sơn mài}' WHERE id = 1 $t$);
CALL kt.chay('T16', 'Video làm ảnh đại diện', 'Bị từ chối',
    $t$ INSERT INTO bt.video(id_hv, uri, dinh_dang, thoi_luong_giay, la_dai_dien) VALUES (2, 's3://x', 'mp4', 60, true) $t$);

-- ---------- T: phương án B ----------
CALL kt.chay('T17', '[B] Hiện vật ở bảng cha nhưng không có dòng bảng con (R1 toàn phần)', 'Bị từ chối',
    $t$ INSERT INTO qh.hien_vat(id, loai, ma_hv, ten, ngay_nhap) VALUES (100, 'tranh', 'HV-000100', 'Mồ côi', current_date) $t$);
CALL kt.chay('T18', '[B] Hiện vật có đủ dòng bảng cha và bảng con', 'Chấp nhận', $t$
    INSERT INTO qh.hien_vat(id, loai, ma_hv, ten, ngay_nhap) VALUES (100, 'tranh', 'HV-000100', 'Đủ', current_date);
    INSERT INTO qh.tranh(id, chat_lieu_nen, co_khung) VALUES (100, 'Lụa', false);
$t$);
CALL kt.chay('T19', '[B] Không giao: thêm dòng tượng cho một hiện vật đã là tranh', 'Bị từ chối',
    $t$ INSERT INTO qh.tuong(id, chat_lieu_chinh) VALUES (1, 'Đồng') $t$);

-- ---------- R12 trong một phiên ----------
CALL kt.chay('T20', 'Chuyển hiện vật thứ 3 vào phòng P401 (sức chứa 2)', 'Bị từ chối', $t$
    CALL bt.chuyen_phong('HV-000003', 'P401');
    CALL bt.chuyen_phong('HV-000008', 'P401');
$t$);

-- ---------- Kết quả ----------
\pset footer off
SELECT ma AS "Ca", noi_dung AS "Nội dung", mong_doi AS "Mong đợi", thuc_te AS "Thực tế",
       CASE WHEN ma LIKE 'V%' THEN CASE WHEN thuc_te <> mong_doi THEN 'Xác nhận vấn đề' ELSE 'Không tái hiện' END
            WHEN thuc_te = mong_doi THEN 'Đạt' ELSE 'KHÔNG ĐẠT' END AS "Kết luận",
       left(thong_bao, 90) AS "Thông báo lỗi"
FROM kt.ket_qua ORDER BY stt;

SELECT count(*) FILTER (WHERE ma LIKE 'T%' AND thuc_te = mong_doi) || '/' ||
       count(*) FILTER (WHERE ma LIKE 'T%') AS "Số ca T đạt"
FROM kt.ket_qua;

-- Đối chiếu sau kiểm thử: bảng định danh khớp với bảng con thực tế (tableoid)
SELECT (SELECT count(*) FROM bt.dinh_danh_hien_vat) AS so_dinh_danh,
       (SELECT count(*) FROM bt.hien_vat) AS so_doi_tuong,
       (SELECT count(*) FROM bt.hien_vat h JOIN bt.dinh_danh_hien_vat d ON d.id = h.id
        WHERE d.loai::text <> (SELECT relname FROM pg_class WHERE oid = h.tableoid)) AS so_dong_lech_loai;

DROP SCHEMA kt CASCADE;
