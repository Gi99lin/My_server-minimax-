# План миграции на Element Server Suite (ESS) в Kubernetes

## Текущая ситуация

**Работающие сервисы (Docker Compose):**
- 3x-ui (VPN) - порт 2096
- Nginx Proxy Manager (reverse proxy + SSL)
- Matrix Synapse + PostgreSQL
- Matrix Authentication Service (MAS)
- LiveKit + Redis + lk-jwt-service
- Telegram Bot (планируется)

**Проблема:**
Element X не может совершать звонки несмотря на правильную конфигурацию LiveKit.

## Стратегия миграции

### Этап 1: Подготовка и резервное копирование
1. ✅ Создать бэкапы баз данных PostgreSQL
2. ✅ Сохранить текущие конфигурации
3. ✅ Документировать все DNS записи

### Этап 2: Установка K3s (легковесный Kubernetes)
```bash
# K3s - минимальный Kubernetes, идеален для VPS
curl -sfL https://get.k3s.io | sh -

# Проверка
kubectl get nodes
```

**Почему K3s:**
- Легковесный (< 512MB RAM)
- Встроенный LoadBalancer (Traefik)
- Автоматические сертификаты Let's Encrypt
- Совместим с Helm charts

### Этап 3: Установка Helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Этап 4: Развёртывание ESS Helm

**Element Server Suite включает:**
- Matrix Synapse
- Element Web
- Element Call (для видеозвонков)
- TURN server (Coturn)
- PostgreSQL (опционально)

**Helm репозиторий:**
```bash
helm repo add ess https://element-hq.github.io/ess-helm
helm repo update
```

**Установка:**
```bash
helm install matrix-stack ess/element-server-suite \
  --set domain=gigglin.tech \
  --set matrixServerName=gigglin.tech \
  --set elementWeb.enabled=true \
  --set elementCall.enabled=true \
  --set postgresql.enabled=true
```

### Этап 5: Миграция данных

**PostgreSQL data:**
```bash
# Экспорт из текущего Docker
docker exec postgres pg_dump -U synapse_user synapse > synapse_backup.sql
docker exec postgres pg_dump -U mas_user mas > mas_backup.sql

# Импорт в K8s PostgreSQL pod
kubectl exec -it matrix-stack-postgresql-0 -- psql -U postgres < synapse_backup.sql
```

### Этап 6: DNS и SSL

**DNS записи (остаются прежними):**
- `gigglin.tech` → 37.60.251.4
- `matrix.gigglin.tech` → 37.60.251.4
- `auth.gigglin.tech` → 37.60.251.4
- `call.gigglin.tech` → 37.60.251.4 (новая для Element Call)

**SSL:** K3s Traefik автоматически получит Let's Encrypt сертификаты.

### Этап 7: Сохранение 3x-ui

**3x-ui остаётся в Docker:**
- Работает параллельно с K3s
- Не конфликтует (разные порты)
- NPM можно заменить на Traefik Ingress

## Альтернативный подход: Гибридная архитектура

**Оставить в Docker Compose:**
- 3x-ui (VPN)
- PostgreSQL (общий для всех)
- Nginx Proxy Manager (reverse proxy)
- Telegram Bot

**Перенести в K3s:**
- Matrix Synapse
- MAS
- Element Web/Call
- LiveKit (если ESS его поддерживает)

## Требования к серверу

**Минимальные:**
- 2 CPU cores
- 4GB RAM (K3s + Matrix + PostgreSQL)
- 20GB disk

**Ваш сервер:**
- Должен справиться без проблем
- Оставит ресурсы для Telegram бота и других сервисов

## Риски и недостатки K8s

1. **Сложность:** Kubernetes сложнее Docker Compose
2. **Отладка:** Логи и диагностика труднее
3. **Ресурсы:** K3s + Matrix = минимум 2GB RAM
4. **Оверкилл:** Для одного сервера K8s избыточен

## Рекомендация

**Вариант A: Минимальная миграция**
- Установить K3s
- Развернуть только Element Call через Helm (без полного ESS)
- Оставить Matrix/MAS в Docker
- Интегрировать Element Call с текущим Matrix

**Вариант B: Полная миграция**
- Установить K3s
- Развернуть весь ESS Helm chart
- Мигрировать данные PostgreSQL
- Остановить Docker Matrix сервисы

**Вариант C: Упрощение (отказ от LiveKit)**
- Остаться на Docker Compose
- Убрать LiveKit
- Использовать встроенные Matrix VoIP звонки (1-to-1)
- Настроить публичный TURN server (coturn.stunprotocol.org)

## Следующие шаги

1. Выбрать стратегию (A, B или C)
2. Создать полный бэкап текущей системы
3. Установить K3s (если выбрана A или B)
4. Тестировать на отдельном namespace в K8s
5. Переключить DNS только после проверки

---

**Вопрос:** Какой вариант предпочтительнее? Или попробуем сначала вариант A (Element Call в K8s + текущий Matrix в Docker)?
