# WordPress di VPS

WordPress + MariaDB di Docker, diakses lewat Cloudflare Tunnel `server-baharma`
sebagai `https://wp.baharma.my.id`. Tidak ada port yang terbuka ke internet.

## Isi folder

| File | Fungsi |
|---|---|
| `docker-compose.yml` | Service `db` (MariaDB 11.4) dan `wordpress` (PHP 8.3 + Apache) |
| `.env.example` | Contoh konfigurasi tanpa password |
| `setup.sh` | Membuat `.env` dan password acak di `secrets/` |
| `config/php.ini` | Hardening PHP + batas upload 64 MB |
| `config/apache-security.conf` | Header keamanan, blok XML-RPC, blok PHP di folder upload |

`.env` dan `secrets/` dibuat di server dan tidak boleh di-commit (sudah ada di `.gitignore`).

## Keamanan yang dipasang

- Port WordPress hanya di `127.0.0.1:8090`; satu-satunya jalan masuk adalah tunnel.
- MariaDB di network `internal`: tanpa port, tanpa akses internet, hanya bisa diakses WordPress.
- Password dibaca dari file (`*_FILE`), tidak muncul di `docker inspect` atau env.
- Container read-only, semua capability Linux dibuang kecuali yang wajib, `no-new-privileges`.
- Batas RAM (db 384 MB, wordpress 512 MB) dan PID, supaya BE dan CMS tetap aman.
- Prefix tabel acak, editor tema/plugin di wp-admin dimatikan, auto-update minor core aktif.
- Log dibatasi 3 × 10 MB per container.

## Pasang di VPS

1. Salin folder ini ke VPS (dari laptop, lewat Tailscale):

   ```bash
   scp -r wordpress ubuntu@<host-vps>:~/
   ```

2. Di VPS, buat `.env` dan password:

   ```bash
   cd ~/wordpress && chmod +x setup.sh && ./setup.sh
   ```

   Ubah `WP_DOMAIN` di `.env` kalau tidak memakai `wp.baharma.my.id`.

3. Jalankan:

   ```bash
   docker compose up -d && docker compose ps
   ```

   Tunggu `db` dan `wordpress` sampai `healthy` (sekitar 1 menit di run pertama).

4. Tes dari VPS:

   ```bash
   curl -I http://127.0.0.1:8090
   ```

   Hasil `302` ke `/wp-admin/install.php` berarti siap.

5. Di Cloudflare Zero Trust → Networks → Tunnels → `server-baharma` →
   **Published application routes** → Add: subdomain `wp`, domain `baharma.my.id`,
   type `HTTP`, URL `localhost:8090`.

6. Buka `https://wp.baharma.my.id` dan selesaikan instalasi. Pakai username selain
   `admin` dan password yang kuat.

## Kalau container tidak mau start

Lihat lognya:

```bash
docker compose logs --tail=50 db wordpress
```

Setup read-only dan pembatasan capability ini belum dites di server. Kalau log
menyebut `Read-only file system` atau `Operation not permitted`, matikan sementara
`read_only: true` dan `cap_drop`/`cap_add` di service yang error dengan memberi `#`
di depannya, lalu `docker compose up -d` lagi dan kirim lognya untuk diperbaiki.

## Setelah instalasi

- Pasang plugin pembatas login (misalnya Limit Login Attempts Reloaded) dan aktifkan 2FA.
- Lindungi `/wp-admin` dengan Zero Trust Access (Access → Applications, path `wp-admin`)
  kalau hanya kamu yang login.
- Hapus tema dan plugin bawaan yang tidak dipakai.

## Backup

Database:

```bash
cd ~/wordpress && docker compose exec -T db sh -c 'mariadb-dump -uroot -p"$(cat /run/secrets/db_root_password)" wordpress' | gzip > wp-db-$(date +%F).sql.gz
```

File (tema, plugin, upload):

```bash
docker run --rm -v wordpress_wp_data:/data:ro -v "$PWD":/backup alpine tar czf /backup/wp-files-$(date +%F).tar.gz -C /data .
```

Simpan juga isi `secrets/` di tempat aman; tanpa itu backup database tidak bisa
dipakai dengan volume yang ada.

## Update

```bash
cd ~/wordpress && docker compose pull && docker compose up -d
```

Data aman di volume `wordpress_db_data` dan `wordpress_wp_data`.
