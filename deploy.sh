#!/bin/bash

# Simple deployment script for Digital Ocean droplet
# Assumes: PM2 is installed, PostgreSQL is running, Node.js is installed

set -e  # Exit on error

echo "Starting deployment..."

# Pull latest code
echo "Pulling latest code..."
git pull origin main

# Deploy API
echo "Deploying API..."
cd app
npm install --production
npx prisma generate
npx prisma migrate deploy

# Start/restart API with PM2
pm2 delete api 2>/dev/null || true
pm2 start api/index.js --name api --env production

# Deploy Marketing site
echo "Deploying Marketing site..."
cd ../marketing
npm install
npm run build

# Start/restart Marketing site with PM2
pm2 delete marketing 2>/dev/null || true
pm2 start npm --name marketing -- start

# Save PM2 configuration
pm2 save
pm2 startup systemd -u $USER --hp /home/$USER || true

echo "Deployment complete!"
echo "Running services:"
pm2 list