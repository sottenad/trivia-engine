#!/bin/bash

# ==============================================================================
# TRIVIA ENGINE - COMPLETE REBUILD SCRIPT
# ==============================================================================
# This script completely rebuilds the application including:
# - Drops and recreates the database
# - Reruns all migrations from scratch
# - Rebuilds all application components
# - Restarts all services
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
DB_NAME="trivia_engine"
DB_USER="trivia"
BACKUP_DIR="/home/${APP_USER}/backups"
LOG_FILE="/home/${APP_USER}/logs/rebuild-$(date +%Y%m%d_%H%M%S).log"

# Parse command line arguments
SKIP_BACKUP=false
SEED_DATA=false
CLEAN_INSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --seed)
            SEED_DATA=true
            shift
            ;;
        --clean)
            CLEAN_INSTALL=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-backup    Skip database backup before rebuild"
            echo "  --seed           Load seed data after rebuild"
            echo "  --clean          Clean install (remove node_modules)"
            echo "  --help           Show this help message"
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
        exit 1
    fi
}

# Start rebuild
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           TRIVIA ENGINE - COMPLETE REBUILD                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}This will completely rebuild your application!${NC}"
echo -e "${YELLOW}Skip backup: ${SKIP_BACKUP}${NC}"
echo -e "${YELLOW}Load seed data: ${SEED_DATA}${NC}"
echo -e "${YELLOW}Clean install: ${CLEAN_INSTALL}${NC}"
echo ""
echo -e "${RED}WARNING: This will DROP and RECREATE your database!${NC}"
echo ""
echo -n "Are you sure you want to continue? (yes/no): "
read confirmation

if [ "$confirmation" != "yes" ]; then
    echo -e "${GREEN}Rebuild cancelled.${NC}"
    exit 0
fi

# Create log directory if it doesn't exist
mkdir -p /home/${APP_USER}/logs

# Load environment variables
if [ -f "${APP_DIR}/app/.env" ]; then
    export $(cat ${APP_DIR}/app/.env | grep -v '^#' | xargs)
fi

# Backup current database
if [ "$SKIP_BACKUP" != true ]; then
    echo -e "\n${YELLOW}Step 1: Backing up current database...${NC}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/pre-rebuild-${TIMESTAMP}.sql.gz"
    
    # Check if database exists before trying to backup
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw ${DB_NAME}; then
        pg_dump $DATABASE_URL | gzip > "${BACKUP_FILE}"
        check_status "Database backed up to ${BACKUP_FILE}"
    else
        echo -e "${YELLOW}Database doesn't exist, skipping backup${NC}"
    fi
else
    echo -e "\n${YELLOW}Step 1: Skipping database backup${NC}"
fi

# Stop all services
echo -e "\n${YELLOW}Step 2: Stopping all services...${NC}"
pm2 stop all || echo "PM2 processes stopped (or not running)"
check_status "Services stopped"

# Drop and recreate database
echo -e "\n${YELLOW}Step 3: Dropping and recreating database...${NC}"

# Get database password from .env or prompt
if [ -z "$DATABASE_URL" ]; then
    echo -n "Enter PostgreSQL password for user ${DB_USER}: "
    read -s DB_PASSWORD
    echo ""
else
    # Extract password from DATABASE_URL
    DB_PASSWORD=$(echo $DATABASE_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
fi

sudo -u postgres psql <<EOF
-- Drop existing connections to the database
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();

-- Drop and recreate databases
DROP DATABASE IF EXISTS ${DB_NAME};
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};

DROP DATABASE IF EXISTS ${DB_NAME}_test;
CREATE DATABASE ${DB_NAME}_test OWNER ${DB_USER};

-- Ensure user has all privileges
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME}_test TO ${DB_USER};
EOF
check_status "Database recreated"

# Clean install if requested
if [ "$CLEAN_INSTALL" = true ]; then
    echo -e "\n${YELLOW}Step 4: Performing clean install (removing node_modules)...${NC}"
    rm -rf ${APP_DIR}/app/node_modules
    rm -rf ${APP_DIR}/marketing/node_modules
    rm -rf ${APP_DIR}/mcp/node_modules
    check_status "node_modules removed"
fi

# Pull latest code
echo -e "\n${YELLOW}Step 5: Pulling latest code...${NC}"
cd ${APP_DIR}
git pull origin main
check_status "Latest code pulled"

# Install dependencies and rebuild API
echo -e "\n${YELLOW}Step 6: Rebuilding API...${NC}"
cd ${APP_DIR}/app
npm install
check_status "API dependencies installed"

# Generate Prisma client and run migrations
echo -e "\n${YELLOW}Step 7: Running database migrations...${NC}"
npx prisma generate
check_status "Prisma client generated"
npx prisma migrate deploy
check_status "Database migrations completed"

# Seed database if requested
if [ "$SEED_DATA" = true ]; then
    echo -e "\n${YELLOW}Step 8: Seeding database...${NC}"
    if [ -f "${APP_DIR}/deploy/database/seed.sql" ]; then
        psql $DATABASE_URL < ${APP_DIR}/deploy/database/seed.sql
        check_status "Database seeded"
    elif [ -f "prisma/seed.js" ] || [ -f "prisma/seed.ts" ]; then
        npx prisma db seed
        check_status "Database seeded with Prisma"
    else
        echo -e "${YELLOW}No seed file found${NC}"
    fi
else
    echo -e "\n${YELLOW}Step 8: Skipping database seeding${NC}"
fi

# Rebuild Marketing site
echo -e "\n${YELLOW}Step 9: Rebuilding marketing site...${NC}"
cd ${APP_DIR}/marketing
npm install
check_status "Marketing dependencies installed"
npm run build
check_status "Marketing site built"

# Rebuild MCP server
echo -e "\n${YELLOW}Step 10: Rebuilding MCP server...${NC}"
cd ${APP_DIR}/mcp
npm install
check_status "MCP dependencies installed"
npm run build
check_status "MCP server built"

# Clear all caches
echo -e "\n${YELLOW}Step 11: Clearing all caches...${NC}"

# Clear PM2 logs
pm2 flush
echo -e "${GREEN}✓${NC} PM2 logs cleared"

# Clear Nginx cache
if [ -d "/var/cache/nginx" ]; then
    sudo rm -rf /var/cache/nginx/*
    echo -e "${GREEN}✓${NC} Nginx cache cleared"
fi

# Clear npm cache
npm cache clean --force
echo -e "${GREEN}✓${NC} npm cache cleared"

# Clear Next.js cache
rm -rf ${APP_DIR}/marketing/.next/cache
echo -e "${GREEN}✓${NC} Next.js cache cleared"

# Restart all services
echo -e "\n${YELLOW}Step 12: Starting all services...${NC}"
cd ${APP_DIR}
pm2 start deploy/config/ecosystem.config.js --env production
check_status "Services started"

# Save PM2 configuration
pm2 save
check_status "PM2 configuration saved"

# Wait for services to stabilize
echo -e "\n${YELLOW}Step 13: Waiting for services to stabilize...${NC}"
sleep 10

# Health checks
echo -e "\n${YELLOW}Step 14: Running health checks...${NC}"

# Check API
API_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3003/api/v1/health)
if [ "$API_HEALTH" = "200" ]; then
    echo -e "${GREEN}✓${NC} API is healthy"
else
    echo -e "${RED}✗${NC} API health check failed (HTTP ${API_HEALTH})"
fi

# Check Marketing site
MARKETING_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
if [ "$MARKETING_HEALTH" = "200" ]; then
    echo -e "${GREEN}✓${NC} Marketing site is healthy"
else
    echo -e "${YELLOW}⚠${NC} Marketing site health check returned HTTP ${MARKETING_HEALTH}"
fi

# Verify database
echo -e "\n${YELLOW}Step 15: Verifying database...${NC}"
DB_CHECK=$(psql $DATABASE_URL -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" -t 2>/dev/null | tr -d ' ')
if [ "$DB_CHECK" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Database has $DB_CHECK tables"
else
    echo -e "${RED}✗${NC} Database appears to be empty"
fi

# Log rebuild info
cat >> ${LOG_FILE} <<EOF

Rebuild Summary
===============
Date: $(date)
Clean Install: ${CLEAN_INSTALL}
Seed Data: ${SEED_DATA}
Database Tables: ${DB_CHECK}

Service Status:
$(pm2 list --no-color)

Health Check Results:
- API: HTTP ${API_HEALTH}
- Marketing: HTTP ${MARKETING_HEALTH}

EOF

# Final summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            REBUILD COMPLETED SUCCESSFULLY!                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Rebuild Details:${NC}"
echo -e "  • Database: ${GREEN}Recreated with ${DB_CHECK} tables${NC}"
echo -e "  • API: ${GREEN}Running on port 3003${NC}"
echo -e "  • Marketing: ${GREEN}Running on port 3000${NC}"
echo -e "  • Log file: ${YELLOW}${LOG_FILE}${NC}"
echo ""
echo -e "${BLUE}Access your application:${NC}"
echo -e "  • Website: ${YELLOW}https://${DOMAIN}${NC}"
echo -e "  • API: ${YELLOW}https://${DOMAIN}/api/v1${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Verify the application is working correctly"
echo -e "  2. Check logs: ${YELLOW}pm2 logs${NC}"
echo -e "  3. Monitor services: ${YELLOW}pm2 monit${NC}"

if [ "$SEED_DATA" != true ]; then
    echo -e "  4. Load data if needed: ${YELLOW}./rebuild-all.sh --seed${NC}"
fi

echo ""
echo -e "${GREEN}Rebuild completed at $(date)${NC}"