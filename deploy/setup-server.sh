#!/bin/bash
# Initial server setup script for Trivia Engine
# Run this once on a fresh Ubuntu server

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    exit 1
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root or with sudo"
fi

# Get deployment user (default: trivia)
read -p "Enter deployment user name (default: trivia): " DEPLOY_USER
DEPLOY_USER=${DEPLOY_USER:-trivia}

# Get domain name
read -p "Enter your domain name (e.g., trivia.example.com): " DOMAIN_NAME
if [ -z "$DOMAIN_NAME" ]; then
    print_error "Domain name is required"
fi

# Update system
print_status "Updating system packages..."
apt-get update && apt-get upgrade -y

# Install essential packages
print_status "Installing essential packages..."
apt-get install -y curl git build-essential nginx certbot python3-certbot-nginx ufw fail2ban

# Install Node.js 20.x
print_status "Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
apt-get install -y nodejs

# Install PM2 globally
print_status "Installing PM2..."
npm install -g pm2

# Create deployment user if it doesn't exist
if ! id "$DEPLOY_USER" &>/dev/null; then
    print_status "Creating deployment user: $DEPLOY_USER"
    useradd -m -s /bin/bash $DEPLOY_USER
    usermod -aG sudo $DEPLOY_USER
fi

# Create application directories
print_status "Creating application directories..."
mkdir -p /home/$DEPLOY_USER/trivia-engine
mkdir -p /home/$DEPLOY_USER/logs
mkdir -p /home/$DEPLOY_USER/backups
chown -R $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER

# Configure firewall
print_status "Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3003/tcp  # API port (will be proxied through nginx)
ufw --force enable

# Configure fail2ban
print_status "Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Create nginx configuration for the domain
print_status "Creating nginx configuration..."
cat > /etc/nginx/sites-available/$DOMAIN_NAME << EOF
# API Backend
upstream api_backend {
    server 127.0.0.1:3003;
    keepalive 64;
}

# Marketing Site
upstream marketing_site {
    server 127.0.0.1:3000;
    keepalive 64;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS Server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;

    # SSL configuration will be added by certbot
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # API routes
    location /api {
        proxy_pass http://api_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Marketing site (root)
    location / {
        proxy_pass http://marketing_site;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml application/javascript application/json;
    gzip_disable "MSIE [1-6]\.";
}
EOF

# Enable nginx site
ln -sf /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Create systemd service for API
print_status "Creating systemd service for API..."
cat > /etc/systemd/system/trivia-api.service << EOF
[Unit]
Description=Trivia Engine API
After=network.target

[Service]
Type=simple
User=$DEPLOY_USER
WorkingDirectory=/home/$DEPLOY_USER/trivia-engine/app
Environment=NODE_ENV=production
ExecStart=/usr/bin/node api/index.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=trivia-api

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Marketing Site
cat > /etc/systemd/system/trivia-marketing.service << EOF
[Unit]
Description=Trivia Engine Marketing Site
After=network.target

[Service]
Type=simple
User=$DEPLOY_USER
WorkingDirectory=/home/$DEPLOY_USER/trivia-engine/marketing
Environment=NODE_ENV=production
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=trivia-marketing

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Create deployment script in user directory
print_status "Creating deployment helper script..."
cat > /home/$DEPLOY_USER/deploy.sh << 'EOF'
#!/bin/bash
# Quick deployment script
cd /home/$DEPLOY_USER/trivia-engine
git pull origin main
cd app && npm install && npx prisma migrate deploy
cd ../marketing && npm install && npm run build
sudo systemctl restart trivia-api trivia-marketing
EOF

chmod +x /home/$DEPLOY_USER/deploy.sh
chown $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER/deploy.sh

# Create backup script
print_status "Creating backup script..."
cat > /home/$DEPLOY_USER/backup.sh << 'EOF'
#!/bin/bash
# Database backup script
BACKUP_DIR="/home/$DEPLOY_USER/backups"
DATE=$(date +%Y%m%d_%H%M%S)
source /home/$DEPLOY_USER/trivia-engine/app/.env

pg_dump $DATABASE_URL > $BACKUP_DIR/trivia_backup_$DATE.sql
gzip $BACKUP_DIR/trivia_backup_$DATE.sql

# Keep only last 7 days of backups
find $BACKUP_DIR -name "trivia_backup_*.sql.gz" -mtime +7 -delete
EOF

chmod +x /home/$DEPLOY_USER/backup.sh
chown $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER/backup.sh

# Add backup cron job
print_status "Setting up daily backups..."
echo "0 2 * * * $DEPLOY_USER /home/$DEPLOY_USER/backup.sh" >> /etc/crontab

print_status "Server setup complete!"
print_warning "Next steps:"
echo "1. Clone your repository: sudo -u $DEPLOY_USER git clone <your-repo-url> /home/$DEPLOY_USER/trivia-engine"
echo "2. Copy and configure environment files:"
echo "   - /home/$DEPLOY_USER/trivia-engine/app/.env"
echo "   - /home/$DEPLOY_USER/trivia-engine/marketing/.env.local"
echo "3. Run database migrations: cd /home/$DEPLOY_USER/trivia-engine/app && npx prisma migrate deploy"
echo "4. Build the marketing site: cd /home/$DEPLOY_USER/trivia-engine/marketing && npm run build"
echo "5. Start services: sudo systemctl enable --now trivia-api trivia-marketing"
echo "6. Set up SSL: sudo certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME"