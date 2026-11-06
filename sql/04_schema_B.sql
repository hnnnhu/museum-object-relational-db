-- =====================================================================
-- 04_schema_B.sql – Phương án B: thiết kế quan hệ thuần (mục 5.2.2), đạt BCNF/4NF
-- Ánh xạ chuyên biệt hóa theo cách 8A (Elmasri & Navathe): bảng lớp cha + bảng lớp con chung khóa.
-- Mọi thuộc tính phức hợp/đa trị được tách để đạt 1NF.
-- Cuối tệp: thủ tục qh.nap_tu_A() chép TOÀN BỘ dữ liệu của phương án A sang B,
-- bảo đảm hai phương án chứa đúng cùng một tập dữ liệu khi so sánh.
-- =====================================================================
SET client_min_messages = warning;
DROP SCHEMA IF EXISTS qh CASCADE;
CREATE SCHEMA qh;
SET search_path = qh, public;

CREATE TABLE bo_suu_tap (ma_bst int PRIMARY KEY, ten varchar(120) NOT NULL UNIQUE, mo_ta text);
CREATE TABLE phong_trung_bay (ma_phong varchar(10) PRIMARY KEY, ten varchar(120) NOT NULL,
                              tang smallint NOT NULL, suc_chua int NOT NULL CHECK (suc_chua > 0));
CREATE TABLE tac_gia (ma_tac_gia int PRIMARY KEY, ho_ten varchar(120) NOT NULL, but_danh varchar(120),
                      nam_sinh smallint, nam_mat smallint, quoc_tich varchar(60));
CREATE TABLE chat_lieu (ma_chat_lieu int PRIMARY KEY, ten varchar(80) NOT NULL UNIQUE);
CREATE TABLE trien_lam (ma_tl int PRIMARY KEY, ten varchar(160) NOT NULL,
                        tu_ngay date NOT NULL, den_ngay date NOT NULL, CHECK (tu_ngay <= den_ngay));

-- ----- Phân cấp hiện vật: bảng cha + 3 bảng con, khóa ngoại kép (id, loai) -----
CREATE TABLE hien_vat (
    id             bigint PRIMARY KEY,
    loai           varchar(12) NOT NULL CHECK (loai IN ('tranh','tuong','tai_lieu_co')),
    ma_hv          varchar(9) NOT NULL UNIQUE CHECK (ma_hv ~ '^HV-[0-9]{6}$'),
    ten            varchar(200) NOT NULL,
    mo_ta          text,
    nien_dai_tu    int,                                    -- năm đầu (đóng)
    nien_dai_den   int,                                    -- năm cuối (đóng)
    nien_dai_mo_ta varchar(80),
    dai_cm         numeric(8,2) CHECK (dai_cm > 0),
    rong_cm        numeric(8,2) CHECK (rong_cm > 0),
    cao_cm         numeric(8,2) CHECK (cao_cm > 0),
    trang_thai     varchar(10) NOT NULL DEFAULT 'luu_kho'
                   CHECK (trang_thai IN ('trung_bay','luu_kho','bao_quan','cho_muon')),
    ngay_nhap      date NOT NULL,
    ma_bst         int REFERENCES bo_suu_tap,
    ma_phong       varchar(10) REFERENCES phong_trung_bay,
    UNIQUE (id, loai),                                     -- đích của khóa ngoại kép
    CHECK (nien_dai_den >= nien_dai_tu),
    CHECK (trang_thai <> 'trung_bay' OR ma_phong IS NOT NULL)
);
CREATE TABLE tranh (
    id   bigint PRIMARY KEY,
    loai varchar(12) NOT NULL DEFAULT 'tranh' CHECK (loai = 'tranh'),
    chat_lieu_nen varchar(60) NOT NULL, truong_phai varchar(60), co_khung boolean NOT NULL,
    FOREIGN KEY (id, loai) REFERENCES hien_vat (id, loai) ON DELETE CASCADE
);
CREATE TABLE tuong (
    id   bigint PRIMARY KEY,
    loai varchar(12) NOT NULL DEFAULT 'tuong' CHECK (loai = 'tuong'),
    chat_lieu_chinh varchar(60) NOT NULL, ky_thuat varchar(60),
    trong_luong_kg numeric(10,2) CHECK (trong_luong_kg > 0),
    FOREIGN KEY (id, loai) REFERENCES hien_vat (id, loai) ON DELETE CASCADE
);
CREATE TABLE tai_lieu_co (
    id   bigint PRIMARY KEY,
    loai varchar(12) NOT NULL DEFAULT 'tai_lieu_co' CHECK (loai = 'tai_lieu_co'),
    ngon_ngu varchar(40) NOT NULL, loai_chu varchar(40) NOT NULL,
    so_trang smallint CHECK (so_trang > 0), tinh_trang_giay varchar(80),
    FOREIGN KEY (id, loai) REFERENCES hien_vat (id, loai) ON DELETE CASCADE
);

-- ----- Thuộc tính đa trị / phức hợp tách thành bảng (1NF) -----
CREATE TABLE hien_vat_tu_khoa (                              -- set<string>
    id_hv bigint REFERENCES hien_vat ON DELETE CASCADE, tu_khoa varchar(60),
    PRIMARY KEY (id_hv, tu_khoa));
CREATE TABLE hien_vat_ten_goi_khac (                         -- list<string>
    id_hv bigint REFERENCES hien_vat ON DELETE CASCADE, thu_tu smallint, ten varchar(200) NOT NULL,
    PRIMARY KEY (id_hv, thu_tu));
CREATE TABLE hien_vat_thuoc_tinh (                           -- dictionary<string,string>
    id_hv bigint REFERENCES hien_vat ON DELETE CASCADE, khoa varchar(80), gia_tri text NOT NULL,
    PRIMARY KEY (id_hv, khoa));
CREATE TABLE muc_luc (                                       -- array<string>
    id_tl bigint REFERENCES tai_lieu_co ON DELETE CASCADE, thu_tu smallint, ten_muc varchar(120) NOT NULL,
    PRIMARY KEY (id_tl, thu_tu));
CREATE TABLE con_dau (                                       -- bag<string>: cần số thứ tự để giữ phần tử trùng
    id_tl bigint REFERENCES tai_lieu_co ON DELETE CASCADE, stt smallint, ten_dau varchar(120) NOT NULL,
    PRIMARY KEY (id_tl, stt));

-- ----- Liên kết -----
CREATE TABLE hien_vat_tac_gia (id_hv bigint REFERENCES hien_vat ON DELETE CASCADE,
    ma_tac_gia int REFERENCES tac_gia, vai_tro varchar(40) NOT NULL, PRIMARY KEY (id_hv, ma_tac_gia));
CREATE TABLE hien_vat_chat_lieu (id_hv bigint REFERENCES hien_vat ON DELETE CASCADE,
    ma_chat_lieu int REFERENCES chat_lieu, PRIMARY KEY (id_hv, ma_chat_lieu));
CREATE TABLE trien_lam_hien_vat (ma_tl int REFERENCES trien_lam ON DELETE CASCADE,
    id_hv bigint REFERENCES hien_vat ON DELETE CASCADE, vi_tri varchar(40), PRIMARY KEY (ma_tl, id_hv));
CREATE TABLE lich_su_bao_quan (ma_ls bigint PRIMARY KEY, id_hv bigint NOT NULL REFERENCES hien_vat ON DELETE CASCADE,
    ngay date NOT NULL, hang_muc varchar(80) NOT NULL, mo_ta text, nguoi_thuc_hien varchar(120));
CREATE TABLE thanh_phan (
    ma_tp bigint PRIMARY KEY,
    id_hv bigint NOT NULL REFERENCES hien_vat ON DELETE CASCADE,
    ma_tp_cha bigint REFERENCES thanh_phan ON DELETE CASCADE,
    ten varchar(120) NOT NULL, so_luong int NOT NULL CHECK (so_luong > 0), chat_lieu varchar(80));

-- ----- Phân cấp tài nguyên số -----
CREATE TABLE tai_nguyen_so (
    ma_tn bigint PRIMARY KEY,
    loai  varchar(5) NOT NULL CHECK (loai IN ('anh','video')),
    id_hv bigint NOT NULL REFERENCES hien_vat ON DELETE CASCADE,
    thu_tu smallint NOT NULL, uri text NOT NULL, dinh_dang varchar(10) NOT NULL,
    kich_thuoc_byte bigint CHECK (kich_thuoc_byte > 0), chu_thich text,
    la_dai_dien boolean NOT NULL DEFAULT false,
    UNIQUE (ma_tn, loai),
    CHECK (NOT la_dai_dien OR loai = 'anh'));
CREATE TABLE anh (
    ma_tn bigint PRIMARY KEY, loai varchar(5) NOT NULL DEFAULT 'anh' CHECK (loai = 'anh'),
    rong_px int NOT NULL CHECK (rong_px > 0), cao_px int NOT NULL CHECK (cao_px > 0), goc_chup varchar(40),
    FOREIGN KEY (ma_tn, loai) REFERENCES tai_nguyen_so (ma_tn, loai) ON DELETE CASCADE);
CREATE TABLE anh_exif (                                      -- dictionary -> bảng khóa–giá trị
    ma_tn bigint REFERENCES anh ON DELETE CASCADE, khoa varchar(40), gia_tri varchar(200) NOT NULL,
    PRIMARY KEY (ma_tn, khoa));
CREATE TABLE video (
    ma_tn bigint PRIMARY KEY, loai varchar(5) NOT NULL DEFAULT 'video' CHECK (loai = 'video'),
    thoi_luong_giay int NOT NULL CHECK (thoi_luong_giay > 0), do_phan_giai varchar(20),
    FOREIGN KEY (ma_tn, loai) REFERENCES tai_nguyen_so (ma_tn, loai) ON DELETE CASCADE);

-- ----- Trigger -----
-- (1) R1 toàn phần: mỗi dòng hien_vat phải có đúng một dòng ở bảng con.
--     Ràng buộc trì hoãn: kiểm tra lúc COMMIT, nên cho phép chèn cha rồi chèn con trong cùng giao dịch.
CREATE FUNCTION fn_toan_phan() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM qh.hien_vat WHERE id = NEW.id) THEN
        RETURN NULL;                                      -- đã bị xóa trong cùng giao dịch
    END IF;
    IF NOT EXISTS (SELECT 1 FROM qh.tranh       WHERE id = NEW.id
                   UNION ALL SELECT 1 FROM qh.tuong       WHERE id = NEW.id
                   UNION ALL SELECT 1 FROM qh.tai_lieu_co WHERE id = NEW.id) THEN
        RAISE EXCEPTION 'Hiện vật % chưa thuộc lớp con nào (R1 toàn phần)', NEW.id;
    END IF;
    RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER trg_toan_phan AFTER INSERT ON hien_vat
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION fn_toan_phan();

-- (2) R8 cấu trúc thành phần – cùng logic với phương án A
CREATE FUNCTION fn_kiem_tra_thanh_phan() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_hv_cha bigint; v_chu_trinh boolean;
BEGIN
    IF NEW.ma_tp_cha IS NULL THEN RETURN NEW; END IF;
    IF NEW.ma_tp_cha = NEW.ma_tp THEN RAISE EXCEPTION 'Thành phần là cha của chính nó'; END IF;
    SELECT id_hv INTO v_hv_cha FROM qh.thanh_phan WHERE ma_tp = NEW.ma_tp_cha;
    IF v_hv_cha <> NEW.id_hv THEN
        RAISE EXCEPTION 'Thành phần cha % thuộc hiện vật khác', NEW.ma_tp_cha;
    END IF;
    IF TG_OP = 'UPDATE' THEN
        WITH RECURSIVE len(ma) AS (
            SELECT NEW.ma_tp_cha
            UNION
            SELECT t.ma_tp_cha FROM qh.thanh_phan t JOIN len ON t.ma_tp = len.ma
            WHERE t.ma_tp_cha IS NOT NULL)
        SELECT EXISTS (SELECT 1 FROM len WHERE ma = NEW.ma_tp) INTO v_chu_trinh;
        IF v_chu_trinh THEN RAISE EXCEPTION 'Tạo chu trình trong cấu trúc thành phần'; END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_thanh_phan BEFORE INSERT OR UPDATE ON thanh_phan
    FOR EACH ROW EXECUTE FUNCTION fn_kiem_tra_thanh_phan();

-- ----- Chỉ mục -----
CREATE INDEX ix_hv_nien_dai ON hien_vat (nien_dai_tu, nien_dai_den);
CREATE INDEX ix_hv_phong ON hien_vat (ma_phong);
CREATE INDEX ix_hv_bst   ON hien_vat (ma_bst);
CREATE INDEX ix_tuong_cl ON tuong (chat_lieu_chinh);
CREATE INDEX ix_tk_tu_khoa ON hien_vat_tu_khoa (tu_khoa);
CREATE INDEX ix_tp_hv  ON thanh_phan (id_hv);
CREATE INDEX ix_tp_cha ON thanh_phan (ma_tp_cha);
CREATE INDEX ix_hvtg_tg ON hien_vat_tac_gia (ma_tac_gia);
CREATE INDEX ix_tns_hv ON tai_nguyen_so (id_hv);
CREATE INDEX ix_exif_kv ON anh_exif (khoa, gia_tri);
CREATE UNIQUE INDEX ux_tns_dai_dien ON tai_nguyen_so (id_hv) WHERE la_dai_dien;
CREATE INDEX ix_tlhv_hv ON trien_lam_hien_vat (id_hv);
CREATE INDEX ix_ls_hv   ON lich_su_bao_quan (id_hv);

-- =====================================================================
-- Chép dữ liệu A → B (cùng id, cùng giá trị) – dùng cho cả dữ liệu mẫu và dữ liệu thực nghiệm
-- =====================================================================
CREATE PROCEDURE nap_tu_A() LANGUAGE plpgsql AS $$
BEGIN
    SET CONSTRAINTS ALL DEFERRED;
    TRUNCATE qh.bo_suu_tap, qh.phong_trung_bay, qh.tac_gia, qh.chat_lieu, qh.trien_lam,
             qh.hien_vat CASCADE;
    INSERT INTO qh.bo_suu_tap SELECT ma_bst, ten, mo_ta FROM bt.bo_suu_tap;
    INSERT INTO qh.phong_trung_bay SELECT * FROM bt.phong_trung_bay;
    INSERT INTO qh.tac_gia SELECT * FROM bt.tac_gia;
    INSERT INTO qh.chat_lieu SELECT * FROM bt.chat_lieu;
    INSERT INTO qh.trien_lam SELECT * FROM bt.trien_lam;

    INSERT INTO qh.hien_vat
    SELECT h.id, d.loai::text, h.ma_hv, h.ten, h.mo_ta,
           lower(h.nien_dai), upper(h.nien_dai) - 1, h.nien_dai_mo_ta,
           (h.kich_thuoc).dai_cm, (h.kich_thuoc).rong_cm, (h.kich_thuoc).cao_cm,
           h.trang_thai::text, h.ngay_nhap, h.ma_bst, h.ma_phong
    FROM bt.hien_vat h JOIN bt.dinh_danh_hien_vat d ON d.id = h.id;
    INSERT INTO qh.tranh SELECT id, 'tranh', chat_lieu_nen, truong_phai, co_khung FROM bt.tranh;
    INSERT INTO qh.tuong SELECT id, 'tuong', chat_lieu_chinh, ky_thuat, trong_luong_kg FROM bt.tuong;
    INSERT INTO qh.tai_lieu_co SELECT id, 'tai_lieu_co', ngon_ngu, loai_chu, so_trang, tinh_trang_giay
                               FROM bt.tai_lieu_co;

    INSERT INTO qh.hien_vat_tu_khoa SELECT h.id, k FROM bt.hien_vat h, unnest(h.tu_khoa) k;
    INSERT INTO qh.hien_vat_ten_goi_khac
        SELECT h.id, o, k FROM bt.hien_vat h, unnest(h.ten_goi_khac) WITH ORDINALITY AS u(k, o);
    -- dictionary lồng: làm phẳng thành khóa dạng đường dẫn "nguon_goc.dia_diem"
    INSERT INTO qh.hien_vat_thuoc_tinh
        SELECT h.id, e1.key || coalesce('.' || e2.key, ''),
               coalesce(e2.value #>> '{}', e1.value #>> '{}')
        FROM bt.hien_vat h
        CROSS JOIN LATERAL jsonb_each(h.thuoc_tinh_mo_rong) e1
        LEFT JOIN LATERAL jsonb_each(CASE jsonb_typeof(e1.value) WHEN 'object' THEN e1.value END) e2 ON true;
    INSERT INTO qh.muc_luc SELECT t.id, o, m FROM bt.tai_lieu_co t, unnest(t.muc_luc) WITH ORDINALITY AS u(m, o);
    INSERT INTO qh.con_dau SELECT t.id, o, c FROM bt.tai_lieu_co t, unnest(t.con_dau) WITH ORDINALITY AS u(c, o);

    INSERT INTO qh.hien_vat_tac_gia SELECT * FROM bt.hien_vat_tac_gia;
    INSERT INTO qh.hien_vat_chat_lieu SELECT * FROM bt.hien_vat_chat_lieu;
    INSERT INTO qh.trien_lam_hien_vat SELECT * FROM bt.trien_lam_hien_vat;
    INSERT INTO qh.lich_su_bao_quan SELECT * FROM bt.lich_su_bao_quan;

    ALTER TABLE qh.thanh_phan DISABLE TRIGGER trg_thanh_phan;   -- dữ liệu nguồn đã được A kiểm tra
    INSERT INTO qh.thanh_phan SELECT * FROM bt.thanh_phan;
    ALTER TABLE qh.thanh_phan ENABLE TRIGGER trg_thanh_phan;

    INSERT INTO qh.tai_nguyen_so
        SELECT ma_tn, CASE WHEN tableoid = 'bt.anh'::regclass THEN 'anh' ELSE 'video' END,
               id_hv, thu_tu, uri, dinh_dang, kich_thuoc_byte, chu_thich, la_dai_dien
        FROM bt.tai_nguyen_so;
    INSERT INTO qh.anh SELECT ma_tn, 'anh', rong_px, cao_px, goc_chup FROM bt.anh;
    INSERT INTO qh.anh_exif SELECT a.ma_tn, e.key, e.value #>> '{}' FROM bt.anh a, jsonb_each(a.exif) e;
    INSERT INTO qh.video SELECT ma_tn, 'video', thoi_luong_giay, do_phan_giai FROM bt.video;
END $$;

CALL nap_tu_A();
ANALYZE;
