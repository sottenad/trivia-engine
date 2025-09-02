#!/bin/bash

# Remote deployment script - runs on the server after files are copied
# This is called by GitHub Actions after artifacts are transferred

set -e

echo "Starting remote deployment..."

# Configuration
# Script now runs from within the extracted deploy-package directory
DEPLOY_DIR="$(pwd)"
PRODUCTION_DIR="/home/trivia/trivia-engine"

# Ensure production directory exists
mkdir -p ${PRODUCTION_DIR}

# Clean PM2 completely to avoid port conflicts
echo "Cleaning up PM2 services..."

# Check if PM2 is running
if pm2 list >/dev/null 2>&1; then
    # PM2 is running, try to stop and delete
    pm2 stop all 2>/dev/null || true
    pm2 delete all 2>/dev/null || true
else
    echo "PM2 daemon not running, will start fresh"
fi

# Check if port 3003 is still in use
if lsof -Pi :3003 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Port 3003 still in use, force killing PM2..."
    pm2 kill 2>/dev/null || true
    # Kill any remaining node processes on port 3003
    lsof -ti:3003 | xargs -r kill -9 2>/dev/null || true
    sleep 2
fi

# Also check port 3000
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Port 3000 still in use, checking process..."
    lsof -i :3000
fi

# Backup current deployment (optional)
if [ -d "${PRODUCTION_DIR}/app" ]; then
    echo "Creating backup..."
    rm -rf ${PRODUCTION_DIR}.backup
    cp -r ${PRODUCTION_DIR} ${PRODUCTION_DIR}.backup
fi

# Deploy API
echo "Deploying API..."
rm -rf ${PRODUCTION_DIR}/app
cp -r ${DEPLOY_DIR}/app ${PRODUCTION_DIR}/

# Create .env file from environment variables passed by GitHub Actions
echo "Creating .env file..."
cat > ${PRODUCTION_DIR}/app/.env << EOF
DATABASE_URL=${DATABASE_URL}
JWT_SECRET=${JWT_SECRET}
PORT=${PORT:-3003}
NODE_ENV=production
EOF

echo "✅ Environment variables configured"

# Deploy Marketing site
echo "Deploying Marketing site..."
# Clean up old marketing directory completely
rm -rf ${PRODUCTION_DIR}/marketing
mkdir -p ${PRODUCTION_DIR}/marketing

# Copy ALL files from deploy-package/marketing (should be static export files)
echo "Copying marketing files from deploy package..."
cp -r ${DEPLOY_DIR}/marketing/* ${PRODUCTION_DIR}/marketing/ 2>/dev/null || true
cp -r ${DEPLOY_DIR}/marketing/.[^.]* ${PRODUCTION_DIR}/marketing/ 2>/dev/null || true

# Show what was deployed
echo "Deployed marketing files:"
ls -la ${PRODUCTION_DIR}/marketing/ | head -20

# Generate Prisma client in production
cd ${PRODUCTION_DIR}/app
npx prisma generate

# Start services with PM2
echo "Starting services..."
cd ${PRODUCTION_DIR}

# Ensure PM2 daemon is running (will auto-start if not)
pm2 list >/dev/null 2>&1 || {
    echo "Starting PM2 daemon..."
    pm2 startup >/dev/null 2>&1 || true
}

# Start API
cd ${PRODUCTION_DIR}/app
echo "Starting API service..."
pm2 start api/index.js --name api \
    --max-memory-restart 512M \
    --log /var/log/pm2/api.log \
    || echo "Failed to start API, check logs"

# Deploy Marketing site
echo "Checking marketing site deployment..."
cd ${PRODUCTION_DIR}/marketing

# Debug: Show what's in the marketing directory
echo "Contents of marketing directory:"
ls -la ${PRODUCTION_DIR}/marketing/ | head -20

# IMPORTANT: Check for static export FIRST (index.html in root)
if [ -f "${PRODUCTION_DIR}/marketing/index.html" ]; then
    echo "✅ Marketing site is a static export"
    echo "Files will be served directly by nginx - no Node.js process needed"
    
    # No PM2 process needed for static files
    echo "Static files ready at: ${PRODUCTION_DIR}/marketing/"
    
    # Stop any existing marketing PM2 process since we don't need it
    pm2 delete marketing 2>/dev/null || true
    echo "Removed PM2 marketing process (not needed for static site)"
    
    # Ensure nginx can serve the files
    echo "Static site will be served by nginx from: ${PRODUCTION_DIR}/marketing/"
    
# Only check for Node.js mode if NO static files found
elif [ ! -f "${PRODUCTION_DIR}/marketing/index.html" ]; then
    echo "No index.html found, checking for Node.js server mode..."
    
    if [ -f "${PRODUCTION_DIR}/marketing/server.js" ]; then
        echo "Found server.js, starting with PM2..."
        PORT=3000 pm2 start server.js --name marketing \
            --max-memory-restart 512M \
            --log /var/log/pm2/marketing.log
    elif [ -d "${PRODUCTION_DIR}/marketing/.next" ] && [ -d "${PRODUCTION_DIR}/marketing/node_modules" ]; then
        echo "Found .next directory and node_modules, trying npm start..."
        pm2 start npm --name marketing \
            --max-memory-restart 512M \
            --log /var/log/pm2/marketing.log \
            -- start
    else
        echo "ERROR: No static files (index.html) and no valid Node.js setup found!"
        echo "Found these files:"
        ls -la ${PRODUCTION_DIR}/marketing/
        echo "The deployment may have failed or the build output is missing."
    fi
else
    echo "ERROR: Unexpected state in marketing deployment"
    ls -la ${PRODUCTION_DIR}/marketing/
fi

# Save PM2 configuration
pm2 save

# Reload nginx (if configurations changed)
sudo nginx -t && sudo systemctl reload nginx

# Health checks
echo "Running health checks..."
sleep 5

# Check PM2 status
pm2 list

# Check if services are running
if pm2 info api | grep -q "online"; then
    echo "✅ API is running"
else
    echo "❌ API failed to start"
    pm2 logs api --lines 20
    exit 1
fi

if pm2 info marketing | grep -q "online"; then
    echo "✅ Marketing site is running"
else
    echo "❌ Marketing site failed to start"
    pm2 logs marketing --lines 20
    exit 1
fi

# Cleanup handled by GitHub Actions workflow
echo "Deployment cleanup will be handled by workflow..."

echo "✅ Deployment complete!"
echo ""
echo "Services status:"
pm2 status
echo ""
echo "To view logs, run:"
echo "  pm2 logs api"
echo "  pm2 logs marketing"