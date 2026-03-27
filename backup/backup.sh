#!/bin/bash
# =============================================================
# backup.sh — Daily server backup to Backblaze B2 via Restic
# =============================================================
# Runs automatically via cron at 03:00 every day.
# Backs up: /home/gigglin/ + /var/lib/docker/volumes/ + DB dumps
# =============================================================

set -euo pipefail

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
LOG_FILE="/var/log/restic-backup.log"
DUMP_DIR="/tmp/restic-db-dumps"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# --- Load credentials ---
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[$TIMESTAMP] ERROR: .env file not found at $ENV_FILE" | tee -a "$LOG_FILE"
  exit 1
fi
# shellcheck source=.env
source "$ENV_FILE"

export B2_ACCOUNT_ID
export B2_ACCOUNT_KEY
export RESTIC_PASSWORD
export RESTIC_REPOSITORY="b2:${B2_BUCKET_NAME}"

# --- Logging helper ---
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# --- Telegram notification (optional) ---
notify() {
  local msg="$1"
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="${TELEGRAM_CHAT_ID}" \
      -d text="🖥️ Backup server: ${msg}" \
      -d parse_mode="Markdown" > /dev/null 2>&1 || true
  fi
}

# --- Rotate logs (keep last 5000 lines) ---
if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE") -gt 5000 ]]; then
  tail -5000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

log "=========================================="
log "Starting backup"
log "=========================================="
BACKUP_START=$(date +%s)

# --- 1. Database dumps ---
log "Step 1: Dumping databases..."
mkdir -p "$DUMP_DIR"
chmod 700 "$DUMP_DIR"

# Nginx Proxy Manager MariaDB
if docker ps --format '{{.Names}}' | grep -q "^nginx-proxy-manager-db$"; then
  log "  Dumping MariaDB (nginx-proxy-manager-db)..."
  docker exec nginx-proxy-manager-db \
    mysqldump --all-databases -uroot -p"${NPM_DB_ROOT_PASSWORD}" \
    --single-transaction --quick --lock-tables=false \
    > "$DUMP_DIR/npm-all-databases.sql" 2>>"$LOG_FILE"
  log "  MariaDB dump: OK ($(du -sh "$DUMP_DIR/npm-all-databases.sql" | cut -f1))"
else
  log "  MariaDB container not running — skipping dump"
fi

# Marzneshin (SQLite — просто будет включён в бэкап папки)
if docker ps --format '{{.Names}}' | grep -qi "marzneshin"; then
  log "  Marzneshin uses SQLite — included in volume backup automatically"
fi

# --- 2. Restic backup ---
log "Step 2: Running restic backup..."

restic backup \
  /home/gigglin/ \
  /var/lib/docker/volumes/ \
  /srv/nextcloud-data \
  "$DUMP_DIR" \
  --exclude="/home/gigglin/.cache" \
  --exclude="/home/gigglin/.local/share/Trash" \
  --exclude="/home/gigglin/snap" \
  --exclude="*.tmp" \
  --exclude="*.log.gz" \
  --exclude="node_modules" \
  --exclude="__pycache__" \
  --exclude=".git/objects/pack" \
  --tag "daily" \
  --tag "auto" \
  --verbose=1 \
  2>&1 | tee -a "$LOG_FILE"

log "Step 2: Restic backup complete"

# --- 3. Forget old snapshots (retention policy) ---
log "Step 3: Applying retention policy..."
restic forget \
  --keep-daily 30 \
  --keep-weekly 8 \
  --keep-monthly 12 \
  --prune \
  2>&1 | tee -a "$LOG_FILE"
log "Step 3: Retention policy applied"

# --- 4. Verify integrity (weekly — on Sundays) ---
if [[ "$(date '+%u')" == "7" ]]; then
  log "Step 4: Running weekly integrity check..."
  restic check 2>&1 | tee -a "$LOG_FILE"
  log "Step 4: Integrity check complete"
fi

# --- 5. Cleanup temp dumps ---
rm -rf "$DUMP_DIR"

# --- Summary ---
BACKUP_END=$(date +%s)
DURATION=$(( BACKUP_END - BACKUP_START ))
DURATION_MIN=$(( DURATION / 60 ))
DURATION_SEC=$(( DURATION % 60 ))

log "=========================================="
log "Backup completed in ${DURATION_MIN}m ${DURATION_SEC}s"
log "=========================================="

notify "✅ Backup completed successfully in ${DURATION_MIN}m ${DURATION_SEC}s"
