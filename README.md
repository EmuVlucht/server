# 🐙 Gitea on Railway - Private Git Server

Private Git server berbasis [Gitea](https://gitea.io) yang dioptimalkan untuk deployment di [Railway](https://railway.app) dengan focus pada reliability dan data persistence.

## ✨ Fitur

- ✅ **Self-hosted Git** - Full git server dengan web UI
- ✅ **Lightweight** - ~100MB memory, cocok untuk Railway free tier
- ✅ **Persistent Storage** - Data aman walau Railway sleep/restart
- ✅ **SSH & HTTPS** - Support clone/push via SSH (port 2222) dan HTTPS
- ✅ **No External DB** - SQLite by default (upgrade ke PostgreSQL kapan saja)
- ✅ **Recovery Ready** - Comprehensive recovery guides dan scripts

## 📋 Persyaratan

- Railway account ([free tier](https://railway.app) OK)
- Railroad CLI: `npm install -g @railway/cli`
- Docker (untuk testing lokal)
- Git (untuk push/pull)

## 🚀 Quick Start (5 menit)

### 1. Generate Secrets
```bash
SECRET=$(openssl rand -hex 16)
TOKEN=$(openssl rand -hex 20)
echo "SECRET_KEY=$SECRET"
echo "INTERNAL_TOKEN=$TOKEN"
```

### 2. Deploy ke Railway
```bash
railway login
railway init --name gitea-server

# Set variables (pakai nilai dari step 1)
railway variables set SECRET_KEY="$SECRET"
railway variables set INTERNAL_TOKEN="$TOKEN"
railway variables set GITEA_ADMIN_USER="admin"
railway variables set GITEA_ADMIN_PASSWORD="YourStrongPassword123!"
railway variables set GITEA_ADMIN_EMAIL="admin@example.com"

# Add persistent volumes
railway volume add gitea-data --mount /var/lib/gitea/data --size 1
railway volume add gitea-repos --mount /var/lib/gitea/repositories --size 2

# Deploy
railway up
```

### 3. Akses Gitea
```bash
# Get URL
GITEA_URL=$(railway status --json | jq -r '.services[0].url')

# Open di browser
echo $GITEA_URL

# Login dengan credentials di step 2
```

## 📚 Dokumentasi Lengkap

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Panduan deployment step-by-step
- **[RECOVERY.md](RECOVERY.md)** - Skenario recovery dan troubleshooting
- **[VERIFICATION.md](VERIFICATION.md)** - Checklist verifikasi setup

## 🏗️ Project Structure

```
.
├── Dockerfile              # Image definition (Gitea 1.21.5)
├── entrypoint.sh          # Custom entrypoint dengan auto-setup
├── app.ini                # Konfigurasi Gitea production-ready
├── railway.json           # Railway deployment config
├── docker-compose.yml     # Local development setup
├── setup.sh               # Setup script untuk initial config
├── start.sh               # Quick deploy helper
├── .env.example           # Template environment variables
├── .env.local             # Local env (git ignored)
├── DEPLOYMENT.md          # Deployment guide
├── RECOVERY.md            # Recovery procedures
├── VERIFICATION.md        # Verification checklist
└── README.md              # This file
```

## 🔧 Konfigurasi

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SECRET_KEY` | ✅ | - | 32-char secret untuk security |
| `INTERNAL_TOKEN` | ✅ | - | 40-char internal token |
| `GITEA_ADMIN_USER` | ✅ | admin | Username admin |
| `GITEA_ADMIN_PASSWORD` | ✅ | - | Password admin (min 8 chars) |
| `GITEA_ADMIN_EMAIL` | ✅ | - | Email admin |
| `INITIAL_REPO_NAME` | ❌ | - | Repository awal (auto-create) |
| `DOMAIN` | ❌ | auto | Custom domain |
| `PROTOCOL` | ❌ | https | Protocol (http/https) |

### Storage

Di `app.ini`:
- **Database**: SQLite di `/var/lib/gitea/data/gitea.db`
- **Repositories**: `/var/lib/gitea/repositories`
- **Logs**: `/var/lib/gitea/log`

Dapat diupgrade ke PostgreSQL tanpa downtime.

## 🔐 Security

✅ **Best Practices:**
- Secrets dikelola via Railway environment variables
- INSTALL_LOCK enabled (prevent unauthorized setup)
- Password hashing dengan PBKDF2
- SSH key-based auth support
- CORS disabled by default

❌ **Jangan lupa:**
- [ ] Ganti admin password default
- [ ] Enable 2FA di user settings
- [ ] Review access control per repository
- [ ] Regular backup volumes
- [ ] Use strong, unique SSH keys

## 📊 Performance

| Metric | Value |
|--------|-------|
| Memory Usage | ~100-200MB |
| Disk Space | ~1-2GB (small repos) |
| Container Startup | ~10-15 seconds |
| First Request | ~500ms (cold start) |
| Concurrent Users | 10-50 (free tier) |

## 🔄 Development Lokal

```bash
# Setup lokal dengan docker-compose
cp .env.example .env.local
nano .env.local  # Edit credentials

# Build dan run
docker-compose build
docker-compose up -d

# Access di http://localhost:3000
# Admin login: admin / admin123!

# View logs
docker-compose logs -f gitea

# Stop
docker-compose down

# Cleanup (termasuk volumes)
docker-compose down -v
```

## 🚨 Troubleshooting Cepat

### Container Crash
```bash
railway logs | tail -50  # Lihat error
railway restart          # Restart container
```

### Cannot Clone/Push
```bash
# Test HTTPS
git clone https://admin:password@$GITEA_URL/admin/test.git

# Test SSH
ssh -T git@$GITEA_URL -p 2222

# Cek firewall/network
```

### Data Hilang
```bash
# Verifikasi volume mounted
railway volume list

# Restore dari backup
railway volume restore gitea-data --backup-id [id]

# Lihat RECOVERY.md untuk langkah lengkap
```

Lihat **[RECOVERY.md](RECOVERY.md)** untuk troubleshooting komprehensif.

## 📈 Next Steps

1. **Setup SSH Keys** (opsional)
   ```bash
   ssh-keygen -t ed25519 -C "your@email.com"
   # Upload public key ke Gitea Settings → SSH/GPG Keys
   ```

2. **Enable 2FA** (recommended)
   - Gitea Web UI → Settings → Security → Two-Factor Authentication

3. **Setup Custom Domain** (opsional)
   - Railway Dashboard → Project → Settings → Domains
   - Update DNS records sesuai instruksi

4. **CI/CD Integration** (opsional)
   - Setup Gitea Actions
   - Integrate dengan GitHub Actions, etc

5. **Backup Strategy**
   ```bash
   # Weekly backup
   railway volume backup gitea-data
   railway volume backup gitea-repos
   ```

## 📞 Support

- **Gitea Docs**: https://docs.gitea.io
- **Railway Docs**: https://docs.railway.app
- **Issues**: Buat issue di repository ini

## 📝 Changelog

### v1.0 (2024)
- Initial release dengan Gitea 1.21.5
- Railway-optimized configuration
- Comprehensive recovery guides
- SQLite default database
- SSH + HTTPS support

## 📄 License

MIT License - Feel free to use dan modify

---

**Made with ❤️ for Railway** | [Gitea Project](https://gitea.io)
