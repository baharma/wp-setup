#!/usr/bin/env sh
# Buat (atau perbarui) database + user untuk satu aplikasi di MySQL bersama.
#
#   ./create-db.sh <nama-database> <file-password>
#
# Contoh:
#   ./create-db.sh wp_blog ~/wp-blog/secrets/db_password.txt
#   ./create-db.sh laravel_toko ~/laravel-toko/secrets/db_password.txt
#
# User MySQL bernama sama dengan database dan hanya punya hak atas database itu.
# Kalau <file-password> sudah ada, password itu yang dipakai; kalau belum,
# dibuat acak dan disimpan ke sana. Aman dijalankan ulang.
set -eu
cd "$(dirname "$0")"

name="${1:-}"
pwfile="${2:-}"
case "$name" in
  ''|*[!a-z0-9_]*) echo "Nama database wajib, hanya huruf kecil, angka, dan _" >&2; exit 1 ;;
esac
# Batas panjang nama user MySQL.
[ "${#name}" -le 32 ] || { echo "Nama database maksimal 32 karakter" >&2; exit 1; }
[ -n "$pwfile" ] || { echo "Path file password wajib diisi" >&2; exit 1; }

mkdir -p "$(dirname "$pwfile")"
chmod 700 "$(dirname "$pwfile")"
if [ ! -s "$pwfile" ]; then
  openssl rand -hex 24 | tr -d '\n' > "$pwfile"
fi
# Bisa dibaca user di dalam container aplikasi; foldernya tetap 700 di host.
chmod 644 "$pwfile"
pw="$(cat "$pwfile")"

docker compose exec -T mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql -uroot' <<SQL
CREATE DATABASE IF NOT EXISTS \`${name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${name}'@'%' IDENTIFIED BY '${pw}';
ALTER USER '${name}'@'%' IDENTIFIED BY '${pw}';
GRANT ALL PRIVILEGES ON \`${name}\`.* TO '${name}'@'%';
SQL

echo "Siap: database & user ${name}, password di ${pwfile}"
