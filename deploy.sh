#!/bin/bash

# Deployment script for Digital Ocean droplet with SSL support
# Assumes: PM2 is installed, PostgreSQL is running, Node.js is installed

set -e  # Exit on error

# ========================================
# CONFIGURATION - EDIT THESE VALUES
# ========================================
DOMAIN="trivia-engine.com"                    # Your main domain
API_SUBDOMAIN="api.${DOMAIN}"             # API subdomain
WWW_DOMAIN="www.${DOMAIN}"                # WWW subdomain
EMAIL="sottenad@exgmailample.com"            # Email for Let's Encrypt
API_PORT=3003                              # Internal API port
MARKETING_PORT=3000                        # Internal marketing site port

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting deployment with SSL setup...${NC}"

# ========================================
# INSTALL DEPENDENCIES IF NEEDED
# ========================================
install_if_missing() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${YELLOW}$1 not found. Installing...${NC}"
        sudo apt-get update
        sudo apt-get install -y $2
    else
        echo -e "${GREEN}✓ $1 is already installed${NC}"
    fi
}

# Check and install nginx
install_if_missing "nginx" "nginx"

# Check and install certbot
if ! command -v certbot &> /dev/null; then
    echo -e "${YELLOW}Certbot not found. Installing...${NC}"
    sudo apt-get update
    sudo apt-get install -y certbot python3-certbot-nginx
else
    echo -e "${GREEN}✓ Certbot is already installed${NC}"
fi

# Pull latest code
echo "Pulling latest code..."
git pull origin main

# ========================================
# NGINX CONFIGURATION
# ========================================
echo -e "${GREEN}Configuring Nginx...${NC}"

# Create nginx configuration for API
sudo tee /etc/nginx/sites-available/${API_SUBDOMAIN} > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${API_SUBDOMAIN};

    location / {
        proxy_pass http://localhost:${API_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts for long-running requests
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Create nginx configuration for Marketing site
sudo tee /etc/nginx/sites-available/${DOMAIN} > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} ${WWW_DOMAIN};

    location / {
        proxy_pass http://localhost:${MARKETING_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable sites if not already enabled
if [ ! -L /etc/nginx/sites-enabled/${API_SUBDOMAIN} ]; then
    sudo ln -s /etc/nginx/sites-available/${API_SUBDOMAIN} /etc/nginx/sites-enabled/
    echo -e "${GREEN}✓ Enabled nginx site for ${API_SUBDOMAIN}${NC}"
fi

if [ ! -L /etc/nginx/sites-enabled/${DOMAIN} ]; then
    sudo ln -s /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/
    echo -e "${GREEN}✓ Enabled nginx site for ${DOMAIN}${NC}"
fi

# Test nginx configuration
sudo nginx -t

# Deploy API
echo "Deploying API..."
cd app
npm install --production
npx prisma generate
npx prisma migrate deploy

# Start/restart API with PM2
pm2 delete api 2>/dev/null || true
pm2 start api/index.js --name api --env production

# Deploy Marketing site
echo "Deploying Marketing site..."
cd ../marketing
npm install
npm run build

# Start/restart Marketing site with PM2
pm2 delete marketing 2>/dev/null || true
pm2 start npm --name marketing -- start

# Save PM2 configuration
pm2 save
pm2 startup systemd -u $USER --hp /home/$USER || true

# ========================================
# SSL CERTIFICATE SETUP
# ========================================
echo -e "${GREEN}Setting up SSL certificates...${NC}"

# Reload nginx to apply initial configuration
sudo systemctl reload nginx

# Function to obtain certificate for a domain
obtain_certificate() {
    local domain=$1
    if sudo certbot certificates 2>/dev/null | grep -q "Domains: ${domain}"; then
        echo -e "${GREEN}✓ SSL certificate already exists for ${domain}${NC}"
    else
        echo -e "${YELLOW}Obtaining SSL certificate for ${domain}...${NC}"
        sudo certbot --nginx -d ${domain} --non-interactive --agree-tos --email ${EMAIL} --redirect
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ SSL certificate obtained for ${domain}${NC}"
        else
            echo -e "${RED}✗ Failed to obtain certificate for ${domain}${NC}"
            echo -e "${YELLOW}You may need to run: sudo certbot --nginx -d ${domain}${NC}"
        fi
    fi
}

# Obtain certificates for all domains
obtain_certificate ${API_SUBDOMAIN}
obtain_certificate ${DOMAIN}

# If www subdomain is different from main domain, get certificate for it too
if [ "${WWW_DOMAIN}" != "${DOMAIN}" ]; then
    # For www, we'll add it to the main domain's certificate
    if ! sudo certbot certificates 2>/dev/null | grep -q "Domains:.*${WWW_DOMAIN}"; then
        echo -e "${YELLOW}Adding ${WWW_DOMAIN} to certificate...${NC}"
        sudo certbot --nginx -d ${DOMAIN} -d ${WWW_DOMAIN} --non-interactive --agree-tos --email ${EMAIL} --redirect --expand
    fi
fi

# ========================================
# SETUP AUTO-RENEWAL
# ========================================
echo -e "${GREEN}Setting up automatic certificate renewal...${NC}"

# Test renewal
sudo certbot renew --dry-run

# The systemd timer should already be enabled by certbot package
if systemctl is-enabled certbot.timer &>/dev/null; then
    echo -e "${GREEN}✓ Automatic renewal is enabled (certbot.timer)${NC}"
    sudo systemctl status certbot.timer --no-pager | head -n 3
else
    # Enable the timer if it's not enabled
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer
    echo -e "${GREEN}✓ Enabled automatic renewal (certbot.timer)${NC}"
fi

# ========================================
# FINAL NGINX RELOAD
# ========================================
echo -e "${GREEN}Reloading Nginx with final configuration...${NC}"
sudo nginx -t && sudo systemctl reload nginx

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Deployment complete with SSL!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Your services are available at:"
echo -e "  API:       ${GREEN}https://${API_SUBDOMAIN}${NC}"
echo -e "  Website:   ${GREEN}https://${DOMAIN}${NC}"
if [ "${WWW_DOMAIN}" != "${DOMAIN}" ]; then
    echo -e "  WWW:       ${GREEN}https://${WWW_DOMAIN}${NC}"
fi
echo ""
echo "Running services:"
pm2 list
echo ""
echo -e "${YELLOW}Note: If this is your first time setting up SSL, you may need to:${NC}"
echo -e "  1. Ensure your DNS A records point to this server"
echo -e "  2. Wait a few minutes for DNS propagation"
echo -e "  3. If certificates fail, run manually:"
echo -e "     ${YELLOW}sudo certbot --nginx -d ${DOMAIN} -d ${WWW_DOMAIN}${NC}"
echo -e "     ${YELLOW}sudo certbot --nginx -d ${API_SUBDOMAIN}${NC}"