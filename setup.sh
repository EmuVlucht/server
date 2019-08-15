#!/bin/bash
# Setup script untuk Gitea - dipanggil setelah container siap

set -e

echo "=========================================="
echo "Gitea Post-Setup Script"
echo "=========================================="

GITEA_URL="${GITEA_URL:-http://localhost:3000}"
ADMIN_USER="${GITEA_ADMIN_USER:-admin}"
ADMIN_PASS="${GITEA_ADMIN_PASSWORD:-admin}"

# Tunggu Gitea siap menerima request
echo "[SETUP] Waiting for Gitea to be ready at $GITEA_URL..."
MAX_WAIT=120
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -s -f "$GITEA_URL/api/healthz" > /dev/null 2>&1; then
        echo "[SETUP] Gitea is ready!"
        break
    fi
    echo "[SETUP] Waiting... ($WAITED/${MAX_WAIT}s)"
    sleep 3
    WAITED=$((WAITED + 3))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "[ERROR] Gitea failed to start within timeout"
    exit 1
fi

# Create admin user jika tidak ada
echo "[SETUP] Ensuring admin user exists..."
if ! curl -s -u "$ADMIN_USER:$ADMIN_PASS" "$GITEA_URL/api/v1/user" > /dev/null 2>&1; then
    echo "[SETUP] Creating admin user via API..."
    curl -s -X POST "$GITEA_URL/api/v1/admin/users" \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"$ADMIN_USER\",
            \"email\": \"${GITEA_ADMIN_EMAIL:-admin@example.com}\",
            \"password\": \"$ADMIN_PASS\",
            \"send_notify\": false,
            \"admin\": true
        }" 2>/dev/null || echo "[SETUP] Admin user already exists or API not ready yet"
fi

# Create initial repository jika diperlukan
if [ -n "$INITIAL_REPO_NAME" ]; then
    echo "[SETUP] Setting up initial repository: $INITIAL_REPO_NAME"
    
    # Get or create API token
    API_TOKEN=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" \
        "$GITEA_URL/api/v1/users/$ADMIN_USER/tokens" \
        -H "Content-Type: application/json" \
        -d '{"name":"setup-token","scopes":["repo","admin"]}' 2>/dev/null | jq -r '.sha1' || echo "")
    
    if [ -n "$API_TOKEN" ] && [ "$API_TOKEN" != "null" ]; then
        echo "[SETUP] Using API token for repository creation"
        
        # Create repository
        curl -s -X POST "$GITEA_URL/api/v1/user/repos" \
            -H "Authorization: token $API_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"$INITIAL_REPO_NAME\",
                \"auto_init\": true,
                \"private\": false,
                \"description\": \"Initial repository created by setup script\"
            }" 2>/dev/null || echo "[SETUP] Repository already exists or creation failed"
        
        echo "[SETUP] Repository $INITIAL_REPO_NAME ready"
    else
        echo "[SETUP] Could not create API token, skipping repository creation"
    fi
fi

echo "[SETUP] Setup complete!"
echo "=========================================="
