#!/bin/sh
# Custom entrypoint untuk Gitea dengan setup yang proper

set -e

export USER=git
export HOME=/var/lib/gitea

# Log startup
echo "================================================"
echo "Gitea on Railway - Startup"
echo "================================================"
echo "User: $(id)"
echo "Home: $HOME"
echo "================================================"

# Cek apakah ini startup pertama
if [ ! -f "/var/lib/gitea/data/.initialized" ]; then
    echo "[SETUP] Deteksi startup pertama, menjalankan initialization..."
    
    # Tunggu sebentar untuk memastikan file system siap
    sleep 2
    
    # Jalankan setup saja (tidak start Gitea di sini)
    /usr/bin/gitea admin create-user \
        --username "${GITEA_ADMIN_USER:-admin}" \
        --password "${GITEA_ADMIN_PASSWORD:-admin}" \
        --email "${GITEA_ADMIN_EMAIL:-admin@example.com}" \
        --admin \
        --must-change-password=false 2>/dev/null || {
        echo "[SETUP] Admin user sudah ada atau gagal dibuat (mungkin sudah ada dari startup sebelumnya)"
    }
    
    # Create initial repo dengan direct filesystem jika diperlukan
    if [ -n "$INITIAL_REPO_NAME" ]; then
        echo "[SETUP] Menyiapkan repository awal: $INITIAL_REPO_NAME"
        # Kita akan membuat repo di dalam Gitea setelah web server berjalan
        # Flag ini untuk post-setup script
        touch /var/lib/gitea/data/.setup_repo_needed
    fi
    
    # Tandai sudah diinisialisasi
    mkdir -p /var/lib/gitea/data
    touch /var/lib/gitea/data/.initialized
    echo "[SETUP] Initialization mark created"
else
    echo "[SETUP] Container sudah pernah dijalankan sebelumnya, skip init"
fi

echo "[STARTUP] Launching Gitea web server..."
echo "================================================"

# Eksekusi Gitea dengan arguments yang dikirim
exec "$@"
