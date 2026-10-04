# WordPress di VPS

Template satu situs WordPress. Database memakai **MySQL bersama** dari folder
`../mysql`, jadi berapa pun situsnya, MySQL tetap satu. Situs diakses lewat
Cloudflare Tunnel `server-baharma`; tidak ada port yang terbuka ke internet.

```
~/mysql/         MySQL 8.4 bersama (satu untuk semua situs)
~/wp-blog/       situs 1  -> wp_blog,  port 8090, wp.baharma.my.id
~/wp-toko/       situs 2  -> wp_toko,  port 8091, toko.baharma.my.id
```

## Isi folder

| File | Fungsi |
|---|---|
| `docker-compose.yml` | Service `wordpress` (PHP 8.3 + Apache), tersambung ke MySQL bersama |
| `.env.example` | Nama situs, domain, port; tanpa password |
| `setup.sh` | Isi prefix tabel acak, buat database + user di MySQL bersama |
| `config/php.ini` | Hardening PHP, upload maksimal 64 MB |
| `config/apache-security.conf` | Header keamanan, blok XML-RPC, blok PHP di folder upload |

`.env` dan `secrets/` dibuat di server dan tidak boleh di-commit.

## Keamanan yang dipasang

- Port WordPress hanya di `127.0.0.1`; dari internet hanya bisa lewat tunnel.
- MySQL tanpa port, di network internal `mysql_shared` (tanpa akses internet).
- Tiap situs punya user MySQL sendiri yang hanya bisa mengakses database-nya.
- Password dibaca dari file, tidak muncul di `docker inspect` atau env.
- Container read-only, capability minimal, `no-new-privileges`, batas RAM dan PID.
- Binary log dan performance schema MySQL dimatikan (hemat disk dan RAM).
- Prefix tabel acak, editor tema/plugin di wp-admin mati, auto-update minor core aktif.

## Pasang pertama kali

Dari laptop, salin kedua folder ke VPS (lewat Tailscale):

```bash
scp -r mysql wordpress ubuntu@<host-vps>:~/
```

Di VPS:

1. Jalankan MySQL bersama (sekali saja untuk semua situs):

   ```bash
   cd ~/mysql && chmod +x setup.sh create-db.sh && ./setup.sh && docker compose up -d
   ```

   Tunggu sampai `docker compose ps` menunjukkan `healthy` (run pertama sekitar 1 menit).

2. Siapkan situs pertama:

   ```bash
   mv ~/wordpress ~/wp-blog && cd ~/wp-blog && cp .env.example .env
   ```

   Cek isi `.env` (`SITE_NAME`, `WP_DOMAIN`, `WP_PORT`), lalu:

   ```bash
   chmod +x setup.sh && ./setup.sh && docker compose up -d
   ```

3. Tes dari VPS. Hasil `302` ke `/wp-admin/install.php` berarti siap:

   ```bash
   curl -I http://127.0.0.1:8090
   ```

4. Cloudflare Zero Trust → Networks → Tunnels → `server-baharma` →
   **Published application routes** → Add: subdomain `wp`, domain `baharma.my.id`,
   type `HTTP`, URL `localhost:8090`.

5. Buka `https://wp.baharma.my.id` dan selesaikan instalasi. Pakai username selain
   `admin` dan password yang kuat.

## Tambah situs baru

Salin template dari situs yang sudah ada, tanpa `.env` dan `secrets/` miliknya:

```bash
mkdir ~/wp-toko && cd ~/wp-blog && cp -r docker-compose.yml .env.example setup.sh config ~/wp-toko/ && cd ~/wp-toko && cp .env.example .env
```

Ubah `.env`: `COMPOSE_PROJECT_NAME=wp-toko`, `SITE_NAME=toko`, domain baru, dan
`WP_PORT` yang belum dipakai (misalnya 8091). Lalu:

```bash
./setup.sh && docker compose up -d
```

Tambahkan route baru di tunnel ke `localhost:<WP_PORT>`.

## Kalau container tidak mau start

```bash
docker compose logs --tail=50
```

Setup read-only dan pembatasan capability ini belum dites di server. Kalau log
menyebut `Read-only file system` atau `Operation not permitted`, matikan sementara
`read_only: true`, `cap_drop`, dan `cap_add` di service yang error dengan memberi `#`
di depannya, jalankan `docker compose up -d` lagi, dan kirim lognya untuk diperbaiki.

`Error establishing a database connection` biasanya berarti stack `~/mysql` belum
jalan atau `./setup.sh` belum dijalankan untuk situs ini.

## Setelah instalasi

- Pasang plugin pembatas login (misalnya Limit Login Attempts Reloaded) dan aktifkan 2FA.
- Lindungi `/wp-admin` dengan Zero Trust Access kalau hanya kamu yang login.
- Hapus tema dan plugin bawaan yang tidak dipakai.

## Backup

Database satu situs (jalankan dari `~/mysql`):

```bash
cd ~/mysql && docker compose exec -T mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysqldump -uroot --single-transaction wp_blog' | gzip > ~/wp_blog-$(date +%F).sql.gz
```

File situs (tema, plugin, upload). Nama volume = `<COMPOSE_PROJECT_NAME>_wp_data`:

```bash
docker run --rm -v wp-blog_wp_data:/data:ro -v "$HOME":/backup alpine tar czf /backup/wp-blog-files-$(date +%F).tar.gz -C /data .
```

Simpan juga isi `~/mysql/secrets/` dan `secrets/` tiap situs di tempat aman.

## Update

```bash
cd ~/wp-blog && docker compose pull && docker compose up -d
```

MySQL di-update dari `~/mysql` dengan perintah yang sama. Tetap di `mysql:8.4`;
lompat ke versi mayor lain perlu backup dulu.
