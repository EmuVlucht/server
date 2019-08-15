#!/bin/bash
# Quick deploy script untuk Gitea on Railway
# Interaktif CLI untuk setup dan deploy

set -e

echo "🚀 Gitea on Railway - Quick Deploy"
echo "===================================="
echo ""

# 1. Generate secrets
echo "Step 1: Generate Security Keys"
echo "------"
SECRET_KEY=$(openssl rand -hex 16)
INTERNAL_TOKEN=$(openssl rand -hex 20)

echo "✓ SECRET_KEY: $SECRET_KEY"
echo "✓ INTERNAL_TOKEN: $INTERNAL_TOKEN"
echo ""

# 2. Input admin details
echo "Step 2: Admin User Configuration"
echo "------"

read -p "Railway Project Name [gitea-server]: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-gitea-server}

read -p "Admin Username [admin]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-admin}

read -sp "Admin Password (min 8 chars): " ADMIN_PASS
echo ""
while [ ${#ADMIN_PASS} -lt 8 ]; do
    echo "❌ Password must be at least 8 characters"
    read -sp "Admin Password (min 8 chars): " ADMIN_PASS
    echo ""
done

read -p "Admin Email: " ADMIN_EMAIL
while [[ ! "$ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
    echo "❌ Invalid email format"
    read -p "Admin Email: " ADMIN_EMAIL
done

read -p "Initial Repository Name [my-first-repo]: " INITIAL_REPO
INITIAL_REPO=${INITIAL_REPO:-my-first-repo}

echo ""
echo "Summary:"
echo "--------"
echo "Project: $PROJECT_NAME"
echo "Admin User: $ADMIN_USER"
echo "Admin Email: $ADMIN_EMAIL"
echo "Initial Repo: $INITIAL_REPO"
echo ""

# 3. Deploy
echo "Step 3: Connecting to Railway..."
echo "------"

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found. Install with:"
    echo "   npm install -g @railway/cli"
    exit 1
fi

# Login dan init
if railway status > /dev/null 2>&1; then
    echo "✓ Already logged in to Railway"
else
    echo "🔓 Opening Railway login..."
    railway login
fi

# Init or link project
echo "🔗 Initializing Railway project..."
railway init --name "$PROJECT_NAME" || railway link

# Set variables
echo "📝 Setting environment variables..."
railway variables set SECRET_KEY="$SECRET_KEY"
railway variables set INTERNAL_TOKEN="$INTERNAL_TOKEN"
railway variables set GITEA_ADMIN_USER="$ADMIN_USER"
railway variables set GITEA_ADMIN_PASSWORD="$ADMIN_PASS"
railway variables set GITEA_ADMIN_EMAIL="$ADMIN_EMAIL"
railway variables set INITIAL_REPO_NAME="$INITIAL_REPO"

# Add volumes
echo "💾 Adding persistent storage..."
railway volume add gitea-data --mount /var/lib/gitea/data --size 1 2>/dev/null || echo "   (volume may already exist)"
railway volume add gitea-repos --mount /var/lib/gitea/repositories --size 2 2>/dev/null || echo "   (volume may already exist)"
railway volume add gitea-logs --mount /var/lib/gitea/log --size 0.5 2>/dev/null || echo "   (volume may already exist)"

# Deploy
echo ""
echo "🚀 Deploying to Railway..."
echo ""
railway up

# Get URL
echo ""
echo "===================================="
echo "✅ Deployment Complete!"
echo ""
GITEA_URL=$(railway status --json 2>/dev/null | jq -r '.services[0].url // "https://your-railway-app.up.railway.app"')
echo "🌐 Gitea URL: $GITEA_URL"
echo ""
echo "📝 Next Steps:"
echo "   1. Open browser: $GITEA_URL"
echo "   2. Login with:"
echo "      Username: $ADMIN_USER"
echo "      Password: (as entered above)"
echo ""
echo "   3. Create repositories and push code"
echo "   4. Optional: Setup SSH keys in Settings → SSH/GPG Keys"
echo ""
echo "📚 For more help, see:"
echo "   - DEPLOYMENT.md - detailed deployment guide"
echo "   - RECOVERY.md - troubleshooting & recovery"
echo "   - VERIFICATION.md - verification checklist"
echo "===================================="
