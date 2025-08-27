#!/bin/bash
# Environment setup and validation script for Trivia Engine
# This script generates secure values and validates configuration

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default options
FORCE_ENV=""
SKIP_DB_CHECK=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --production)
            FORCE_ENV="production"
            shift
            ;;
        --development)
            FORCE_ENV="development"
            shift
            ;;
        --skip-db-check)
            SKIP_DB_CHECK=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --production     Force production environment"
            echo "  --development    Force development environment"
            echo "  --skip-db-check  Skip database connection validation"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Generate secure random string
generate_secret() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Validate PostgreSQL connection string
validate_database_url() {
    local db_url=$1
    
    # Check URL format
    if [[ ! $db_url =~ ^postgresql://[^:]+:[^@]+@[^/]+/[^?]+(\?.*)?$ ]]; then
        print_error "Invalid DATABASE_URL format"
        print_warning "Expected format: postgresql://username:password@host:port/database"
        return 1
    fi
    
    # Skip actual connection test if requested
    if [ "$SKIP_DB_CHECK" = "true" ]; then
        print_warning "Skipping database connection test (--skip-db-check)"
        return 0
    fi
    
    # Try to connect
    if command -v psql &> /dev/null; then
        if psql "$db_url" -c "SELECT 1" &> /dev/null; then
            print_success "Database connection successful"
            return 0
        else
            print_error "Database connection failed"
            print_warning "Make sure PostgreSQL is running and credentials are correct"
            return 1
        fi
    else
        print_warning "psql not installed, cannot test connection"
        return 0
    fi
}

# Main setup
print_header "Trivia Engine Environment Setup"

# Detect environment and find app directory
# Check if we're in a subdirectory of the project
CURRENT_DIR="$(pwd)"
if [[ "$CURRENT_DIR" == */trivia-engine/deploy ]]; then
    APP_DIR="$(dirname "$CURRENT_DIR")"
elif [[ "$CURRENT_DIR" == */trivia-engine ]]; then
    APP_DIR="$CURRENT_DIR"
elif [ -d "/home/trivia/trivia-engine" ]; then
    APP_DIR="/home/trivia/trivia-engine"
else
    print_error "Could not find trivia-engine directory"
    exit 1
fi

# Detect environment type
if [ -n "$FORCE_ENV" ]; then
    ENV_TYPE="$FORCE_ENV"
    print_warning "Using forced environment: $ENV_TYPE"
else
    # Auto-detect environment
    if [[ "$APP_DIR" == "/home/trivia/trivia-engine" ]] || \
       [[ -f /etc/digitalocean ]] || \
       [[ -f /.dockerenv ]] || \
       [[ "$HOSTNAME" == *"droplet"* ]] || \
       [[ "$PWD" == "/root"* ]]; then
        ENV_TYPE="production"
        print_warning "Detected production environment at $APP_DIR"
    else
        ENV_TYPE="development"
        print_warning "Detected development environment at $APP_DIR"
    fi
fi

# Ensure app directory exists
if [ ! -d "$APP_DIR/app" ]; then
    print_error "App directory not found at $APP_DIR/app"
    print_warning "Make sure you're running this from the trivia-engine directory or its deploy subdirectory"
    exit 1
fi

# Ask for confirmation
read -p "Setting up environment for: $ENV_TYPE. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

print_header "API Environment (.env)"

# API environment file
API_ENV_FILE="$APP_DIR/app/.env"
API_ENV_EXAMPLE="$APP_DIR/.env.example"

if [ -f "$API_ENV_FILE" ]; then
    print_warning "API .env file already exists!"
    read -p "Backup and regenerate? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$API_ENV_FILE" "$API_ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        print_success "Backed up existing .env file"
    else
        print_warning "Keeping existing .env file"
        SKIP_API_ENV=true
    fi
fi

if [ "$SKIP_API_ENV" != "true" ]; then
    # Generate API .env file
    cat > "$API_ENV_FILE" << EOF
# Trivia Engine API Environment Variables
# Generated on $(date)
# Environment: $ENV_TYPE

# Server Configuration
NODE_ENV=$ENV_TYPE
PORT=3003

EOF

    # Database Configuration
    print_header "Database Configuration"
    if [ "$ENV_TYPE" = "production" ]; then
        echo "Enter your PostgreSQL connection details:"
        echo ""
        echo "Example: If you have a database 'trivia_prod' with user 'trivia_user' on localhost"
        echo "Host: localhost, Port: 5432, Database: trivia_prod, User: trivia_user"
        echo ""
        
        read -p "Database host (default: localhost): " DB_HOST
        DB_HOST=${DB_HOST:-localhost}
        
        read -p "Database port (default: 5432): " DB_PORT
        DB_PORT=${DB_PORT:-5432}
        
        while [ -z "$DB_NAME" ]; do
            read -p "Database name (required): " DB_NAME
        done
        
        while [ -z "$DB_USER" ]; do
            read -p "Database user (required): " DB_USER
        done
        
        while [ -z "$DB_PASS" ]; do
            read -s -p "Database password (required): " DB_PASS
            echo
        done
        
        DATABASE_URL="postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
        echo ""
        print_warning "Database URL: postgresql://${DB_USER}:****@${DB_HOST}:${DB_PORT}/${DB_NAME}"
    else
        # Development defaults
        read -p "Use default development database? (postgresql://postgres:postgres@localhost:5432/trivia_dev) [Y/n]: " USE_DEFAULT
        if [[ "$USE_DEFAULT" =~ ^[Nn]$ ]]; then
            # Custom development database
            read -p "Database URL: " DATABASE_URL
        else
            DATABASE_URL="postgresql://postgres:postgres@localhost:5432/trivia_dev"
            print_warning "Using default development database URL"
        fi
    fi

    # Validate database connection
    if validate_database_url "$DATABASE_URL"; then
        cat >> "$API_ENV_FILE" << EOF
# Database Configuration
DATABASE_URL=$DATABASE_URL
DB_CONNECTION_LIMIT=10

EOF
    else
        print_error "Database validation failed. Please check your connection details."
        exit 1
    fi

    # Generate secure secrets
    print_header "Generating Secure Secrets"
    
    JWT_SECRET=$(generate_secret 64)
    print_success "Generated JWT secret"
    
    cat >> "$API_ENV_FILE" << EOF
# JWT Configuration
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=30d
JWT_REFRESH_EXPIRES_IN=90d

# API Key Configuration
API_KEY_SALT_ROUNDS=32
DEFAULT_RATE_LIMIT_REQUESTS=100
DEFAULT_RATE_LIMIT_WINDOW=3600

# Security Configuration
BCRYPT_ROUNDS=$([ "$ENV_TYPE" = "production" ] && echo "12" || echo "10")
EOF

    # CORS Configuration
    if [ "$ENV_TYPE" = "production" ]; then
        read -p "Enter your domain (e.g., example.com): " DOMAIN
        CORS_ORIGIN="https://${DOMAIN},https://www.${DOMAIN}"
    else
        CORS_ORIGIN="http://localhost:3000"
    fi

    cat >> "$API_ENV_FILE" << EOF
CORS_ORIGIN=$CORS_ORIGIN
TRUSTED_PROXIES=127.0.0.1

# Logging Configuration
LOG_LEVEL=info
LOG_FORMAT=json

# Cache Configuration (optional)
CACHE_ENABLED=false
CACHE_TTL=3600
# REDIS_URL=redis://localhost:6379

# Rate Limiting
GLOBAL_RATE_LIMIT_ENABLED=true
GLOBAL_RATE_LIMIT_MAX=1000
GLOBAL_RATE_LIMIT_WINDOW_MS=900000
EOF

    chmod 600 "$API_ENV_FILE"
    print_success "Created API .env file with secure permissions"
fi

# Marketing environment file
print_header "Marketing Environment (.env.local)"

MARKETING_ENV_FILE="$APP_DIR/marketing/.env.local"

if [ -f "$MARKETING_ENV_FILE" ]; then
    print_warning "Marketing .env.local file already exists!"
    read -p "Backup and regenerate? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$MARKETING_ENV_FILE" "$MARKETING_ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        print_success "Backed up existing .env.local file"
    else
        SKIP_MARKETING_ENV=true
    fi
fi

if [ "$SKIP_MARKETING_ENV" != "true" ]; then
    if [ "$ENV_TYPE" = "production" ]; then
        API_BASE_URL="https://${DOMAIN}/api/v1"
    else
        API_BASE_URL="http://localhost:3003/api/v1"
    fi

    # Generate initial API key
    INITIAL_API_KEY="sk_$(generate_secret 32)"
    
    cat > "$MARKETING_ENV_FILE" << EOF
# Trivia Engine Marketing Site Environment Variables
# Generated on $(date)
# Environment: $ENV_TYPE

# API Configuration
NEXT_PUBLIC_API_BASE_URL=$API_BASE_URL
NEXT_PUBLIC_API_KEY=$INITIAL_API_KEY

# Add any additional Next.js environment variables here
EOF

    chmod 600 "$MARKETING_ENV_FILE"
    print_success "Created Marketing .env.local file"
    print_warning "Remember to create this API key in your database after deployment"
fi

# MCP Server environment (optional)
if [ -d "$APP_DIR/mcp" ]; then
    print_header "MCP Server Environment (.env)"
    
    MCP_ENV_FILE="$APP_DIR/mcp/.env"
    
    if [ ! -f "$MCP_ENV_FILE" ] || [[ $REPLY =~ ^[Yy]$ ]]; then
        cat > "$MCP_ENV_FILE" << EOF
# Trivia Engine MCP Server Environment Variables
# Generated on $(date)

# API Configuration
TRIVIA_API_BASE_URL=${API_BASE_URL:-http://localhost:3003/api/v1}
TRIVIA_API_KEY=$INITIAL_API_KEY
EOF
        chmod 600 "$MCP_ENV_FILE"
        print_success "Created MCP .env file"
    fi
fi

# Validation
print_header "Validating Environment Configuration"

# Check all required files exist
check_file() {
    if [ -f "$1" ]; then
        print_success "$2 exists"
        return 0
    else
        print_error "$2 missing"
        return 1
    fi
}

VALIDATION_PASSED=true

check_file "$API_ENV_FILE" "API .env" || VALIDATION_PASSED=false
check_file "$MARKETING_ENV_FILE" "Marketing .env.local" || VALIDATION_PASSED=false

# Validate required environment variables
print_header "Checking Required Variables"

check_env_var() {
    local file=$1
    local var=$2
    local description=$3
    
    if grep -q "^${var}=" "$file" && [ -n "$(grep "^${var}=" "$file" | cut -d'=' -f2-)" ]; then
        print_success "$description configured"
        return 0
    else
        print_error "$description missing or empty"
        return 1
    fi
}

# API checks
if [ -f "$API_ENV_FILE" ]; then
    check_env_var "$API_ENV_FILE" "DATABASE_URL" "Database URL" || VALIDATION_PASSED=false
    check_env_var "$API_ENV_FILE" "JWT_SECRET" "JWT Secret" || VALIDATION_PASSED=false
    check_env_var "$API_ENV_FILE" "NODE_ENV" "Node Environment" || VALIDATION_PASSED=false
    check_env_var "$API_ENV_FILE" "CORS_ORIGIN" "CORS Origin" || VALIDATION_PASSED=false
fi

# Marketing checks
if [ -f "$MARKETING_ENV_FILE" ]; then
    check_env_var "$MARKETING_ENV_FILE" "NEXT_PUBLIC_API_BASE_URL" "API Base URL" || VALIDATION_PASSED=false
    check_env_var "$MARKETING_ENV_FILE" "NEXT_PUBLIC_API_KEY" "API Key" || VALIDATION_PASSED=false
fi

# Generate summary report
print_header "Setup Summary"

if [ "$VALIDATION_PASSED" = "true" ]; then
    print_success "All environment files configured successfully!"
    
    echo -e "\n${GREEN}Generated credentials:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "JWT Secret: ${JWT_SECRET:0:20}... (truncated)"
    echo "Initial API Key: $INITIAL_API_KEY"
    if [ "$ENV_TYPE" = "production" ]; then
        echo "Domain: $DOMAIN"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Review the generated .env files"
    echo "2. Run database migrations: cd app && npx prisma migrate deploy"
    echo "3. Create initial API key in database"
    echo "4. Deploy your application"
    
    # Save credentials to a temporary file (not in git)
    CREDS_FILE="$APP_DIR/credentials.$(date +%Y%m%d_%H%M%S).txt"
    cat > "$CREDS_FILE" << EOF
Trivia Engine Credentials
Generated: $(date)
Environment: $ENV_TYPE

JWT Secret: $JWT_SECRET
Initial API Key: $INITIAL_API_KEY

IMPORTANT: Save these credentials securely and delete this file!
EOF
    chmod 600 "$CREDS_FILE"
    echo -e "\n${YELLOW}Credentials saved to: $CREDS_FILE${NC}"
    echo -e "${RED}Delete this file after saving the credentials securely!${NC}"
else
    print_error "Some validations failed. Please check the errors above."
    exit 1
fi

# Git safety check
print_header "Git Safety Check"

if command -v git &> /dev/null && [ -d "$APP_DIR/.git" ]; then
    cd "$APP_DIR"
    
    # Check if .env files are in .gitignore
    for env_file in "app/.env" "marketing/.env.local" "mcp/.env" "credentials.*.txt"; do
        if ! grep -q "$env_file" .gitignore 2>/dev/null; then
            echo "$env_file" >> .gitignore
            print_warning "Added $env_file to .gitignore"
        fi
    done
    
    # Check if any .env files are staged
    if git ls-files --cached | grep -E '\.(env|env\.local)$'; then
        print_error "WARNING: .env files are staged in git!"
        print_warning "Run: git rm --cached <file> to unstage them"
    else
        print_success "No .env files staged in git"
    fi
fi

print_header "Setup Complete!"
print_success "Your environment is configured and ready for deployment"