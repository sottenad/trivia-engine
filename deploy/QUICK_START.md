# Quick Start - Deployment Instructions

## On Your DigitalOcean Droplet

### Method 1: Direct from GitHub (Recommended)
```bash
# SSH into your droplet as root
ssh root@your-droplet-ip

# Download and run the setup script directly
curl -sSL https://raw.githubusercontent.com/sottenad/trivia-engine/main/deploy/scripts/setup-server.sh -o setup-server.sh
chmod +x setup-server.sh
bash setup-server.sh
```

### Method 2: Clone First, Then Run
```bash
# SSH into your droplet as root
ssh root@your-droplet-ip

# Clone the repository
git clone https://github.com/sottenad/trivia-engine.git /tmp/trivia-setup
cd /tmp/trivia-setup

# Make sure the script is executable and run it
chmod +x deploy/scripts/setup-server.sh
bash deploy/scripts/setup-server.sh
```

### Method 3: If Already Cloned
```bash
# Navigate to the repository
cd /path/to/trivia-engine

# Run with bash explicitly
bash deploy/scripts/setup-server.sh

# OR make executable and run
chmod +x deploy/scripts/setup-server.sh
./deploy/scripts/setup-server.sh
```

## Common Issues

### "cannot execute: required file not found"
This usually means:
1. **Line ending issue** - The script has Windows line endings
2. **Missing bash** - The system doesn't have bash at /bin/bash
3. **Wrong working directory** - Not running from the repository root

**Fix:**
```bash
# Convert line endings (if needed)
dos2unix deploy/scripts/setup-server.sh
# OR
sed -i 's/\r$//' deploy/scripts/setup-server.sh

# Then run with bash explicitly
bash deploy/scripts/setup-server.sh
```

### Permission Denied
```bash
chmod +x deploy/scripts/setup-server.sh
sudo bash deploy/scripts/setup-server.sh
```

## What the Setup Script Will Do

1. **Prompt for:**
   - GitHub repository URL (default: sottenad/trivia-engine)
   - Database password
   - Email for SSL certificates

2. **Install:**
   - Node.js 20
   - PostgreSQL 15
   - Nginx
   - PM2
   - SSL certificates (Let's Encrypt)

3. **Configure:**
   - Create trivia user
   - Set up databases
   - Configure firewall
   - Set up automated backups
   - Deploy your application

## After Setup

Once setup completes, your application will be available at:
- Website: https://trivia-engine.com
- API: https://trivia-engine.com/api/v1

## Regular Deployments

After initial setup, use:
```bash
cd /home/trivia/trivia-engine
./deploy/scripts/deploy.sh
```

## Complete Rebuild (Database + App)
```bash
cd /home/trivia/trivia-engine
./deploy/scripts/rebuild-all.sh --seed
```

## Nuclear Reset
```bash
cd /home/trivia/trivia-engine
./deploy/scripts/reset-server.sh
# Type: DELETE EVERYTHING
# Then run setup again
```