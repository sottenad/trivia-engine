# Trivia Engine Deployment Guide

This guide covers deploying the Trivia Engine application to a DigitalOcean droplet or similar Ubuntu server.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Server Setup](#initial-server-setup)
3. [Manual Deployment](#manual-deployment)
4. [Automated Deployment](#automated-deployment)
5. [Using PM2 (Alternative)](#using-pm2-alternative)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Server Requirements
- Ubuntu 20.04 or 22.04 LTS
- Minimum 2GB RAM (4GB recommended)
- PostgreSQL 13+ installed and configured
- Domain name pointing to your server's IP

### Local Requirements
- SSH access to the server
- Git repository with your code
- Environment variables configured

## Initial Server Setup

### 1. Run the Setup Script

SSH into your server as root or with sudo privileges:

```bash
# Download and run setup script
wget https://raw.githubusercontent.com/yourusername/trivia-engine/main/deploy/setup-server.sh
chmod +x setup-server.sh
sudo ./setup-server.sh
```

The script will:
- Install Node.js 20.x, nginx, and required packages
- Create a deployment user (default: `trivia`)
- Configure firewall and security
- Set up nginx with your domain
- Create systemd services
- Set up automated backups

### 2. Manual Initial Setup (Alternative)

If you prefer manual setup:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install other dependencies
sudo apt install -y nginx postgresql-client git build-essential

# Create deployment user
sudo useradd -m -s /bin/bash trivia
sudo usermod -aG sudo trivia

# Create application directories
sudo mkdir -p /home/trivia/{trivia-engine,logs,backups}
sudo chown -R trivia:trivia /home/trivia
```

## Manual Deployment

### 1. Clone Repository

```bash
sudo -u trivia git clone <your-repo-url> /home/trivia/trivia-engine
cd /home/trivia/trivia-engine
```

### 2. Configure Environment Variables

```bash
# API configuration
cp .env.example app/.env
nano app/.env  # Edit with your values

# Marketing site configuration
cp marketing/.env.example marketing/.env.local
nano marketing/.env.local  # Edit with your values
```

Required environment variables:
- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET`: Strong secret key for JWT tokens
- `CORS_ORIGIN`: Your domain(s) for CORS
- `NEXT_PUBLIC_API_BASE_URL`: API URL for marketing site

### 3. Install Dependencies & Build

```bash
# API
cd app
npm install
npx prisma migrate deploy
npx prisma generate

# Marketing Site
cd ../marketing
npm install
npm run build
```

### 4. Set Up Services

```bash
# Copy systemd service files
sudo cp deploy/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload

# Enable and start services
sudo systemctl enable trivia-api trivia-marketing
sudo systemctl start trivia-api trivia-marketing

# Check status
sudo systemctl status trivia-api
sudo systemctl status trivia-marketing
```

### 5. Configure SSL

```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

## Automated Deployment

### Option 1: Using Deploy Script

The deploy script handles updates with zero-downtime deployment:

```bash
# As the trivia user
cd /home/trivia/trivia-engine
./deploy/deploy.sh

# With options
./deploy/deploy.sh --branch develop --skip-backup
```

Features:
- Automatic database backups before deployment
- Health checks after deployment
- Automatic rollback on failure
- Service status reporting

### Option 2: GitHub Actions

1. Set up GitHub Secrets:
   - `SSH_PRIVATE_KEY`: SSH key for deployment user
   - `SSH_KNOWN_HOSTS`: Server's SSH fingerprint
   - `DEPLOY_HOST`: Server IP or hostname
   - `DEPLOY_USER`: Deployment username (trivia)
   - `PRODUCTION_URL`: Your domain

2. Push to main branch to trigger deployment:
   ```bash
   git push origin main
   ```

The workflow will:
- Run tests (if configured)
- Deploy to production
- Restart services
- Check health endpoints

## Using PM2 (Alternative)

PM2 provides additional features like clustering and monitoring:

### 1. Install PM2

```bash
sudo npm install -g pm2
pm2 install pm2-logrotate
```

### 2. Start Applications

```bash
cd /home/trivia/trivia-engine
pm2 start deploy/ecosystem.config.js --env production

# Save PM2 configuration
pm2 save
pm2 startup systemd -u trivia --hp /home/trivia
```

### 3. PM2 Commands

```bash
# View logs
pm2 logs

# Monitor applications
pm2 monit

# Restart with zero downtime
pm2 reload all

# View detailed info
pm2 info trivia-api
```

## Monitoring & Maintenance

### 1. View Logs

**Systemd logs:**
```bash
# API logs
sudo journalctl -u trivia-api -f

# Marketing site logs
sudo journalctl -u trivia-marketing -f

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

**Application logs:**
```bash
tail -f /home/trivia/logs/*.log
```

### 2. Database Backups

Automatic backups run daily at 2 AM. Manual backup:

```bash
sudo -u trivia /home/trivia/backup.sh
```

Restore from backup:
```bash
zcat /home/trivia/backups/trivia_backup_20240101_020000.sql.gz | psql $DATABASE_URL
```

### 3. Monitor Performance

```bash
# Check memory usage
free -h

# Check disk space
df -h

# Check service status
sudo systemctl status trivia-api trivia-marketing

# Check nginx status
sudo nginx -t
sudo systemctl status nginx
```

### 4. Update Dependencies

```bash
cd /home/trivia/trivia-engine/app
npm audit
npm update

cd ../marketing
npm audit
npm update
```

## Troubleshooting

### Service Won't Start

1. Check logs:
   ```bash
   sudo journalctl -u trivia-api -n 100 --no-pager
   ```

2. Check environment variables:
   ```bash
   sudo -u trivia cat /home/trivia/trivia-engine/app/.env
   ```

3. Test manually:
   ```bash
   sudo -u trivia bash
   cd /home/trivia/trivia-engine/app
   node api/index.js
   ```

### Database Connection Issues

1. Test connection:
   ```bash
   sudo -u trivia psql $DATABASE_URL -c "SELECT 1"
   ```

2. Check PostgreSQL status:
   ```bash
   sudo systemctl status postgresql
   ```

### Nginx Issues

1. Test configuration:
   ```bash
   sudo nginx -t
   ```

2. Reload after changes:
   ```bash
   sudo systemctl reload nginx
   ```

### Port Already in Use

```bash
# Find process using port
sudo lsof -i :3003
sudo lsof -i :3000

# Kill if needed
sudo kill -9 <PID>
```

### SSL Certificate Renewal

Certbot sets up automatic renewal. Test renewal:

```bash
sudo certbot renew --dry-run
```

## Security Checklist

- [ ] Change default PostgreSQL passwords
- [ ] Configure firewall (ufw)
- [ ] Set up fail2ban
- [ ] Use strong JWT_SECRET
- [ ] Enable SSL/HTTPS
- [ ] Set proper CORS origins
- [ ] Regular security updates: `sudo apt update && sudo apt upgrade`
- [ ] Monitor logs for suspicious activity
- [ ] Set up database backups
- [ ] Restrict SSH access (key-only)

## Performance Optimization

1. **Enable Nginx Caching:**
   ```nginx
   location /api {
       proxy_cache api_cache;
       proxy_cache_valid 200 60m;
       proxy_cache_use_stale error timeout;
   }
   ```

2. **Database Indexes:**
   Check slow queries and add indexes as needed.

3. **Node.js Memory:**
   Adjust in systemd service or PM2 config:
   ```
   Environment="NODE_OPTIONS=--max-old-space-size=2048"
   ```

4. **CDN for Static Assets:**
   Configure Cloudflare or similar for the marketing site.

## Support

For issues:
1. Check application logs
2. Review this documentation
3. Check systemd/PM2 status
4. Review nginx error logs
5. Verify environment variables

Remember to keep your system updated and monitor resource usage regularly!