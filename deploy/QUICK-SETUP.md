# Quick Production Setup Guide

This guide helps you quickly set up the Trivia Engine on your DigitalOcean droplet.

## Prerequisites

- PostgreSQL is installed and running
- You have a PostgreSQL database and user created
- You're logged in as root or have sudo access

## Step 1: Create PostgreSQL Database (if needed)

```bash
# Connect to PostgreSQL as superuser
sudo -u postgres psql

# Create database and user
CREATE DATABASE trivia_production;
CREATE USER trivia_user WITH PASSWORD 'your_secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE trivia_production TO trivia_user;
\q
```

## Step 2: Run Setup Script

```bash
cd /home/trivia/trivia-engine
./deploy/setup-env.sh --production
```

When prompted, enter:
- Database host: `localhost` (or press Enter for default)
- Database port: `5432` (or press Enter for default)  
- Database name: `trivia_production`
- Database user: `trivia_user`
- Database password: `your_secure_password_here`

## Step 3: Manual Setup (Alternative)

If the script fails, set up manually:

### Create API .env file:

```bash
cd /home/trivia/trivia-engine/app
cat > .env << 'EOF'
# Server Configuration
NODE_ENV=production
PORT=3003

# Database Configuration
DATABASE_URL=postgresql://trivia_user:your_secure_password_here@localhost:5432/trivia_production
DB_CONNECTION_LIMIT=10

# JWT Configuration (generate a new secret)
JWT_SECRET=your_64_character_secret_here_change_this
JWT_EXPIRES_IN=30d
JWT_REFRESH_EXPIRES_IN=90d

# Security Configuration
BCRYPT_ROUNDS=12
CORS_ORIGIN=https://yourdomain.com,https://www.yourdomain.com
TRUSTED_PROXIES=127.0.0.1

# Rate Limiting
GLOBAL_RATE_LIMIT_ENABLED=true
GLOBAL_RATE_LIMIT_MAX=1000
GLOBAL_RATE_LIMIT_WINDOW_MS=900000

# Logging
LOG_LEVEL=info
LOG_FORMAT=json
EOF

# Set proper permissions
chmod 600 .env
```

### Generate secure JWT secret:

```bash
# Generate and add to .env
JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
sed -i "s/JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env
```

### Create Marketing .env.local:

```bash
cd /home/trivia/trivia-engine/marketing
cat > .env.local << 'EOF'
# API Configuration  
NEXT_PUBLIC_API_BASE_URL=https://yourdomain.com/api/v1
NEXT_PUBLIC_API_KEY=sk_your_api_key_here
EOF

chmod 600 .env.local
```

## Step 4: Run Database Migrations

```bash
cd /home/trivia/trivia-engine/app
npm install
npx prisma migrate deploy
npx prisma generate
```

## Step 5: Build Marketing Site

```bash
cd /home/trivia/trivia-engine/marketing
npm install
npm run build
```

## Step 6: Start Services

```bash
# Copy service files
sudo cp /home/trivia/trivia-engine/deploy/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload

# Enable and start services
sudo systemctl enable trivia-api trivia-marketing
sudo systemctl start trivia-api trivia-marketing

# Check status
sudo systemctl status trivia-api
sudo systemctl status trivia-marketing
```

## Step 7: Configure Nginx

```bash
# Copy nginx config
sudo cp /home/trivia/trivia-engine/deploy/nginx.conf /etc/nginx/sites-available/trivia-engine

# Update with your domain
sudo nano /etc/nginx/sites-available/trivia-engine
# Replace 'yourdomain.com' with your actual domain

# Enable site
sudo ln -s /etc/nginx/sites-available/trivia-engine /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Step 8: Set Up SSL

```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

## Troubleshooting

### Database Connection Failed

```bash
# Test connection
psql "postgresql://trivia_user:your_password@localhost:5432/trivia_production" -c "SELECT 1"

# Check PostgreSQL is running
sudo systemctl status postgresql

# Check PostgreSQL logs
sudo journalctl -u postgresql -n 50
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R trivia:trivia /home/trivia/trivia-engine

# Fix file permissions
find /home/trivia/trivia-engine -name "*.env*" -exec chmod 600 {} \;
```

### Service Won't Start

```bash
# Check logs
sudo journalctl -u trivia-api -n 100
sudo journalctl -u trivia-marketing -n 100

# Test manually
sudo -u trivia bash
cd /home/trivia/trivia-engine/app
node api/index.js
```

## Quick Commands Reference

```bash
# Restart services
sudo systemctl restart trivia-api trivia-marketing

# View logs
sudo journalctl -u trivia-api -f
sudo journalctl -u trivia-marketing -f

# Check service status
sudo systemctl status trivia-api trivia-marketing

# Run setup with options
./deploy/setup-env.sh --production --skip-db-check
```