#!/bin/bash
# =============================================================
# restore.sh — Restore server from Restic backup (Backblaze B2)
# =============================================================
# Usage:
#   ./restore.sh              — показать список снапшотов
#   ./restore.sh list         — список снапшотов
#   ./restore.sh restore      — восстановить последний снапшот
#   ./restore.sh restore <ID> — восстановить конкретный снапшот
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# --- Load credentials ---
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  echo "Copy .env.example to .env and fill in your credentials."
  exit 1
fi
source "$ENV_FILE"

export B2_ACCOUNT_ID
export B2_ACCOUNT_KEY
export RESTIC_PASSWORD
export RESTIC_REPOSITORY="b2:${B2_BUCKET_NAME}"

CMD="${1:-list}"

case "$CMD" in
  # ============================================================
  list)
    echo "Available snapshots:"
    echo "-----------------------------------"
    restic snapshots
    ;;

  # ============================================================
  restore)
    SNAPSHOT="${2:-latest}"
    RESTORE_TARGET="${3:-/tmp/restic-restore}"

    echo "============================================"
    echo "RESTORE PLAN"
    echo "============================================"
    echo "Snapshot : $SNAPSHOT"
    echo "Target   : $RESTORE_TARGET"
    echo ""
    echo "WARNING: This will restore files to $RESTORE_TARGET"
    echo "It will NOT overwrite your current /home/gigglin/ automatically."
    echo "You will need to manually move files after review."
    echo ""
    read -r -p "Continue? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
      echo "Aborted."
      exit 0
    fi

    mkdir -p "$RESTORE_TARGET"
    echo "Restoring snapshot '$SNAPSHOT' to $RESTORE_TARGET ..."
    restic restore "$SNAPSHOT" --target "$RESTORE_TARGET" --verbose

    echo ""
    echo "============================================"
    echo "Restore complete!"
    echo "Files are in: $RESTORE_TARGET"
    echo ""
    echo "Next steps:"
    echo "  1. Review the restored files:"
    echo "     ls $RESTORE_TARGET/home/gigglin/"
    echo ""
    echo "  2. Restore configs to your home dir:"
    echo "     rsync -av $RESTORE_TARGET/home/gigglin/My_server/ /home/gigglin/My_server/"
    echo ""
    echo "  3. Restore Docker volumes:"
    echo "     ls $RESTORE_TARGET/var/lib/docker/volumes/"
    echo "     # Then for each volume, e.g.:"
    echo "     # docker volume create vps-server_nginx-data"
    echo "     # docker run --rm -v vps-server_nginx-data:/dest -v \\"
    echo "     #   $RESTORE_TARGET/var/lib/docker/volumes/vps-server_nginx-data/_data:/src alpine \\"
    echo "     #   sh -c 'cp -a /src/. /dest/'"
    echo ""
    echo "  4. Restore database from dump:"
    echo "     ls $RESTORE_TARGET/tmp/restic-db-dumps/"
    echo "     # Then:"
    echo "     # cat $RESTORE_TARGET/tmp/restic-db-dumps/npm-all-databases.sql | \\"
    echo "     #   docker exec -i nginx-proxy-manager-db mysql -uroot -p\${NPM_DB_ROOT_PASSWORD}"
    echo ""
    echo "  5. Restart all services:"
    echo "     cd /home/gigglin/My_server && docker compose up -d"
    echo "============================================"
    ;;

  # ============================================================
  check)
    echo "Running repository integrity check..."
    restic check
    ;;

  # ============================================================
  stats)
    echo "Repository statistics:"
    restic stats
    ;;

  # ============================================================
  *)
    echo "Usage: $0 [list|restore [snapshot_id] [target]|check|stats]"
    exit 1
    ;;
esac
