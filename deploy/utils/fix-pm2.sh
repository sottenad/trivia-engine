#!/bin/bash

# ==============================================================================
# TRIVIA ENGINE - PM2 FIX SCRIPT
# ==============================================================================
# This script fixes common PM2 issues that cause 502 errors
# Run as root: bash fix-pm2.sh
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_USER="trivia"
APP_DIR="/home/${APP_USER}/trivia-engine"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              PM2 FIX SCRIPT                                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Stop all PM2 processes (both root and trivia)
echo -e "${YELLOW}Step 1: Stopping all PM2 processes...${NC}"
pm2 kill 2>/dev/null || true
sudo -u ${APP_USER} PM2_HOME=/home/${APP_USER}/.pm2 pm2 kill 2>/dev/null || true
echo -e "${GREEN}✓${NC} All PM2 processes stopped"
echo ""

# 2. Clear PM2 logs
echo -e "${YELLOW}Step 2: Clearing old logs...${NC}"
rm -rf /root/.pm2/logs/* 2>/dev/null || true
rm -rf /home/${APP_USER}/.pm2/logs/* 2>/dev/null || true
rm -rf /home/${APP_USER}/logs/*.log 2>/dev/null || true
echo -e "${GREEN}✓${NC} Logs cleared"
echo ""

# 3. Ensure correct ownership
echo -e "${YELLOW}Step 3: Fixing file permissions...${NC}"
chown -R ${APP_USER}:${APP_USER} ${APP_DIR}
chown -R ${APP_USER}:${APP_USER} /home/${APP_USER}/.pm2 2>/dev/null || true
chown -R ${APP_USER}:${APP_USER} /home/${APP_USER}/logs 2>/dev/null || true
echo -e "${GREEN}✓${NC} Permissions fixed"
echo ""

# 4. Check environment files
echo -e "${YELLOW}Step 4: Checking environment files...${NC}"
if [ ! -f "${APP_DIR}/app/.env" ]; then
    echo -e "${RED}✗${NC} API .env file missing!"
    echo "Creating from example..."
    if [ -f "${APP_DIR}/.env.example" ]; then
        cp ${APP_DIR}/.env.example ${APP_DIR}/app/.env
        chown ${APP_USER}:${APP_USER} ${APP_DIR}/app/.env
        echo -e "${YELLOW}⚠${NC} Created .env from example - PLEASE UPDATE WITH REAL VALUES"
    fi
else
    echo -e "${GREEN}✓${NC} API .env exists"
fi

if [ ! -f "${APP_DIR}/marketing/.env.local" ]; then
    echo -e "${RED}✗${NC} Marketing .env.local file missing!"
    echo "Creating default..."
    cat > ${APP_DIR}/marketing/.env.local <<EOF
NEXT_PUBLIC_API_BASE_URL=https://trivia-engine.com/api/v1
NEXT_PUBLIC_API_KEY=your-api-key-here
NEXT_PUBLIC_DOMAIN=https://trivia-engine.com
EOF
    chown ${APP_USER}:${APP_USER} ${APP_DIR}/marketing/.env.local
    echo -e "${YELLOW}⚠${NC} Created .env.local with defaults"
else
    echo -e "${GREEN}✓${NC} Marketing .env.local exists"
fi
echo ""

# 5. Check if node_modules exist
echo -e "${YELLOW}Step 5: Checking dependencies...${NC}"
if [ ! -d "${APP_DIR}/app/node_modules" ]; then
    echo -e "${YELLOW}Installing API dependencies...${NC}"
    cd ${APP_DIR}/app
    sudo -u ${APP_USER} npm install --production
fi

if [ ! -d "${APP_DIR}/marketing/node_modules" ]; then
    echo -e "${YELLOW}Installing Marketing dependencies...${NC}"
    cd ${APP_DIR}/marketing
    sudo -u ${APP_USER} npm install
fi

if [ ! -d "${APP_DIR}/marketing/.next" ]; then
    echo -e "${YELLOW}Building Marketing site...${NC}"
    cd ${APP_DIR}/marketing
    sudo -u ${APP_USER} npm run build
fi
echo -e "${GREEN}✓${NC} Dependencies checked"
echo ""

# 6. Start PM2 as trivia user
echo -e "${YELLOW}Step 6: Starting PM2 processes as ${APP_USER} user...${NC}"
cd ${APP_DIR}

# Start with ecosystem config
sudo -u ${APP_USER} PM2_HOME=/home/${APP_USER}/.pm2 pm2 start deploy/config/ecosystem.config.js --env production

# Save PM2 config
sudo -u ${APP_USER} PM2_HOME=/home/${APP_USER}/.pm2 pm2 save

# Set up startup script
sudo env PATH=$PATH:/usr/bin PM2_HOME=/home/${APP_USER}/.pm2 pm2 startup systemd -u ${APP_USER} --hp /home/${APP_USER} 2>/dev/null || true

echo -e "${GREEN}✓${NC} PM2 processes started"
echo ""

# 7. Wait for services to start
echo -e "${YELLOW}Step 7: Waiting for services to start...${NC}"
sleep 5

# 8. Check status
echo -e "${YELLOW}Step 8: Checking service status...${NC}"
echo ""
echo "PM2 Process List:"
sudo -u ${APP_USER} PM2_HOME=/home/${APP_USER}/.pm2 pm2 list
echo ""

# Test connections
echo "Testing API:"
if curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:3003/api/v1/health | grep -q "HTTP 200"; then
    echo -e "${GREEN}✓${NC} API is responding on port 3003"
else
    echo -e "${RED}✗${NC} API is not responding on port 3003"
    echo "Checking API logs:"
    sudo -u ${APP_USER} PM2_HOME=/home/${APP_USER}/.pm2 pm2 logs trivia-api --lines 10 --nostream
fi
echo ""

echo "Testing Marketing site:"
if curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:3000 | grep -q "HTTP 200"; then
    echo -e "${GREEN}✓${NC} Marketing site is responding on port 3000"
else
    echo -e "${RED}✗${NC} Marketing site is not responding on port 3000"
    echo "Checking Marketing logs:"
    sudo -u ${APP_USER} PM2_HOME=/home/${APP_USER}/.pm2 pm2 logs trivia-marketing --lines 10 --nostream
fi
echo ""

# 9. Restart Nginx
echo -e "${YELLOW}Step 9: Restarting Nginx...${NC}"
sudo nginx -t && sudo systemctl restart nginx
echo -e "${GREEN}✓${NC} Nginx restarted"
echo ""

# 10. Final test
echo -e "${YELLOW}Step 10: Testing through Nginx...${NC}"
sleep 2
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://trivia-engine.com 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ Website is working! (HTTP 200)${NC}"
elif [ "$RESPONSE" = "502" ]; then
    echo -e "${RED}✗ Still getting 502 error${NC}"
    echo ""
    echo "Check the logs for more details:"
    echo "  sudo -u trivia pm2 logs"
    echo "  sudo tail -f /var/log/nginx/trivia-engine.error.log"
else
    echo -e "${YELLOW}⚠ Got HTTP ${RESPONSE}${NC}"
fi
echo ""

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    FIX COMPLETE                             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Commands for monitoring:"
echo "  • View logs: sudo -u trivia pm2 logs"
echo "  • Process list: sudo -u trivia pm2 list"
echo "  • Monitor: sudo -u trivia pm2 monit"
echo ""
echo "If still having issues, run the diagnostic script:"
echo "  bash ${APP_DIR}/deploy/utils/diagnose-502.sh"