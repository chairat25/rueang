#!/bin/bash
set -e

PORT=55432
DATA=$(mktemp -d)/pgdata
LOG="/tmp/pg_rueang_test.log"

cleanup() {
  echo "Stopping temporary PostgreSQL..."
  pg_ctl -D "$DATA" stop -m immediate >/dev/null 2>&1 || true
  rm -rf "$DATA" "$LOG"
}
trap cleanup EXIT

echo "Initializing temporary Postgres database in $DATA..."
initdb -D "$DATA" -U postgres --auth=trust --no-instructions >/dev/null

echo "Starting temporary Postgres on port $PORT..."
pg_ctl -D "$DATA" -o "-p $PORT -h 127.0.0.1 -c unix_socket_directories=''" -l "$LOG" start >/dev/null

PSQL="psql -h 127.0.0.1 -p $PORT -U postgres"

echo "Creating rueang_test database..."
$PSQL -c "CREATE DATABASE rueang_test;" >/dev/null
$PSQL -d rueang_test -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" >/dev/null

echo "Applying stub and migrations..."
for f in supabase/tests/00_stub_supabase.sql supabase/migrations/0001_core.sql supabase/migrations/0002_travel_kit.sql supabase/migrations/0003_rls.sql; do
  $PSQL -d rueang_test -v ON_ERROR_STOP=1 -q -f "$f"
  echo "  ✅ Applied $f"
done

echo "Running 01_schema_smoke.sql..."
$PSQL -d rueang_test -f supabase/tests/01_schema_smoke.sql

echo "Running 02_rls.sql..."
$PSQL -d rueang_test -f supabase/tests/02_rls.sql

echo "🎉 All database and RLS schema tests executed successfully!"
