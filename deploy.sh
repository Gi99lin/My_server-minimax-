#!/bin/bash

# VPS Server Deployment Script
# Usage: ./deploy.sh [start|stop|restart|update|logs]

set -e

COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_NC='\033[0m'

PROJECT_DIR="$(dirname "$(readlink -f "$0")")"

# Load environment variables (after PROJECT_DIR is set)
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    . "$PROJECT_DIR/.env"
    set +a
fi

DOMAIN="${MATRIX_DOMAIN:-gigglin.tech}"

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

        # Generate MAS config if it doesn't exist
        if [ ! -f "mas-config/config.yaml" ]; then
            warn "Generating MAS configuration..."
            mkdir -p "$PROJECT_DIR/mas-config"
            
            # Generate encryption key (32-byte hex-encoded = 64 hex chars)
            MAS_ENC_KEY=$(openssl rand -hex 32)
            
            # Generate RSA signing key
            MAS_RSA_KEY=$(openssl genrsa 2048 2>/dev/null)
            
            cat > "$PROJECT_DIR/mas-config/config.yaml" << ENDFILE
http:
  public_base: https://auth.${DOMAIN}/
  listeners:
    - name: web
      resources:
        - name: discovery
        - name: human
        - name: oauth
        - name: compat
      binds:
        - address: "0.0.0.0:8080"

database:
  uri: postgresql://matrix:${POSTGRES_PASSWORD}@matrix-postgres:5432/mas

matrix:
  homeserver: ${DOMAIN}
  secret: ${SYNAPSE_SECRET:-$(openssl rand -hex 32)}
  endpoint: "http://matrix-synapse:8008"

secrets:
  encryption: "${MAS_ENC_KEY}"
  keys:
    - kid: "default"
      key: |
$(echo "$MAS_RSA_KEY" | sed 's/^/        /')

passwords:
  enabled: true
  schemes:
    - version: 1
      algorithm: argon2id

account:
  password_registration_enabled: true
  password_change_allowed: true
ENDFILE

            chmod 600 "$PROJECT_DIR/mas-config/config.yaml"
            log "MAS configuration generated!"
        fi

        docker-compose up -d mas
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
