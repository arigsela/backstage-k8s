#!/bin/bash

# Backstage Database Backup Script
# This script creates timestamped backups of the Backstage PostgreSQL database

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backstage_backup_$TIMESTAMP.sql"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo -e "${GREEN}Starting Backstage database backup...${NC}"

# Check if docker-compose is running
if ! docker-compose ps | grep -q "backstage-postgres.*Up"; then
    echo -e "${RED}Error: PostgreSQL container is not running${NC}"
    exit 1
fi

# Perform backup
echo "Creating backup: $BACKUP_FILE"
if docker-compose exec -T postgres pg_dump -U backstage backstage > "$BACKUP_FILE"; then
    echo -e "${GREEN}Backup created successfully${NC}"
else
    echo -e "${RED}Error: Backup failed${NC}"
    exit 1
fi

# Compress backup
echo "Compressing backup..."
gzip "$BACKUP_FILE"
echo -e "${GREEN}Backup compressed: ${BACKUP_FILE}.gz${NC}"

# Get backup size
BACKUP_SIZE=$(ls -lh "${BACKUP_FILE}.gz" | awk '{print $5}')
echo "Backup size: $BACKUP_SIZE"

# Remove old backups
echo "Cleaning up old backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "backstage_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete

# List remaining backups
echo -e "\n${GREEN}Current backups:${NC}"
ls -lh "$BACKUP_DIR"/backstage_backup_*.sql.gz 2>/dev/null || echo "No backups found"

echo -e "\n${GREEN}Backup completed successfully!${NC}"