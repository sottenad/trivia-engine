#!/bin/bash
# Deployment script for Trivia Engine
# This script handles both initial deployment and updates

set -e  # Exit on error

# Configuration
DEPLOY_USER="trivia"
APP_DIR="/home/$DEPLOY_USER/trivia-engine"
BACKUP_DIR="/home/$DEPLOY_USER/backups"
LOG_DIR="/home/$DEPLOY_USER/logs"
REPO_URL="${REPO_URL:-}"
BRANCH="${BRANCH:-main}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check if running as the deploy user
if [ "$USER" != "$DEPLOY_USER" ]; then
    log_error "This script must be run as the $DEPLOY_USER user"
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            REPO_URL="$2"
            shift 2
            ;;
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
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [--repo <url>] [--branch <name>] [--skip-backup] [--skip-tests]"
            exit 1
            ;;
    esac
done

# Function to backup database
backup_database() {
    log_info "Backing up database..."
    if [ -f "$APP_DIR/app/.env" ]; then
        source "$APP_DIR/app/.env"
        BACKUP_FILE="$BACKUP_DIR/trivia_backup_$(date +%Y%m%d_%H%M%S).sql"
        pg_dump "$DATABASE_URL" > "$BACKUP_FILE"
        gzip "$BACKUP_FILE"
        log_info "Database backed up to ${BACKUP_FILE}.gz"
        
        # Keep only last 7 days of backups
        find "$BACKUP_DIR" -name "trivia_backup_*.sql.gz" -mtime +7 -delete
    else
        log_warning "No .env file found, skipping database backup"
    fi
}

# Function to check service health
check_service_health() {
    local service=$1
    local port=$2
    local max_attempts=30
    local attempt=1
    
    log_info "Checking $service health on port $port..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "http://localhost:$port/api/v1/health" > /dev/null 2>&1; then
            log_info "$service is healthy"
            return 0
        fi
        
        log_info "Waiting for $service to become healthy (attempt $attempt/$max_attempts)..."
        sleep 2
        ((attempt++))
    done
    
    log_error "$service failed to become healthy"
    return 1
}

# Main deployment process
log_info "Starting deployment..."

# Create directories if they don't exist
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Backup database (unless skipped)
if [ "$SKIP_BACKUP" != "true" ]; then
    backup_database
fi

# Clone or update repository
if [ ! -d "$APP_DIR/.git" ]; then
    if [ -z "$REPO_URL" ]; then
        log_error "Repository URL required for initial deployment"
        exit 1
    fi
    log_info "Cloning repository..."
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
    git checkout "$BRANCH"
else
    log_info "Updating repository..."
    cd "$APP_DIR"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
fi

# Deploy API
log_info "Deploying API..."
cd "$APP_DIR/app"

# Install dependencies
log_info "Installing API dependencies..."
npm ci --production

# Run database migrations
if [ -f ".env" ]; then
    log_info "Running database migrations..."
    npx prisma migrate deploy
    log_info "Generating Prisma client..."
    npx prisma generate
else
    log_warning "No .env file found, skipping database migrations"
fi

# Deploy Marketing Site
log_info "Deploying Marketing Site..."
cd "$APP_DIR/marketing"

# Install dependencies
log_info "Installing Marketing dependencies..."
npm ci

# Build the Next.js application
log_info "Building Marketing site..."
npm run build

# Deploy MCP Server (optional)
if [ -d "$APP_DIR/mcp" ]; then
    log_info "Building MCP server..."
    cd "$APP_DIR/mcp"
    npm ci
    npm run build
fi

# Restart services with zero downtime
log_info "Restarting services..."

# API service
if systemctl is-active --quiet trivia-api; then
    log_info "Restarting API service..."
    sudo systemctl reload trivia-api || sudo systemctl restart trivia-api
    
    # Wait for API to be healthy
    if ! check_service_health "API" 3003; then
        log_error "API failed health check after restart"
        # Attempt rollback would go here
        exit 1
    fi
else
    log_warning "API service not running, starting it..."
    sudo systemctl start trivia-api
fi

# Marketing service
if systemctl is-active --quiet trivia-marketing; then
    log_info "Restarting Marketing service..."
    sudo systemctl reload trivia-marketing || sudo systemctl restart trivia-marketing
    
    # Give Next.js time to start
    sleep 5
else
    log_warning "Marketing service not running, starting it..."
    sudo systemctl start trivia-marketing
fi

# Clear nginx cache (if configured)
if [ -d "/var/cache/nginx" ]; then
    log_info "Clearing nginx cache..."
    sudo rm -rf /var/cache/nginx/*
fi

# Run post-deployment tasks
log_info "Running post-deployment tasks..."

# Log deployment
echo "$(date +'%Y-%m-%d %H:%M:%S') - Deployment completed for branch $BRANCH" >> "$LOG_DIR/deployments.log"

# Send notification (if configured)
if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"Trivia Engine deployed successfully to production (branch: $BRANCH)\"}" \
        "$SLACK_WEBHOOK_URL" 2>/dev/null || true
fi

log_info "Deployment completed successfully!"

# Show service status
echo ""
log_info "Service Status:"
sudo systemctl status trivia-api --no-pager | grep "Active:"
sudo systemctl status trivia-marketing --no-pager | grep "Active:"