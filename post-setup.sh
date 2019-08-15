#!/bin/bash
# Post-setup script - dipanggil setelah Gitea web server berjalan
# Untuk membuat repository awal dan konfigurasi lanjutan

set -e

GITEA_URL="${GITEA_URL:-http://localhost:3000}"
ADMIN_USER="${GITEA_ADMIN_USER:-admin}"
ADMIN_PASS="${GITEA_ADMIN_PASSWORD:-admin}"
REPO_NAME="${INITIAL_REPO_NAME:-my-first-repo}"

echo "=========================================="
echo "Gitea Post-Setup"
echo "=========================================="

# Tunggu Gitea siap
echo "[POST-SETUP] Waiting for Gitea at $GITEA_URL..."
for i in {1..60}; do
    if curl -s -f "$GITEA_URL/api/healthz" > /dev/null 2>&1; then
        echo "[POST-SETUP] Gitea is ready!"
        break
    fi
    echo "[POST-SETUP] Attempt $i/60..."
    sleep 2
done

# Create initial repository
if [ -n "$REPO_NAME" ] && [ "$REPO_NAME" != "my-first-repo" ]; then
    echo "[POST-SETUP] Creating repository: $REPO_NAME"
    
    # Try to create via API
    curl -s -X POST "$GITEA_URL/api/v1/user/repos" \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$REPO_NAME\",
            \"auto_init\": true,
            \"private\": false,
            \"description\": \"Initial repository\"
        }" 2>/dev/null && echo "[POST-SETUP] Repository created" || \
        echo "[POST-SETUP] Repository creation skipped (may already exist)"
fi

echo "[POST-SETUP] Complete!"
