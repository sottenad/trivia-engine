# GitHub Actions Deployment Setup

This guide explains how to set up automated deployment using GitHub Actions.

## Required GitHub Secrets

Go to your repository's Settings → Secrets and variables → Actions, and add these secrets:

### 1. `DO_HOST`
Your Digital Ocean droplet's IP address.
Example: `165.232.149.123`

### 2. `DO_USER`
SSH username for deployment (usually `root` or `trivia`).
Example: `root`

### 3. `DO_SSH_KEY`
Your private SSH key for accessing the server.

To get this:
```bash
# On your local machine, if you have an existing key:
cat ~/.ssh/id_rsa

# Or generate a new deployment key:
ssh-keygen -t rsa -b 4096 -f ~/.ssh/deploy_key -N ""
# Then add the public key to your server:
ssh-copy-id -i ~/.ssh/deploy_key.pub root@your-server-ip
# Copy the private key content:
cat ~/.ssh/deploy_key
```

### 4. `DATABASE_URL`
Your production PostgreSQL connection string.
Example: `postgresql://trivia_user:password@localhost:5432/trivia_engine`

### 5. `JWT_SECRET`
A secure random string for JWT signing (minimum 32 characters).
Generate one with: `openssl rand -base64 32`

## Server Prerequisites

Before the first deployment, ensure your server has:

1. **Node.js 20+ and npm installed**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

2. **PM2 installed globally**
```bash
sudo npm install -g pm2
```

3. **PostgreSQL installed and configured**
```bash
sudo apt install postgresql postgresql-contrib
```

4. **Nginx installed and configured** (from deploy.sh)

5. **Environment file created**
```bash
# Create /home/trivia/trivia-engine/app/.env with:
DATABASE_URL="your-connection-string"
JWT_SECRET="your-secret"
PORT=3003
```

## Deployment Process

### Automatic Deployment
Every push to the `main` branch triggers automatic deployment.

### Manual Deployment
1. Go to Actions tab in GitHub
2. Select "Deploy to Production" workflow
3. Click "Run workflow"
4. Select the branch to deploy

## Monitoring

### View deployment logs:
- GitHub Actions tab shows build and deployment progress
- On server: `pm2 logs` shows application logs

### Check service status:
```bash
pm2 status        # View all services
pm2 info api      # Detailed API info
pm2 info marketing # Detailed marketing site info
```

### View nginx logs:
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## Rollback

If deployment fails, the previous version remains on the server at:
```
/home/trivia/trivia-engine.backup
```

To rollback manually:
```bash
cd /home/trivia
mv trivia-engine trivia-engine.failed
mv trivia-engine.backup trivia-engine
pm2 restart all
```

## Troubleshooting

### Build fails with memory error
- The GitHub Actions runner has sufficient memory
- If local build needed, ensure swap space is configured

### SSH connection fails
- Verify SSH key is correctly added to GitHub secrets
- Check server firewall allows SSH from GitHub IPs
- Ensure public key is in server's authorized_keys

### Database migrations fail
- Verify DATABASE_URL secret is correct
- Check PostgreSQL is running: `sudo systemctl status postgresql`
- Check user permissions in PostgreSQL

### Services won't start
- Check logs: `pm2 logs api --lines 100`
- Verify .env file exists on server
- Check port availability: `sudo lsof -i :3003`

## Security Notes

- Never commit .env files or secrets to the repository
- Rotate SSH keys periodically
- Use strong passwords for database
- Keep secrets in GitHub, not in code
- Limit SSH access to specific IPs if possible