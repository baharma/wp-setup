# MySQL bersama

Satu MySQL 8.4 untuk semua aplikasi di VPS: WordPress, Laravel, atau apa pun
yang butuh MySQL. Aplikasi baru tidak deploy MySQL sendiri; cukup buat database
di sini dan sambungkan ke network `mysql_shared`.

```
~/mysql/          MySQL bersama (deploy sekali)
~/wp-blog/        WordPress  -> database wp_blog
~/laravel-toko/   Laravel    -> database laravel_toko
```

| File | Fungsi |
|---|---|
| `docker-compose.yml` | Service `mysql`, network internal `mysql_shared`, tanpa port ke host |
| `config/my.cnf` | Binary log dan performance schema mati, buffer pool 256 MB |
| `setup.sh` | Buat `.env` dan password root acak di `secrets/` |
| `create-db.sh` | Buat database + user untuk satu aplikasi |

## Pasang (sekali)

```bash
cd ~/mysql && chmod +x setup.sh create-db.sh && ./setup.sh && docker compose up -d
```

Tunggu sampai `docker compose ps` menunjukkan `healthy`.

## Tambah database untuk aplikasi baru

```bash
~/mysql/create-db.sh <nama_database> <file-password>
```

Nama user MySQL sama dengan nama database, dan user itu hanya bisa mengakses
database tersebut. Password dibuat acak dan disimpan di file yang kamu tentukan.

## Menyambungkan aplikasi

Aplikasi harus jalan di Docker dan ikut network `mysql_shared`. Host database-nya
`mysql`, port `3306`.

### WordPress

Sudah otomatis lewat `setup.sh` di template `../wordpress`.

### Laravel

1. Buat database:

   ```bash
   ~/mysql/create-db.sh laravel_toko ~/laravel-toko/secrets/db_password.txt
   ```

2. Di `docker-compose.yml` Laravel, sambungkan service aplikasinya ke network
   bersama. Tetap pakai network `default` supaya aplikasi bisa akses internet:

   ```yaml
   services:
     app:
       # ...image/build Laravel kamu...
       networks:
         - default
         - mysql

   networks:
     default: {}
     mysql:
       name: mysql_shared
       external: true
   ```

3. Di `.env` Laravel:

   ```dotenv
   DB_CONNECTION=mysql
   DB_HOST=mysql
   DB_PORT=3306
   DB_DATABASE=laravel_toko
   DB_USERNAME=laravel_toko
   DB_PASSWORD=<isi dari ~/laravel-toko/secrets/db_password.txt>
   ```

   Laravel membaca password dari `.env`, jadi salin isinya ke sana dan pastikan
   `.env` itu `chmod 600`.

4. Jalankan migrasi dari container aplikasi:

   ```bash
   docker compose exec app php artisan migrate --force
   ```

Jangan tambahkan service `mysql` lagi di compose Laravel.

### Aplikasi yang tidak jalan di Docker

Buka baris `ports` yang dikomentari di `docker-compose.yml` (`127.0.0.1:3306`),
lalu `docker compose up -d`. Aplikasi di host memakai `DB_HOST=127.0.0.1`.
Port tetap hanya bisa diakses dari dalam VPS.

## Perintah berguna

Konsol MySQL sebagai root:

```bash
cd ~/mysql && docker compose exec mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql -uroot'
```

Lihat semua database:

```bash
cd ~/mysql && docker compose exec mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql -uroot -e "SHOW DATABASES;"'
```

Backup satu database:

```bash
cd ~/mysql && docker compose exec -T mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysqldump -uroot --single-transaction laravel_toko' | gzip > ~/laravel_toko-$(date +%F).sql.gz
```

Kalau aplikasinya makin banyak dan terasa lambat, naikkan `innodb-buffer-pool-size`
di `config/my.cnf` (dan `mem_limit` di compose), lalu `docker compose up -d`.

## Catatan

- Setup read-only dan pembatasan capability belum dites di server. Kalau container
  gagal start, cek `docker compose logs --tail=50`.
- Simpan isi `secrets/` di tempat aman. Tanpa password root, database tidak bisa
  dikelola.
- Postgres untuk BE undangan (`be-undangan-postgres-1`) terpisah dan tidak terpengaruh.
