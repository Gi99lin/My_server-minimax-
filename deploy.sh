#!/bin/bash

# VPS Server Deployment Script
# Usage: ./deploy.sh [start|stop|restart|update|logs]

set -e

COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_NC='\033[0m'

PROJECT_DIR="/opt/vps-server"
DOMAIN="gigglin.tech"

log() {
    echo -e "${COLOR_GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${COLOR_YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${COLOR_RED}[ERROR]${NC} $1"
}

case "${1:-start}" in
    start)
        log "Starting all services..."
        cd "$PROJECT_DIR"
        docker-compose up -d
        log "All services started!"
        ;;

    stop)
        log "Stopping all services..."
        cd "$PROJECT_DIR"
        docker-compose down
        log "All services stopped!"
        ;;

    restart)
        log "Restarting all services..."
        cd "$PROJECT_DIR"
        docker-compose restart
        log "All services restarted!"
        ;;

    update)
        log "Updating services..."
        cd "$PROJECT_DIR"

        # Pull latest images
        docker-compose pull

        # Check if Synapse config exists
        if [ ! -f "matrix-data/homeserver.yaml" ]; then
            warn "Generating Synapse config..."
            docker run --rm \
                -v vps-server_matrix-data:/data \
                -e SYNAPSE_SERVER_NAME="$DOMAIN" \
                -e SYNAPSE_REPORT_STATS=no \
                matrixdotorg/synapse:latest generate

            # Add registration settings
            docker run --rm -v vps-server_matrix-data:/data alpine sh -c "cat >> /data/homeserver.yaml << 'EOF'

enable_registration: true
enable_registration_without_verification: true
EOF"
        fi

        docker-compose up -d
        log "Update complete!"
        ;;

    logs)
        cd "$PROJECT_DIR"
        docker-compose logs -f "${2:-}"
        ;;

    status)
        cd "$PROJECT_DIR"
        docker-compose ps
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|update|logs [service]}"
        exit 1
        ;;
esac
