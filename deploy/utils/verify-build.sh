#!/bin/bash

# ==============================================================================
# TRIVIA ENGINE - BUILD VERIFICATION SCRIPT
# ==============================================================================
# This script verifies that all components can build successfully
# Run this before deployment to catch issues early
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="${1:-/home/trivia/trivia-engine}"
ERRORS=0
WARNINGS=0

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           TRIVIA ENGINE - BUILD VERIFICATION                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Checking build for all components...${NC}"
echo ""

# Function to check build
check_build() {
    local component=$1
    local dir=$2
    local build_cmd=${3:-"npm run build"}
    
    echo -e "${BLUE}Checking ${component}...${NC}"
    
    if [ ! -d "$dir" ]; then
        echo -e "${RED}✗${NC} Directory not found: $dir"
        ((ERRORS++))
        return 1
    fi
    
    cd "$dir"
    
    # Check package.json exists
    if [ ! -f "package.json" ]; then
        echo -e "${RED}✗${NC} No package.json found in $dir"
        ((ERRORS++))
        return 1
    fi
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}⚠${NC} No node_modules found. Running npm install..."
        npm install
    fi
    
    # Try to build
    echo "  Running: $build_cmd"
    if eval "$build_cmd" > /tmp/build-${component}.log 2>&1; then
        echo -e "${GREEN}✓${NC} ${component} build successful"
        return 0
    else
        echo -e "${RED}✗${NC} ${component} build failed"
        echo -e "${YELLOW}  See /tmp/build-${component}.log for details${NC}"
        tail -10 /tmp/build-${component}.log
        ((ERRORS++))
        return 1
    fi
}

# Check Node.js version
echo -e "${BLUE}Node.js version:${NC}"
node --version
if [[ $(node --version | cut -d'.' -f1 | sed 's/v//') -lt 18 ]]; then
    echo -e "${RED}✗${NC} Node.js version must be 18 or higher"
    ((ERRORS++))
fi
echo ""

# Check npm version
echo -e "${BLUE}npm version:${NC}"
npm --version
echo ""

# Check API
check_build "API" "${APP_DIR}/app" "echo 'No build required for API'"

# Check if Prisma can generate
echo -e "${BLUE}Checking Prisma generation...${NC}"
cd "${APP_DIR}/app"
if npx prisma generate > /tmp/prisma-generate.log 2>&1; then
    echo -e "${GREEN}✓${NC} Prisma client generated successfully"
else
    echo -e "${RED}✗${NC} Prisma generation failed"
    cat /tmp/prisma-generate.log
    ((ERRORS++))
fi
echo ""

# Check Marketing site
check_build "Marketing Site" "${APP_DIR}/marketing" "npm run build"
echo ""

# Check MCP server
check_build "MCP Server" "${APP_DIR}/mcp" "npm run build"
echo ""

# Check for security vulnerabilities
echo -e "${BLUE}Security audit:${NC}"
cd "${APP_DIR}/app"
AUDIT_RESULT=$(npm audit --json 2>/dev/null | jq -r '.metadata.vulnerabilities | to_entries[] | "\(.key): \(.value)"' 2>/dev/null || echo "Unable to parse audit results")
if [ "$AUDIT_RESULT" != "Unable to parse audit results" ]; then
    echo "$AUDIT_RESULT"
    if echo "$AUDIT_RESULT" | grep -q "critical: [1-9]"; then
        echo -e "${RED}⚠ Critical vulnerabilities found${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠${NC} Could not run security audit"
fi
echo ""

# Summary
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}║                 BUILD VERIFICATION PASSED                   ║${NC}"
else
    echo -e "${RED}║                 BUILD VERIFICATION FAILED                   ║${NC}"
fi
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Errors: ${RED}$ERRORS${NC} | Warnings: ${YELLOW}$WARNINGS${NC}"

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}To see detailed error logs:${NC}"
    echo "  • API: /tmp/build-API.log"
    echo "  • Marketing: /tmp/build-Marketing Site.log"
    echo "  • MCP: /tmp/build-MCP Server.log"
    echo "  • Prisma: /tmp/prisma-generate.log"
    exit 1
fi

echo ""
echo -e "${GREEN}All components build successfully!${NC}"
exit 0