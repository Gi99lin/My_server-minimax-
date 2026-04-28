#!/bin/bash
# ============================================================
# Marznode Deploy Script
# Deploys a marznode to a fresh VPS with Docker installed.
#
# Usage:
#   ./deploy_node.sh <node_name> <vps_ip>
#   SSH_PASS=mypassword ./deploy_node.sh <node_name> <vps_ip>
#
# Example:
#   ./deploy_node.sh nl1 85.208.110.9
#   SSH_PASS=secret123 ./deploy_node.sh nl2 194.60.132.37
# ============================================================

set -euo pipefail

NODE_NAME="${1:?Usage: $0 <node_name> <vps_ip>}"
VPS_IP="${2:?Usage: $0 <node_name> <vps_ip>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARZNODE_DIR="${SCRIPT_DIR}/../marzneshin/marznode"
NODE_DIR="${MARZNODE_DIR}/${NODE_NAME}"
REMOTE_DIR="/opt/marznode"
SSH_USER="${SSH_USER:-root}"
SSH_KEY="${SSH_KEY:-}"
SSH_PASS="${SSH_PASS:-}"

# Validate node exists
if [ ! -d "$NODE_DIR" ]; then
    echo "❌ Node directory not found: $NODE_DIR"
    echo "   Available nodes:"
    ls -d "${MARZNODE_DIR}"/*/  2>/dev/null | xargs -I{} basename {} || echo "   (none)"
    exit 1
fi

# Check required files
for file in xray_config.json singbox_config.json; do
    if [ ! -f "${NODE_DIR}/${file}" ]; then
        echo "❌ Missing ${file} in ${NODE_DIR}"
        exit 1
    fi
done

if [ ! -f "${MARZNODE_DIR}/client_cert.pem" ]; then
    echo "❌ Missing client_cert.pem in ${MARZNODE_DIR}"
    echo "   Copy it from the Marzneshin panel first."
    exit 1
fi

# SSH options
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
if [ -n "$SSH_KEY" ]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

# Wrap ssh/scp with sshpass if password is provided
if [ -n "$SSH_PASS" ]; then
    if ! command -v sshpass &>/dev/null; then
        echo "❌ sshpass not found. Install: brew install esolitos/ipa/sshpass"
        exit 1
    fi
    SSH_CMD="sshpass -p ${SSH_PASS} ssh ${SSH_OPTS}"
    SCP_CMD="sshpass -p ${SSH_PASS} scp ${SSH_OPTS}"
else
    SSH_CMD="ssh ${SSH_OPTS}"
    SCP_CMD="scp ${SSH_OPTS}"
fi

echo "🚀 Deploying marznode '${NODE_NAME}' to ${VPS_IP}..."
echo ""

# Step 1: Test SSH connectivity
echo "📡 Testing SSH connection..."
$SSH_CMD "${SSH_USER}@${VPS_IP}" "echo 'SSH OK'" || {
    echo "❌ Cannot connect to ${VPS_IP} via SSH"
    exit 1
}

# Step 2: System updates and Docker installation
echo "🐳 Updating system and ensuring Docker is installed..."
$SSH_CMD "${SSH_USER}@${VPS_IP}" '
    export DEBIAN_FRONTEND=noninteractive
    
    echo "Updating package lists..."
    apt-get update -qq
    
    echo "Installing security updates..."
    apt-get upgrade -y -qq
    
    echo "Setting up unattended-upgrades..."
    apt-get install -y -qq unattended-upgrades
    echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
    dpkg-reconfigure -f noninteractive unattended-upgrades

    if ! command -v docker &>/dev/null; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
    else
        echo "Docker already installed."
    fi
    docker --version
'

# Step 3: Create remote directory
echo "📁 Setting up remote directory..."
$SSH_CMD "${SSH_USER}@${VPS_IP}" "mkdir -p ${REMOTE_DIR} /var/lib/marznode"

# Step 4: Copy config files
echo "📦 Copying configuration files..."
COMPOSE_FILE="${MARZNODE_DIR}/docker-compose.yml"
if [ -f "${NODE_DIR}/docker-compose.yml" ]; then
    echo "📜 Using node-specific docker-compose.yml"
    COMPOSE_FILE="${NODE_DIR}/docker-compose.yml"
fi

$SCP_CMD \
    "${NODE_DIR}/xray_config.json" \
    "${NODE_DIR}/singbox_config.json" \
    "${COMPOSE_FILE}" \
    "${MARZNODE_DIR}/client_cert.pem" \
    "${SSH_USER}@${VPS_IP}:${REMOTE_DIR}/"

# Step 5: Generate Hysteria2 self-signed cert on server
echo "🔐 Generating Hysteria2 TLS certificate..."
$SSH_CMD "${SSH_USER}@${VPS_IP}" "
    if [ ! -f /var/lib/marznode/hysteria.cert ]; then
        openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
            -keyout /var/lib/marznode/hysteria.key \
            -out /var/lib/marznode/hysteria.cert \
            -subj '/CN=bing.com' -days 36500
        echo 'Hysteria2 cert generated.'
    else
        echo 'Hysteria2 cert already exists.'
    fi
"

# Step 6: Configure firewall (UFW)
echo "🛡️  Configuring firewall..."
$SSH_CMD "${SSH_USER}@${VPS_IP}" '
    if command -v ufw &>/dev/null; then
        ufw allow 22/tcp    # SSH
        ufw allow 443/tcp   # VLESS Reality
        ufw allow 10443/udp # Hysteria2
        ufw allow 1080/tcp  # Proxy (GOST)
        ufw allow 62050/tcp # Marznode <-> Panel
        ufw --force enable
        echo "UFW configured."
    else
        echo "UFW not found, skipping firewall setup."
        echo "⚠️  Make sure ports 443/tcp, 10443/udp, 1080/tcp, 62050/tcp are open!"
    fi
'

# Step 7: Start marznode
echo "🚀 Starting marznode..."
$SSH_CMD "${SSH_USER}@${VPS_IP}" "
    cd ${REMOTE_DIR}

    # Detect docker compose command
    if docker compose version &>/dev/null; then
        COMPOSE='docker compose'
    elif docker-compose version &>/dev/null; then
        COMPOSE='docker-compose'
    else
        echo 'Installing docker compose plugin...'
        apt-get update -qq && apt-get install -y -qq docker-compose-plugin 2>/dev/null \
            || (mkdir -p ~/.docker/cli-plugins && \
                curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-\$(uname -m) -o ~/.docker/cli-plugins/docker-compose && \
                chmod +x ~/.docker/cli-plugins/docker-compose)
        COMPOSE='docker compose'
    fi

    \$COMPOSE down 2>/dev/null || true
    \$COMPOSE pull
    \$COMPOSE up -d
    echo ''
    echo '✅ Marznode started. Checking logs...'
    sleep 3
    \$COMPOSE logs --tail=10
"

echo ""
echo "============================================"
echo "✅ Node '${NODE_NAME}' deployed to ${VPS_IP}"
echo ""
echo "Next steps:"
echo "  1. Add this node in Marzneshin panel:"
echo "     Address: ${VPS_IP}"
echo "     Port: 62050"
echo "  2. Create inbound configs in the panel"
echo ""
echo "Public keys for Marzneshin panel (Reality):"
case "$NODE_NAME" in
    nl1) echo "  PublicKey: uv0nhtNTdsHmFYoKFGMd3vO8JtpkKCf9yYf36wiH1jM" ;;
    nl2) echo "  PublicKey: KW0_1AlQW752_llEAOA_hiMK6GGp4JHS-bSRCjnctzE" ;;
    fi)  echo "  PublicKey: lgvlY3Vh-kzRAqllq6K0_GZPW1CoGPsaUuqFn2_JSmc" ;;
    us)  echo "  PublicKey: 53m9sAoGezwte6zoqtp_ocR6leyuhtMTE28_wiMMNVE" ;;
esac
echo "============================================"
