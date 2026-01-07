#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Разделение RTC на 2 домена ==="
echo ""
echo "mrtc.gigglin.tech → Authorization Service (JWT auth)"
echo "sfu.gigglin.tech → LiveKit SFU (WebSocket media)"
echo ""

# Найти правильное имя ConfigMap
echo "Поиск ConfigMap для .well-known..."
kubectl get cm -n ess | grep -i well-known || echo "Не найден well-known ConfigMap"
echo ""

echo "Все ConfigMaps в namespace ess:"
kubectl get cm -n ess
echo ""

# Попробуем найти deployment для .well-known
echo "Поиск deployment для .well-known:"
kubectl get deployment -n ess | grep -i well-known || echo "Не найден well-known deployment"
echo ""

echo "Все deployments в namespace ess:"
kubectl get deployment -n ess
echo ""

# Попробуем найти service
echo "Поиск service для .well-known:"
kubectl get svc -n ess | grep -i well-known || echo "Не найден well-known service"
echo ""

# Получить NodePort LiveKit SFU
SFU_NODEPORT=$(kubectl get svc -n ess ess-matrix-rtc-sfu -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "NOT_FOUND")
echo "LiveKit SFU NodePort: $SFU_NODEPORT"
echo ""

# Если well-known как отдельный сервис не существует, возможно он в haproxy
echo "Проверяю HAProxy ConfigMap:"
kubectl get cm -n ess | grep haproxy
echo ""

echo "=========================================="
echo "СЛЕДУЮЩИЙ ШАГ:"
echo "=========================================="
echo "Отправь мне полный вывод этого скрипта"
echo ""
