#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Диагностика LIVEKIT_PUBLIC_URL ==="
echo ""

# Получить имя пода
POD_NAME=$(kubectl get pods -n ess -l app.kubernetes.io/name=matrix-rtc-authorisation-service -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD_NAME"
echo ""

# Проверить переменные в деплойменте
echo "[1] Переменные в Deployment (должно быть):"
kubectl get deployment -n ess ess-matrix-rtc-authorisation-service \
  -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' | grep LIVEKIT
echo ""

# Проверить переменные в запущенном поде
echo "[2] Переменные в запущенном Pod (фактически):"
kubectl exec -n ess $POD_NAME -- env | grep LIVEKIT || echo "LIVEKIT переменные не найдены!"
echo ""

echo "=========================================="
echo "АНАЛИЗ:"
echo "=========================================="
echo ""
echo "Если в Deployment есть LIVEKIT_PUBLIC_URL, но в Pod нет -"
echo "значит pod не перезапустился или переменная перезаписана."
echo ""
echo "Попробуй удалить pod принудительно:"
echo "  kubectl delete pod -n ess $POD_NAME"
echo ""
