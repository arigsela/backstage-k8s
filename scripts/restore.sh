#!/bin/bash

# Backstage Database Restore Script
# This script restores a PostgreSQL backup to the Backstage database

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if backup file is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: No backup file specified${NC}"
    echo "Usage: $0 <backup_file>"
    echo ""
    echo "Available backups:"
    ls -lh "$BACKUP_DIR"/backstage_backup_*.sql.gz 2>/dev/null || echo "No backups found in $BACKUP_DIR"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

# Check if docker-compose is running
if ! docker-compose ps | grep -q "backstage-postgres.*Up"; then
    echo -e "${RED}Error: PostgreSQL container is not running${NC}"
    exit 1
fi

echo -e "${YELLOW}WARNING: This will replace all data in the Backstage database!${NC}"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

echo -e "${GREEN}Starting Backstage database restore...${NC}"

# Stop Backstage application to prevent connections during restore
echo "Stopping Backstage application..."
docker-compose stop backstage

# Create temporary uncompressed file if backup is compressed
TEMP_FILE=""
if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo "Decompressing backup..."
    TEMP_FILE="${BACKUP_FILE%.gz}"
    gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"
    RESTORE_FILE="$TEMP_FILE"
else
    RESTORE_FILE="$BACKUP_FILE"
fi

# Drop existing connections and recreate database
echo "Preparing database for restore..."
docker-compose exec -T postgres psql -U backstage -d postgres <<EOF
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'backstage'
  AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS backstage;
CREATE DATABASE backstage;
EOF

# Restore backup
echo "Restoring backup..."
if docker-compose exec -T postgres psql -U backstage backstage < "$RESTORE_FILE"; then
    echo -e "${GREEN}Database restored successfully${NC}"
else
    echo -e "${RED}Error: Restore failed${NC}"
    # Clean up temp file if it exists
    [ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
    exit 1
fi

# Clean up temp file if it exists
[ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"

# Start Backstage application
echo "Starting Backstage application..."
docker-compose start backstage

# Wait for Backstage to be ready
echo "Waiting for Backstage to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:7007/healthcheck > /dev/null; then
        echo -e "${GREEN}Backstage is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo -e "\n${GREEN}Restore completed successfully!${NC}"
echo "Please verify your data at http://localhost:7007"