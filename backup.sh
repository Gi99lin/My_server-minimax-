#!/bin/bash

# Backup script for VPS server services
# Usage: ./backup.sh [daily|weekly|monthly]

set -e

BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/opt/vps-server"
RETENTION_DAYS=7

# Function to check command result
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} $1"
    else
        echo -e "${RED}[FAIL]${NC} $1"
        exit 1
    fi
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Starting backup at $DATE..."

# Stop services
cd "$PROJECT_DIR"
echo "Stopping services..."
docker-compose down
check_status "Services stopped"

# Create backup archive
BACKUP_FILE="$BACKUP_DIR/backup_${DATE}.tar.gz"
echo "Creating backup archive..."
tar czf "$BACKUP_FILE" \
    -C "$PROJECT_DIR" \
    docker-compose.yml \
    .env \
    telegram-bot/

check_status "Backup created: $BACKUP_FILE"

# Start services
echo "Starting services..."
docker-compose up -d
check_status "Services started"

# Cleanup old backups
echo "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete
check_status "Old backups cleaned up"

# Show backup info
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo ""
echo -e "${GREEN}=== Backup Complete ===${NC}"
echo "File: $BACKUP_FILE"
echo "Size: $BACKUP_SIZE"
echo "Backups kept: $(find "$BACKUP_DIR" -name "backup_*.tar.gz" | wc -l)"
