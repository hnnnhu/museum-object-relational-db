"""Kịch bản transaction K1–K4 (mục 7.3) trên CSDL mẫu baotang, phương án A.

K1   giao dịch nhập hiện vật thành công (4 bước)
K2   lỗi ở bước cuối → ROLLBACK toàn bộ, không còn dòng định danh mồ côi
K2b  lỗi ở bước tùy chọn sau SAVEPOINT → ROLLBACK TO SAVEPOINT, phần còn lại COMMIT
K3   hai phiên cùng chuyển hiện vật vào phòng P401 (sức chứa 2, đang có 1), 4 cơ chế:
       K3a READ COMMITTED, không khóa          K3b READ COMMITTED + SELECT … FOR UPDATE
       K3c SERIALIZABLE, không khóa, thử lại    K3d REPEATABLE READ, không khóa (write skew)
     mỗi cơ chế chạy lặp N_LAP lần; nhật ký chi tiết của lần đầu được in ra.
K4   hai phiên chèn trùng mã vào hai lớp con khác nhau
Kịch bản tự nạp lại lược đồ A và dữ liệu mẫu trước khi chạy, nên có thể lặp lại.
Chạy:  python3 scripts/07_transaction.py  >  results/transaction_output.txt
"""
import os
import threading
import time
import psycopg2
from psycopg2 import errors
from psycopg2.extensions import (ISOLATION_LEVEL_READ_COMMITTED, ISOLATION_LEVEL_REPEATABLE_READ,
                                 ISOLATION_LEVEL_SERIALIZABLE)
from truy_van_ab import DSN_MAU

THU_MUC_SQL = os.path.join(os.path.dirname(__file__), "..", "sql")
N_LAP = 10
TRE = 1.0          # giây giữa bước đếm và bước ghi trong thủ tục (mở rộng cửa sổ cạnh tranh)
LECH = 0.2         # phiên 2 bắt đầu sau phiên 1


def ket_noi(muc=ISOLATION_LEVEL_READ_COMMITTED, autocommit=False):
    c = psycopg2.connect(DSN_MAU)
    c.set_session(isolation_level=muc, autocommit=autocommit)
    return c


def nap_lai():
    c = ket_noi(autocommit=True)
    cur = c.cursor()
    for tep in ("01_schema_A.sql", "02_seed.sql"):
        with open(os.path.join(THU_MUC_SQL, tep), encoding="utf-8") as f:
            cur.execute(f.read())
    c.close()


def truy(sql, tham_so=None):
    c = ket_noi(autocommit=True)
    cur = c.cursor()
    cur.execute(sql, tham_so)
    kq = cur.fetchall()
    c.close()
    return kq


def dem_hv(ma_hv):
    return truy("""SELECT (SELECT count(*) FROM bt.dinh_danh_hien_vat WHERE ma_hv = %(m)s),
                          (SELECT count(*) FROM bt.thanh_phan t JOIN bt.dinh_danh_hien_vat d ON d.id = t.id_hv WHERE d.ma_hv = %(m)s),
                          (SELECT count(*) FROM bt.tai_nguyen_so t JOIN bt.dinh_danh_hien_vat d ON d.id = t.id_hv WHERE d.ma_hv = %(m)s),
                          (SELECT count(*) FROM bt.video t JOIN bt.dinh_danh_hien_vat d ON d.id = t.id_hv WHERE d.ma_hv = %(m)s)""",
                {"m": ma_hv})[0]


BUOC_NHAP = [
    ("chèn tượng HV-000010 (trigger tạo dòng định danh)",
     "INSERT INTO bt.tuong(ma_hv, ten, chat_lieu_chinh, ma_bst) VALUES ('HV-000010', 'Tượng Quan Âm', 'Gỗ mít', 2) RETURNING id"),
    ("chèn 2 thành phần",
     "INSERT INTO bt.thanh_phan(id_hv, ten, chat_lieu) VALUES (%(id)s, 'Thân tượng', 'Gỗ mít'), (%(id)s, 'Bệ', 'Gỗ mít')"),
    ("gắn tác giả", "INSERT INTO bt.hien_vat_tac_gia VALUES (%(id)s, 4, 'nghệ nhân')"),
]
ANH_TOT = "INSERT INTO bt.anh(id_hv, uri, dinh_dang, rong_px, cao_px, la_dai_dien) VALUES (%(id)s, 's3://kho-so/HV-000010/1.jpg', 'jpg', 4000, 3000, true)"
ANH_LOI = "INSERT INTO bt.anh(id_hv, uri, dinh_dang, rong_px, cao_px, la_dai_dien) VALUES (%(id)s, 's3://kho-so/HV-000010/1.jpg', 'jpg', 0, 3000, true)"
VIDEO_LOI = "INSERT INTO bt.video(id_hv, uri, dinh_dang, thoi_luong_giay) VALUES (%(id)s, 's3://x.mp4', 'mp4', -5)"


def k1_k2():
    print("=" * 100 + "\nK1, K2, K2b – tính nguyên tử\n" + "=" * 100)
    # K1
    c = ket_noi(); cur = c.cursor()
    cur.execute(BUOC_NHAP[0][1]); id_ = cur.fetchone()[0]
    for _, sql in BUOC_NHAP[1:]:
        cur.execute(sql, {"id": id_})
    cur.execute(ANH_TOT, {"id": id_})
    c.commit(); c.close()
    d = dem_hv("HV-000010")
    print(f"K1  4/4 bước thành công, COMMIT → định danh={d[0]}, thành phần={d[1]}, tài nguyên={d[2]}")
    truy("DELETE FROM bt.tuong WHERE ma_hv = 'HV-000010' RETURNING id")

    # K2
    c = ket_noi(); cur = c.cursor()
    try:
        cur.execute(BUOC_NHAP[0][1]); id_ = cur.fetchone()[0]
        for _, sql in BUOC_NHAP[1:]:
            cur.execute(sql, {"id": id_})
        cur.execute(ANH_LOI, {"id": id_})
        c.commit()
    except psycopg2.Error as e:
        loi = e.diag.message_primary
        c.rollback()
    c.close()
    d = dem_hv("HV-000010")
    print(f"K2  bước 4/4 lỗi ({loi}) → ROLLBACK → định danh={d[0]}, thành phần={d[1]}, tài nguyên={d[2]}")

    # K2b
    c = ket_noi(); cur = c.cursor()
    cur.execute(BUOC_NHAP[0][1]); id_ = cur.fetchone()[0]
    for _, sql in BUOC_NHAP[1:]:
        cur.execute(sql, {"id": id_})
    cur.execute(ANH_TOT, {"id": id_})
    cur.execute("SAVEPOINT truoc_video")
    try:
        cur.execute(VIDEO_LOI, {"id": id_})
    except psycopg2.Error as e:
        loi = e.diag.message_primary
        cur.execute("ROLLBACK TO SAVEPOINT truoc_video")
    c.commit(); c.close()
    d = dem_hv("HV-000010")
    print(f"K2b bước tùy chọn lỗi ({loi}) → ROLLBACK TO SAVEPOINT, COMMIT → "
          f"định danh={d[0]}, thành phần={d[1]}, tài nguyên={d[2]}, video={d[3]}")
    truy("DELETE FROM bt.tuong WHERE ma_hv = 'HV-000010' RETURNING id")


CO_CHE = {
    "K3a": ("READ COMMITTED, không khóa", ISOLATION_LEVEL_READ_COMMITTED, False),
    "K3b": ("READ COMMITTED + SELECT … FOR UPDATE trên dòng phòng", ISOLATION_LEVEL_READ_COMMITTED, True),
    "K3c": ("SERIALIZABLE, không khóa, thử lại khi lỗi 40001", ISOLATION_LEVEL_SERIALIZABLE, False),
    "K3d": ("REPEATABLE READ, không khóa", ISOLATION_LEVEL_REPEATABLE_READ, False),
}


def phien(ten, ma_hv, muc, khoa, t0, log, kq):
    so_lan = 0
    time.sleep(LECH if ten == "Phiên 2" else 0)
    bat_dau = time.perf_counter()           # tính từ lần thử ĐẦU TIÊN, gồm cả thời gian chờ và thử lại
    while True:
        so_lan += 1
        c = ket_noi(muc); cur = c.cursor()
        log.append((time.perf_counter() - t0, ten, f"lần {so_lan}: BEGIN, gọi chuyen_phong({ma_hv}, P401)"))
        try:
            cur.execute("CALL bt.chuyen_phong(%s, 'P401', %s, %s)", (ma_hv, TRE, khoa))
            c.commit()
            log.append((time.perf_counter() - t0, ten, f"lần {so_lan}: COMMIT"))
            kq[ten] = ("COMMIT", so_lan, (time.perf_counter() - bat_dau) * 1000)
            c.close(); return
        except errors.SerializationFailure as e:
            c.rollback(); c.close()
            log.append((time.perf_counter() - t0, ten, f"lần {so_lan}: lỗi tuần tự hóa 40001 → ROLLBACK, thử lại"))
            if so_lan >= 5:
                kq[ten] = ("HẾT LẦN THỬ", so_lan, 0); return
        except psycopg2.Error as e:
            c.rollback(); c.close()
            log.append((time.perf_counter() - t0, ten, f"lần {so_lan}: từ chối – {e.diag.message_primary}"))
            kq[ten] = ("TỪ CHỐI", so_lan, (time.perf_counter() - bat_dau) * 1000)
            return


def chay_k3(ma, in_log):
    mo_ta, muc, khoa = CO_CHE[ma]
    truy("""UPDATE bt.hien_vat SET trang_thai = 'luu_kho', ma_phong = NULL
            WHERE ma_hv IN ('HV-000003', 'HV-000008') RETURNING id""")
    log, kq = [], {}
    t0 = time.perf_counter()
    ts = [threading.Thread(target=phien, args=("Phiên 1", "HV-000003", muc, khoa, t0, log, kq)),
          threading.Thread(target=phien, args=("Phiên 2", "HV-000008", muc, khoa, t0, log, kq))]
    for t in ts: t.start()
    for t in ts: t.join()
    so = truy("SELECT count(*) FROM bt.hien_vat WHERE ma_phong = 'P401' AND trang_thai = 'trung_bay'")[0][0]
    if in_log:
        print(f"\n--- {ma} – {mo_ta}: nhật ký lần chạy đầu ---")
        for t, ten, viec in sorted(log):
            print(f"  t={t * 1000:7.0f} ms  {ten}: {viec}")
        print(f"  → P401 sau cùng: {so}/2")
    return so, kq


def k3():
    print("\n" + "=" * 100 + f"\nK3 – hai phiên cạnh tranh sức chứa phòng P401 (sức chứa 2, đang có 1); "
          f"độ trễ đếm→ghi {TRE:.1f} s; mỗi cơ chế {N_LAP} lần\n" + "=" * 100)
    tong_hop = []
    for ma in CO_CHE:
        vi_pham, thu_lai, cho_p2 = 0, 0, []
        for i in range(N_LAP):
            so, kq = chay_k3(ma, in_log=(i == 0))
            vi_pham += so > 2
            thu_lai += sum(v[1] - 1 for v in kq.values())
            cho_p2.append(kq["Phiên 2"][2])
            ket_qua_dau = kq if i == 0 else ket_qua_dau
        tong_hop.append((ma, CO_CHE[ma][0], vi_pham, thu_lai, sorted(cho_p2)[len(cho_p2) // 2], ket_qua_dau))
    print(f"\n{'Kịch bản':<9}{'Cơ chế':<54}{'Vi phạm R12':>12}{'Số lần thử lại':>16}{'Phiên 2 tổng (ms)':>23}  Kết cục phiên 2 (lần đầu)")
    for ma, mo_ta, vp, tl, cho, kq in tong_hop:
        print(f"{ma:<9}{mo_ta:<54}{f'{vp}/{N_LAP}':>12}{tl:>16}{cho:>23.0f}  {kq['Phiên 2'][0]} sau {kq['Phiên 2'][1]} lần")


def k4():
    print("\n" + "=" * 100 + "\nK4 – hai phiên chèn trùng mã HV-000777 vào hai lớp con\n" + "=" * 100)
    kq = {}
    t0 = time.perf_counter()

    def p1():
        c = ket_noi(); cur = c.cursor()
        cur.execute("INSERT INTO bt.tranh(ma_hv, ten, chat_lieu_nen) VALUES ('HV-000777', 'Tranh A', 'Lụa')")
        time.sleep(1.0)
        c.commit(); c.close()
        kq["Phiên 1"] = f"COMMIT tại t={1000 * (time.perf_counter() - t0):.0f} ms"

    def p2():
        time.sleep(0.2)
        c = ket_noi(); cur = c.cursor()
        bd = time.perf_counter()
        try:
            cur.execute("INSERT INTO bt.tuong(ma_hv, ten, chat_lieu_chinh) VALUES ('HV-000777', 'Tượng B', 'Đồng')")
            c.commit(); kq["Phiên 2"] = "COMMIT"
        except psycopg2.Error as e:
            c.rollback()
            kq["Phiên 2"] = (f"bị chặn {1000 * (time.perf_counter() - bd):.0f} ms rồi lỗi: "
                             f"{e.diag.message_primary}")
        c.close()

    ts = [threading.Thread(target=p1), threading.Thread(target=p2)]
    for t in ts: t.start()
    for t in ts: t.join()
    so = truy("SELECT count(*) FROM bt.dinh_danh_hien_vat WHERE ma_hv = 'HV-000777'")[0][0]
    print(f"  Phiên 1: {kq['Phiên 1']}\n  Phiên 2: {kq['Phiên 2']}\n  → số đối tượng mang mã HV-000777: {so}")
    truy("DELETE FROM bt.tranh WHERE ma_hv = 'HV-000777' RETURNING id")


if __name__ == "__main__":
    nap_lai()
    print(truy("SELECT version()")[0][0])
    k1_k2()
    k3()
    k4()
    nap_lai()
    print("\nĐã nạp lại dữ liệu mẫu.")
