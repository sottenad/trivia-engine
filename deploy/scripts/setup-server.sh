#!/bin/bash

# ==============================================================================
# TRIVIA ENGINE - INITIAL SERVER SETUP SCRIPT
# ==============================================================================
# This script sets up a fresh Ubuntu server (20.04/22.04) for Trivia Engine
# Run this on a blank DigitalOcean droplet to configure everything from scratch
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
APP_USER="trivia"
APP_DIR="/home/${APP_USER}/trivia-engine"
DOMAIN="trivia-engine.com"
DB_NAME="trivia_engine"
DB_USER="trivia"
NODE_VERSION="20"
POSTGRES_VERSION="15"
GITHUB_REPO="https://github.com/sottenad/trivia-engine.git"  # UPDATE THIS

# Get user input
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           TRIVIA ENGINE - SERVER SETUP                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}This script will set up your server for Trivia Engine.${NC}"
echo -e "${YELLOW}Domain: ${DOMAIN}${NC}"
echo ""

# Get GitHub repository
echo -n "Enter your GitHub repository URL (or press Enter for default): "
read user_repo
if [ ! -z "$user_repo" ]; then
    GITHUB_REPO="$user_repo"
fi

# Get database password
echo -n "Enter a strong password for the PostgreSQL database: "
read -s DB_PASSWORD
echo ""
echo -n "Confirm the database password: "
read -s DB_PASSWORD_CONFIRM
echo ""

if [ "$DB_PASSWORD" != "$DB_PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Passwords do not match. Exiting.${NC}"
    exit 1
fi

# Get email for SSL certificate
echo -n "Enter your email for SSL certificate notifications: "
read SSL_EMAIL

echo ""
echo -e "${YELLOW}Starting server setup...${NC}"
sleep 2

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1 failed"
        exit 1
    fi
}

# Update system
echo -e "\n${YELLOW}Step 1: Updating system packages...${NC}"
sudo apt-get update
check_status "System update"
sudo apt-get upgrade -y
check_status "System upgrade"

# Install essential packages
echo -e "\n${YELLOW}Step 2: Installing essential packages...${NC}"
sudo apt-get install -y curl git build-essential software-properties-common ufw fail2ban
check_status "Essential packages installed"

# Install Node.js
echo -e "\n${YELLOW}Step 3: Installing Node.js ${NODE_VERSION}...${NC}"
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
check_status "Node.js repository added"
sudo apt-get install -y nodejs
check_status "Node.js installed"
node --version

# Install PostgreSQL
echo -e "\n${YELLOW}Step 4: Installing PostgreSQL ${POSTGRES_VERSION}...${NC}"
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y postgresql-${POSTGRES_VERSION} postgresql-client-${POSTGRES_VERSION}
check_status "PostgreSQL installed"

# Install Nginx
echo -e "\n${YELLOW}Step 5: Installing Nginx...${NC}"
sudo apt-get install -y nginx
check_status "Nginx installed"

# Install PM2
echo -e "\n${YELLOW}Step 6: Installing PM2...${NC}"
sudo npm install -g pm2
check_status "PM2 installed"
pm2 install pm2-logrotate
check_status "PM2 log rotation configured"

# Install Certbot for SSL
echo -e "\n${YELLOW}Step 7: Installing Certbot...${NC}"
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot
check_status "Certbot installed"

# Create application user
echo -e "\n${YELLOW}Step 8: Creating application user...${NC}"
if id "${APP_USER}" &>/dev/null; then
    echo -e "${YELLOW}User ${APP_USER} already exists${NC}"
else
    sudo useradd -m -s /bin/bash ${APP_USER}
    check_status "User ${APP_USER} created"
fi

# Create directory structure
echo -e "\n${YELLOW}Step 9: Creating directory structure...${NC}"
sudo mkdir -p ${APP_DIR}
sudo mkdir -p /home/${APP_USER}/logs
sudo mkdir -p /home/${APP_USER}/backups
sudo chown -R ${APP_USER}:${APP_USER} /home/${APP_USER}
check_status "Directories created"

# Configure PostgreSQL
echo -e "\n${YELLOW}Step 10: Configuring PostgreSQL...${NC}"
sudo -u postgres psql <<EOF
-- Create user if not exists
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '${DB_USER}') THEN
      CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
   END IF;
END
\$\$;

-- Create databases
DROP DATABASE IF EXISTS ${DB_NAME};
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
DROP DATABASE IF EXISTS ${DB_NAME}_test;
CREATE DATABASE ${DB_NAME}_test OWNER ${DB_USER};

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME}_test TO ${DB_USER};
EOF
check_status "PostgreSQL configured"

# Configure firewall
echo -e "\n${YELLOW}Step 11: Configuring firewall...${NC}"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp  # Next.js dev
sudo ufw allow 3003/tcp  # API dev
echo "y" | sudo ufw enable
check_status "Firewall configured"

# Configure Nginx (Initial HTTP-only for Certbot)
echo -e "\n${YELLOW}Step 12: Configuring Nginx (HTTP-only initially)...${NC}"
sudo tee /etc/nginx/sites-available/trivia-engine > /dev/null <<EOF
# Initial HTTP-only configuration for Certbot
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

    # Allow Let's Encrypt ACME challenges
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Logging
    access_log /var/log/nginx/trivia-engine.access.log;
    error_log /var/log/nginx/trivia-engine.error.log;

    # API proxy
    location /api {
        proxy_pass http://localhost:3003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Marketing site proxy
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/rss+xml application/atom+xml image/svg+xml application/vnd.ms-fontobject application/x-font-ttf font/opentype;
}
EOF

sudo ln -sf /etc/nginx/sites-available/trivia-engine /etc/nginx/sites-enabled/
sudo nginx -t
check_status "Nginx configured (HTTP-only)"

# Clone repository
echo -e "\n${YELLOW}Step 13: Cloning repository...${NC}"
sudo -u ${APP_USER} git clone ${GITHUB_REPO} ${APP_DIR}
check_status "Repository cloned"

# Create environment files
echo -e "\n${YELLOW}Step 14: Creating environment files...${NC}"

# API .env file
sudo -u ${APP_USER} tee ${APP_DIR}/app/.env > /dev/null <<EOF
# Database
DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}"

# JWT Secret (generate a strong one)
JWT_SECRET="$(openssl rand -base64 32)"

# Server
PORT=3003
NODE_ENV=production

# CORS
CORS_ORIGIN="https://${DOMAIN},https://www.${DOMAIN}"

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100

# Logging
LOG_LEVEL=info
EOF

# Marketing .env.local file
sudo -u ${APP_USER} tee ${APP_DIR}/marketing/.env.local > /dev/null <<EOF
# API Configuration
NEXT_PUBLIC_API_BASE_URL=https://${DOMAIN}/api/v1
NEXT_PUBLIC_API_KEY=your-api-key-here

# Domain
NEXT_PUBLIC_DOMAIN=https://${DOMAIN}
EOF

# MCP .env file
sudo -u ${APP_USER} tee ${APP_DIR}/mcp/.env > /dev/null <<EOF
# API Configuration
API_BASE_URL=https://${DOMAIN}/api/v1
API_KEY=your-mcp-api-key

# Server Configuration
SERVER_NAME=trivia-engine-mcp
SERVER_VERSION=1.0.0
EOF

check_status "Environment files created"

# Create backup script
echo -e "\n${YELLOW}Step 15: Creating backup script...${NC}"
sudo tee /home/${APP_USER}/backup.sh > /dev/null <<'EOF'
#!/bin/bash
BACKUP_DIR="/home/trivia/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="trivia_engine"

# Create backup
pg_dump $DATABASE_URL | gzip > "${BACKUP_DIR}/trivia_backup_${TIMESTAMP}.sql.gz"

# Keep only last 30 days of backups
find ${BACKUP_DIR} -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: trivia_backup_${TIMESTAMP}.sql.gz"
EOF

sudo chmod +x /home/${APP_USER}/backup.sh
sudo chown ${APP_USER}:${APP_USER} /home/${APP_USER}/backup.sh
check_status "Backup script created"

# Set up cron job for backups
echo -e "\n${YELLOW}Step 16: Setting up automated backups...${NC}"
(sudo -u ${APP_USER} crontab -l 2>/dev/null; echo "0 2 * * * /home/${APP_USER}/backup.sh >> /home/${APP_USER}/logs/backup.log 2>&1") | sudo -u ${APP_USER} crontab -
check_status "Automated backups configured"

# Install dependencies and build
echo -e "\n${YELLOW}Step 17: Installing dependencies and building applications...${NC}"
cd ${APP_DIR}/app
sudo -u ${APP_USER} npm install
check_status "API dependencies installed"

cd ${APP_DIR}/marketing
sudo -u ${APP_USER} npm install
sudo -u ${APP_USER} npm run build
check_status "Marketing site built"

cd ${APP_DIR}/mcp
sudo -u ${APP_USER} npm install
sudo -u ${APP_USER} npm run build
check_status "MCP server built"

# Run database migrations
echo -e "\n${YELLOW}Step 18: Running database migrations...${NC}"
cd ${APP_DIR}/app
sudo -u ${APP_USER} npx prisma generate
sudo -u ${APP_USER} npx prisma migrate deploy
check_status "Database migrations completed"

# Set up PM2
echo -e "\n${YELLOW}Step 19: Setting up PM2...${NC}"
sudo -u ${APP_USER} PM2_HOME=/home/${APP_USER}/.pm2 pm2 start ${APP_DIR}/deploy/config/ecosystem.config.js --env production
sudo -u ${APP_USER} PM2_HOME=/home/${APP_USER}/.pm2 pm2 save
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ${APP_USER} --hp /home/${APP_USER}
check_status "PM2 configured"

# Restart Nginx
echo -e "\n${YELLOW}Step 20: Restarting Nginx...${NC}"
sudo systemctl restart nginx
check_status "Nginx restarted"

# Set up SSL
echo -e "\n${YELLOW}Step 21: Setting up SSL certificate...${NC}"
sudo certbot certonly --webroot -w /var/www/html -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email ${SSL_EMAIL}
check_status "SSL certificate obtained"

# Update Nginx configuration with SSL
echo -e "\n${YELLOW}Step 22: Updating Nginx with SSL configuration...${NC}"
sudo cp /etc/nginx/sites-available/trivia-engine /etc/nginx/sites-available/trivia-engine.backup
sudo tee /etc/nginx/sites-available/trivia-engine > /dev/null <<EOF
# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};
    
    # Allow Let's Encrypt renewals
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\\\$server_name\\\$request_uri;
    }
}

# HTTPS server block
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN} www.${DOMAIN};

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Modern configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Logging
    access_log /var/log/nginx/trivia-engine.access.log;
    error_log /var/log/nginx/trivia-engine.error.log;

    # API proxy
    location /api {
        proxy_pass http://localhost:3003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \\\$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \\\$host;
        proxy_cache_bypass \\\$http_upgrade;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Marketing site proxy
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \\\$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \\\$host;
        proxy_cache_bypass \\\$http_upgrade;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/rss+xml application/atom+xml image/svg+xml application/vnd.ms-fontobject application/x-font-ttf font/opentype;
}
EOF

sudo nginx -t
sudo systemctl reload nginx
check_status "Nginx updated with SSL"

# Final setup
echo -e "\n${YELLOW}Step 23: Final configuration...${NC}"
sudo chown -R ${APP_USER}:${APP_USER} ${APP_DIR}
check_status "Permissions set"

# Create deployment info file
echo -e "\n${YELLOW}Creating deployment info...${NC}"
cat > /home/${APP_USER}/deployment-info.txt <<EOF
Trivia Engine Deployment Information
=====================================
Date: $(date)
Domain: https://${DOMAIN}
API URL: https://${DOMAIN}/api/v1
Database: ${DB_NAME}
User: ${APP_USER}

Services:
- PM2 processes: pm2 list
- Nginx status: sudo systemctl status nginx
- PostgreSQL: sudo systemctl status postgresql

Logs:
- PM2 logs: pm2 logs
- Nginx logs: /var/log/nginx/trivia-engine.*.log
- Application logs: /home/${APP_USER}/logs/

Commands:
- Deploy updates: ${APP_DIR}/deploy/scripts/deploy.sh
- View PM2 status: pm2 status
- Restart services: pm2 restart all
- Database backup: /home/${APP_USER}/backup.sh
EOF

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║               SETUP COMPLETE!                               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Your Trivia Engine server is now configured!${NC}"
echo ""
echo -e "${BLUE}Access your application at:${NC}"
echo -e "  • Website: ${YELLOW}https://${DOMAIN}${NC}"
echo -e "  • API: ${YELLOW}https://${DOMAIN}/api/v1${NC}"
echo ""
echo -e "${BLUE}Important files:${NC}"
echo -e "  • API Environment: ${YELLOW}${APP_DIR}/app/.env${NC}"
echo -e "  • Marketing Environment: ${YELLOW}${APP_DIR}/marketing/.env.local${NC}"
echo -e "  • Deployment info: ${YELLOW}/home/${APP_USER}/deployment-info.txt${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Update the API keys in the environment files"
echo -e "  2. Test the application at https://${DOMAIN}"
echo -e "  3. Monitor logs with: ${YELLOW}pm2 logs${NC}"
echo -e "  4. Set up GitHub secrets for automated deployment"
echo ""
echo -e "${GREEN}Setup completed successfully!${NC}"