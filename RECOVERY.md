# 🔧 Panduan Recovery Gitea

## Skenario 1: Container Gagal Start

### Diagnosis
```bash
# Cek logs
railway logs | tail -50

# Cek status container
railway status

# Cek environment variables
railway variables
```

### Penyebab Umum & Solusi

**Penyebab: Secret keys tidak valid**
```bash
# Solusi: Regenerate dengan format yang benar
railway variables set SECRET_KEY="$(openssl rand -hex 16)"
railway variables set INTERNAL_TOKEN="$(openssl rand -hex 20)"

# Restart
railway restart
```

**Penyebab: Volume tidak mounted**
```bash
# Cek volume attachment
railway volume list

# Jika ada volume yang tidak mounted:
railway volume attach gitea-data --mount /var/lib/gitea/data
railway volume attach gitea-repos --mount /var/lib/gitea/repositories
railway volume attach gitea-logs --mount /var/lib/gitea/log

# Restart
railway restart
```

**Penyebab: Insufficient memory**
```bash
# Di Railway Dashboard:
# Project → Deployment Settings → Memory Limit
# Set ke 512MB minimum untuk Gitea
```

## Skenario 2: Konfigurasi Rusak (Config Lock)

### Diagnosis
```bash
# Akses container shell
railway run -- /bin/sh

# Di dalam container, cek config
ls -la /etc/gitea/app.ini
cat /var/lib/gitea/data/gitea.db
```

### Recovery Steps

```bash
# 1. Backup config saat ini (jika masih ada)
railway run -- cp /etc/gitea/app.ini /var/lib/gitea/data/app.ini.bak

# 2. Reset config dengan yang di repository
railway run -- rm /etc/gitea/app.ini
railway run -- cp /etc/gitea/app.ini.default /etc/gitea/app.ini

# 3. Jika database juga rusak, reset hanya database
railway run -- rm /var/lib/gitea/data/gitea.db

# 4. Restart container untuk reinitialize
railway restart
```

## Skenario 3: Repository Corruption

### Diagnosis
```bash
# Akses container
railway run -- /bin/sh

# Cek integritas repository
cd /var/lib/gitea/repositories/admin/repo-name
git fsck --full
```

### Recovery Options

**Option 1: Repair via Git**
```bash
# Di dalam container:
cd /var/lib/gitea/repositories/admin/repo-name

# Repair loose objects
git prune

# Rebuild pack files
git gc --aggressive --prune=now
```

**Option 2: Full Repository Restore dari Backup**
```bash
# Restore volume dari checkpoint Railway
# Di Railway Dashboard → Deployments → select previous deployment
```

**Option 3: Clone Repository Baru (jika remote masih ada)**
```bash
# Local machine:
git clone https://[gitea-url]/admin/backup-repo.git new-repo
```

## Skenario 4: Admin Password Lupa

### Recovery via Container

```bash
# 1. Akses container shell
railway run -- /bin/bash

# 2. Set password baru
/usr/bin/gitea admin user change-password --username admin --password NewPasswordHere123!

# 3. Exit container
exit

# 4. Restart service
railway restart
```

### Alternative: Reset via Database

```bash
# 1. Stop container (jangan, akan break service)
# Lebih baik pakai metode di atas

# 2. Jika benar-benar butuh akses database:
railway run -- sqlite3 /var/lib/gitea/data/gitea.db

# Di sqlite prompt:
# SELECT id, name, passwd FROM user WHERE name='admin';
# UPDATE user SET passwd='' WHERE name='admin';
# .quit
```

## Skenario 5: Data Loss Saat Railway Sleep

### Proteksi Preventif

```bash
# 1. Pastikan volume mounted dengan benar
railway volume list

# 2. Verifikasi data tersimpan
railway run -- ls -la /var/lib/gitea/data/
railway run -- du -sh /var/lib/gitea/data
railway run -- du -sh /var/lib/gitea/repositories

# 3. Upgrade plan jika perlu always-on
# Di Railway Dashboard → Billing → switch to paid plan
```

### Backup Strategy

```bash
# Backup manual sebelum maintenance
railway volume backup gitea-data
railway volume backup gitea-repos

# Cek backup tersedia
railway volume backups gitea-data

# Restore dari backup
railway volume restore gitea-data --backup-id [backup-id]
```

## Skenario 6: SSH Connection Failed

### Diagnosis
```bash
# Local machine - test SSH
ssh -vvv -T git@[gitea-url] -p 2222

# Cek SSH keys di Gitea Web UI
# Settings → SSH/GPG Keys
```

### Common Issues & Solutions

**Issue: "Permission denied (publickey)"**
```bash
# Solusi 1: Ensure SSH key added to Gitea
# Web UI → Settings → SSH/GPG Keys → Add Key

# Solusi 2: Verify key format (ed25519 recommended)
ssh-keygen -t ed25519 -C "email@example.com"

# Solusi 3: Check config
# ~/.ssh/config:
Host gitea
  HostName [your-gitea-url]
  Port 2222
  User git
  IdentityFile ~/.ssh/id_ed25519

# Solusi 4: Test SSH
ssh -T git@[gitea-url] -p 2222
```

**Issue: "Connection refused"**
```bash
# Cek apakah SSH service berjalan di container
railway run -- netstat -tlnp | grep 2222

# Jika tidak ada, cek Gitea logs
railway logs | grep -i ssh

# Restart container
railway restart
```

## Skenario 7: High Memory Usage

### Diagnosis
```bash
# Monitor memory
railway run -- free -m
railway run -- ps aux --sort=-%mem | head -10

# Cek Gitea process
railway run -- ps aux | grep gitea
```

### Optimization

```bash
# 1. Reduce indexer impact
# Di app.ini, set:
# [indexer]
# REPO_INDEXER_ENABLED = false

# 2. Clear cache periodically
railway run -- rm -rf /var/lib/gitea/data/sessions/*

# 3. Limit max open connections
# Di app.ini, add under [database]:
# MAX_OPEN_CONNS = 20
# CONN_MAX_LIFETIME = 3600

# 4. Restart service
railway restart
```

## Skenario 8: Complete Data Wipe & Restart

⚠️ **WARNING: This will delete all data!**

```bash
# BACKUP FIRST!
railway volume backup gitea-data
railway volume backup gitea-repos

# Remove volumes
railway volume remove gitea-data
railway volume remove gitea-repos
railway volume remove gitea-logs

# Recreate fresh volumes
railway volume add gitea-data --mount /var/lib/gitea/data --size 1
railway volume add gitea-repos --mount /var/lib/gitea/repositories --size 2
railway volume add gitea-logs --mount /var/lib/gitea/log --size 0.5

# Reset environment (mark as uninitialized)
railway run -- rm /var/lib/gitea/data/.initialized

# Restart
railway restart
```

## Verification Commands

```bash
# Cek health status
curl -f https://[your-gitea-url]/api/healthz

# Cek API connectivity
curl -s https://[your-gitea-url]/api/v1/repos/search | jq

# Cek SSH connectivity
ssh -T git@[your-gitea-url] -p 2222

# Cek database integrity
railway run -- /usr/bin/gitea doctor

# Cek file permissions
railway run -- ls -la /var/lib/gitea/data/

# Full diagnostics
railway run -- /usr/bin/gitea doctor --all
```

## Getting Help

1. Check Gitea logs: `railway logs`
2. Enable debug mode: `railway variables set LOG_LEVEL="debug"`
3. Check Gitea Doctor: `railway run -- /usr/bin/gitea doctor`
4. Review Gitea docs: https://docs.gitea.io
5. Railway support: https://railway.app/support

## Prevention Best Practices

✅ **DO:**
- Regular backups (weekly)
- Monitor logs regularly
- Use strong admin password + 2FA
- Keep SSH keys secure
- Update Gitea version regularly
- Document custom configurations

❌ **DON'T:**
- Run multiple Gitea instances on same volume
- Store passwords in config files
- Disable INSTALL_LOCK without reason
- Delete volumes without backup
- Expose Gitea to internet without reverse proxy
