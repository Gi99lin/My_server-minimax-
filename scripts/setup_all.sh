#!/bin/bash
# Complete Server Setup - Step by Step Commands
# Run each section manually, don't execute the entire script at once!

echo "=========================================="
echo "PHASE 1: SYSTEM SETUP"
echo "=========================================="

# 1.1 Update system
sudo apt update && sudo apt upgrade -y

# 1.2 Install basic tools
sudo apt install -y curl wget git ufw net-tools

# 1.3 Configure firewall
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 81/tcp
sudo ufw --force enable
sudo ufw status

echo "✅ Phase 1 complete! Press Enter to continue to Phase 2..."
read

echo "=========================================="
echo "PHASE 2: INSTALL DOCKER"
echo "=========================================="

# 2.1 Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh

# 2.2 Add user to docker group
sudo usermod -aG docker $USER

# 2.3 Enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# 2.4 Install Docker Compose plugin
sudo apt install -y docker-compose-plugin

# 2.5 Verify
docker --version
docker compose version

echo "✅ Phase 2 complete!"
echo "⚠️  IMPORTANT: Log out and log back in for docker group to take effect!"
echo "Press Enter after you've logged back in to continue..."
read

echo "=========================================="
echo "PHASE 3: INSTALL K3S"
echo "=========================================="

# 3.1 Install K3s (using Chinese mirror)
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -

# 3.2 Wait for K3s to start
sleep 10

# 3.3 Verify K3s
sudo systemctl status k3s --no-pager
sudo kubectl get nodes

# 3.4 Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 3.5 Verify Helm
helm version

echo "✅ Phase 3 complete! Press Enter to continue to Phase 4..."
read

echo "=========================================="
echo "PHASE 4: CLONE REPOSITORY"
echo "=========================================="

# 4.1 Clone repository
cd ~
git clone https://github.com/Gi99lin/My_server.git
cd My_server

# 4.2 Review files
echo "Repository structure:"
ls -la
echo ""
echo "Docker Compose config:"
cat docker-compose.yml

echo "✅ Phase 4 complete! Press Enter to continue to Phase 5..."
read

echo "=========================================="
echo "PHASE 5: DEPLOY NGINX PROXY MANAGER"
echo "=========================================="

# 5.1 Start NPM
cd ~/My_server
docker compose up -d

# 5.2 Wait for initialization
echo "Waiting 30 seconds for NPM to initialize..."
sleep 30

# 5.3 Check status
docker ps
docker logs nginx-proxy-manager --tail=20

echo ""
echo "✅ Phase 5 complete!"
echo "📝 Next steps:"
echo "   1. Open browser: http://$(hostname -I | awk '{print $1}'):81"
echo "   2. Login with: admin@example.com / changeme"
echo "   3. Change email and password"
echo ""
echo "Press Enter when you've configured NPM to continue to Phase 6..."
read

echo "=========================================="
echo "PHASE 6: DEPLOY NEXTCLOUD"
echo "=========================================="

# 6.1 Verify K3s is ready
cd ~/My_server
sudo ./scripts/verify_k3s_ready.sh

echo ""
echo "Press Enter if all checks passed to continue..."
read

# 6.2 Install Nextcloud
cd ~/My_server/nextcloud
sudo ./install.sh

echo ""
echo "Waiting 2 minutes for Nextcloud to initialize..."
sleep 120

# 6.3 Check pods
sudo kubectl get pods -n nextcloud

# 6.4 Get NodePort
NODEPORT=$(sudo kubectl get svc -n nextcloud nextcloud -o jsonpath='{.spec.ports[0].nodePort}')
echo ""
echo "📝 Nextcloud NodePort: $NODEPORT"

# 6.5 Test locally
echo "Testing Nextcloud locally..."
curl -I http://127.0.0.1:$NODEPORT

# 6.6 Add trusted domain
echo ""
echo "Adding trusted domain..."
POD=$(sudo kubectl get pods -n nextcloud -l app.kubernetes.io/name=nextcloud -o jsonpath='{.items[0].metadata.name}')
sudo kubectl exec -n nextcloud $POD -- php occ config:system:set trusted_domains 1 --value='cloud.gigglin.tech'

# 6.7 Verify trusted domains
echo "Trusted domains:"
sudo kubectl exec -n nextcloud $POD -- php occ config:system:get trusted_domains

echo ""
echo "✅ Phase 6 complete!"
echo "📝 Nextcloud NodePort: $NODEPORT"
echo ""
echo "Press Enter to continue to Phase 7..."
read

echo "=========================================="
echo "PHASE 7: CONFIGURE NPM FOR NEXTCLOUD"
echo "=========================================="

echo "📝 Manual steps in NPM web interface:"
echo ""
echo "1. Open NPM: http://$(hostname -I | awk '{print $1}'):81"
echo "2. Go to 'Proxy Hosts' → 'Add Proxy Host'"
echo "3. Details tab:"
echo "   - Domain Names: cloud.gigglin.tech"
echo "   - Scheme: http"
echo "   - Forward Hostname/IP: 127.0.0.1"
echo "   - Forward Port: $NODEPORT"
echo "   - Cache Assets: OFF"
echo "   - Block Common Exploits: OFF"
echo "   - Websockets Support: ON"
echo ""
echo "4. SSL tab:"
echo "   - Request a new SSL Certificate"
echo "   - Force SSL: ON"
echo "   - HTTP/2 Support: ON"
echo "   - Email: your email"
echo "   - Agree to Let's Encrypt ToS"
echo ""
echo "5. Click Save"
echo ""
echo "Press Enter when you've configured the proxy..."
read

echo "=========================================="
echo "PHASE 8: VERIFICATION"
echo "=========================================="

echo "Testing Nextcloud access..."
echo ""
echo "From this server:"
curl -I https://cloud.gigglin.tech

echo ""
echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Open browser: https://cloud.gigglin.tech"
echo "   2. Login: admin / ChangeMe123!"
echo "   3. Change password immediately!"
echo ""
echo "🎉 Your Nextcloud is ready!"
