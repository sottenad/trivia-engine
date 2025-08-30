#!/bin/bash

# ==============================================================================
# TRIVIA ENGINE - HEALTH CHECK SCRIPT
# ==============================================================================
# This script checks the health of all Trivia Engine services
# Can be run manually or via cron for monitoring
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="trivia-engine.com"
API_URL="http://localhost:3003/api/v1/health"
MARKETING_URL="http://localhost:3000"
PUBLIC_API_URL="https://${DOMAIN}/api/v1/health"
PUBLIC_SITE_URL="https://${DOMAIN}"
LOG_FILE="/home/trivia/logs/health-check.log"
ALERT_EMAIL="admin@trivia-engine.com"
SEND_ALERTS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --alert)
            SEND_ALERTS=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Status tracking
ERRORS=0
WARNINGS=0

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    if [ "$VERBOSE" = true ]; then
        echo "$1"
    fi
}

# Check function
check_service() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_code" ]; then
        echo -e "${GREEN}✓${NC} $name is healthy (HTTP $response)"
        log "✓ $name is healthy (HTTP $response)"
        return 0
    elif [ "$response" = "000" ]; then
        echo -e "${RED}✗${NC} $name is unreachable"
        log "✗ $name is unreachable"
        ((ERRORS++))
        return 1
    else
        echo -e "${YELLOW}⚠${NC} $name returned HTTP $response (expected $expected_code)"
        log "⚠ $name returned HTTP $response (expected $expected_code)"
        ((WARNINGS++))
        return 1
    fi
}

# Start health checks
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           TRIVIA ENGINE - HEALTH CHECK                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Checking services at $(date)${NC}"
echo ""

# Check system resources
echo -e "${BLUE}System Resources:${NC}"

# Memory check
MEM_USAGE=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
MEM_AVAILABLE=$(free -m | awk 'NR==2{printf "%d", $7}')
if (( $(echo "$MEM_USAGE > 90" | bc -l) )); then
    echo -e "${RED}✗${NC} Memory usage critical: ${MEM_USAGE}% (${MEM_AVAILABLE}MB available)"
    ((ERRORS++))
elif (( $(echo "$MEM_USAGE > 80" | bc -l) )); then
    echo -e "${YELLOW}⚠${NC} Memory usage high: ${MEM_USAGE}% (${MEM_AVAILABLE}MB available)"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} Memory usage: ${MEM_USAGE}% (${MEM_AVAILABLE}MB available)"
fi

# Disk check
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
DISK_AVAILABLE=$(df -h / | awk 'NR==2{print $4}')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo -e "${RED}✗${NC} Disk usage critical: ${DISK_USAGE}% (${DISK_AVAILABLE} available)"
    ((ERRORS++))
elif [ "$DISK_USAGE" -gt 80 ]; then
    echo -e "${YELLOW}⚠${NC} Disk usage high: ${DISK_USAGE}% (${DISK_AVAILABLE} available)"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} Disk usage: ${DISK_USAGE}% (${DISK_AVAILABLE} available)"
fi

# CPU load check
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
CPU_COUNT=$(nproc)
LOAD_RATIO=$(echo "scale=2; $LOAD_AVG / $CPU_COUNT" | bc)
if (( $(echo "$LOAD_RATIO > 2" | bc -l) )); then
    echo -e "${RED}✗${NC} CPU load critical: ${LOAD_AVG} (${CPU_COUNT} cores)"
    ((ERRORS++))
elif (( $(echo "$LOAD_RATIO > 1" | bc -l) )); then
    echo -e "${YELLOW}⚠${NC} CPU load high: ${LOAD_AVG} (${CPU_COUNT} cores)"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} CPU load: ${LOAD_AVG} (${CPU_COUNT} cores)"
fi

echo ""

# Check services
echo -e "${BLUE}Service Status:${NC}"

# Check PostgreSQL
if systemctl is-active --quiet postgresql; then
    echo -e "${GREEN}✓${NC} PostgreSQL is running"
    # Check database connection
    if sudo -u postgres psql -c "SELECT 1" &>/dev/null; then
        echo -e "${GREEN}✓${NC} PostgreSQL connection successful"
    else
        echo -e "${RED}✗${NC} PostgreSQL connection failed"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗${NC} PostgreSQL is not running"
    ((ERRORS++))
fi

# Check Nginx
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓${NC} Nginx is running"
    # Test Nginx configuration
    if sudo nginx -t &>/dev/null; then
        echo -e "${GREEN}✓${NC} Nginx configuration valid"
    else
        echo -e "${RED}✗${NC} Nginx configuration invalid"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗${NC} Nginx is not running"
    ((ERRORS++))
fi

# Check PM2
if pm2 list &>/dev/null; then
    PM2_STATUS=$(pm2 jlist 2>/dev/null)
    if [ ! -z "$PM2_STATUS" ]; then
        echo -e "${GREEN}✓${NC} PM2 is running"
        
        # Check individual PM2 processes
        API_STATUS=$(echo "$PM2_STATUS" | jq -r '.[] | select(.name=="trivia-api") | .pm2_env.status' 2>/dev/null || echo "stopped")
        MARKETING_STATUS=$(echo "$PM2_STATUS" | jq -r '.[] | select(.name=="trivia-marketing") | .pm2_env.status' 2>/dev/null || echo "stopped")
        MCP_STATUS=$(echo "$PM2_STATUS" | jq -r '.[] | select(.name=="trivia-mcp") | .pm2_env.status' 2>/dev/null || echo "stopped")
        
        if [ "$API_STATUS" = "online" ]; then
            echo -e "${GREEN}✓${NC} API process is online"
        else
            echo -e "${RED}✗${NC} API process status: $API_STATUS"
            ((ERRORS++))
        fi
        
        if [ "$MARKETING_STATUS" = "online" ]; then
            echo -e "${GREEN}✓${NC} Marketing process is online"
        else
            echo -e "${RED}✗${NC} Marketing process status: $MARKETING_STATUS"
            ((ERRORS++))
        fi
        
        if [ "$MCP_STATUS" = "online" ] || [ "$MCP_STATUS" = "stopped" ]; then
            echo -e "${GREEN}✓${NC} MCP process status: $MCP_STATUS"
        else
            echo -e "${YELLOW}⚠${NC} MCP process status: $MCP_STATUS"
            ((WARNINGS++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} PM2 has no processes"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} PM2 is not running"
    ((ERRORS++))
fi

echo ""

# Check endpoints
echo -e "${BLUE}Endpoint Health:${NC}"

# Local endpoints
check_service "API (local)" "$API_URL"
check_service "Marketing (local)" "$MARKETING_URL"

# Public endpoints
check_service "API (public)" "$PUBLIC_API_URL"
check_service "Website (public)" "$PUBLIC_SITE_URL"

# Check SSL certificate
echo ""
echo -e "${BLUE}SSL Certificate:${NC}"
CERT_EXPIRY=$(echo | openssl s_client -servername ${DOMAIN} -connect ${DOMAIN}:443 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ ! -z "$CERT_EXPIRY" ]; then
    EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
    
    if [ $DAYS_LEFT -lt 7 ]; then
        echo -e "${RED}✗${NC} SSL certificate expires in $DAYS_LEFT days!"
        ((ERRORS++))
    elif [ $DAYS_LEFT -lt 30 ]; then
        echo -e "${YELLOW}⚠${NC} SSL certificate expires in $DAYS_LEFT days"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✓${NC} SSL certificate valid for $DAYS_LEFT days"
    fi
else
    echo -e "${YELLOW}⚠${NC} Could not check SSL certificate"
    ((WARNINGS++))
fi

# Check recent logs for errors
echo ""
echo -e "${BLUE}Recent Errors:${NC}"
ERROR_COUNT=$(grep -c ERROR /home/trivia/logs/*.log 2>/dev/null | awk -F: '{sum+=$2} END {print sum}' || echo 0)
if [ "$ERROR_COUNT" -gt 100 ]; then
    echo -e "${RED}✗${NC} Found $ERROR_COUNT errors in logs"
    ((WARNINGS++))
elif [ "$ERROR_COUNT" -gt 10 ]; then
    echo -e "${YELLOW}⚠${NC} Found $ERROR_COUNT errors in logs"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} Found $ERROR_COUNT errors in logs"
fi

# Summary
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}║                 ALL SYSTEMS OPERATIONAL                     ║${NC}"
    STATUS="HEALTHY"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}║              SYSTEMS OPERATIONAL WITH WARNINGS              ║${NC}"
    STATUS="WARNING"
else
    echo -e "${RED}║                   CRITICAL ISSUES DETECTED                  ║${NC}"
    STATUS="CRITICAL"
fi
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "Errors: ${RED}$ERRORS${NC} | Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "Status: $STATUS"
echo -e "Check completed at $(date)"

# Log summary
log "Health check completed - Status: $STATUS, Errors: $ERRORS, Warnings: $WARNINGS"

# Send alert if needed
if [ "$SEND_ALERTS" = true ] && [ $ERRORS -gt 0 ]; then
    ALERT_MSG="Trivia Engine Health Check Alert\n\nStatus: $STATUS\nErrors: $ERRORS\nWarnings: $WARNINGS\n\nCheck the logs for details: $LOG_FILE"
    
    # Send email alert (requires mail command configured)
    if command -v mail &> /dev/null; then
        echo -e "$ALERT_MSG" | mail -s "[$STATUS] Trivia Engine Health Check" "$ALERT_EMAIL"
        echo "Alert sent to $ALERT_EMAIL"
    fi
    
    # You can also add webhook notifications here
    # curl -X POST "your-webhook-url" -H "Content-Type: application/json" \
    #   -d "{\"text\":\"Health check status: $STATUS - Errors: $ERRORS, Warnings: $WARNINGS\"}"
fi

# Exit with appropriate code
if [ $ERRORS -gt 0 ]; then
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    exit 2
else
    exit 0
fi