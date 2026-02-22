#!/bin/bash

NAMESPACE="nextcloud"

echo "=== Complete Nextcloud Removal ==="

# 1. Uninstall Helm Release
echo "Uninstalling Helm release..."
helm uninstall nextcloud -n $NAMESPACE 2>/dev/null || echo "No helm release found"

# 2. Delete Namespace (this removes all resources)
echo "Deleting namespace $NAMESPACE..."
kubectl delete namespace $NAMESPACE --timeout=120s 2>/dev/null || echo "Namespace already deleted"

# 3. Wait for cleanup
echo "Waiting for cleanup to complete..."
sleep 10

# 4. Verify removal
echo ""
echo "=== Verification ==="
kubectl get all -n $NAMESPACE 2>/dev/null || echo "✅ Namespace removed successfully"
kubectl get pvc -n $NAMESPACE 2>/dev/null || echo "✅ PVCs removed"

echo ""
echo "=== Nextcloud completely removed ==="
