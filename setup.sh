#!/usr/bin/env sh
# Siapkan satu situs: isi prefix tabel, lalu buat database + user di MySQL
# bersama. Butuh .env (salin dari .env.example) dan stack ../mysql sudah jalan.
# Aman dijalankan ulang.
set -eu
cd "$(dirname "$0")"

MYSQL_DIR="${MYSQL_DIR:-$HOME/mysql}"

if [ ! -f .env ]; then
  echo "Belum ada .env. Jalankan: cp .env.example .env, sesuaikan isinya, lalu ./setup.sh lagi." >&2
  exit 1
fi
chmod 600 .env

if grep -q '^WP_TABLE_PREFIX=$' .env; then
  prefix="wp_$(openssl rand -hex 3)_"
  sed -i.bak "s/^WP_TABLE_PREFIX=$/WP_TABLE_PREFIX=${prefix}/" .env && rm -f .env.bak
  echo "Prefix tabel: ${prefix}"
fi

site="$(sed -n 's/^SITE_NAME=//p' .env)"
[ -x "$MYSQL_DIR/create-db.sh" ] || { echo "Tidak ketemu $MYSQL_DIR/create-db.sh (set MYSQL_DIR kalau lokasinya lain)" >&2; exit 1; }

"$MYSQL_DIR/create-db.sh" "wp_${site}" "$PWD/secrets/db_password.txt"

echo
echo "Jalankan: docker compose up -d"
