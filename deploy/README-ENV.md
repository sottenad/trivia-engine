# Environment Variables Setup Guide

This guide explains how to set up and manage environment variables for the Trivia Engine application.

## Quick Start

Use the automated setup script to generate secure environment files:

```bash
# For initial setup
./deploy/setup-env.sh

# To validate existing setup
./deploy/validate-env.sh
```

## Environment Files

The application uses three main environment files:

1. **`app/.env`** - API server configuration
2. **`marketing/.env.local`** - Marketing site configuration  
3. **`mcp/.env`** - MCP server configuration (optional)

These files are **NEVER** committed to git and are listed in `.gitignore`.

## Manual Setup

### 1. API Environment (`app/.env`)

```bash
cd app
cp ../.env.example .env
nano .env
```

Required variables:
- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET` - Secret for JWT tokens (generate with `openssl rand -base64 32`)
- `NODE_ENV` - Environment (development/production)
- `CORS_ORIGIN` - Allowed origins for CORS

### 2. Marketing Site (`marketing/.env.local`)

```bash
cd marketing
cp .env.example .env.local
nano .env.local
```

Required variables:
- `NEXT_PUBLIC_API_BASE_URL` - API endpoint URL
- `NEXT_PUBLIC_API_KEY` - API key for public endpoints

### 3. MCP Server (`mcp/.env`)

```bash
cd mcp
cp .env.example .env
nano .env
```

Required variables:
- `TRIVIA_API_BASE_URL` - API endpoint URL
- `TRIVIA_API_KEY` - API key for MCP access

## Security Best Practices

1. **Generate Strong Secrets**
   ```bash
   # Generate JWT secret
   openssl rand -base64 64
   
   # Generate API key
   echo "sk_$(openssl rand -base64 32 | tr -d '=')"
   ```

2. **Set Proper File Permissions**
   ```bash
   chmod 600 app/.env
   chmod 600 marketing/.env.local
   chmod 600 mcp/.env
   ```

3. **Different Values Per Environment**
   - Never reuse development secrets in production
   - Use different database credentials
   - Use environment-specific API keys

4. **Backup Secrets Securely**
   - Store production secrets in a password manager
   - Never email or message secrets
   - Use secure secret management tools for teams

## Environment-Specific Values

### Development
```bash
NODE_ENV=development
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/trivia_dev
CORS_ORIGIN=http://localhost:3000
JWT_SECRET=dev-secret-change-in-production
```

### Production
```bash
NODE_ENV=production
DATABASE_URL=postgresql://trivia_user:strong_password@localhost:5432/trivia_production
CORS_ORIGIN=https://yourdomain.com,https://www.yourdomain.com
JWT_SECRET=<use-generated-64-char-secret>
```

## Deployment

### First-Time Setup on Server

```bash
# SSH to server
ssh trivia@your-server.com

# Run setup script
cd /home/trivia/trivia-engine
./deploy/setup-env.sh

# The script will:
# - Generate secure secrets
# - Validate database connection
# - Create all required .env files
# - Set proper permissions
# - Save credentials to a temporary file
```

### Updating Environment Variables

```bash
# Edit the file
nano /home/trivia/trivia-engine/app/.env

# Restart services to apply changes
sudo systemctl restart trivia-api trivia-marketing
```

### GitHub Actions Secrets

Set these in your repository settings:

1. Go to Settings → Secrets and variables → Actions
2. Add these secrets:
   - `SSH_PRIVATE_KEY` - For deployment
   - `SSH_KNOWN_HOSTS` - Server fingerprint
   - `DEPLOY_HOST` - Your server address
   - `DEPLOY_USER` - Deployment username

## Validation

Run the validation script to check your setup:

```bash
./deploy/validate-env.sh
```

This will check:
- All required variables are set
- Database connection works
- File permissions are correct
- No sensitive files are tracked in git

## Troubleshooting

### Missing Environment Variables

```bash
# Check what's set
cat app/.env | grep -E "^[A-Z]" | cut -d'=' -f1

# Compare with example
diff <(cat .env.example | grep -E "^[A-Z]" | cut -d'=' -f1 | sort) \
     <(cat app/.env | grep -E "^[A-Z]" | cut -d'=' -f1 | sort)
```

### Database Connection Failed

```bash
# Test connection directly
psql "postgresql://user:pass@host:port/database" -c "SELECT 1"

# Check PostgreSQL is running
sudo systemctl status postgresql

# Check firewall
sudo ufw status
```

### Services Not Reading Environment

```bash
# Check systemd environment
sudo systemctl show trivia-api | grep Environment

# Check if file exists and readable
sudo -u trivia cat /home/trivia/trivia-engine/app/.env
```

### Git Tracking .env Files

```bash
# Remove from git (keeps local file)
git rm --cached app/.env
git rm --cached marketing/.env.local

# Verify gitignore
git check-ignore app/.env
```

## Important Notes

- The `setup-env.sh` script generates a `credentials.*.txt` file with your secrets
- **Delete this file** after saving the credentials securely
- Never share environment files or credentials
- Always use HTTPS in production for API URLs
- Rotate secrets periodically