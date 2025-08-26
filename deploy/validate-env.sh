#!/bin/bash
# Quick environment validation script
# Run this to check if all required environment variables are set

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect environment
if [ -f "/home/trivia/trivia-engine/app/.env" ]; then
    APP_DIR="/home/trivia/trivia-engine"
else
    APP_DIR="$(pwd)"
fi

echo "Checking environment files in: $APP_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check function
check_var() {
    local file=$1
    local var=$2
    if [ -f "$file" ] && grep -q "^${var}=" "$file" && [ -n "$(grep "^${var}=" "$file" | cut -d'=' -f2-)" ]; then
        echo -e "${GREEN}✓${NC} $var"
        return 0
    else
        echo -e "${RED}✗${NC} $var"
        return 1
    fi
}

# API Environment
echo -e "\n${YELLOW}API Environment ($APP_DIR/app/.env):${NC}"
if [ -f "$APP_DIR/app/.env" ]; then
    check_var "$APP_DIR/app/.env" "NODE_ENV"
    check_var "$APP_DIR/app/.env" "DATABASE_URL"
    check_var "$APP_DIR/app/.env" "JWT_SECRET"
    check_var "$APP_DIR/app/.env" "CORS_ORIGIN"
    
    # Test database connection
    if command -v psql &> /dev/null; then
        source "$APP_DIR/app/.env"
        if psql "$DATABASE_URL" -c "SELECT 1" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Database connection OK"
        else
            echo -e "${RED}✗${NC} Database connection FAILED"
        fi
    fi
else
    echo -e "${RED}File not found!${NC}"
fi

# Marketing Environment
echo -e "\n${YELLOW}Marketing Environment ($APP_DIR/marketing/.env.local):${NC}"
if [ -f "$APP_DIR/marketing/.env.local" ]; then
    check_var "$APP_DIR/marketing/.env.local" "NEXT_PUBLIC_API_BASE_URL"
    check_var "$APP_DIR/marketing/.env.local" "NEXT_PUBLIC_API_KEY"
else
    echo -e "${RED}File not found!${NC}"
fi

# MCP Environment (optional)
if [ -d "$APP_DIR/mcp" ]; then
    echo -e "\n${YELLOW}MCP Environment ($APP_DIR/mcp/.env):${NC}"
    if [ -f "$APP_DIR/mcp/.env" ]; then
        check_var "$APP_DIR/mcp/.env" "TRIVIA_API_BASE_URL"
        check_var "$APP_DIR/mcp/.env" "TRIVIA_API_KEY"
    else
        echo -e "${RED}File not found!${NC}"
    fi
fi

# Check file permissions
echo -e "\n${YELLOW}File Permissions:${NC}"
for file in "$APP_DIR/app/.env" "$APP_DIR/marketing/.env.local" "$APP_DIR/mcp/.env"; do
    if [ -f "$file" ]; then
        perms=$(stat -c %a "$file" 2>/dev/null || stat -f %p "$file" 2>/dev/null | tail -c 4)
        if [ "$perms" = "600" ]; then
            echo -e "${GREEN}✓${NC} $file (600)"
        else
            echo -e "${YELLOW}!${NC} $file ($perms) - should be 600"
        fi
    fi
done

echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"