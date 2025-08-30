#!/bin/bash

# ==============================================================================
# TRIVIA ENGINE - COMPLETE SERVER RESET SCRIPT
# ==============================================================================
# WARNING: This script will COMPLETELY RESET your server to a blank state
# It will DELETE:
# - All application code and data
# - PostgreSQL databases
# - Nginx configurations
# - PM2 processes
# - User accounts
# - ALL application files
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration
APP_USER="trivia"
APP_DIR="/home/${APP_USER}/trivia-engine"
DOMAIN="trivia-engine.com"
DB_NAME="trivia_engine"

echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                    ⚠️  EXTREME WARNING ⚠️                     ║${NC}"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}║  This script will COMPLETELY RESET your server!             ║${NC}"
echo -e "${RED}║  ALL DATA WILL BE PERMANENTLY DELETED!                      ║${NC}"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}║  This includes:                                             ║${NC}"
echo -e "${RED}║  • All databases and their data                             ║${NC}"
echo -e "${RED}║  • All application code                                     ║${NC}"
echo -e "${RED}║  • All user accounts and configurations                     ║${NC}"
echo -e "${RED}║  • All logs and backups                                     ║${NC}"
echo -e "${RED}║  • All SSL certificates                                     ║${NC}"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}To continue, type exactly: DELETE EVERYTHING${NC}"
echo -n "Your response: "
read confirmation

if [ "$confirmation" != "DELETE EVERYTHING" ]; then
    echo -e "${GREEN}Reset cancelled. Your server is safe.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Are you ABSOLUTELY SURE? Type 'yes' to proceed:${NC}"
echo -n "Your response: "
read final_confirmation

if [ "$final_confirmation" != "yes" ]; then
    echo -e "${GREEN}Reset cancelled. Your server is safe.${NC}"
    exit 0
fi

echo ""
echo -e "${RED}Starting complete server reset...${NC}"
sleep 3

# Function to safely execute commands
safe_exec() {
    if eval "$1" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${YELLOW}⚠${NC} $2 (may have already been removed)"
    fi
}

# Stop all services
echo -e "\n${YELLOW}Step 1: Stopping all services...${NC}"
safe_exec "sudo systemctl stop trivia-api" "Stopped API service"
safe_exec "sudo systemctl stop trivia-marketing" "Stopped marketing service"
safe_exec "sudo systemctl disable trivia-api" "Disabled API service"
safe_exec "sudo systemctl disable trivia-marketing" "Disabled marketing service"

# Stop PM2 processes
echo -e "\n${YELLOW}Step 2: Stopping PM2 processes...${NC}"
if command -v pm2 &> /dev/null; then
    safe_exec "pm2 stop all" "Stopped all PM2 processes"
    safe_exec "pm2 delete all" "Deleted all PM2 processes"
    safe_exec "pm2 unstartup" "Removed PM2 startup script"
    safe_exec "pm2 kill" "Killed PM2 daemon"
fi

# Remove Nginx configurations
echo -e "\n${YELLOW}Step 3: Removing Nginx configurations...${NC}"
safe_exec "sudo rm -f /etc/nginx/sites-enabled/trivia-engine" "Removed Nginx site config"
safe_exec "sudo rm -f /etc/nginx/sites-available/trivia-engine" "Removed Nginx available config"
safe_exec "sudo rm -rf /etc/nginx/sites-available/${DOMAIN}*" "Removed domain configs"
safe_exec "sudo rm -rf /etc/nginx/sites-enabled/${DOMAIN}*" "Removed enabled domain configs"
safe_exec "sudo nginx -t && sudo systemctl reload nginx" "Reloaded Nginx"

# Remove SSL certificates
echo -e "\n${YELLOW}Step 4: Removing SSL certificates...${NC}"
safe_exec "sudo certbot delete --cert-name ${DOMAIN} --non-interactive" "Removed SSL certificate for ${DOMAIN}"
safe_exec "sudo certbot delete --cert-name www.${DOMAIN} --non-interactive" "Removed SSL certificate for www.${DOMAIN}"

# Drop PostgreSQL database and user
echo -e "\n${YELLOW}Step 5: Removing PostgreSQL database...${NC}"
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw ${DB_NAME}; then
    sudo -u postgres psql <<EOF
DROP DATABASE IF EXISTS ${DB_NAME};
DROP DATABASE IF EXISTS ${DB_NAME}_test;
DROP USER IF EXISTS ${APP_USER};
EOF
    echo -e "${GREEN}✓${NC} Dropped database and user"
else
    echo -e "${YELLOW}⚠${NC} Database doesn't exist"
fi

# Remove application files
echo -e "\n${YELLOW}Step 6: Removing application files...${NC}"
safe_exec "sudo rm -rf ${APP_DIR}" "Removed application directory"
safe_exec "sudo rm -rf /home/${APP_USER}/logs" "Removed logs directory"
safe_exec "sudo rm -rf /home/${APP_USER}/backups" "Removed backups directory"
safe_exec "sudo rm -rf /home/${APP_USER}/.pm2" "Removed PM2 config"
safe_exec "sudo rm -rf /home/${APP_USER}/.npm" "Removed npm cache"
safe_exec "sudo rm -rf /home/${APP_USER}/.cache" "Removed cache directory"

# Remove systemd service files
echo -e "\n${YELLOW}Step 7: Removing systemd services...${NC}"
safe_exec "sudo rm -f /etc/systemd/system/trivia-api.service" "Removed API service file"
safe_exec "sudo rm -f /etc/systemd/system/trivia-marketing.service" "Removed marketing service file"
safe_exec "sudo systemctl daemon-reload" "Reloaded systemd"

# Remove cron jobs
echo -e "\n${YELLOW}Step 8: Removing cron jobs...${NC}"
safe_exec "sudo crontab -u ${APP_USER} -r" "Removed user cron jobs"

# Remove user account (optional - commented out for safety)
echo -e "\n${YELLOW}Step 9: User account...${NC}"
echo -e "${YELLOW}Note: User account '${APP_USER}' preserved for safety.${NC}"
echo -e "${YELLOW}To remove manually: sudo userdel -r ${APP_USER}${NC}"

# Uninstall PM2 globally
echo -e "\n${YELLOW}Step 10: Uninstalling PM2...${NC}"
if command -v pm2 &> /dev/null; then
    safe_exec "sudo npm uninstall -g pm2" "Uninstalled PM2"
fi

# Clean package manager caches
echo -e "\n${YELLOW}Step 11: Cleaning caches...${NC}"
safe_exec "sudo apt-get clean" "Cleaned apt cache"
safe_exec "sudo apt-get autoremove -y" "Removed unused packages"
safe_exec "npm cache clean --force" "Cleaned npm cache"

# Final cleanup
echo -e "\n${YELLOW}Step 12: Final cleanup...${NC}"
safe_exec "sudo rm -rf /var/log/trivia-*" "Removed application logs"
safe_exec "sudo rm -rf /tmp/trivia-*" "Removed temp files"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    RESET COMPLETE                           ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  Your server has been reset to a blank state.               ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  Remaining installed packages:                              ║${NC}"
echo -e "${GREEN}║  • Node.js (if it was installed system-wide)                ║${NC}"
echo -e "${GREEN}║  • PostgreSQL (service still running)                       ║${NC}"
echo -e "${GREEN}║  • Nginx (service still running)                            ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  To do a fresh deployment, run:                             ║${NC}"
echo -e "${GREEN}║  ./deploy/scripts/setup-server.sh                           ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${YELLOW}System packages status:${NC}"
echo -n "Node.js: "; node --version 2>/dev/null || echo "Not installed"
echo -n "PostgreSQL: "; sudo -u postgres psql --version 2>/dev/null || echo "Not installed"
echo -n "Nginx: "; nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+' || echo "Not installed"

echo ""
echo -e "${GREEN}Reset script completed successfully.${NC}"