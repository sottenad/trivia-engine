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

# Stop and delete services to prevent port conflicts
echo "Stopping and cleaning up services..."
pm2 stop api 2>/dev/null || true
pm2 delete api 2>/dev/null || true
pm2 stop marketing 2>/dev/null || true
pm2 delete marketing 2>/dev/null || true
# Give processes time to fully stop
sleep 2

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

# Start API
cd ${PRODUCTION_DIR}/app
pm2 start api/index.js --name api \
    --max-memory-restart 512M \
    --log /var/log/pm2/api.log

# Start Marketing site
cd ${PRODUCTION_DIR}/marketing

# Check if standalone build exists
if [ -f "${PRODUCTION_DIR}/marketing/server.js" ]; then
    echo "Starting standalone Next.js server from marketing/server.js..."
    PORT=3000 pm2 start server.js --name marketing \
        --max-memory-restart 512M \
        --log /var/log/pm2/marketing.log
elif [ -f "${PRODUCTION_DIR}/marketing/.next/standalone/server.js" ]; then
    echo "Starting Next.js standalone from .next/standalone/server.js..."
    PORT=3000 pm2 start .next/standalone/server.js --name marketing \
        --max-memory-restart 512M \
        --log /var/log/pm2/marketing.log
else
    echo "WARNING: No standalone build found, falling back to npm start..."
    echo "This requires node_modules which may not be present!"
    pm2 start npm --name marketing \
        --max-memory-restart 512M \
        --log /var/log/pm2/marketing.log \
        -- start
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