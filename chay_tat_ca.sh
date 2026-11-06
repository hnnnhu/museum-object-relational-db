#!/usr/bin/env bash
# =====================================================================
# chay_tat_ca.sh – Tái lập TOÀN BỘ kết quả của đồ án từ đầu, trên CSDL mới
# Yêu cầu: PostgreSQL 16, Python 3 + psycopg2, (tùy chọn) ECPG + gcc, Graphviz
# Kết quả ghi vào thư mục results/
# Dùng:  PGPASSWORD=postgres ./chay_tat_ca.sh
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"
export PGHOST=${PGHOST:-localhost} PGUSER=${PGUSER:-postgres} PGPASSWORD=${PGPASSWORD:-postgres}
PSQL="psql -q -v ON_ERROR_STOP=1 -X"
# Windows (Git Bash) thường chỉ có lệnh "python", Linux/macOS có "python3"
PY=$(command -v python3 >/dev/null && python3 -c "import sys" 2>/dev/null && echo python3 || echo python)
export PYTHONIOENCODING=utf-8 PGCLIENTENCODING=UTF8
mkdir -p results

echo "== 1. CSDL mẫu baotang (Chương 6–7) =="
dropdb --if-exists baotang && createdb baotang
$PSQL -d baotang -f sql/01_schema_A.sql -f sql/02_seed.sql -f sql/04_schema_B.sql
$PSQL -d baotang -f sql/03_tests.sql        > results/03_tests_output.txt
$PSQL -d baotang -f sql/06_queries.sql      > results/06_queries_output.txt
$PSQL -d baotang -f sql/08_sql_nang_cao.sql > results/08_sql_nang_cao_output.txt 2>&1
$PY scripts/07_transaction.py           > results/07_transaction_output.txt
$PY scripts/10_api_cursor.py            > results/10_api_cursor_output.txt
if command -v ecpg >/dev/null && command -v gcc >/dev/null; then
  ( tmp=$(mktemp -d); cp scripts/10_ecpg_demo.pgc "$tmp"/; cd "$tmp"
    ecpg 10_ecpg_demo.pgc
    gcc -o ecpg_demo 10_ecpg_demo.c -I"$(pg_config --includedir)" -L"$(pg_config --libdir)" -lecpg
    ./ecpg_demo ) > results/10_ecpg_output.txt
else
  echo "(bỏ qua ECPG: cần cả ecpg và gcc)" > results/10_ecpg_output.txt
fi

echo "== 2. CSDL thực nghiệm bench (Chương 8) =="
dropdb --if-exists bench && createdb bench
$PSQL -d bench -f sql/01_schema_A.sql -f sql/04_schema_B.sql
$PSQL -d bench -v n_tranh=30000 -v n_tuong=15000 -v n_tlc=15000 -f sql/05_generate.sql > results/05_generate_output.txt
$PSQL -d bench -f sql/12_schema_metrics.sql > results/12_schema_metrics_output.txt
$PY scripts/verify_ab.py                > results/verify_ab_output.txt
$PY scripts/bench.py                    > results/bench_output.txt
$PY scripts/11_index_eval.py            > results/11_index_eval_output.txt
$PY scripts/09_impedance.py             > results/09_impedance_output.txt

echo "== 3. Hình vẽ (nếu có Graphviz) =="
if command -v dot >/dev/null; then
  ( cd docs
    dot   -Tpng -Gdpi=110 eer_a_phan_cap.dot -o eer_a_phan_cap.png && dot   -Tsvg eer_a_phan_cap.dot -o eer_a_phan_cap.svg
    neato -Tpng -Gdpi=110 eer_b_lien_ket.dot -o eer_b_lien_ket.png && neato -Tsvg eer_b_lien_ket.dot -o eer_b_lien_ket.svg )
  $PY docs/uml.py
fi
echo "Xong. Xem thư mục results/."
