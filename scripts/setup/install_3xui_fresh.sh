#!/bin/bash
set -e

echo "=== Fresh 3x-ui VPN Installation Script ==="
echo ""

# Update system
echo "1. Updating system..."
apt update && apt upgrade -y

# Install required packages
echo ""
echo "2. Installing required packages..."
apt install -y curl wget git ufw

# Configure firewall
echo ""
echo "3. Configuring firewall..."
ufw allow 22/tcp
ufw allow 2053/tcp
ufw allow 443/tcp
ufw --force enable

# Install Docker
echo ""
echo "4. Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
else
    echo "Docker already installed"
fi

# Create 3x-ui directory
echo ""
echo "5. Creating 3x-ui directory..."
mkdir -p /root/3x-ui
cd /root/3x-ui

# Create docker-compose.yml
echo ""
echo "6. Creating docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  3x-ui:
    image: ghcr.io/mhsanaei/3x-ui:latest
    container_name: 3x-ui
    restart: unless-stopped
    network_mode: host
    environment:
      - XUI_V2RAY_LICENSE_KEY=
    volumes:
      - ./data:/etc/x-ui
      - ./certs:/etc/certs
EOF

# Performance optimization
echo ""
echo "7. Applying performance optimizations..."

# BBR and TCP tuning
cat >> /etc/sysctl.conf << 'EOF'

# BBR Congestion Control
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# TCP Buffer Tuning
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.ipv4.tcp_mtu_probing=1

# Network Optimization
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.ip_forward=1
EOF

sysctl -p

# Start 3x-ui
echo ""
echo "8. Starting 3x-ui..."
docker-compose up -d

# Wait for startup
echo ""
echo "9. Waiting for 3x-ui to start..."
sleep 10

# Show status
echo ""
echo "10. Checking status..."
docker ps | grep 3x-ui

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Access 3x-ui panel at: http://$(hostname -I | awk '{print $1}'):2053"
echo "Default credentials: admin / admin"
echo ""
echo "⚠️  IMPORTANT: Change the default password immediately!"
echo ""
echo "BBR Status:"
sysctl net.ipv4.tcp_congestion_control
echo ""
