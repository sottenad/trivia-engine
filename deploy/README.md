# Trivia Engine Deployment Guide

Complete deployment solution for trivia-engine.com on DigitalOcean.

## Quick Start

### 1. Initial Setup (Fresh Droplet)

```bash
# SSH into your droplet
ssh root@your-droplet-ip

# Download and run setup script
wget https://raw.githubusercontent.com/yourusername/trivia-engine/main/deploy/scripts/setup-server.sh
chmod +x setup-server.sh
sudo ./setup-server.sh
```

### 2. Regular Deployment

```bash
cd /home/trivia/trivia-engine
./deploy/scripts/deploy.sh
```

### 3. Complete Rebuild (Database + App)

```bash
./deploy/scripts/rebuild-all.sh --seed
```

### 4. Nuclear Reset (Remove Everything)

```bash
./deploy/scripts/reset-server.sh
# Type: DELETE EVERYTHING
# Then run setup-server.sh again
```

## Scripts Overview

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `setup-server.sh` | Initial server setup | Fresh droplet, first deployment |
| `deploy.sh` | Deploy updates | Regular code updates |
| `rebuild-all.sh` | Complete rebuild | Database schema changes, major updates |
| `reset-server.sh` | Nuclear reset | Start over from scratch |
| `health-check.sh` | Monitor services | Scheduled checks, debugging |

## Directory Structure

```
deploy/
├── scripts/           # Deployment scripts
│   ├── setup-server.sh
│   ├── deploy.sh
│   ├── rebuild-all.sh
│   └── reset-server.sh
├── config/           # Configuration files
│   ├── ecosystem.config.js
│   ├── nginx.conf
│   └── .env.production.example
├── database/         # Database scripts
│   └── seed.sql     # Optional seed data
└── utils/           # Utility scripts
    └── health-check.sh
```

## Prerequisites

- Ubuntu 20.04/22.04 DigitalOcean Droplet
- Minimum 2GB RAM (4GB recommended)
- Domain: trivia-engine.com pointing to droplet
- GitHub repository with your code

## Step-by-Step Deployment

### Step 1: Prepare Your Droplet

1. Create a new droplet on DigitalOcean
2. Choose Ubuntu 22.04 LTS
3. Select at least 2GB RAM
4. Add your SSH key
5. Set hostname to `trivia-engine`

### Step 2: Configure DNS

Point trivia-engine.com to your droplet:
- A record: `@` → `your-droplet-ip`
- A record: `www` → `your-droplet-ip`

### Step 3: Run Initial Setup

```bash
# SSH as root
ssh root@trivia-engine.com

# Clone the repository first
git clone https://github.com/yourusername/trivia-engine.git /tmp/trivia-setup
cd /tmp/trivia-setup

# Make script executable and run
chmod +x deploy/scripts/setup-server.sh
./deploy/scripts/setup-server.sh
```

You'll be prompted for:
- GitHub repository URL
- Database password
- SSL certificate email

### Step 4: Configure Environment

After setup, edit the environment files:

```bash
# Switch to trivia user
sudo su - trivia
cd trivia-engine

# Edit API environment
nano app/.env

# Edit Marketing environment
nano marketing/.env.local

# Edit MCP environment
nano mcp/.env
```

### Step 5: Deploy Application

```bash
# First deployment
./deploy/scripts/deploy.sh

# Check health
./deploy/utils/health-check.sh
```

## Common Operations

### View Logs

```bash
# PM2 logs
pm2 logs

# Specific service
pm2 logs trivia-api
pm2 logs trivia-marketing

# Nginx logs
sudo tail -f /var/log/nginx/trivia-engine.access.log
```

### Restart Services

```bash
# Restart all with zero downtime
pm2 reload all

# Restart specific service
pm2 restart trivia-api
```

### Database Operations

```bash
# Manual backup
pg_dump $DATABASE_URL | gzip > backup-$(date +%Y%m%d).sql.gz

# Restore backup
gunzip < backup-20240101.sql.gz | psql $DATABASE_URL

# Run migrations
cd app && npx prisma migrate deploy
```

### Update Code

```bash
# Standard deployment
./deploy/scripts/deploy.sh

# Deploy specific branch
./deploy/scripts/deploy.sh --branch develop

# Skip tests
./deploy/scripts/deploy.sh --skip-tests
```

## Monitoring

### Health Checks

```bash
# Manual health check
./deploy/utils/health-check.sh --verbose

# Setup automated checks (cron)
crontab -e
# Add: */5 * * * * /home/trivia/trivia-engine/deploy/utils/health-check.sh --alert
```

### PM2 Monitoring

```bash
# Interactive dashboard
pm2 monit

# Status overview
pm2 status

# Process info
pm2 info trivia-api
```

### System Resources

```bash
# Memory usage
free -h

# Disk usage
df -h

# CPU and load
htop
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
pm2 logs trivia-api --lines 100

# Test manually
cd app && node api/index.js

# Check environment
cat app/.env
```

### Database Connection Issues

```bash
# Test connection
psql $DATABASE_URL -c "SELECT 1"

# Check PostgreSQL
sudo systemctl status postgresql

# View PostgreSQL logs
sudo tail -f /var/log/postgresql/*.log
```

### Nginx Issues

```bash
# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx

# Check error log
sudo tail -f /var/log/nginx/trivia-engine.error.log
```

### SSL Certificate Issues

```bash
# Renew certificate
sudo certbot renew

# Force renewal
sudo certbot renew --force-renewal

# Check certificate
sudo certbot certificates
```

## Security Checklist

- [ ] Changed default passwords
- [ ] Configured firewall (ufw)
- [ ] Set up fail2ban
- [ ] Enabled automatic security updates
- [ ] Configured SSL/HTTPS
- [ ] Set proper file permissions
- [ ] Regular backups configured
- [ ] Monitoring alerts enabled

## Environment Variables

Key environment variables to configure:

### API (.env)
- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET` - Strong secret for JWT tokens
- `CORS_ORIGIN` - Allowed origins

### Marketing (.env.local)
- `NEXT_PUBLIC_API_BASE_URL` - API endpoint
- `NEXT_PUBLIC_DOMAIN` - Public domain

### MCP (.env)
- `API_BASE_URL` - API endpoint for MCP
- `API_KEY` - MCP API key

## Backup Strategy

Automated backups run daily at 2 AM:
- Database dumps to `/home/trivia/backups/`
- 30-day retention
- Compressed with gzip

Manual backup:
```bash
/home/trivia/backup.sh
```

## Performance Tuning

### PM2 Cluster Mode
The API runs in cluster mode using all CPU cores.

### Nginx Caching
Static assets are cached with long expiry times.

### Database Optimization
Run these periodically:
```bash
# Analyze and vacuum
psql $DATABASE_URL -c "VACUUM ANALYZE;"

# Check slow queries
psql $DATABASE_URL -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

## GitHub Actions Integration

To enable automated deployment via GitHub Actions:

1. Generate SSH key:
```bash
ssh-keygen -t ed25519 -C "github-actions"
```

2. Add public key to server:
```bash
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
```

3. Add secrets to GitHub:
- `SSH_PRIVATE_KEY` - Private key content
- `SSH_KNOWN_HOSTS` - Run: `ssh-keyscan trivia-engine.com`
- `DEPLOY_HOST` - trivia-engine.com
- `DEPLOY_USER` - trivia
- `PRODUCTION_URL` - trivia-engine.com

4. Push to main branch to trigger deployment

## Support

For issues:
1. Check health status: `./deploy/utils/health-check.sh --verbose`
2. Review logs: `pm2 logs`
3. Check this README
4. Review error logs: `/home/trivia/logs/`

## License

Copyright (c) 2024 Trivia Engine. All rights reserved.