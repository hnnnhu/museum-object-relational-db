-- =====================================================================
-- 01_schema_A.sql – Phương án A: mô hình quan hệ–đối tượng trên PostgreSQL 16
-- Đồ án 9 – Thiết kế CSDL hướng đối tượng cho hệ thống bảo tàng số
-- Hiện thực lược đồ ODL (mục 5.1) bằng: kiểu phức hợp, miền, enum, kiểu khoảng,
-- kế thừa bảng (INHERITS), mảng, JSONB, hàm (phương thức) và trigger.
-- Chạy được nhiều lần: xóa và tạo lại schema bt.
-- =====================================================================
SET client_min_messages = warning;
DROP SCHEMA IF EXISTS bt CASCADE;
CREATE SCHEMA bt;
SET search_path = bt, public;

-- ---------------------------------------------------------------------
-- 1. Kiểu dữ liệu do người dùng định nghĩa (literal của ODMG)
-- ---------------------------------------------------------------------
CREATE DOMAIN ma_hien_vat AS varchar(9)
    CHECK (VALUE ~ '^HV-[0-9]{6}$');                       -- R2: định dạng mã

CREATE TYPE loai_hien_vat AS ENUM ('tranh', 'tuong', 'tai_lieu_co');
CREATE TYPE trang_thai_hv AS ENUM ('trung_bay', 'luu_kho', 'bao_quan', 'cho_muon');

CREATE TYPE kich_thuoc AS (                                 -- struct KichThuoc
    dai_cm  numeric(8,2),
    rong_cm numeric(8,2),
    cao_cm  numeric(8,2)
);
-- struct NienDai được hiện thực bằng int4range (từ năm, đến năm) + cột mô tả.
-- Quy ước: khoảng nửa mở [tu_nam, den_nam + 1) – den_nam trong ODL là năm cuối (đóng).

-- CHECK không được chứa truy vấn con, nên kiểm tra "set không trùng" đặt trong hàm
CREATE FUNCTION mang_khong_trung(a text[]) RETURNS boolean LANGUAGE sql IMMUTABLE AS
$$ SELECT cardinality(a) = (SELECT count(DISTINCT x) FROM unnest(a) x) $$;

CREATE SEQUENCE seq_hien_vat;                               -- OID dùng chung cho mọi lớp con
CREATE SEQUENCE seq_tai_nguyen;                             -- OID dùng chung cho Anh, Video

-- ---------------------------------------------------------------------
-- 2. Các lớp độc lập
-- ---------------------------------------------------------------------
CREATE TABLE bo_suu_tap (                                   -- class BoSuuTap (key ten)
    ma_bst serial PRIMARY KEY,
    ten    varchar(120) NOT NULL UNIQUE,
    mo_ta  text
);

CREATE TABLE phong_trung_bay (                              -- class PhongTrungBay (key ma_phong)
    ma_phong varchar(10) PRIMARY KEY,
    ten      varchar(120) NOT NULL,
    tang     smallint NOT NULL,
    suc_chua int NOT NULL CHECK (suc_chua > 0)
);

CREATE TABLE tac_gia (                                      -- class TacGia
    ma_tac_gia serial PRIMARY KEY,
    ho_ten     varchar(120) NOT NULL,
    but_danh   varchar(120),
    nam_sinh   smallint,
    nam_mat    smallint,
    quoc_tich  varchar(60),
    CHECK (nam_mat IS NULL OR nam_sinh IS NULL OR nam_mat >= nam_sinh)
);

CREATE TABLE chat_lieu (                                    -- class ChatLieu (key ten)
    ma_chat_lieu serial PRIMARY KEY,
    ten          varchar(80) NOT NULL UNIQUE
);

CREATE TABLE trien_lam (                                    -- class TrienLam
    ma_tl    serial PRIMARY KEY,
    ten      varchar(160) NOT NULL,
    tu_ngay  date NOT NULL,
    den_ngay date NOT NULL,
    CHECK (tu_ngay <= den_ngay)                             -- R11
);

-- ---------------------------------------------------------------------
-- 3. Bảng định danh dùng chung – bù cho PK/UNIQUE/FK không được kế thừa (mục 6.2–6.3)
-- ---------------------------------------------------------------------
CREATE TABLE dinh_danh_hien_vat (
    id    bigint PRIMARY KEY,                               -- OID trên toàn phân cấp
    ma_hv ma_hien_vat NOT NULL UNIQUE,                      -- R2: duy nhất toàn bảo tàng
    loai  loai_hien_vat NOT NULL                            -- lớp thực của đối tượng
);

-- ---------------------------------------------------------------------
-- 4. Lớp gốc trừu tượng HienVat và ba lớp con (kế thừa bảng)
-- ---------------------------------------------------------------------
CREATE TABLE hien_vat (                                     -- class HienVat (extent tat_ca_hien_vat)
    id                 bigint NOT NULL DEFAULT nextval('seq_hien_vat'),
    ma_hv              ma_hien_vat NOT NULL,
    ten                varchar(200) NOT NULL,
    mo_ta              text,
    nien_dai           int4range,                           -- struct NienDai
    nien_dai_mo_ta     varchar(80),
    kich_thuoc         kich_thuoc,                          -- struct KichThuoc
    trang_thai         trang_thai_hv NOT NULL DEFAULT 'luu_kho',
    ngay_nhap          date NOT NULL DEFAULT current_date,
    ma_bst             int,
    ma_phong           varchar(10),
    tu_khoa            text[] NOT NULL DEFAULT '{}',        -- set<string>
    ten_goi_khac       text[] NOT NULL DEFAULT '{}',        -- list<string> (có thứ tự)
    thuoc_tinh_mo_rong jsonb  NOT NULL DEFAULT '{}',        -- dictionary<string,string>
    -- Các CHECK và NOT NULL dưới đây ĐƯỢC kế thừa sang bảng con
    CONSTRAINT ck_nien_dai CHECK (nien_dai IS NULL OR (NOT lower_inf(nien_dai) AND NOT isempty(nien_dai))),
    CONSTRAINT ck_kich_thuoc_duong CHECK (                  -- R5
        ((kich_thuoc).dai_cm  IS NULL OR (kich_thuoc).dai_cm  > 0) AND
        ((kich_thuoc).rong_cm IS NULL OR (kich_thuoc).rong_cm > 0) AND
        ((kich_thuoc).cao_cm  IS NULL OR (kich_thuoc).cao_cm  > 0)),
    CONSTRAINT ck_trung_bay_co_phong                         -- R6
        CHECK (trang_thai <> 'trung_bay' OR ma_phong IS NOT NULL),
    CONSTRAINT ck_tu_khoa_khong_trung                        -- set<string>: không phần tử trùng
        CHECK (mang_khong_trung(tu_khoa))
);
COMMENT ON TABLE hien_vat IS 'Lớp trừu tượng: không chứa dòng; truy vấn trên bảng này bao gồm mọi bảng con (extent tat_ca_hien_vat).';


-- Lớp con: PK, UNIQUE, FK phải KHAI BÁO LẠI ở từng bảng con (không được kế thừa)
CREATE TABLE tranh (                                        -- class Tranh extends HienVat
    chat_lieu_nen varchar(60) NOT NULL,
    truong_phai   varchar(60),
    co_khung      boolean NOT NULL DEFAULT false,
    PRIMARY KEY (id), UNIQUE (ma_hv),
    FOREIGN KEY (id) REFERENCES dinh_danh_hien_vat ON DELETE CASCADE,
    FOREIGN KEY (ma_bst) REFERENCES bo_suu_tap,
    FOREIGN KEY (ma_phong) REFERENCES phong_trung_bay
) INHERITS (hien_vat);

CREATE TABLE tuong (                                        -- class Tuong extends HienVat
    chat_lieu_chinh varchar(60) NOT NULL,
    ky_thuat        varchar(60),
    trong_luong_kg  numeric(10,2) CHECK (trong_luong_kg > 0),
    PRIMARY KEY (id), UNIQUE (ma_hv),
    FOREIGN KEY (id) REFERENCES dinh_danh_hien_vat ON DELETE CASCADE,
    FOREIGN KEY (ma_bst) REFERENCES bo_suu_tap,
    FOREIGN KEY (ma_phong) REFERENCES phong_trung_bay
) INHERITS (hien_vat);

CREATE TABLE tai_lieu_co (                                  -- class TaiLieuCo extends HienVat
    ngon_ngu        varchar(40) NOT NULL,
    loai_chu        varchar(40) NOT NULL,
    so_trang        smallint CHECK (so_trang > 0),
    tinh_trang_giay varchar(80),
    muc_luc         text[] NOT NULL DEFAULT '{}',           -- array<string>, truy cập muc_luc[i]
    con_dau         text[] NOT NULL DEFAULT '{}',           -- bag<string>: cho phép trùng
    PRIMARY KEY (id), UNIQUE (ma_hv),
    FOREIGN KEY (id) REFERENCES dinh_danh_hien_vat ON DELETE CASCADE,
    FOREIGN KEY (ma_bst) REFERENCES bo_suu_tap,
    FOREIGN KEY (ma_phong) REFERENCES phong_trung_bay
) INHERITS (hien_vat);

-- ---------------------------------------------------------------------
-- 5. Các lớp phụ thuộc hiện vật – tham chiếu bảng định danh (một hiện vật bất kỳ)
-- ---------------------------------------------------------------------
CREATE TABLE thanh_phan (                                   -- class ThanhPhan (cấu trúc đệ quy)
    ma_tp     bigserial PRIMARY KEY,
    id_hv     bigint NOT NULL REFERENCES dinh_danh_hien_vat ON DELETE CASCADE,
    ma_tp_cha bigint REFERENCES thanh_phan ON DELETE CASCADE,
    ten       varchar(120) NOT NULL,
    so_luong  int NOT NULL DEFAULT 1 CHECK (so_luong > 0),
    chat_lieu varchar(80)
);

CREATE TABLE hien_vat_tac_gia (                             -- lớp kết hợp SangTac
    id_hv      bigint REFERENCES dinh_danh_hien_vat ON DELETE CASCADE,
    ma_tac_gia int REFERENCES tac_gia,
    vai_tro    varchar(40) NOT NULL,
    PRIMARY KEY (id_hv, ma_tac_gia)
);

CREATE TABLE hien_vat_chat_lieu (                           -- relationship lam_bang (M:N)
    id_hv        bigint REFERENCES dinh_danh_hien_vat ON DELETE CASCADE,
    ma_chat_lieu int REFERENCES chat_lieu,
    PRIMARY KEY (id_hv, ma_chat_lieu)
);

CREATE TABLE trien_lam_hien_vat (                           -- lớp kết hợp ThamGiaTrienLam
    ma_tl  int REFERENCES trien_lam ON DELETE CASCADE,
    id_hv  bigint REFERENCES dinh_danh_hien_vat ON DELETE CASCADE,
    vi_tri varchar(40),
    PRIMARY KEY (ma_tl, id_hv)
);

CREATE TABLE lich_su_bao_quan (                             -- class LichSuBaoQuan
    ma_ls           bigserial PRIMARY KEY,
    id_hv           bigint NOT NULL REFERENCES dinh_danh_hien_vat ON DELETE CASCADE,
    ngay            date NOT NULL,
    hang_muc        varchar(80) NOT NULL,
    mo_ta           text,
    nguoi_thuc_hien varchar(120)
);

-- Phân cấp tài nguyên số: TaiNguyenSo (trừu tượng) → Anh, Video
CREATE TABLE tai_nguyen_so (
    ma_tn           bigint NOT NULL DEFAULT nextval('seq_tai_nguyen'),
    id_hv           bigint NOT NULL,
    thu_tu          smallint NOT NULL DEFAULT 1,            -- vị trí trong list<TaiNguyenSo>
    uri             text NOT NULL,
    dinh_dang       varchar(10) NOT NULL,
    kich_thuoc_byte bigint CHECK (kich_thuoc_byte > 0),
    chu_thich       text,
    la_dai_dien     boolean NOT NULL DEFAULT false
);
CREATE TABLE anh (                                          -- class Anh extends TaiNguyenSo
    rong_px  int NOT NULL CHECK (rong_px > 0),
    cao_px   int NOT NULL CHECK (cao_px > 0),
    goc_chup varchar(40),
    exif     jsonb NOT NULL DEFAULT '{}',                   -- dictionary<string,string>
    PRIMARY KEY (ma_tn),
    FOREIGN KEY (id_hv) REFERENCES dinh_danh_hien_vat ON DELETE CASCADE
) INHERITS (tai_nguyen_so);
CREATE TABLE video (                                        -- class Video extends TaiNguyenSo
    thoi_luong_giay int NOT NULL CHECK (thoi_luong_giay > 0),
    do_phan_giai    varchar(20),
    PRIMARY KEY (ma_tn),
    FOREIGN KEY (id_hv) REFERENCES dinh_danh_hien_vat ON DELETE CASCADE,
    CHECK (NOT la_dai_dien)                                 -- R9: chỉ ảnh làm ảnh đại diện
) INHERITS (tai_nguyen_so);

-- ---------------------------------------------------------------------
-- 6. Trigger
-- ---------------------------------------------------------------------
-- 6.1 Đồng bộ bảng định danh; bảo vệ OID bất biến (R2, R3)
CREATE FUNCTION fn_dong_bo_dinh_danh() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO bt.dinh_danh_hien_vat(id, ma_hv, loai)
        VALUES (NEW.id, NEW.ma_hv, TG_ARGV[0]::bt.loai_hien_vat);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.id <> OLD.id THEN
            RAISE EXCEPTION 'Không được thay đổi định danh đối tượng (OID) %', OLD.id;
        END IF;
        IF NEW.ma_hv <> OLD.ma_hv THEN
            UPDATE bt.dinh_danh_hien_vat SET ma_hv = NEW.ma_hv WHERE id = NEW.id;
        END IF;
        RETURN NEW;
    ELSE  -- DELETE: xóa dòng định danh, kéo theo CASCADE tới các đối tượng phụ thuộc (R10)
        DELETE FROM bt.dinh_danh_hien_vat WHERE id = OLD.id;
        RETURN OLD;
    END IF;
END $$;

CREATE TRIGGER trg_tranh_dd BEFORE INSERT OR UPDATE ON tranh
    FOR EACH ROW EXECUTE FUNCTION fn_dong_bo_dinh_danh('tranh');
CREATE TRIGGER trg_tranh_dd_del AFTER DELETE ON tranh
    FOR EACH ROW EXECUTE FUNCTION fn_dong_bo_dinh_danh('tranh');
CREATE TRIGGER trg_tuong_dd BEFORE INSERT OR UPDATE ON tuong
    FOR EACH ROW EXECUTE FUNCTION fn_dong_bo_dinh_danh('tuong');
CREATE TRIGGER trg_tuong_dd_del AFTER DELETE ON tuong
    FOR EACH ROW EXECUTE FUNCTION fn_dong_bo_dinh_danh('tuong');
CREATE TRIGGER trg_tlc_dd BEFORE INSERT OR UPDATE ON tai_lieu_co
    FOR EACH ROW EXECUTE FUNCTION fn_dong_bo_dinh_danh('tai_lieu_co');
CREATE TRIGGER trg_tlc_dd_del AFTER DELETE ON tai_lieu_co
    FOR EACH ROW EXECUTE FUNCTION fn_dong_bo_dinh_danh('tai_lieu_co');

-- 6.2 Lớp trừu tượng (R1 toàn phần): trigger dòng không kế thừa sang bảng con,
--     nên chỉ chặn chèn TRỰC TIẾP vào bảng cha.
CREATE FUNCTION fn_chan_lop_truu_tuong() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION '% là lớp trừu tượng: hãy chèn vào một bảng con', TG_TABLE_NAME;
END $$;
CREATE TRIGGER trg_hien_vat_truu_tuong BEFORE INSERT ON hien_vat
    FOR EACH ROW EXECUTE FUNCTION fn_chan_lop_truu_tuong();
CREATE TRIGGER trg_tai_nguyen_truu_tuong BEFORE INSERT ON tai_nguyen_so
    FOR EACH ROW EXECUTE FUNCTION fn_chan_lop_truu_tuong();

-- 6.3 Cấu trúc thành phần (R8): cha cùng hiện vật, không chu trình
CREATE FUNCTION fn_kiem_tra_thanh_phan() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_hv_cha bigint; v_chu_trinh boolean;
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.id_hv <> OLD.id_hv AND
       EXISTS (SELECT 1 FROM bt.thanh_phan WHERE ma_tp_cha = NEW.ma_tp) THEN
        RAISE EXCEPTION 'Không đổi hiện vật của thành phần % khi còn thành phần con', NEW.ma_tp;
    END IF;
    IF NEW.ma_tp_cha IS NULL THEN RETURN NEW; END IF;
    IF NEW.ma_tp_cha = NEW.ma_tp THEN
        RAISE EXCEPTION 'Thành phần % không thể là cha của chính nó', NEW.ma_tp;
    END IF;
    SELECT id_hv INTO v_hv_cha FROM bt.thanh_phan WHERE ma_tp = NEW.ma_tp_cha;
    IF v_hv_cha <> NEW.id_hv THEN
        RAISE EXCEPTION 'Thành phần cha % thuộc hiện vật khác', NEW.ma_tp_cha;
    END IF;
    IF TG_OP = 'UPDATE' THEN    -- chỉ khi sửa mới có thể tạo chu trình
        WITH RECURSIVE len(ma) AS (
            SELECT NEW.ma_tp_cha
            UNION
            SELECT t.ma_tp_cha FROM bt.thanh_phan t JOIN len ON t.ma_tp = len.ma
            WHERE t.ma_tp_cha IS NOT NULL)
        SELECT EXISTS (SELECT 1 FROM len WHERE ma = NEW.ma_tp) INTO v_chu_trinh;
        IF v_chu_trinh THEN
            RAISE EXCEPTION 'Tạo chu trình trong cấu trúc thành phần (ma_tp=%)', NEW.ma_tp;
        END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_thanh_phan BEFORE INSERT OR UPDATE ON thanh_phan
    FOR EACH ROW EXECUTE FUNCTION fn_kiem_tra_thanh_phan();

-- ---------------------------------------------------------------------
-- 7. Chỉ mục – không được kế thừa, phải tạo ở từng bảng con
-- ---------------------------------------------------------------------
CREATE INDEX ix_tranh_nien_dai ON tranh       USING gist (nien_dai);
CREATE INDEX ix_tuong_nien_dai ON tuong       USING gist (nien_dai);
CREATE INDEX ix_tlc_nien_dai   ON tai_lieu_co USING gist (nien_dai);
CREATE INDEX ix_tranh_tk ON tranh       USING gin (tu_khoa);
CREATE INDEX ix_tuong_tk ON tuong       USING gin (tu_khoa);
CREATE INDEX ix_tlc_tk   ON tai_lieu_co USING gin (tu_khoa);
CREATE INDEX ix_tranh_phong ON tranh       (ma_phong);
CREATE INDEX ix_tuong_phong ON tuong       (ma_phong);
CREATE INDEX ix_tlc_phong   ON tai_lieu_co (ma_phong);
CREATE INDEX ix_tranh_bst ON tranh       (ma_bst);
CREATE INDEX ix_tuong_bst ON tuong       (ma_bst);
CREATE INDEX ix_tlc_bst   ON tai_lieu_co (ma_bst);
CREATE INDEX ix_tuong_cl  ON tuong (chat_lieu_chinh);
CREATE INDEX ix_tp_hv  ON thanh_phan (id_hv);
CREATE INDEX ix_tp_cha ON thanh_phan (ma_tp_cha);
CREATE INDEX ix_hvtg_tg ON hien_vat_tac_gia (ma_tac_gia);
CREATE INDEX ix_anh_hv   ON anh   (id_hv);
CREATE INDEX ix_video_hv ON video (id_hv);
CREATE INDEX ix_anh_exif ON anh USING gin (exif jsonb_path_ops);
CREATE UNIQUE INDEX ux_anh_dai_dien ON anh (id_hv) WHERE la_dai_dien;      -- R9
CREATE INDEX ix_tlhv_hv ON trien_lam_hien_vat (id_hv);
CREATE INDEX ix_ls_hv   ON lich_su_bao_quan (id_hv);

-- ---------------------------------------------------------------------
-- 8. Phương thức (hàm)
-- ---------------------------------------------------------------------
-- short tuoi(): thuộc tính dẫn xuất; gọi được như h.tuoi hoặc tuoi(h).
-- Quy ước: tính theo cận dưới của niên đại (tuổi tối đa có thể).
CREATE FUNCTION tuoi(h hien_vat) RETURNS int LANGUAGE sql STABLE AS
$$ SELECT extract(year FROM current_date)::int - lower(h.nien_dai) $$;

-- float the_tich_cm3()
CREATE FUNCTION the_tich_cm3(h hien_vat) RETURNS numeric LANGUAGE sql IMMUTABLE AS
$$ SELECT (h.kich_thuoc).dai_cm * (h.kich_thuoc).rong_cm * (h.kich_thuoc).cao_cm $$;

-- long tong_thanh_phan(): tổng so_luong của mọi nút (đếm phẳng, không nhân dồn)
CREATE FUNCTION tong_thanh_phan(p_id bigint) RETURNS int LANGUAGE sql STABLE AS
$$ SELECT coalesce(sum(so_luong), 0)::int FROM bt.thanh_phan WHERE id_hv = p_id $$;

-- bag<string> cac_chat_lieu(): chất liệu theo từng NÚT thành phần, giữ phần tử trùng
CREATE FUNCTION cac_chat_lieu(p_id bigint) RETURNS text[] LANGUAGE sql STABLE AS
$$ SELECT coalesce(array_agg(chat_lieu ORDER BY chat_lieu), '{}')
   FROM bt.thanh_phan WHERE id_hv = p_id AND chat_lieu IS NOT NULL $$;

-- string ten_lop(): tên lớp thực của đối tượng (phục vụ OQL Q5)
CREATE FUNCTION ten_lop(p_id bigint) RETURNS text LANGUAGE sql STABLE AS
$$ SELECT loai::text FROM bt.dinh_danh_hien_vat WHERE id = p_id $$;

-- set<ThanhPhan> tat_ca_hau_due(): mọi thành phần con cháu của một nút, độ sâu tùy ý
CREATE FUNCTION tat_ca_hau_due(p_ma_tp bigint) RETURNS SETOF thanh_phan
LANGUAGE sql STABLE AS $$
    WITH RECURSIVE d AS (
        SELECT * FROM bt.thanh_phan WHERE ma_tp_cha = p_ma_tp
        UNION ALL
        SELECT t.* FROM bt.thanh_phan t JOIN d ON t.ma_tp_cha = d.ma_tp)
    SELECT * FROM d
$$;

-- string mo_ta_ngan(): phương thức "đa hình" – PostgreSQL không có ràng buộc muộn,
-- nên phân giải theo lớp thực ghi trong bảng định danh (gọi từng dòng – xem P8).
CREATE FUNCTION mo_ta_ngan(p_id bigint) RETURNS text LANGUAGE plpgsql STABLE AS $$
DECLARE r text;
BEGIN
    SELECT CASE d.loai
        WHEN 'tranh' THEN (SELECT format('Tranh %s, chất liệu %s', t.ten, t.chat_lieu_nen)
                           FROM bt.tranh t WHERE t.id = d.id)
        WHEN 'tuong' THEN (SELECT format('Tượng %s, %s, kỹ thuật %s', t.ten, t.chat_lieu_chinh,
                                         coalesce(t.ky_thuat, '?'))
                           FROM bt.tuong t WHERE t.id = d.id)
        ELSE (SELECT format('Tài liệu %s, chữ %s, %s trang', t.ten, t.loai_chu,
                            coalesce(t.so_trang::text, '?'))
              FROM bt.tai_lieu_co t WHERE t.id = d.id)
    END INTO r
    FROM bt.dinh_danh_hien_vat d WHERE d.id = p_id;
    RETURN r;
END $$;

-- Hàm PL/pgSQL ĐỆ QUY (S9): số chi tiết vật lý thực = nhân dồn số lượng dọc đường đi
CREATE FUNCTION fn_chi_tiet_nut(p_ma_tp bigint, p_he_so int) RETURNS int
LANGUAGE plpgsql STABLE AS $$
DECLARE v_tong int := 0; r record;
BEGIN
    FOR r IN SELECT ma_tp, so_luong FROM bt.thanh_phan WHERE ma_tp_cha = p_ma_tp LOOP
        v_tong := v_tong + p_he_so * r.so_luong
                         + bt.fn_chi_tiet_nut(r.ma_tp, p_he_so * r.so_luong);
    END LOOP;
    RETURN v_tong;
END $$;
CREATE FUNCTION so_chi_tiet_thuc(p_ma_hv text) RETURNS int LANGUAGE plpgsql STABLE AS $$
DECLARE v_id bigint; v_tong int := 0; r record;
BEGIN
    SELECT id INTO v_id FROM bt.dinh_danh_hien_vat WHERE ma_hv = p_ma_hv;
    IF NOT FOUND THEN RAISE EXCEPTION 'Không có hiện vật %', p_ma_hv; END IF;
    FOR r IN SELECT ma_tp, so_luong FROM bt.thanh_phan
             WHERE id_hv = v_id AND ma_tp_cha IS NULL LOOP
        v_tong := v_tong + r.so_luong + bt.fn_chi_tiet_nut(r.ma_tp, r.so_luong);
    END LOOP;
    RETURN v_tong;
END $$;

-- void chuyen_phong(in string ma_phong) raises (PhongDaDay) – R12
-- p_khoa = true: khóa dòng phòng (SELECT … FOR UPDATE) – phương án được chọn
-- p_khoa = false: không khóa – chỉ dùng để tái hiện lỗi trong thực nghiệm K3a/K3d
-- p_tre: độ trễ giữa bước đếm và bước ghi – chỉ dùng trong thực nghiệm K3
CREATE PROCEDURE chuyen_phong(p_ma_hv ma_hien_vat, p_ma_phong varchar,
                              p_tre numeric DEFAULT 0, p_khoa boolean DEFAULT true)
LANGUAGE plpgsql AS $$
DECLARE v_suc_chua int; v_dang_co int; v_id bigint;
BEGIN
    IF p_khoa THEN
        SELECT suc_chua INTO v_suc_chua FROM bt.phong_trung_bay
        WHERE ma_phong = p_ma_phong FOR UPDATE;               -- khóa dòng phòng
    ELSE
        SELECT suc_chua INTO v_suc_chua FROM bt.phong_trung_bay
        WHERE ma_phong = p_ma_phong;
    END IF;
    IF NOT FOUND THEN RAISE EXCEPTION 'Phòng % không tồn tại', p_ma_phong; END IF;

    SELECT id INTO v_id FROM bt.dinh_danh_hien_vat WHERE ma_hv = p_ma_hv;
    IF NOT FOUND THEN RAISE EXCEPTION 'Không có hiện vật %', p_ma_hv; END IF;

    SELECT count(*) INTO v_dang_co FROM bt.hien_vat
    WHERE ma_phong = p_ma_phong AND trang_thai = 'trung_bay' AND id <> v_id;
    PERFORM pg_sleep(p_tre);
    IF v_dang_co >= v_suc_chua THEN
        RAISE EXCEPTION 'PhongDaDay: phòng % đã đủ % hiện vật', p_ma_phong, v_suc_chua
              USING ERRCODE = 'P0001';
    END IF;
    UPDATE bt.hien_vat SET ma_phong = p_ma_phong, trang_thai = 'trung_bay' WHERE id = v_id;
END $$;

-- SQL động có phòng chống SQL injection (S11)
CREATE FUNCTION tim_hien_vat(p_lop text, p_bo_loc jsonb DEFAULT '{}')
RETURNS TABLE (ma_hv text, ten text, nien_dai int4range)
LANGUAGE plpgsql STABLE SET search_path = bt AS $$
DECLARE v_sql text; v_dk text := 'true';
BEGIN
    IF p_lop NOT IN ('hien_vat', 'tranh', 'tuong', 'tai_lieu_co') THEN   -- danh sách trắng
        RAISE EXCEPTION 'Lớp không hợp lệ: %', p_lop;
    END IF;
    IF p_bo_loc ? 'tu_nam' THEN
        v_dk := v_dk || format(' AND upper(nien_dai) > %s', (p_bo_loc ->> 'tu_nam')::int);
    END IF;
    IF p_bo_loc ? 'den_nam' THEN
        v_dk := v_dk || format(' AND lower(nien_dai) <= %s', (p_bo_loc ->> 'den_nam')::int);
    END IF;
    IF p_bo_loc ? 'tu_khoa' THEN
        v_dk := v_dk || format(' AND %L = ANY (tu_khoa)', p_bo_loc ->> 'tu_khoa');
    END IF;
    IF p_bo_loc ? 'trang_thai' THEN
        v_dk := v_dk || format(' AND trang_thai = %L', p_bo_loc ->> 'trang_thai');
    END IF;
    v_sql := format('SELECT ma_hv::text, ten::text, nien_dai FROM %I WHERE %s ORDER BY ma_hv',
                    p_lop, v_dk);
    RAISE NOTICE 'SQL sinh ra: %', v_sql;
    RETURN QUERY EXECUTE v_sql;
END $$;

-- ---------------------------------------------------------------------
-- 9. View đối tượng và view vật chất hóa (S12)
-- ---------------------------------------------------------------------
CREATE VIEW v_hien_vat_doi_tuong AS
SELECT h.id, h.ma_hv,
       jsonb_build_object(
         'lop', bt.ten_lop(h.id),
         'ma_hv', h.ma_hv, 'ten', h.ten,
         'nien_dai', jsonb_build_object('tu', lower(h.nien_dai), 'den', upper(h.nien_dai) - 1,
                                        'mo_ta', h.nien_dai_mo_ta),
         'kich_thuoc', to_jsonb(h.kich_thuoc),
         'tu_khoa', to_jsonb(h.tu_khoa),
         'tac_gia', (SELECT coalesce(jsonb_agg(jsonb_build_object('ho_ten', tg.ho_ten,
                                                                  'vai_tro', x.vai_tro)), '[]')
                     FROM bt.hien_vat_tac_gia x JOIN bt.tac_gia tg USING (ma_tac_gia)
                     WHERE x.id_hv = h.id),
         'thanh_phan_goc', (SELECT coalesce(jsonb_agg(jsonb_build_object('ten', t.ten,
                                                                         'so_luong', t.so_luong)), '[]')
                            FROM bt.thanh_phan t WHERE t.id_hv = h.id AND t.ma_tp_cha IS NULL),
         'so_anh', (SELECT count(*) FROM bt.anh a WHERE a.id_hv = h.id)
       ) AS doi_tuong
FROM bt.hien_vat h;

CREATE MATERIALIZED VIEW mv_thong_ke_lop AS
SELECT d.loai::text AS lop, count(*) AS so_hien_vat,
       min(lower(h.nien_dai)) AS nam_som_nhat, max(lower(h.nien_dai)) AS nam_muon_nhat,
       (SELECT count(*) FROM bt.tai_nguyen_so t JOIN bt.dinh_danh_hien_vat d2 ON d2.id = t.id_hv
        WHERE d2.loai = d.loai) AS so_tai_nguyen
FROM bt.hien_vat h JOIN bt.dinh_danh_hien_vat d ON d.id = h.id
GROUP BY d.loai;
