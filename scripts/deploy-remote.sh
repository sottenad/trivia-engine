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
rm -rf ${PRODUCTION_DIR}/marketing/.next
rm -rf ${PRODUCTION_DIR}/marketing/.next.backup
rm -rf ${PRODUCTION_DIR}/marketing/public
rm -rf ${PRODUCTION_DIR}/marketing/node_modules
mkdir -p ${PRODUCTION_DIR}/marketing

# Copy all marketing files including pre-built dependencies
cp -r ${DEPLOY_DIR}/marketing/.next ${PRODUCTION_DIR}/marketing/
cp -r ${DEPLOY_DIR}/marketing/public ${PRODUCTION_DIR}/marketing/ 2>/dev/null || true
cp ${DEPLOY_DIR}/marketing/package*.json ${PRODUCTION_DIR}/marketing/

# Copy node_modules if included (for standalone or pre-installed deps)
if [ -d "${DEPLOY_DIR}/marketing/node_modules" ]; then
    echo "Copying pre-installed node_modules..."
    cp -r ${DEPLOY_DIR}/marketing/node_modules ${PRODUCTION_DIR}/marketing/
elif [ -d "${DEPLOY_DIR}/marketing/.next/standalone" ]; then
    echo "Using Next.js standalone build (self-contained)..."
    cp -r ${DEPLOY_DIR}/marketing/.next/standalone/* ${PRODUCTION_DIR}/marketing/
    # Copy static files for standalone
    mkdir -p ${PRODUCTION_DIR}/marketing/.next/static
    cp -r ${DEPLOY_DIR}/marketing/.next/static ${PRODUCTION_DIR}/marketing/.next/
else
    echo "WARNING: No node_modules or standalone build found"
    echo "Marketing site may not start properly"
fi

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

# Start Marketing site
cd ${PRODUCTION_DIR}/marketing

# Debug: Show what files exist
echo "Checking marketing directory structure..."
echo "Contents of ${PRODUCTION_DIR}/marketing:"
ls -la ${PRODUCTION_DIR}/marketing/ | head -20
echo "Contents of ${PRODUCTION_DIR}/marketing/.next (if exists):"
ls -la ${PRODUCTION_DIR}/marketing/.next/ 2>/dev/null | head -10 || echo "No .next directory"
echo "Looking for standalone builds:"
find ${PRODUCTION_DIR}/marketing -name "server.js" -type f 2>/dev/null | head -5

# Check if standalone build exists (Next.js standalone creates a server.js in root when copied)
if [ -f "${PRODUCTION_DIR}/marketing/server.js" ]; then
    echo "✅ Found standalone server at: ${PRODUCTION_DIR}/marketing/server.js"
    echo "Starting standalone Next.js server..."
    cd ${PRODUCTION_DIR}/marketing
    # Use node directly to avoid PM2 env issues
    PORT=3000 pm2 start "node server.js" --name marketing \
        --max-memory-restart 512M \
        --log /var/log/pm2/marketing.log
elif [ -d "${PRODUCTION_DIR}/marketing/.next/standalone" ]; then
    echo "✅ Found .next/standalone directory"
    # The standalone build should have been copied to root, but check if it's still in .next
    if [ -f "${PRODUCTION_DIR}/marketing/.next/standalone/server.js" ]; then
        echo "Starting from .next/standalone/server.js"
        cd ${PRODUCTION_DIR}/marketing/.next/standalone
        PORT=3000 pm2 start "node server.js" --name marketing \
            --max-memory-restart 512M \
            --log /var/log/pm2/marketing.log
    else
        echo "ERROR: Standalone directory exists but no server.js found!"
        ls -la ${PRODUCTION_DIR}/marketing/.next/standalone/
    fi
else
    echo "❌ ERROR: No standalone build found!"
    echo "The deployment should include a standalone Next.js build."
    echo "Checking for node_modules as last resort..."
    if [ -d "${PRODUCTION_DIR}/marketing/node_modules" ]; then
        echo "Found node_modules, attempting npm start..."
        pm2 start npm --name marketing \
            --max-memory-restart 512M \
            --log /var/log/pm2/marketing.log \
            -- start
    else
        echo "FATAL: No standalone build and no node_modules. Marketing site cannot start!"
        echo "Deployment packaging may have failed."
    fi
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