#!/bin/bash

# Configuration
# Copy kubeconfig to tmp to avoid permission/snap issues
cp /etc/rancher/k3s/k3s.yaml /tmp/k3s.yaml
chmod 644 /tmp/k3s.yaml
export KUBECONFIG=/tmp/k3s.yaml

NAMESPACE="nextcloud"
SERVER_NAME="cloud.gigglin.tech"
# Initial admin password (change after login!)
ADMIN_USER="admin"
ADMIN_PASS="ChangeMe123!"

echo "=== Deploying Nextcloud to K3s ==="
echo "Domain: $SERVER_NAME"
echo "Namespace: $NAMESPACE"

# 1. Setup Namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 2. Add Helm Repo
helm repo add nextcloud https://nextcloud.github.io/helm/
helm repo update

# 3. Deploy Nextcloud
# We use the official chart. We disable internal ingress because we use external NPM.
# We enable MariaDB (default) for better performance than SQLite.
echo "Installing/Updating Nextcloud (this may take a few minutes)..."

helm upgrade --install nextcloud nextcloud/nextcloud \
  --namespace $NAMESPACE \
  -f ./values.yaml \
  --wait

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "1. Get NodePort:"
PORT=$(kubectl get svc -n $NAMESPACE nextcloud -o jsonpath='{.spec.ports[0].nodePort}')
echo "   Nextcloud HTTP Port: $PORT"
echo ""
echo "2. Configure Nginx Proxy Manager (NPM):"
echo "   - Domain Names: $SERVER_NAME"
echo "   - Scheme: http"
echo "   - Forward Hostname / IP: 192.168.1.11 (or local server IP)"
echo "   - Forward Port: $PORT"
echo "   - Websockets Support: ON"
echo "   - Block Common Exploits: OFF (Important for CalDav/CardDav)"
echo ""
echo "3. Finish Setup:"
echo "   Go to https://$SERVER_NAME"
echo "   Login with: $ADMIN_USER / $ADMIN_PASS"
echo "   (Change password immediately!)"
echo ""
echo "4. Enable Calls:"
echo "   - Log in as Admin"
echo "   - Go to Apps -> Multimedia"
echo "   - Enable 'Talk'"
echo "   - Done! (P2P calls work immediately)"
