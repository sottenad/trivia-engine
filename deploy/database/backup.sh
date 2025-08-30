#!/bin/bash

# ==============================================================================
# TRIVIA ENGINE - DATABASE BACKUP SCRIPT
# ==============================================================================
# This script backs up the PostgreSQL database
# Can be run manually or via cron for scheduled backups
# ==============================================================================

set -e

# Configuration
DB_NAME="trivia_engine"
BACKUP_DIR="/home/trivia/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30
S3_BUCKET=""  # Optional: S3 bucket for offsite backups
ALERT_EMAIL="admin@trivia-engine.com"

# Parse arguments
RESTORE_FILE=""
LIST_BACKUPS=false
UPLOAD_S3=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --restore)
            RESTORE_FILE="$2"
            shift 2
            ;;
        --list)
            LIST_BACKUPS=true
            shift
            ;;
        --s3)
            UPLOAD_S3=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --restore <file>  Restore from backup file"
            echo "  --list            List available backups"
            echo "  --s3              Upload to S3 after backup"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create backup directory if it doesn't exist
mkdir -p ${BACKUP_DIR}

# Load environment variables
if [ -f "/home/trivia/trivia-engine/app/.env" ]; then
    export $(cat /home/trivia/trivia-engine/app/.env | grep -v '^#' | xargs)
fi

# Function to list backups
list_backups() {
    echo -e "${YELLOW}Available backups:${NC}"
    echo "----------------------------------------"
    ls -lh ${BACKUP_DIR}/*.sql.gz 2>/dev/null | awk '{print $9, $5}' | while read file size; do
        filename=$(basename "$file")
        echo -e "${GREEN}$filename${NC} ($size)"
    done
    
    # Count backups
    BACKUP_COUNT=$(ls ${BACKUP_DIR}/*.sql.gz 2>/dev/null | wc -l)
    echo "----------------------------------------"
    echo "Total backups: $BACKUP_COUNT"
    
    # Calculate total size
    TOTAL_SIZE=$(du -sh ${BACKUP_DIR} 2>/dev/null | cut -f1)
    echo "Total size: $TOTAL_SIZE"
}

# Function to perform backup
perform_backup() {
    echo -e "${YELLOW}Starting database backup...${NC}"
    
    # Check database size
    DB_SIZE=$(psql $DATABASE_URL -t -c "SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));" 2>/dev/null | tr -d ' ')
    echo "Database size: $DB_SIZE"
    
    # Create backup filename
    BACKUP_FILE="${BACKUP_DIR}/trivia_backup_${TIMESTAMP}.sql.gz"
    
    # Perform backup with progress
    echo "Creating backup: $(basename $BACKUP_FILE)"
    
    # Use pg_dump with custom options for better backups
    pg_dump $DATABASE_URL \
        --verbose \
        --no-owner \
        --no-acl \
        --clean \
        --if-exists \
        --create \
        --format=plain \
        --encoding=UTF8 | gzip -9 > "${BACKUP_FILE}"
    
    # Check if backup was successful
    if [ $? -eq 0 ] && [ -f "${BACKUP_FILE}" ]; then
        BACKUP_SIZE=$(ls -lh "${BACKUP_FILE}" | awk '{print $5}')
        echo -e "${GREEN}✓ Backup completed successfully${NC}"
        echo "File: ${BACKUP_FILE}"
        echo "Size: ${BACKUP_SIZE}"
        
        # Verify backup integrity
        if gunzip -t "${BACKUP_FILE}" 2>/dev/null; then
            echo -e "${GREEN}✓ Backup integrity verified${NC}"
        else
            echo -e "${RED}✗ Backup integrity check failed!${NC}"
            exit 1
        fi
        
        # Upload to S3 if requested
        if [ "$UPLOAD_S3" = true ] && [ ! -z "$S3_BUCKET" ]; then
            echo -e "${YELLOW}Uploading to S3...${NC}"
            if command -v aws &> /dev/null; then
                aws s3 cp "${BACKUP_FILE}" "s3://${S3_BUCKET}/backups/$(basename ${BACKUP_FILE})"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ Uploaded to S3${NC}"
                else
                    echo -e "${RED}✗ S3 upload failed${NC}"
                fi
            else
                echo -e "${YELLOW}AWS CLI not installed, skipping S3 upload${NC}"
            fi
        fi
        
        # Clean up old backups
        echo -e "${YELLOW}Cleaning up old backups...${NC}"
        find ${BACKUP_DIR} -name "trivia_backup_*.sql.gz" -mtime +${RETENTION_DAYS} -delete
        DELETED_COUNT=$(find ${BACKUP_DIR} -name "trivia_backup_*.sql.gz" -mtime +${RETENTION_DAYS} 2>/dev/null | wc -l)
        if [ $DELETED_COUNT -gt 0 ]; then
            echo "Deleted $DELETED_COUNT old backups (older than ${RETENTION_DAYS} days)"
        fi
        
        # Log backup info
        echo "[$(date)] Backup completed: ${BACKUP_FILE} (${BACKUP_SIZE})" >> ${BACKUP_DIR}/backup.log
        
        return 0
    else
        echo -e "${RED}✗ Backup failed!${NC}"
        
        # Send alert
        if command -v mail &> /dev/null; then
            echo "Database backup failed at $(date)" | mail -s "[ALERT] Trivia Engine Backup Failed" "$ALERT_EMAIL"
        fi
        
        return 1
    fi
}

# Function to restore from backup
restore_backup() {
    local backup_file="$1"
    
    # Check if file exists
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Error: Backup file not found: $backup_file${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                    RESTORE WARNING                          ║${NC}"
    echo -e "${YELLOW}║                                                              ║${NC}"
    echo -e "${YELLOW}║  This will REPLACE your current database!                   ║${NC}"
    echo -e "${YELLOW}║  All current data will be LOST!                             ║${NC}"
    echo -e "${YELLOW}║                                                              ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Backup file: $(basename $backup_file)"
    echo "Size: $(ls -lh $backup_file | awk '{print $5}')"
    echo ""
    echo -n "Are you sure you want to restore? (yes/no): "
    read confirmation
    
    if [ "$confirmation" != "yes" ]; then
        echo -e "${GREEN}Restore cancelled.${NC}"
        exit 0
    fi
    
    # Create a safety backup first
    echo -e "${YELLOW}Creating safety backup before restore...${NC}"
    SAFETY_BACKUP="${BACKUP_DIR}/pre_restore_safety_$(date +%Y%m%d_%H%M%S).sql.gz"
    pg_dump $DATABASE_URL | gzip > "${SAFETY_BACKUP}"
    echo -e "${GREEN}Safety backup created: ${SAFETY_BACKUP}${NC}"
    
    # Stop services
    echo -e "${YELLOW}Stopping services...${NC}"
    pm2 stop all
    
    # Restore database
    echo -e "${YELLOW}Restoring database...${NC}"
    
    # Drop existing connections
    psql $DATABASE_URL -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();" 2>/dev/null
    
    # Restore
    gunzip < "$backup_file" | psql $DATABASE_URL
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Database restored successfully${NC}"
        
        # Run migrations to ensure schema is up to date
        echo -e "${YELLOW}Running migrations...${NC}"
        cd /home/trivia/trivia-engine/app
        npx prisma migrate deploy
        
        # Restart services
        echo -e "${YELLOW}Restarting services...${NC}"
        pm2 restart all
        
        echo -e "${GREEN}✓ Restore completed successfully${NC}"
        echo "[$(date)] Restored from: ${backup_file}" >> ${BACKUP_DIR}/restore.log
    else
        echo -e "${RED}✗ Restore failed!${NC}"
        echo -e "${YELLOW}Attempting to restore safety backup...${NC}"
        gunzip < "${SAFETY_BACKUP}" | psql $DATABASE_URL
        pm2 restart all
        exit 1
    fi
}

# Main logic
if [ "$LIST_BACKUPS" = true ]; then
    list_backups
elif [ ! -z "$RESTORE_FILE" ]; then
    restore_backup "$RESTORE_FILE"
else
    perform_backup
fi