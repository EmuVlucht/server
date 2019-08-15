# 🚀 Panduan Deployment Gitea di Railway

## Prasyarat
- Railway Account (free tier cukup untuk mulai)
- Railway CLI terinstall: `npm install -g @railway/cli`
- Docker Desktop (untuk testing lokal)

## Langkah 1: Generate Secret Keys

```bash
# Generate SECRET_KEY
SECRET=$(openssl rand -hex 16)
echo "SECRET_KEY=$SECRET"

# Generate INTERNAL_TOKEN
TOKEN=$(openssl rand -hex 20)
echo "INTERNAL_TOKEN=$TOKEN"

# Simpan kedua nilai ini, akan digunakan di langkah berikutnya
```

## Langkah 2: Siapkan Environment Variables

```bash
# Copy template dan isi
cp .env.example .env.local

# Edit .env.local dengan editor favorit
nano .env.local

# Isi nilai:
# - SECRET_KEY: hasil dari Langkah 1
# - INTERNAL_TOKEN: hasil dari Langkah 1
# - GITEA_ADMIN_USER: username admin (default: admin)
# - GITEA_ADMIN_PASSWORD: password kuat (minimal 8 karakter)
# - GITEA_ADMIN_EMAIL: email valid
```

## Langkah 3: Test Lokal dengan Docker Compose

```bash
# Build image
docker-compose build

# Jalankan
docker-compose up -d

# Cek status
docker-compose ps

# Lihat logs
docker-compose logs -f gitea

# Akses di: http://localhost:3000
# Username: admin
# Password: sesuai GITEA_ADMIN_PASSWORD di .env.local
```

## Langkah 4: Deploy ke Railway

```bash
# 1. Login ke Railway
railway login

# 2. Inisialisasi project baru atau link ke existing
railway init --name "gitea-server"

# Jika project sudah ada:
# railway link <project-id>

# 3. Set environment variables dari .env.local
railway variables set SECRET_KEY="$(grep SECRET_KEY .env.local | cut -d= -f2)"
railway variables set INTERNAL_TOKEN="$(grep INTERNAL_TOKEN .env.local | cut -d= -f2)"
railway variables set GITEA_ADMIN_USER="$(grep GITEA_ADMIN_USER .env.local | cut -d= -f2)"
railway variables set GITEA_ADMIN_PASSWORD="$(grep GITEA_ADMIN_PASSWORD .env.local | cut -d= -f2)"
railway variables set GITEA_ADMIN_EMAIL="$(grep GITEA_ADMIN_EMAIL .env.local | cut -d= -f2)"
railway variables set INITIAL_REPO_NAME="my-first-repo"

# 4. Tambahkan volume untuk persistent storage
railway volume add gitea-data --mount /var/lib/gitea/data --size 1
railway volume add gitea-repos --mount /var/lib/gitea/repositories --size 2
railway volume add gitea-logs --mount /var/lib/gitea/log --size 0.5

# 5. Deploy
railway up
```

## Langkah 5: Akses dan Konfigurasi

```bash
# Dapatkan URL Gitea
GITEA_URL=$(railway status --json | jq -r '.services[0].url')
echo "Gitea URL: $GITEA_URL"

# Login dengan admin credentials
# Buka di browser: $GITEA_URL
# Username: admin
# Password: sesuai yang di-set di .env.local
```

## Langkah 6: Tambahkan Custom Domain (Opsional)

Di Railway Dashboard:
1. Buka Project → Settings → Domains
2. Tambahkan domain custom (eg. gitea.example.com)
3. Update DNS records sesuai instruksi Railway
4. Update app.ini dengan DOMAIN baru:
   ```
   railway variables set DOMAIN="gitea.example.com"
   ```

## Langkah 7: Setup SSH Keys (Opsional)

```bash
# Generate SSH key jika belum ada
ssh-keygen -t ed25519 -C "your-email@example.com"

# Di Gitea Web UI:
# 1. Login → Settings → SSH/GPG Keys
# 2. Add Key
# 3. Paste isi ~/.ssh/id_ed25519.pub

# Test SSH connection
ssh -T git@$GITEA_URL -p 2222
```

## Troubleshooting Deployment

### Container Gagal Start
```bash
# Cek logs
railway logs

# Cek environment variables
railway variables

# Restart container
railway restart
```

### Web UI Tidak Bisa Diakses
```bash
# Cek health status
curl https://[your-railway-url]/api/healthz

# Cek firewall/proxy settings di Railway
railway status --json | jq
```

### SSH Connection Fails
```bash
# Edit ~/.ssh/config
Host railway-gitea
  HostName [your-railway-url]
  Port 2222
  User git
  IdentityFile ~/.ssh/id_ed25519

# Test
ssh -vvv -T railway-gitea
```

### Data Loss pada Railway Sleep
- Railway free tier auto-sleep setelah 5 menit idle
- Volume persistent menjaga data tetap aman
- Container restart otomatis saat ada request (butuh ~30s)
- Upgrade ke paid plan untuk always-on

## Scaling & Optimization

### Memory Usage Tinggi
```bash
# Di Railway Dashboard → Deployment Settings
# Set memory limit ke 512MB (default 1GB)
```

### Backup Strategy
```bash
# Backup volume gitea-data
railway volume backup gitea-data

# Restore dari backup
railway volume restore gitea-data
```

### Database Migration (Future)
Jika perlu migrasi dari SQLite ke PostgreSQL:

```bash
# 1. Buat PostgreSQL di Railway
# 2. Update env vars:
railway variables set DB_TYPE="postgres"
railway variables set DB_HOST="[postgres-url]"
railway variables set DB_USER="postgres"
railway variables set DB_PASSWORD="[password]"

# 3. Uncomment database section di app.ini
# 4. Restart container
railway restart
```

## Next Steps

1. ✅ Deploy selesai
2. Buat repository pertama: di Web UI → Create Repository
3. Setup SSH keys untuk push/pull via SSH
4. Enable 2FA: Settings → Security → Two-Factor Authentication
5. Review akses control dan permissions per repository

Untuk dokumentasi lengkap Gitea: https://docs.gitea.io
