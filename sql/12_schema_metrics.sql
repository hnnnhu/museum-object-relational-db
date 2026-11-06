-- =====================================================================
-- 12_schema_metrics.sql – Độ phức tạp lược đồ đo từ catalog (mục 8.3), so sánh schema bt (A) và qh (B)
-- Không tính: bảng định danh được tính vào A (là một phần của giải pháp); thủ tục nap_tu_A của B bị loại
-- vì chỉ là công cụ chép dữ liệu phục vụ thực nghiệm.
-- =====================================================================
\pset footer off
WITH s(ten, nsp) AS (VALUES ('A – quan hệ–đối tượng', 'bt'), ('B – quan hệ thuần', 'qh'))
SELECT s.ten AS "Phương án",
  (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = s.nsp AND c.relkind = 'r') AS "Bảng",
  (SELECT count(*) FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = s.nsp AND c.relkind = 'r' AND a.attnum > 0 AND NOT a.attisdropped AND a.attislocal) AS "Cột khai báo",
  (SELECT count(*) FROM pg_constraint k JOIN pg_namespace n ON n.oid = k.connamespace
   WHERE n.nspname = s.nsp AND k.contype = 'p') AS "PK",
  (SELECT count(*) FROM pg_constraint k JOIN pg_namespace n ON n.oid = k.connamespace
   WHERE n.nspname = s.nsp AND k.contype = 'f') AS "FK",
  (SELECT count(*) FROM pg_constraint k JOIN pg_namespace n ON n.oid = k.connamespace
   WHERE n.nspname = s.nsp AND k.contype = 'u') AS "UNIQUE",
  (SELECT count(*) FROM pg_constraint k JOIN pg_namespace n ON n.oid = k.connamespace
   WHERE n.nspname = s.nsp AND k.contype = 'c' AND k.conislocal AND k.conrelid <> 0) AS "CHECK",
  (SELECT count(*) FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = s.nsp AND NOT i.indisprimary
     AND NOT EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conindid = i.indexrelid AND k.contype = 'u')) AS "Chỉ mục phụ",
  (SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = s.nsp AND NOT t.tgisinternal) AS "Trigger",
  (SELECT count(*) FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
   WHERE n.nspname = s.nsp AND (t.typtype IN ('d', 'e') OR (t.typtype = 'c' AND EXISTS
         (SELECT 1 FROM pg_class c WHERE c.oid = t.typrelid AND c.relkind = 'c')))) AS "Kiểu tự định nghĩa",
  (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = s.nsp AND p.proname <> 'nap_tu_a') AS "Hàm/thủ tục"
FROM s;
