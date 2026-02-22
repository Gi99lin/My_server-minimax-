#!/bin/bash

# Setup kubectl access
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== K3s Prerequisites Check ==="

# 1. Check K3s is running
echo "1. Checking K3s service..."
if systemctl is-active --quiet k3s; then
    echo "   ✅ K3s is running"
else
    echo "   ❌ K3s is not running"
    echo "   Run: sudo systemctl start k3s"
    exit 1
fi

# 2. Check kubectl access
echo "2. Checking kubectl access..."
if sudo kubectl get nodes &>/dev/null; then
    echo "   ✅ kubectl is configured"
    sudo kubectl get nodes
else
    echo "   ❌ kubectl cannot connect"
    exit 1
fi

# 3. Check Helm
echo "3. Checking Helm..."
if command -v helm &>/dev/null; then
    echo "   ✅ Helm is installed ($(helm version --short))"
else
    echo "   ❌ Helm not found"
    echo "   Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# 4. Check storage provisioner
echo "4. Checking storage provisioner..."
if sudo kubectl get storageclass local-path &>/dev/null; then
    echo "   ✅ local-path storage class available"
else
    echo "   ⚠️  local-path storage class not found"
fi

# 5. Check DNS
echo "5. Checking CoreDNS..."
if sudo kubectl get pods -n kube-system -l k8s-app=kube-dns | grep -q Running; then
    echo "   ✅ CoreDNS is running"
else
    echo "   ⚠️  CoreDNS issues detected"
fi

# 6. Check available resources
echo "6. Checking node resources..."
sudo kubectl top node 2>/dev/null || echo "   ⚠️  Metrics not available (non-critical)"

echo ""
echo "=== Prerequisites Check Complete ==="
echo "If all critical checks passed (✅), you can proceed with installation."
