#!/bin/bash

# ==============================================================================
# TRIVIA ENGINE - DEPLOYMENT SCRIPT
# ==============================================================================
# This script deploys updates to your Trivia Engine application
# It pulls the latest code, builds, and restarts services with zero downtime
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
BACKUP_DIR="/home/${APP_USER}/backups"
LOG_FILE="/home/${APP_USER}/logs/deploy-$(date +%Y%m%d_%H%M%S).log"
BRANCH="main"
SKIP_BACKUP=false
SKIP_TESTS=false
FORCE_DEPLOY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --force)
            FORCE_DEPLOY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --branch <branch>    Deploy from specific branch (default: main)"
            echo "  --skip-backup        Skip database backup"
            echo "  --skip-tests         Skip running tests"
            echo "  --force              Force deployment even if tests fail"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check status function
check_status() {
    if [ $? -eq 0 ]; then
        log "✓ $1"
        echo -e "${GREEN}✓${NC} $1"
    else
        log "✗ $1 failed"
        echo -e "${RED}✗${NC} $1 failed"
        if [ "$FORCE_DEPLOY" != true ]; then
            exit 1
        fi
    fi
}

# Start deployment
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              TRIVIA ENGINE - DEPLOYMENT                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Deploying from branch: ${BRANCH}${NC}"
echo -e "${YELLOW}Skip backup: ${SKIP_BACKUP}${NC}"
echo -e "${YELLOW}Skip tests: ${SKIP_TESTS}${NC}"
echo ""

# Create log directory if it doesn't exist
mkdir -p /home/${APP_USER}/logs

# Check if we're running as the correct user
if [ "$USER" != "$APP_USER" ]; then
    echo -e "${YELLOW}Switching to user ${APP_USER}...${NC}"
    sudo -u ${APP_USER} $0 "$@"
    exit $?
fi

# Save current version info
echo -e "\n${YELLOW}Step 1: Saving current version info...${NC}"
cd ${APP_DIR}
CURRENT_COMMIT=$(git rev-parse HEAD)
log "Current commit: ${CURRENT_COMMIT}"

# Backup database
if [ "$SKIP_BACKUP" != true ]; then
    echo -e "\n${YELLOW}Step 2: Backing up database...${NC}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/pre-deploy-${TIMESTAMP}.sql.gz"
    pg_dump $DATABASE_URL | gzip > "${BACKUP_FILE}"
    check_status "Database backed up to ${BACKUP_FILE}"
else
    echo -e "\n${YELLOW}Step 2: Skipping database backup${NC}"
fi

# Fetch latest code
echo -e "\n${YELLOW}Step 3: Fetching latest code...${NC}"
git fetch origin
check_status "Code fetched from origin"

# Check for changes
CHANGES=$(git diff HEAD origin/${BRANCH} --stat)
if [ -z "$CHANGES" ] && [ "$FORCE_DEPLOY" != true ]; then
    echo -e "${GREEN}No changes detected. Already up to date.${NC}"
    exit 0
fi

# Pull latest code
echo -e "\n${YELLOW}Step 4: Pulling latest code...${NC}"
git checkout ${BRANCH}
git pull origin ${BRANCH}
check_status "Code updated to latest version"

NEW_COMMIT=$(git rev-parse HEAD)
log "New commit: ${NEW_COMMIT}"

# Install/update dependencies for API
echo -e "\n${YELLOW}Step 5: Updating API dependencies...${NC}"
cd ${APP_DIR}/app
if [ -f "package-lock.json" ]; then
    npm ci --production
else
    npm install --production
fi
check_status "API dependencies updated"

# Run database migrations
echo -e "\n${YELLOW}Step 6: Running database migrations...${NC}"
npx prisma generate
check_status "Prisma client generated"
npx prisma migrate deploy
check_status "Database migrations completed"

# Run tests if not skipped
if [ "$SKIP_TESTS" != true ]; then
    echo -e "\n${YELLOW}Step 7: Running tests...${NC}"
    if [ -f "package.json" ] && grep -q "\"test\"" package.json; then
        npm test || {
            echo -e "${YELLOW}Tests failed. Check logs for details.${NC}"
            if [ "$FORCE_DEPLOY" != true ]; then
                echo -e "${RED}Deployment aborted due to test failures.${NC}"
                exit 1
            fi
        }
    else
        echo -e "${YELLOW}No tests configured${NC}"
    fi
else
    echo -e "\n${YELLOW}Step 7: Skipping tests${NC}"
fi

# Build and update Marketing site
echo -e "\n${YELLOW}Step 8: Building marketing site...${NC}"
cd ${APP_DIR}/marketing
if [ -f "package-lock.json" ]; then
    npm ci
else
    npm install
fi
check_status "Marketing dependencies updated"

npm run build
check_status "Marketing site built"

# Build MCP server
echo -e "\n${YELLOW}Step 9: Building MCP server...${NC}"
cd ${APP_DIR}/mcp
if [ -f "package-lock.json" ]; then
    npm ci
else
    npm install
fi
check_status "MCP dependencies updated"

npm run build
check_status "MCP server built"

# Health check before restart
echo -e "\n${YELLOW}Step 10: Performing pre-restart health check...${NC}"
curl -f http://localhost:3003/api/v1/health || echo -e "${YELLOW}API health check failed (may be normal if first deployment)${NC}"

# Restart services with PM2 (zero-downtime reload)
echo -e "\n${YELLOW}Step 11: Restarting services...${NC}"
cd ${APP_DIR}
pm2 reload ecosystem.config.js --env production
check_status "Services restarted with zero downtime"

# Wait for services to stabilize
echo -e "\n${YELLOW}Step 12: Waiting for services to stabilize...${NC}"
sleep 5

# Post-deployment health checks
echo -e "\n${YELLOW}Step 13: Running post-deployment health checks...${NC}"

# Check API
API_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3003/api/v1/health)
if [ "$API_HEALTH" = "200" ]; then
    echo -e "${GREEN}✓${NC} API is healthy"
else
    echo -e "${RED}✗${NC} API health check failed (HTTP ${API_HEALTH})"
    if [ "$FORCE_DEPLOY" != true ]; then
        echo -e "${RED}Rolling back deployment...${NC}"
        git checkout ${CURRENT_COMMIT}
        cd ${APP_DIR}/app && npm ci --production
        cd ${APP_DIR}/marketing && npm ci && npm run build
        cd ${APP_DIR}/mcp && npm ci && npm run build
        pm2 reload ecosystem.config.js --env production
        echo -e "${YELLOW}Rolled back to previous version${NC}"
        exit 1
    fi
fi

# Check Marketing site
MARKETING_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
if [ "$MARKETING_HEALTH" = "200" ]; then
    echo -e "${GREEN}✓${NC} Marketing site is healthy"
else
    echo -e "${YELLOW}⚠${NC} Marketing site health check returned HTTP ${MARKETING_HEALTH}"
fi

# Clear caches
echo -e "\n${YELLOW}Step 14: Clearing caches...${NC}"
# Clear Nginx cache if configured
if [ -d "/var/cache/nginx" ]; then
    sudo rm -rf /var/cache/nginx/*
    echo -e "${GREEN}✓${NC} Nginx cache cleared"
fi

# Clear Node.js cache
npm cache verify
echo -e "${GREEN}✓${NC} npm cache verified"

# Log deployment info
echo -e "\n${YELLOW}Step 15: Logging deployment info...${NC}"
cat >> ${LOG_FILE} <<EOF

Deployment Summary
==================
Date: $(date)
Branch: ${BRANCH}
Previous Commit: ${CURRENT_COMMIT}
New Commit: ${NEW_COMMIT}
Changes:
${CHANGES}

Service Status:
$(pm2 list --no-color)

EOF

# Clean up old backups (keep last 30 days)
echo -e "\n${YELLOW}Step 16: Cleaning up old backups...${NC}"
find ${BACKUP_DIR} -name "*.sql.gz" -mtime +30 -delete
check_status "Old backups cleaned"

# Send deployment notification (optional - requires configuration)
# curl -X POST "your-webhook-url" -H "Content-Type: application/json" \
#   -d "{\"text\":\"Deployment completed successfully on ${DOMAIN}\"}"

# Final summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            DEPLOYMENT COMPLETED SUCCESSFULLY!               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Deployment Details:${NC}"
echo -e "  • Previous version: ${YELLOW}${CURRENT_COMMIT:0:8}${NC}"
echo -e "  • New version: ${YELLOW}${NEW_COMMIT:0:8}${NC}"
echo -e "  • API Status: ${GREEN}Running${NC}"
echo -e "  • Marketing Site: ${GREEN}Running${NC}"
echo -e "  • Log file: ${YELLOW}${LOG_FILE}${NC}"
echo ""
echo -e "${BLUE}Access your application:${NC}"
echo -e "  • Website: ${YELLOW}https://${DOMAIN}${NC}"
echo -e "  • API: ${YELLOW}https://${DOMAIN}/api/v1${NC}"
echo ""
echo -e "${BLUE}Monitor services:${NC}"
echo -e "  • PM2 Dashboard: ${YELLOW}pm2 monit${NC}"
echo -e "  • View logs: ${YELLOW}pm2 logs${NC}"
echo -e "  • Service status: ${YELLOW}pm2 status${NC}"
echo ""
echo -e "${GREEN}Deployment completed at $(date)${NC}"