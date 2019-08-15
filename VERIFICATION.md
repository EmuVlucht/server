# ✅ Panduan Verifikasi Gitea Setup

## Checklist Pre-Deployment

- [ ] All secret keys are generated (SECRET_KEY, INTERNAL_TOKEN)
- [ ] Environment variables are set in Railway
- [ ] Volumes are created and mounted:
  - [ ] gitea-data → /var/lib/gitea/data
  - [ ] gitea-repos → /var/lib/gitea/repositories
  - [ ] gitea-logs → /var/lib/gitea/log
- [ ] Dockerfile builds successfully: `docker-compose build`
- [ ] Local test passes: `docker-compose up` works
- [ ] Admin user credentials are set
- [ ] All ports are accessible (3000 for HTTP, 2222 for SSH)

## Step 1: Verify Web UI Access

```bash
# Get your Gitea URL
GITEA_URL=$(railway status --json | jq -r '.services[0].url')
echo "Gitea URL: $GITEA_URL"

# Test HTTP connectivity
curl -I $GITEA_URL

# Expected response: HTTP 200 or 302 (redirect)
# If fails: check if container is running (railway status)
```

## Step 2: Verify Container Health

```bash
# Check container status
railway status

# Expected: Container should be RUNNING

# Check health probe
curl -f $GITEA_URL/api/healthz
# Expected: HTTP 200 with {"status":"ok"} or similar
```

## Step 3: Verify Web UI Login

```bash
# Open in browser
echo "Open this URL in your browser: $GITEA_URL"

# Check you can login with admin credentials:
# Username: (from GITEA_ADMIN_USER)
# Password: (from GITEA_ADMIN_PASSWORD)

# After login, verify:
# ✓ Dashboard loads
# ✓ User profile visible (top right)
# ✓ No error messages
```

## Step 4: Verify HTTPS/API Access

```bash
# Test API endpoint (requires auth)
curl -u "admin:$(railway variables --json | jq -r '.GITEA_ADMIN_PASSWORD')" \
  $GITEA_URL/api/v1/user

# Expected: JSON response with user info
# If 401: credentials wrong or admin not created
```

## Step 5: Verify Repository Creation

```bash
# Via Web UI
# 1. Click "+" → New Repository
# 2. Name: test-repo
# 3. Click "Create Repository"
# 4. Should show success page

# Via API
API_TOKEN=$(curl -s -u "admin:password" \
  $GITEA_URL/api/v1/users/admin/tokens \
  -H "Content-Type: application/json" \
  -d '{"name":"test"}' | jq -r '.sha1')

curl -X POST "$GITEA_URL/api/v1/user/repos" \
  -H "Authorization: token $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"api-test-repo","auto_init":true}'

# Expected: HTTP 201 with repo details
```

## Step 6: Verify HTTPS (Clone)

```bash
# Create test repository first (if not done)

# Clone repository
git clone https://admin:$(railway variables --json | jq -r '.GITEA_ADMIN_PASSWORD')@$GITEA_URL/admin/test-repo.git
cd test-repo

# Verify clone worked:
# ✓ Directory created
# ✓ .git folder exists
# ✓ Can read files
ls -la
git log
```

## Step 7: Verify HTTPS Push/Pull

```bash
# In cloned repository
cd test-repo

# Create test commit
echo "Test $(date)" > test.txt
git add .
git commit -m "Test commit"

# Push to repository
git push origin main
# or: git push origin master

# Expected:
# ✓ No permission errors
# ✓ Remote accepted commits
# ✓ Counter updated on web UI

# Verify on web UI:
# Navigate to $GITEA_URL/admin/test-repo
# Should see test-repo commits and files
```

## Step 8: Verify SSH Setup (Optional)

```bash
# 1. Generate SSH key (if not done)
ssh-keygen -t ed25519 -C "your@email.com"

# 2. Add to Gitea Web UI:
# Web UI → Settings → SSH and GPG Keys → Add Key
# Paste ~/.ssh/id_ed25519.pub

# 3. Test SSH connectivity
ssh -T git@$GITEA_URL -p 2222

# Expected: "Hi admin! You've successfully authenticated, but Gitea does not provide shell access."

# 4. Clone via SSH
git clone ssh://git@$GITEA_URL:2222/admin/test-repo-ssh.git
cd test-repo-ssh

# 5. Test SSH push
echo "SSH test $(date)" >> test.txt
git add .
git commit -m "SSH test"
git push

# Expected: Works without password prompt
```

## Step 9: Verify Persistent Storage

```bash
# Create repository with some content
# 1. Push commits to repositories
# 2. Upload attachment to an issue
# 3. Create wiki pages

# Simulate restart
railway restart

# Wait 30-60 seconds for container to restart

# Verify data still exists:
# ✓ Repositories still there
# ✓ Commits still visible
# ✓ Attachments still accessible
# ✓ Wiki pages preserved

curl -u "admin:password" $GITEA_URL/api/v1/repos/search
```

## Step 10: Verify Logging

```bash
# Check logs being written
railway run -- ls -la /var/lib/gitea/log/

# Tail recent logs
railway logs | tail -20

# Expected:
# ✓ No ERROR or FATAL messages
# ✓ INFO messages showing normal operations
# ✓ Request logs visible
```

## Performance Verification

```bash
# Check memory usage
railway run -- free -m

# Expected: < 512MB in use

# Check disk usage
railway run -- du -sh /var/lib/gitea/data
railway run -- du -sh /var/lib/gitea/repositories

# Acceptable: < 100MB initially

# Check container uptime
railway run -- uptime

# Check processes
railway run -- ps aux | grep gitea
```

## Security Verification

```bash
# Verify INSTALL_LOCK is set (prevents setup wizard)
railway run -- grep INSTALL_LOCK /etc/gitea/app.ini

# Expected: INSTALL_LOCK = true

# Verify SECRET_KEY and INTERNAL_TOKEN are not default
railway variables | grep -E "SECRET_KEY|INTERNAL_TOKEN"

# Expected: Not "change-me" or similar defaults

# Verify password policy
railway run -- grep -A 5 "\[security\]" /etc/gitea/app.ini
```

## Troubleshooting Verification Failures

### "Cannot connect to Gitea" / "Connection refused"
```bash
# 1. Check container status
railway status

# 2. Check logs for errors
railway logs | grep -i error

# 3. Restart container
railway restart

# 4. Wait 60+ seconds and retry
```

### "Login failed" / "Invalid credentials"
```bash
# 1. Verify admin user exists
railway run -- /usr/bin/gitea admin user list

# 2. Check credentials in environment
railway variables | grep GITEA_ADMIN

# 3. Reset password
railway run -- /usr/bin/gitea admin user change-password --username admin --password newpass123!
```

### "Cannot clone repository" / "Repository not found"
```bash
# 1. Verify repository exists
curl -u "admin:password" $GITEA_URL/api/v1/repos/search

# 2. Check repository is public or user has access
# Web UI → Repository → Settings → Authorization

# 3. Verify HTTPS works
curl -I $GITEA_URL/admin/test-repo.git

# Expected: HTTP 301 or 200
```

### "SSH connection refused"
```bash
# 1. Verify SSH port is exposed (2222)
railway status | grep -i port

# 2. Check SSH service in container
railway run -- netstat -tlnp | grep 2222

# 3. Check firewall allows port 2222
# (This is on Railway's side - usually OK)

# 4. Verify SSH key is added to Gitea
# Web UI → Settings → SSH and GPG Keys
```

## Final Checklist

After all verification steps, confirm:

- [ ] Web UI accessible at $GITEA_URL
- [ ] Admin login works
- [ ] HTTPS clone works
- [ ] HTTPS push works
- [ ] SSH clone works (if configured)
- [ ] SSH push works (if configured)
- [ ] Data persists after restart
- [ ] No error logs
- [ ] Memory usage < 512MB
- [ ] All volumes mounted
- [ ] Setup time < 60 seconds

## Ready for Production?

If all checks pass ✅, your Gitea setup is ready for:
1. Creating user repositories
2. Team collaboration
3. Regular backups
4. Custom domain setup
5. Integration with CI/CD

For ongoing monitoring, check:
- Weekly: `railway logs` for errors
- Monthly: `railway volume backup` for backups
- Quarterly: Update Gitea version in Dockerfile
