#!/usr/bin/env sh
# Sekali jalan: buat .env dan password root acak. Aman dijalankan ulang;
# file yang sudah ada tidak ditimpa.
set -eu
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  cp .env.example .env
  chmod 600 .env
  echo "Dibuat: .env"
else
  echo "Lewati: .env sudah ada"
fi

mkdir -p secrets
chmod 700 secrets
f=secrets/mysql_root_password.txt
if [ ! -s "$f" ]; then
  openssl rand -hex 24 | tr -d '\n' > "$f"
  echo "Dibuat: $f"
else
  echo "Lewati: $f sudah ada"
fi
# Dibaca user mysql di dalam container; folder secrets/ tetap 700 di host.
chmod 644 "$f"

echo
echo "Jalankan: docker compose up -d"
