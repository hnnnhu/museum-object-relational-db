# Đồ án 9 – Thiết kế CSDL hướng đối tượng cho hệ thống bảo tàng số

Học phần Cơ sở dữ liệu nâng cao – Trường Đại học Sài Gòn
Sinh viên: Huỳnh Nguyễn Ngọc Như – MSSV 3122410285

Thiết kế ODMG (ODL/OQL), hiện thực trên PostgreSQL 16 theo hai phương án và so sánh:

- **A – quan hệ–đối tượng** (schema `bt`): kế thừa bảng `INHERITS`, kiểu phức hợp, miền, enum, `int4range`, mảng, JSONB, hàm làm phương thức, bảng định danh dùng chung + trigger để bù phần ràng buộc không được kế thừa.
- **B – quan hệ thuần** (schema `qh`): bảng cha + bảng con chung khóa (cách 8A), chuẩn hóa BCNF/4NF.

## Yêu cầu môi trường

| Thành phần | Phiên bản đã kiểm tra |
|---|---|
| PostgreSQL | 16.15 (Ubuntu 24.04), cấu hình mặc định |
| Python | 3.x + `psycopg2` (`pip install -r requirements.txt`) |
| ECPG + gcc (tùy chọn, cho ví dụ SQL nhúng) | `apt install libecpg-dev gcc` |
| Graphviz (tùy chọn, để vẽ lại hình) | `apt install graphviz` |

Các script Python kết nối bằng `user=postgres password=postgres host=localhost`. Có thể đổi bằng biến môi trường `DSN_MAU` và `DSN_BENCH`.

## Chạy lại toàn bộ

```bash
PGPASSWORD=postgres ./chay_tat_ca.sh      # khoảng 3 phút; mọi kết quả ghi vào results/
```

Hoặc chạy từng bước:

```bash
# 1. CSDL mẫu (9 hiện vật) – Chương 6, 7
createdb baotang
psql -d baotang -f sql/01_schema_A.sql -f sql/02_seed.sql -f sql/04_schema_B.sql
psql -d baotang -f sql/03_tests.sql          # kiểm thử toàn vẹn V1–V2, T1–T20
psql -d baotang -f sql/06_queries.sql        # Q1–Q14 (OQL trong chú thích + SQL)
psql -d baotang -f sql/08_sql_nang_cao.sql   # S1–S12
python3 scripts/07_transaction.py            # K1–K4 (tự nạp lại dữ liệu mẫu)
python3 scripts/10_api_cursor.py             # API + con trỏ phía server
# SQL nhúng (ECPG):
cd scripts && ecpg 10_ecpg_demo.pgc && gcc -o ecpg_demo 10_ecpg_demo.c \
  -I$(pg_config --includedir) -L$(pg_config --libdir) -lecpg && ./ecpg_demo; cd ..

# 2. CSDL thực nghiệm (60.000 hiện vật, A và B cùng dữ liệu) – Chương 8
createdb bench
psql -d bench -f sql/01_schema_A.sql -f sql/04_schema_B.sql
psql -d bench -v n_tranh=30000 -v n_tuong=15000 -v n_tlc=15000 -f sql/05_generate.sql
psql -d bench -f sql/12_schema_metrics.sql   # độ phức tạp lược đồ
python3 scripts/verify_ab.py                 # A và B trả cùng kết quả
python3 scripts/bench.py                     # hiệu năng P1–P12
python3 scripts/11_index_eval.py             # trước/sau chỉ mục
python3 scripts/09_impedance.py              # lệch pha trở kháng
```

## Cấu trúc và đối chiếu với báo cáo

| Tệp | Nội dung | Mục báo cáo |
|---|---|---|
| `docs/odl_schema.odl` | Lược đồ ODMG ODL đầy đủ (16 lớp) | 5.1 |
| `docs/eer_a_phan_cap.*`, `docs/eer_b_lien_ket.*` | EER ký pháp Elmasri (nguồn `.dot`) | 4 |
| `docs/uml_tong_quan.*`, `docs/uml_chi_tiet.*` (nguồn `uml_svg.py`) | Sơ đồ lớp UML: tổng quan liên kết và chi tiết thuộc tính | 4.3, 4.4 |
| `sql/01_schema_A.sql` | Phương án A: kiểu, bảng kế thừa, bảng định danh, trigger, hàm, thủ tục, view | 6 |
| `sql/02_seed.sql` | Dữ liệu mẫu 9 hiện vật | 6–7 |
| `sql/03_tests.sql` | Kiểm thử toàn vẹn V1–V2, T1–T20 | 8.2 |
| `sql/04_schema_B.sql` | Phương án B + thủ tục chép dữ liệu A → B | 5.2, 6.7 |
| `sql/05_generate.sql` | Sinh 60.000 hiện vật (tất định) | 8.1 |
| `sql/06_queries.sql` | Q1–Q14: OQL + SQL | 7.1 |
| `sql/08_sql_nang_cao.sql` | S1–S12 | 7.2 |
| `sql/12_schema_metrics.sql` | Đếm bảng, cột, ràng buộc, chỉ mục, trigger từ catalog | 8.3 |
| `scripts/07_transaction.py` | K1, K2, K2b, K3a–K3d (lặp 10 lần), K4 | 7.3 |
| `scripts/10_ecpg_demo.pgc` | SQL nhúng trong C (ECPG), con trỏ | 7.2.6 |
| `scripts/10_api_cursor.py` | API psycopg2, con trỏ phía server, `WHERE CURRENT OF` | 7.2.6 |
| `scripts/truy_van_ab.py` | Cặp truy vấn đối chiếu P1–P12 | 8.4–8.5 |
| `scripts/verify_ab.py`, `scripts/bench.py` | Kiểm tra kết quả A = B; đo hiệu năng | 8.5 |
| `scripts/11_index_eval.py` | Kế hoạch thực thi và thời gian trước/sau chỉ mục | 6.10 |
| `scripts/09_impedance.py` | Nạp 500 đối tượng theo 3 cách | 8.6 |
| `results/*_output.txt`, `results/bench.csv` | Nhật ký kết quả của lần chạy dùng trong báo cáo | 7–8 |
| `docs/CAP_NHAT_BAO_CAO.md` | Danh sách nội dung và số liệu cần cập nhật vào báo cáo | – |

## Ghi chú về tái lập

- Dữ liệu thực nghiệm tất định (`setseed(0.42)` + công thức số học), nên chạy lại cho cùng dữ liệu.
- Thời gian đo dao động giữa các lần chạy, thường ±10–20%. Báo cáo dùng trung vị và ghi kèm min–max.
- Triển lãm trong dữ liệu mẫu được đặt theo `current_date`, nên Q8 và S3 luôn có triển lãm đang diễn ra.
- `tuoi()` tính theo `current_date`, nên giá trị tăng theo năm chạy.
