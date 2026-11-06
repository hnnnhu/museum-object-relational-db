# Nội dung cần cập nhật vào báo cáo

Toàn bộ script đã được dựng lại và chạy thật trên PostgreSQL 16.15 (Ubuntu 24.04, 2 vCPU, 7 GB RAM; client và server cùng máy).
**Mọi số liệu trong báo cáo phải lấy từ `results/`**, không giữ số cũ. Dưới đây là các thay đổi theo từng mục.
Thời gian đo dao động khoảng ±10–20% giữa các lần chạy; các con số ghi ở đây lấy từ lần chạy lưu trong `results/`.

---

## 1. Chương 3 – Quy tắc nghiệp vụ

- **R1:** bổ sung cơ chế cho phương án B: "trigger ràng buộc trì hoãn `trg_toan_phan` (đã cài)".
- **R9:** bổ sung "video không được làm ảnh đại diện (CHECK)".
- **R13:** bổ sung `ten_goi_khac` (list) và `con_dau` (bag).

## 2. Chương 4 – EER và UML

- **Thay Hình 4.1** bằng hai hình mới:
  - `docs/eer_a_phan_cap.png` (Hình 4.1a – phân cấp và thuộc tính);
  - `docs/eer_b_lien_ket.png` (Hình 4.1b – các kiểu liên kết).
  Cả hai vẽ theo ký pháp Elmasri: thoi, elip, elip đôi, elip nét đứt, gạch chân khóa, vòng tròn d, đường đôi cho toàn phần.
- **LichSuBaoQuan:** thay "thực thể phụ thuộc" bằng "thực thể thường, tham gia toàn phần vào GHI_NHẬN, xóa theo hiện vật (CASCADE)".
- **Bảng 4.3:** đổi "thuộc HienVat–BoSuuTap N:1" thành **bộ phận**, vì cột `ma_bst` cho phép NULL.
- **Thay Hình 4.2** bằng `docs/uml.png`: 16 lớp, 2 struct, 1 enum, 1 exception; tên thuộc tính khớp ODL; bản số ghi ở hai đầu.

## 3. Mục 5.1 – ODL

- Thay toàn bộ 5.1.2 bằng một **trích đoạn khoảng 1 trang** (HienVat và 3 lớp con). Bản đầy đủ `docs/odl_schema.odl` đưa vào phụ lục.
- Sửa các con số: **16 lớp** (thêm `ThamGiaTrienLam`), có `exception PhongDaDay`.
- Thêm vào bảng ánh xạ 5.1.1 hai dòng ví dụ:
  - `list<string> ten_goi_khac` (attribute);
  - `bag<string> con_dau` (attribute).
- Thêm câu: liên kết "tham gia" mang `vi_tri`, nên được chuyển thành lớp kết hợp `ThamGiaTrienLam`, theo cùng quy tắc đã áp dụng cho SangTac.

## 4. Mục 5.2 – Chuẩn hóa

**5.2.3:** đổi "thu được từ quy tắc nghiệp vụ và phỏng vấn bộ phận sưu tầm" thành "thu được từ quy tắc nghiệp vụ và **giả định nghiệp vụ của đồ án**".

**5.2.4 – thay đoạn phân loại vi phạm bằng:**

> Với khóa {A, L, P}, lược đồ chỉ đạt 1NF. Các phụ thuộc bộ phận vào khóa (vi phạm 2NF) gồm: f1 (A → BCDEFH, A ⊂ ALP), f5 (L → MN, L ⊂ ALP) và f6 (AL → O, AL ⊂ ALP). Các phụ thuộc bắc cầu (vi phạm 3NF) gồm: A → F → G và A → H → IJK. Hệ quả thấy được trên dữ liệu: tên phòng lặp lại ở mọi dòng của mọi hiện vật trong phòng; đổi tên phòng phải sửa nhiều dòng (dị thường cập nhật).

**5.2.6 – thay bảng kiểm tra nối không mất mát bằng:**

| Bước | Tách | Giao | Phụ thuộc dùng | Kết luận |
|---|---|---|---|---|
| 1 | PHIEU_KIEM_KE → T1(A,B,C,D,E,F,G,H,I,J,K) ∪ T2(A,L,M,N,O,P) | A | A → B…K (vì A⁺ = {A,…,K}) | Không mất mát |
| 2 | T1 → T1′(A,B,C,D,E,F,H,I,J,K) ∪ R2(F,G) | F | F → G | Không mất mát |
| 3 | T1′ → R1(A,B,C,D,E,F,H) ∪ R3(H,I,J,K) | H | H → IJK | Không mất mát |
| 4 | T2 → R4(L,M,N) ∪ T3(A,L,O,P) | L | L → MN | Không mất mát |
| 5 | T3 → R5(A,L,O) ∪ R6(A,L,P) | AL | AL → O | Không mất mát |

**5.2.7:** dữ liệu mẫu đã có đúng ví dụ 4NF. Vườn xuân có 2 tác giả (Nguyễn Văn An, Trần Thị Bình) và 2 chất liệu (Sơn mài, Vàng lá), nên R6 chưa phân rã cần 4 dòng.

**5.2.2 (lược đồ B):** bổ sung các bảng
- `HIEN_VAT_TEN_GOI_KHAC(id_hv, thu_tu, ten)` – list;
- `CON_DAU(id_tl, stt, ten_dau)` – bag, cần `stt` để giữ phần tử trùng;
- `TAI_NGUYEN_SO` có cột `thu_tu`.

## 5. Chương 6 – Vật lý

- **Phát hiện mới, nên đưa vào 6.2:** `FOREIGN KEY (ma_bst)`, `(ma_phong)` khai báo trên bảng cha `hien_vat` cũng **không** được kế thừa. Vì vậy chúng được khai báo lại ở từng bảng con (xem `01_schema_A.sql`).
- **6.8:** sửa dòng "R1 toàn phần" của B từ "chưa cài" thành "trigger ràng buộc trì hoãn `trg_toan_phan`" (ca T17, T18).
- **6.9:** từ điển dữ liệu đầy đủ chuyển xuống phụ lục.
- **Bảng mới 6.10b – Trước/sau chỉ mục** (`results/11_index_eval_output.txt`, trung vị 3 vòng × 10 lần):

| Ca | Truy vấn | Chỉ mục | Số dòng | Có chỉ mục (ms) | Không chỉ mục (ms) | Lợi |
|---|---|---|---|---|---|---|
| I1 | Niên đại giao 1945–1946 | GiST int4range | 2.007 | 1,57 | 12,19 | 7,8× |
| I2 | Niên đại giao 1900–1950 (= P4, ≈22% dòng) | GiST int4range | 13.046 | 8,01 | 12,10 | 1,5× |
| I3 | Từ khóa chu_de_7 (= P10) | GIN text[] | 1.000 | 3,76 | 15,77 | 4,2× |
| I4 | EXIF Canon và ISO 800 | GIN jsonb_path_ops | 2.857 | 3,55 | 35,00 | 9,9× |
| I5 | EXIF Canon (= P11, ≈33% dòng) | GIN jsonb_path_ops | 79.999 | 37,11 | 58,48 | 1,6× |
| I6 | Tượng đồng (= P3) | B-tree | 3.000 | 0,49 | 1,49 | 3,0× |

Nhận xét nên viết:
- Chỉ mục có lợi rõ khi điều kiện **chọn lọc cao** (I1, I4). Khi kết quả chiếm 20–33% số dòng (I2, I5), lợi ích còn khoảng 1,5×.
- Ở I2, kế hoạch thực thi cho thấy bộ tối ưu **chọn khác nhau cho từng bảng con**: `tranh` quét tuần tự, `tuong` và `tai_lieu_co` dùng Bitmap Index Scan. Lý do là mỗi bảng con có thống kê riêng. Đây là một hệ quả đáng nêu của kế thừa bảng.

## 6. Chương 7

**7.1 – OQL sửa** (bản đầy đủ trong chú thích của `sql/06_queries.sql`):
- **Q2:** dùng `t.nien_dai.den_nam < 1960`. Bản ép kiểu thêm điều kiện niên đại. Ghi quy ước: `den_nam` đóng, `upper()` mở, nên `den_nam < 1960 ⇔ upper(nien_dai) ≤ 1960`.
- **Q4:** thêm bản (b) dùng `p.tat_ca_hau_due()` cho độ sâu tùy ý, và SQL tương ứng Q4b.
- **Q5:** gom theo đúng 3 lớp:
  ```
  select tac_gia, lop, so: count(partition)
  from s in tat_ca_sang_tac
  group by tac_gia: s.cua_tac_gia.ho_ten, lop: s.cua_hien_vat.ten_lop()
  ```
  Biểu thức đại số tương ứng: `Γ_{tac_gia, lop; so = count}( χ_{tac_gia := s.cua_tac_gia.ho_ten, lop := s.cua_hien_vat.ten_lop()}( Extent(SangTac) ) )`.
- **Q8:** đi qua lớp kết hợp: `from t in tat_ca_trien_lam, x in t.gom`, dùng `x.cua_hien_vat`, `x.vi_tri`. Đại số: `μ_{x : t.gom}` thay cho `μ_{h : t.hien_vat}`.
- **Q9:** viết gọn: `count(select distinct s.cua_hien_vat.ten_lop() from s in tg.sang_tac) >= 2`.
- **Q13:** thêm túi `con_dau`. Sắc phong có `{Sắc mệnh chi bảo, Sắc mệnh chi bảo}` (2 phần tử, 1 giá trị), là minh chứng cho bag. Số từ khóa khác nhau: **24**.
- Ghi chú quy ước: `cac_chat_lieu()` đếm theo **nút** (9 phần tử), `tong_thanh_phan()` đếm theo **số lượng** (12); `tuoi()` tính theo cận dưới.

**7.2.6 – đổi tên thành "SQL nhúng và lập trình qua API".** Viết thành hai đoạn:
- **(a) SQL nhúng thực sự bằng ECPG** (`scripts/10_ecpg_demo.pgc`):
  - con trỏ `DECLARE c_tai_lieu CURSOR`, `FETCH … INTO :bien_chu`;
  - `SELECT … INTO`, `CALL` thủ tục, đọc `sqlca.sqlcode`;
  - trích 15–20 dòng code và kết quả `results/10_ecpg_output.txt`. Lần gọi thứ hai bị từ chối với `sqlcode = -400`, thông báo "PhongDaDay".
- **(b) API gọi hàm (SQL/CLI) bằng psycopg2** (`scripts/10_api_cursor.py`):
  - con trỏ phía server, `UPDATE … WHERE CURRENT OF`;
  - kiểu phức hợp được ánh xạ thành namedtuple;
  - tham số tách khỏi câu lệnh, nên chuỗi độc hại trả 0 dòng.
- Thêm một câu phân biệt hai cách theo Elmasri chương 10.

**7.3 – thay bảng K3** bằng bảng 4 cơ chế, mỗi cơ chế lặp 10 lần (`results/07_transaction_output.txt`):

| Kịch bản | Cơ chế | Vi phạm R12 | Số lần thử lại | Phiên 2 tổng (ms) | Kết cục phiên 2 |
|---|---|---|---|---|---|
| K3a | READ COMMITTED, không khóa | 10/10 | 0 | ≈1.020 | COMMIT → phòng 3/2 |
| K3b | READ COMMITTED + `SELECT … FOR UPDATE` | 0/10 | 0 | ≈1.820 (chờ khóa ≈0,8 s) | Từ chối nghiệp vụ |
| K3c | SERIALIZABLE, thử lại khi 40001 | 0/10 | 10 | ≈2.040 | Lỗi 40001, thử lại, từ chối |
| K3d | REPEATABLE READ, không khóa | 10/10 | 0 | ≈1.020 | COMMIT → phòng 3/2 |

Nhận xét nên viết: K3d chứng minh lỗi là **write skew** theo nghĩa chặt. Hai snapshot cùng đọc số đếm 1 rồi ghi hai dòng khác nhau, không có xung đột ghi, nên snapshot isolation (REPEATABLE READ của PostgreSQL) không chặn được. Chỉ khóa tường minh hoặc SSI (SERIALIZABLE) giữ đúng R12.

- **K1, K2, K2b:** giữ nguyên nội dung; số liệu khớp.
- **K4:** phiên 2 bị chặn khoảng 800 ms rồi nhận lỗi `dinh_danh_hien_vat_ma_hv_key`; còn đúng 1 đối tượng.

## 7. Chương 8

**8.1:**
- Dữ liệu mẫu: 9 hiện vật, 10 thành phần, 33 ảnh + 3 video.
- Dữ liệu thực nghiệm: 60.000 hiện vật, 225.000 thành phần, 120.000 liên kết tác giả, 239.997 ảnh, 6.000 video.
- **Dung lượng: A 156 MB, B 232 MB** (số cũ "đều khoảng 109 MB" là sai).
- Cách đo đọc: 3 vòng × 6 lần (bỏ lần làm nóng). Ghi (P12): thời gian phía client, gồm cả kiểm tra ràng buộc trì hoãn, rồi ROLLBACK.

**8.2:** bảng ca kiểm thử mới **V1–V2, T1–T20**, kết quả **20/20 đạt** (`results/03_tests_output.txt`). Ca mới:
- T15: set không trùng;
- T16: video không làm ảnh đại diện;
- T17–T19: phương án B (toàn phần, không giao);
- T20: R12 trong một phiên.

**8.3 – thay bảng** (`results/12_schema_metrics_output.txt`, đếm trên toàn schema):

| Chỉ số | A – quan hệ–đối tượng | B – quan hệ thuần |
|---|---|---|
| Bảng | 18 | 23 |
| Cột khai báo (không tính cột kế thừa) | 82 | 105 |
| PK / FK / UNIQUE / CHECK | 16 / 20 / 6 / 15 | 23 / 23 / 5 / 24 |
| Chỉ mục phụ | 22 | 13 |
| Trigger | 9 | 2 |
| Kiểu tự định nghĩa | 4 | 0 |
| Hàm / thủ tục (không tính công cụ chép dữ liệu) | 15 | 2 |
| Dòng DDL cả tệp | 489 | 233 |

Câu kết luận cũ "ít hơn 3 bảng và 15 cột" đổi thành **"ít hơn 5 bảng và 23 cột"**. B có 2 trigger (toàn phần và cây thành phần), không phải 0.

**8.5 – thay bảng hiệu năng** (`results/bench_output.txt`; B ÷ A > 1 nghĩa là A nhanh hơn):

| Mã | Phép đo | A (ms) | B (ms) | B ÷ A |
|---|---|---|---|---|
| P1 | Đa hình, chỉ thuộc tính chung | 9,93 | 6,00 | 0,60 |
| P2 | Đối tượng đầy đủ, đa hình | 12,52 | 42,40 | 3,39 |
| P3 | Lớp con + thuộc tính riêng (Q2) | 0,99 | 8,03 | 8,07 |
| P4 | Niên đại giao 1900–1950 (Q3) | 8,44 | 5,02 | 0,59 |
| P5 | Cây thành phần (Q4) | 0,03 | 0,03 | 1,00 |
| P6 | Tác giả × lớp (Q5) | 70,32 | 58,53 | 0,83 |
| P7 | Trên 3 ảnh và có video (Q6) | 129,72 | 109,37 | 0,84 |
| P8 | Mô tả đa hình, hàm từng dòng | 643,20 | 49,68 | 0,08 |
| P9 | Mô tả đa hình, theo tập hợp (so B của P8) | 28,70 | 49,68 | 1,73 |
| P10 | Tìm theo từ khóa (mảng + GIN) | 3,95 | 7,31 | 1,85 |
| P11 | Ảnh theo EXIF (JSONB + GIN) | 39,26 | 51,17 | 1,30 |
| P12 | Chèn 5.000 tranh (ghi) | 202,01 | 240,47 | 1,19 |

**Các kết luận phải sửa so với báo cáo cũ:**
1. Đọc đối tượng có thuộc tính lớp con: A nhanh gấp **3,4–8,1 lần** (P2, P3).
2. Chỉ cần thuộc tính chung (P1, P4): **B nhanh hơn khoảng 40%**. A phải quét 3 bảng con rộng hơn; ở P4 có bảng con còn chọn quét tuần tự (xem bảng 6.10b). Câu cũ "P4–P7 chênh dưới 15%" **không còn đúng**.
3. Gom nhóm có kết nối (P6, P7): B nhanh hơn khoảng 16–17%. B gom theo cột `loai`, còn A gom theo `tableoid` qua `Append`.
4. Phương thức đa hình từng dòng chậm gấp **13 lần** (P8). Viết theo tập hợp (P9) thì A nhanh gấp 1,7 lần.
5. JSONB + GIN (P11) **nhanh hơn** bảng khóa–giá trị 1,3 lần. Kết luận cũ "JSONB chậm hơn 20%" **ngược với số đo mới**.
6. Ghi (P12): A **nhanh hơn** khoảng 16% khi B được cài đủ ràng buộc toàn phần và phải chèn thêm bảng từ khóa. Kết luận cũ "A ghi chậm hơn 30%" **không còn đúng**: phép so sánh cũ chưa công bằng vì B chưa có ràng buộc toàn phần.

**8.6 – thay bảng** (`results/09_impedance_output.txt`):

| Cách nạp | Lượt gọi/đối tượng | Thời gian 500 đối tượng (ms) | Dòng mã ánh xạ |
|---|---|---|---|
| B – quan hệ thuần | 5 | 315 | 14 |
| A – quan hệ–đối tượng | 4 | 343 | 12 |
| A1 – JSON lồng | 1 | 352 | 19 |

- Khứ hồi đo được: 0,054 ms. Khi client và server cùng máy, B còn hơi nhanh hơn, vì chi phí dựng JSON và phân tích kiểu phức hợp lớn hơn chi phí mạng gần như bằng 0.
- Phần **ước tính lý thuyết** giữ nguyên: với khứ hồi 1 ms, riêng chi phí mạng là 2,5 s / 2,0 s / 0,5 s. Cả ba cách được kiểm tra cho ra cùng 500 đối tượng.

**8.8, Tóm tắt, Abstract, 9.1:** cập nhật theo các số trên (16 lớp; 20/20 ca; 3,4–8,1×; 13×; ghi nhanh hơn 16%; 4 cơ chế K3).

**8.9 – thêm hạn chế:** chỉ có một cấu hình phần cứng; mỗi kịch bản K3 chỉ có 2 phiên.

## 8. Phụ lục B

- Thay bằng nội dung `README.md`, kèm **link GitHub**.
- Danh sách tệp mới: `03_tests` (T1–T20), `10_ecpg_demo.pgc`, `10_api_cursor.py`, `11_index_eval.py`, `12_schema_metrics.sql`, `chay_tat_ca.sh`.
