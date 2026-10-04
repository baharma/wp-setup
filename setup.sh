#!/usr/bin/env sh
# Sekali jalan: buat .env dan password acak. Aman dijalankan ulang;
# file yang sudah ada tidak ditimpa (password lama tetap dipakai DB).
set -eu
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  prefix="wp_$(openssl rand -hex 3)_"
  sed "s/^WP_TABLE_PREFIX=.*/WP_TABLE_PREFIX=${prefix}/" .env.example > .env
  chmod 600 .env
  echo "Dibuat: .env (prefix tabel ${prefix})"
else
  echo "Lewati: .env sudah ada"
fi

mkdir -p secrets
chmod 700 secrets
for name in db_password db_root_password; do
  f="secrets/${name}.txt"
  if [ ! -s "$f" ]; then
    openssl rand -hex 24 | tr -d '\n' > "$f"
    echo "Dibuat: $f"
  else
    echo "Lewati: $f sudah ada"
  fi
  # Dibaca oleh user di dalam container (mysql/www-data); folder secrets/
  # tetap 700 sehingga user lain di host tidak bisa masuk.
  chmod 644 "$f"
done

echo
echo "Cek WP_DOMAIN di .env, lalu jalankan: docker compose up -d"
