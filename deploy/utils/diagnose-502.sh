#!/bin/bash

# ==============================================================================
# TRIVIA ENGINE - 502 BAD GATEWAY DIAGNOSTIC SCRIPT
# ==============================================================================
# This script helps diagnose why you're getting 502 errors
# Run as root on your server: bash diagnose-502.sh
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         502 BAD GATEWAY DIAGNOSTIC                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Check PM2 Status
echo -e "${YELLOW}1. Checking PM2 processes...${NC}"
echo "Current user: $(whoami)"
echo ""

# Check as root
echo "PM2 processes as root:"
pm2 list || echo "No PM2 processes running as root"
echo ""

# Check as trivia user
echo "PM2 processes as trivia user:"
sudo -u trivia PM2_HOME=/home/trivia/.pm2 pm2 list || echo "No PM2 processes running as trivia"
echo ""

# 2. Check if services are listening on ports
echo -e "${YELLOW}2. Checking port bindings...${NC}"
echo "Port 3003 (API):"
sudo netstat -tlnp | grep :3003 || echo "  ✗ Nothing listening on port 3003"
echo ""
echo "Port 3000 (Marketing):"
sudo netstat -tlnp | grep :3000 || echo "  ✗ Nothing listening on port 3000"
echo ""

# 3. Test localhost connections
echo -e "${YELLOW}3. Testing direct connections...${NC}"
echo "Testing API on localhost:3003:"
curl -s -o /dev/null -w "  HTTP Status: %{http_code}\n" http://localhost:3003/api/v1/health || echo "  ✗ API not responding"
echo ""
echo "Testing Marketing on localhost:3000:"
curl -s -o /dev/null -w "  HTTP Status: %{http_code}\n" http://localhost:3000 || echo "  ✗ Marketing site not responding"
echo ""

# 4. Check Nginx status and errors
echo -e "${YELLOW}4. Checking Nginx...${NC}"
sudo systemctl status nginx --no-pager | head -10
echo ""
echo "Recent Nginx errors:"
sudo tail -5 /var/log/nginx/error.log 2>/dev/null || echo "No error log found"
echo ""
echo "Trivia Engine specific errors:"
sudo tail -5 /var/log/nginx/trivia-engine.error.log 2>/dev/null || echo "No trivia-engine error log"
echo ""

# 5. Check application logs
echo -e "${YELLOW}5. Checking application logs...${NC}"
echo "API logs (trivia user):"
if [ -f /home/trivia/logs/api-error.log ]; then
    sudo tail -10 /home/trivia/logs/api-error.log
else
    echo "  No API error log found"
fi
echo ""
echo "Marketing logs (trivia user):"
if [ -f /home/trivia/logs/marketing-error.log ]; then
    sudo tail -10 /home/trivia/logs/marketing-error.log
else
    echo "  No Marketing error log found"
fi
echo ""

# 6. Check environment files
echo -e "${YELLOW}6. Checking environment files...${NC}"
echo "API .env exists:"
[ -f /home/trivia/trivia-engine/app/.env ] && echo "  ✓ Yes" || echo "  ✗ No"
echo "Marketing .env.local exists:"
[ -f /home/trivia/trivia-engine/marketing/.env.local ] && echo "  ✓ Yes" || echo "  ✗ No"
echo ""

# 7. Check database connection
echo -e "${YELLOW}7. Testing database connection...${NC}"
if [ -f /home/trivia/trivia-engine/app/.env ]; then
    export $(cat /home/trivia/trivia-engine/app/.env | grep DATABASE_URL | xargs)
    if [ ! -z "$DATABASE_URL" ]; then
        psql $DATABASE_URL -c "SELECT 1" &>/dev/null && echo "  ✓ Database connection successful" || echo "  ✗ Database connection failed"
    else
        echo "  ✗ DATABASE_URL not found in .env"
    fi
else
    echo "  ✗ Cannot test - .env file missing"
fi
echo ""

# 8. Check file permissions
echo -e "${YELLOW}8. Checking file permissions...${NC}"
echo "App directory owner:"
ls -ld /home/trivia/trivia-engine | awk '{print "  Owner: " $3 ", Group: " $4}'
echo "Node modules exist:"
[ -d /home/trivia/trivia-engine/app/node_modules ] && echo "  ✓ API node_modules" || echo "  ✗ API node_modules missing"
[ -d /home/trivia/trivia-engine/marketing/node_modules ] && echo "  ✓ Marketing node_modules" || echo "  ✗ Marketing node_modules missing"
echo ""

# 9. Check ecosystem config
echo -e "${YELLOW}9. Checking PM2 ecosystem config...${NC}"
if [ -f /home/trivia/trivia-engine/deploy/config/ecosystem.config.js ]; then
    echo "  ✓ Ecosystem config exists"
    echo "  Location: /home/trivia/trivia-engine/deploy/config/ecosystem.config.js"
else
    echo "  ✗ Ecosystem config not found"
fi
echo ""

# 10. System resources
echo -e "${YELLOW}10. System resources...${NC}"
echo "Memory:"
free -h | grep Mem | awk '{print "  Total: " $2 ", Used: " $3 ", Free: " $4}'
echo "Disk:"
df -h / | tail -1 | awk '{print "  Total: " $2 ", Used: " $3 ", Available: " $4 ", Use: " $5}'
echo ""

# Summary and recommendations
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    DIAGNOSIS SUMMARY                        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

ISSUES=0

# Check for common issues
if ! sudo netstat -tlnp | grep -q :3003; then
    echo -e "${RED}Issue $((++ISSUES)):${NC} API not running on port 3003"
    echo "  Fix: Start the API with PM2 as trivia user"
fi

if ! sudo netstat -tlnp | grep -q :3000; then
    echo -e "${RED}Issue $((++ISSUES)):${NC} Marketing site not running on port 3000"
    echo "  Fix: Start the marketing site with PM2 as trivia user"
fi

if [ "$ISSUES" -eq 0 ]; then
    echo -e "${GREEN}No obvious issues found. Services appear to be running.${NC}"
    echo "Check the logs above for specific errors."
else
    echo ""
    echo -e "${YELLOW}Quick fix commands:${NC}"
    echo ""
    echo "1. Switch to trivia user and restart PM2:"
    echo -e "${GREEN}   sudo su - trivia${NC}"
    echo -e "${GREEN}   cd /home/trivia/trivia-engine${NC}"
    echo -e "${GREEN}   pm2 delete all${NC}"
    echo -e "${GREEN}   pm2 start deploy/config/ecosystem.config.js --env production${NC}"
    echo -e "${GREEN}   pm2 save${NC}"
    echo -e "${GREEN}   exit${NC}"
    echo ""
    echo "2. Or run the quick fix script:"
    echo -e "${GREEN}   bash /home/trivia/trivia-engine/deploy/utils/fix-pm2.sh${NC}"
fi

echo ""
echo "For more detailed logs, run:"
echo "  • PM2 logs: sudo -u trivia pm2 logs"
echo "  • Nginx logs: sudo tail -f /var/log/nginx/trivia-engine.error.log"
echo "  • Journalctl: sudo journalctl -xe"