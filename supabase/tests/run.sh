#!/usr/bin/env bash
# Recria um banco de teste local, aplica as migrations e roda os testes.
set -euo pipefail
PSQL="psql -h ${PGHOST:-/tmp} -p ${PGPORT:-54322} -U postgres -v ON_ERROR_STOP=1 -q"
cd "$(dirname "$0")/.."
$PSQL -d postgres -c "drop database if exists lc_crm_test" -c "create database lc_crm_test"
$PSQL -d lc_crm_test -f tests/00_supabase_shim.sql
for f in migrations/*.sql; do echo "aplicando $f"; $PSQL -d lc_crm_test -f "$f"; done
$PSQL -d lc_crm_test -f tests/10_regras_test.sql
$PSQL -d lc_crm_test -f tests/20_distribuicao_test.sql
$PSQL -d lc_crm_test -f tests/30_entradas_test.sql
