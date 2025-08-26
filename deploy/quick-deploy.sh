#!/bin/bash
# Quick deployment helper for development/testing
# This script can be run locally to deploy to your server

set -e

# Configuration
DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_USER="${DEPLOY_USER:-trivia}"
DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Check if host is provided
if [ -z "$DEPLOY_HOST" ]; then
    echo -e "${RED}Error: DEPLOY_HOST environment variable not set${NC}"
    echo "Usage: DEPLOY_HOST=your.server.com ./deploy/quick-deploy.sh"
    exit 1
fi

echo -e "${GREEN}Deploying to $DEPLOY_HOST as $DEPLOY_USER...${NC}"

# Run deployment on remote server
ssh -t ${DEPLOY_USER}@${DEPLOY_HOST} << EOF
    set -e
    
    echo -e "${GREEN}Pulling latest changes...${NC}"
    cd /home/${DEPLOY_USER}/trivia-engine
    git fetch origin
    git checkout $DEPLOY_BRANCH
    git pull origin $DEPLOY_BRANCH
    
    echo -e "${GREEN}Installing API dependencies...${NC}"
    cd app
    npm ci --production
    
    echo -e "${GREEN}Running database migrations...${NC}"
    npx prisma migrate deploy
    npx prisma generate
    
    echo -e "${GREEN}Building marketing site...${NC}"
    cd ../marketing
    npm ci
    npm run build
    
    echo -e "${GREEN}Restarting services...${NC}"
    sudo systemctl restart trivia-api trivia-marketing
    
    echo -e "${GREEN}Checking service status...${NC}"
    sleep 3
    
    # Check API health
    if curl -f -s http://localhost:3003/api/v1/health > /dev/null; then
        echo -e "${GREEN}✓ API is healthy${NC}"
    else
        echo -e "${RED}✗ API health check failed${NC}"
        exit 1
    fi
    
    # Show service status
    sudo systemctl is-active trivia-api trivia-marketing
    
    echo -e "${GREEN}Deployment completed successfully!${NC}"
EOF

echo -e "${GREEN}Done! Your application is deployed to https://${DEPLOY_HOST}${NC}"