#!/bin/bash
# =============================================================
# install.sh — One-time setup of Restic backup on the server
# =============================================================
# Run once as root on the server:
#   sudo bash /home/gigglin/My_server/backup/install.sh
# =============================================================

set -euo pipefail

BACKUP_DIR="/home/gigglin/My_server/backup"
LOG_FILE="/var/log/restic-backup.log"
CRON_FILE="/etc/cron.d/restic-backup"
RESTIC_BIN="/usr/local/bin/restic"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

echo "============================================"
echo "  Restic Backup Installer"
echo "============================================"
echo ""

# --- Must be root ---
if [[ "$EUID" -ne 0 ]]; then
  err "This script must be run as root: sudo bash $0"
fi

# --- Check .env exists ---
ENV_FILE="$BACKUP_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$BACKUP_DIR/.env.example" ]]; then
    warn ".env not found. Creating from .env.example..."
    cp "$BACKUP_DIR/.env.example" "$ENV_FILE"
    echo ""
    echo "Please edit $ENV_FILE and fill in your credentials:"
    echo "  nano $ENV_FILE"
    echo ""
    echo "Then re-run this script."
    exit 1
  else
    err ".env.example not found at $BACKUP_DIR/.env.example"
  fi
fi

# Validate required vars
source "$ENV_FILE"
for VAR in B2_ACCOUNT_ID B2_ACCOUNT_KEY B2_BUCKET_NAME RESTIC_PASSWORD NPM_DB_ROOT_PASSWORD; do
  if [[ -z "${!VAR:-}" ]] || [[ "${!VAR}" == *"your_"* ]] || [[ "${!VAR}" == *"here"* ]]; then
    err "Variable $VAR is not set in $ENV_FILE. Please fill it in first."
  fi
done
ok ".env looks good"

# --- Install restic ---
if command -v restic &>/dev/null; then
  ok "Restic already installed: $(restic version | head -1)"
else
  echo "Installing restic..."
  # Ensure bzip2 is available
  if ! command -v bunzip2 &>/dev/null; then
    apt-get install -y bzip2 > /dev/null 2>&1 || true
  fi

  RESTIC_VERSION=$(curl -s https://api.github.com/repos/restic/restic/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  RESTIC_VERSION="${RESTIC_VERSION:-0.17.3}"
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) RESTIC_ARCH="amd64" ;;
    aarch64|arm64) RESTIC_ARCH="arm64" ;;
    *) err "Unsupported architecture: $ARCH" ;;
  esac

  TMP=$(mktemp -d)
  curl -fsSL "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_${RESTIC_ARCH}.bz2" \
    -o "$TMP/restic.bz2"
  bunzip2 "$TMP/restic.bz2"
  install -m 755 "$TMP/restic" "$RESTIC_BIN"
  rm -rf "$TMP"
  ok "Restic installed: $(restic version | head -1)"
fi

# --- Make scripts executable ---
chmod +x "$BACKUP_DIR/backup.sh"
chmod +x "$BACKUP_DIR/restore.sh"
chmod 600 "$ENV_FILE"
ok "Script permissions set"

# --- Create log file ---
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"
ok "Log file: $LOG_FILE"

# --- Initialize restic repository ---
export B2_ACCOUNT_ID
export B2_ACCOUNT_KEY
export RESTIC_PASSWORD
export RESTIC_REPOSITORY="b2:${B2_BUCKET_NAME}"

echo ""
echo "Checking restic repository..."
if restic snapshots &>/dev/null; then
  ok "Repository already initialized (found existing snapshots)"
else
  echo "Initializing new repository in B2 bucket '${B2_BUCKET_NAME}'..."
  restic init
  ok "Repository initialized!"
fi

# --- Setup cron job ---
cat > "$CRON_FILE" << EOF
# Restic daily backup — runs at 03:00 every day
# Logs: $LOG_FILE
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

0 3 * * * root $BACKUP_DIR/backup.sh >> $LOG_FILE 2>&1
EOF

chmod 644 "$CRON_FILE"
ok "Cron job installed: $CRON_FILE (daily at 03:00)"

echo ""
echo "============================================"
echo -e "${GREEN}  Setup complete!${NC}"
echo "============================================"
echo ""
echo "Next steps:"
echo ""
echo "  1. Run a manual backup to test everything:"
echo "     sudo $BACKUP_DIR/backup.sh"
echo ""
echo "  2. Verify the snapshot was created:"
echo "     sudo $BACKUP_DIR/restore.sh list"
echo ""
echo "  3. Check the log:"
echo "     tail -50 $LOG_FILE"
echo ""
echo "  Backups will run automatically every day at 03:00"
echo "  Retention: 30 daily | 8 weekly | 12 monthly"
echo ""
