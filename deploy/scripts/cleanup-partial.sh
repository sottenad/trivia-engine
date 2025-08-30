#!/bin/bash

# ==============================================================================
# TRIVIA ENGINE - CLEANUP PARTIAL INSTALLATION
# ==============================================================================
# Use this script to clean up a partial or failed installation
# before running setup-server.sh again
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
DOMAIN="trivia-engine.com"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        TRIVIA ENGINE - CLEANUP PARTIAL INSTALLATION         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}This will clean up a partial installation to allow a fresh setup.${NC}"
echo -e "${YELLOW}It will NOT remove installed packages or system configurations.${NC}"
echo ""
echo -n "Continue? (yes/no): "
read confirmation

if [ "$confirmation" != "yes" ]; then
    echo -e "${GREEN}Cleanup cancelled.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}Starting cleanup...${NC}"

# Stop any running services
echo -e "\n${YELLOW}Stopping services if running...${NC}"
sudo systemctl stop trivia-api 2>/dev/null || true
sudo systemctl stop trivia-marketing 2>/dev/null || true
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true

# Remove application directory
if [ -d "${APP_DIR}" ]; then
    echo -e "${YELLOW}Removing application directory...${NC}"
    sudo rm -rf ${APP_DIR}
    echo -e "${GREEN}✓${NC} Application directory removed"
else
    echo -e "${GREEN}✓${NC} Application directory doesn't exist"
fi

# Remove environment files
if [ -d "/home/${APP_USER}" ]; then
    echo -e "${YELLOW}Cleaning up home directory...${NC}"
    sudo rm -rf /home/${APP_USER}/logs 2>/dev/null || true
    sudo rm -rf /home/${APP_USER}/backups 2>/dev/null || true
    sudo rm -rf /home/${APP_USER}/.pm2 2>/dev/null || true
    sudo rm -f /home/${APP_USER}/backup.sh 2>/dev/null || true
    sudo rm -f /home/${APP_USER}/deployment-info.txt 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Home directory cleaned"
fi

# Remove Nginx configuration
if [ -f "/etc/nginx/sites-available/trivia-engine" ]; then
    echo -e "${YELLOW}Removing Nginx configuration...${NC}"
    sudo rm -f /etc/nginx/sites-enabled/trivia-engine
    sudo rm -f /etc/nginx/sites-available/trivia-engine
    sudo nginx -t && sudo systemctl reload nginx
    echo -e "${GREEN}✓${NC} Nginx configuration removed"
fi

# Remove systemd services
if [ -f "/etc/systemd/system/trivia-api.service" ]; then
    echo -e "${YELLOW}Removing systemd services...${NC}"
    sudo systemctl disable trivia-api 2>/dev/null || true
    sudo systemctl disable trivia-marketing 2>/dev/null || true
    sudo rm -f /etc/systemd/system/trivia-api.service
    sudo rm -f /etc/systemd/system/trivia-marketing.service
    sudo systemctl daemon-reload
    echo -e "${GREEN}✓${NC} Systemd services removed"
fi

# Clear PM2
if command -v pm2 &> /dev/null; then
    echo -e "${YELLOW}Clearing PM2...${NC}"
    pm2 kill 2>/dev/null || true
    echo -e "${GREEN}✓${NC} PM2 cleared"
fi

# Optional: Drop databases (commented out for safety)
echo -e "\n${YELLOW}Note: Databases have been preserved.${NC}"
echo -e "${YELLOW}To drop databases, run:${NC}"
echo -e "  sudo -u postgres psql -c \"DROP DATABASE IF EXISTS trivia_engine;\""
echo -e "  sudo -u postgres psql -c \"DROP DATABASE IF EXISTS trivia_engine_test;\""

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   CLEANUP COMPLETE                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}You can now run the setup script again:${NC}"
echo -e "  ${YELLOW}./deploy/scripts/setup-server.sh${NC}"
echo ""
echo -e "${BLUE}What was cleaned:${NC}"
echo -e "  • Application directory (${APP_DIR})"
echo -e "  • PM2 processes and configuration"
echo -e "  • Nginx site configuration"
echo -e "  • Systemd services"
echo -e "  • Log and backup directories"
echo ""
echo -e "${BLUE}What was preserved:${NC}"
echo -e "  • System packages (Node.js, PostgreSQL, Nginx, PM2)"
echo -e "  • PostgreSQL databases"
echo -e "  • SSL certificates"
echo -e "  • User account (${APP_USER})"
echo ""