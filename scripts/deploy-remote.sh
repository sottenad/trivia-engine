#!/bin/bash

# Remote deployment script - runs on the server after files are copied
# This is called by GitHub Actions after artifacts are transferred

set -e

echo "Starting remote deployment..."

# Configuration
DEPLOY_DIR="/home/trivia/trivia-engine-deploy"
PRODUCTION_DIR="/home/trivia/trivia-engine"

# Ensure production directory exists
mkdir -p ${PRODUCTION_DIR}

# Stop services to prevent file locks
echo "Stopping services..."
pm2 stop api marketing 2>/dev/null || true

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

# Ensure .env file exists (should be manually configured on server)
if [ ! -f "${PRODUCTION_DIR}/app/.env" ]; then
    echo "WARNING: No .env file found in ${PRODUCTION_DIR}/app/"
    echo "Please configure environment variables!"
fi

# Deploy Marketing site
echo "Deploying Marketing site..."
rm -rf ${PRODUCTION_DIR}/marketing/.next
rm -rf ${PRODUCTION_DIR}/marketing/public
mkdir -p ${PRODUCTION_DIR}/marketing
cp -r ${DEPLOY_DIR}/marketing/.next ${PRODUCTION_DIR}/marketing/
cp -r ${DEPLOY_DIR}/marketing/public ${PRODUCTION_DIR}/marketing/ 2>/dev/null || true
cp ${DEPLOY_DIR}/marketing/package*.json ${PRODUCTION_DIR}/marketing/

# Install marketing production dependencies
cd ${PRODUCTION_DIR}/marketing
npm ci --production

# Generate Prisma client in production
cd ${PRODUCTION_DIR}/app
npx prisma generate

# Start services with PM2
echo "Starting services..."
cd ${PRODUCTION_DIR}

# Start API
pm2 delete api 2>/dev/null || true
cd ${PRODUCTION_DIR}/app
pm2 start api/index.js --name api --env production \
    --max-memory-restart 512M \
    --error /var/log/pm2/api-error.log \
    --output /var/log/pm2/api-out.log

# Start Marketing site
pm2 delete marketing 2>/dev/null || true
cd ${PRODUCTION_DIR}/marketing

# Check if standalone build exists
if [ -f ".next/standalone/server.js" ]; then
    echo "Starting standalone Next.js server..."
    pm2 start .next/standalone/server.js --name marketing \
        --env production \
        --max-memory-restart 512M \
        --error /var/log/pm2/marketing-error.log \
        --output /var/log/pm2/marketing-out.log
else
    echo "Starting Next.js with npm start..."
    pm2 start npm --name marketing -- start \
        --max-memory-restart 512M \
        --error /var/log/pm2/marketing-error.log \
        --output /var/log/pm2/marketing-out.log
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

# Cleanup old deployment files
echo "Cleaning up..."
rm -rf ${DEPLOY_DIR}

echo "✅ Deployment complete!"
echo ""
echo "Services status:"
pm2 status
echo ""
echo "To view logs, run:"
echo "  pm2 logs api"
echo "  pm2 logs marketing"