# Миграция на Element Server Suite (K8s)

Пошаговое руководство по переходу с Docker Compose на Kubernetes (K3s) с использованием официального Element Server Suite Helm chart.

## Обзор

**Проблема:** Element X не может совершать звонки несмотря на правильную конфигурацию LiveKit в Docker.

**Решение:** Переход на проверенное решение Element Server Suite, которое включает:
- Matrix Synapse
- Element Web
- Element Call (видеозвонки)
- Интеграция LiveKit/Jitsi
- Автоматическая конфигурация

## Структура директории

```
k8s-migration/
├── 00-PLAN.md                # Детальный план миграции
├── 01-install-k3s.sh         # Установка K3s + Helm
├── 02-backup-current.sh      # Резервное копирование Docker
├── 03-ess-values.yaml        # Helm values для ESS
├── 04-deploy-ess.sh          # Развёртывание ESS
├── 05-stop-docker.sh         # Остановка Docker сервисов
└── README.md                 # Этот файл
```

## Пошаговая инструкция

### Шаг 0: Изучение плана

```bash
cat 00-PLAN.md
```

Прочитайте полный план, включая варианты миграции (A, B, C).

### Шаг 1: Резервное копирование

**ОБЯЗАТЕЛЬНО!** Создайте бэкапы перед любыми изменениями:

```bash
cd /root/My_server
chmod +x k8s-migration/02-backup-current.sh
./k8s-migration/02-backup-current.sh
```

Проверьте архив:
```bash
ls -lh backups/pre-k8s-*.tar.gz
```

### Шаг 2: Установка K3s

```bash
chmod +x k8s-migration/01-install-k3s.sh
./k8s-migration/01-install-k3s.sh
```

**Что делает скрипт:**
- Устанавливает K3s (lightweight Kubernetes)
- Отключает встроенный Traefik (используем NPM)
- Устанавливает Helm 3
- Добавляет Element Helm репозиторий

**Проверка:**
```bash
kubectl get nodes
# Должен показать Ready

helm version
# Должен показать v3.x
```

### Шаг 3: Настройка конфигурации

Отредактируйте [`03-ess-values.yaml`](k8s-migration/03-ess-values.yaml):

```bash
nano k8s-migration/03-ess-values.yaml
```

**Ключевые параметры:**
- `global.domain` - ваш домен (gigglin.tech)
- `synapse.postgresql` - подключение к PostgreSQL
- `elementWeb.ingress.hostname` - домен Element Web
- `elementCall.ingress.hostname` - домен Element Call

### Шаг 4: Развёртывание ESS

```bash
chmod +x k8s-migration/04-deploy-ess.sh
cd k8s-migration
./04-deploy-ess.sh
```

**Мониторинг развёртывания:**
```bash
# Следить за статусом pods
kubectl get pods -n matrix -w

# Логи Synapse
kubectl logs -n matrix -l app=synapse -f

# Все сервисы
kubectl get all -n matrix
```

### Шаг 5: Настройка Nginx Proxy Manager

Получите NodePort сервисов:
```bash
kubectl get svc -n matrix
```

Добавьте Proxy Hosts в NPM:

1. **app.gigglin.tech** → `localhost:[NodePort-element-web]`
   - SSL: Let's Encrypt
   - WebSocket: Enabled

2. **call.gigglin.tech** → `localhost:[NodePort-element-call]`
   - SSL: Let's Encrypt
   - WebSocket: Enabled

### Шаг 6: Проверка работоспособности

```bash
# Проверка .well-known
curl -s https://gigglin.tech/.well-known/matrix/client | jq .

# Проверка Matrix API
curl -s https://matrix.gigglin.tech/_matrix/client/versions | jq .

# Проверка Element Web
curl -I https://app.gigglin.tech

# Проверка Element Call
curl -I https://call.gigglin.tech
```

### Шаг 7: Тестирование звонков

1. Откройте [`https://app.gigglin.tech`](https://app.gigglin.tech)
2. Войдите в аккаунт
3. Создайте DM с другим пользователем
4. Нажмите кнопку видеозвонка
5. Проверьте логи:
   ```bash
   kubectl logs -n matrix -l app=element-call -f
   ```

### Шаг 8: Остановка Docker сервисов

**ТОЛЬКО ПОСЛЕ УСПЕШНОГО ТЕСТИРОВАНИЯ!**

```bash
chmod +x k8s-migration/05-stop-docker.sh
./k8s-migration/05-stop-docker.sh
```

Сервисы, которые останутся:
- PostgreSQL (используется K8s)
- Nginx Proxy Manager (reverse proxy)
- 3x-ui (VPN)

## Откат изменений

Если что-то пошло не так:

### 1. Удаление K8s deployment
```bash
helm uninstall matrix-stack -n matrix
kubectl delete namespace matrix
```

### 2. Восстановление Docker
```bash
cd /root/My_server
docker-compose up -d matrix-synapse matrix-mas livekit livekit-jwt-service redis
```

### 3. Восстановление БД (если нужно)
```bash
tar -xzf backups/pre-k8s-YYYYMMDD_HHMMSS.tar.gz
cat backups/pre-k8s-*/synapse.sql | docker exec -i postgres psql -U synapse_user synapse
cat backups/pre-k8s-*/mas.sql | docker exec -i postgres psql -U mas_user mas
```

## Полезные команды K8s

```bash
# Список всех pods
kubectl get pods -n matrix

# Логи конкретного pod
kubectl logs -n matrix <pod-name> -f

# Описание pod (для диагностики)
kubectl describe pod -n matrix <pod-name>

# Список сервисов
kubectl get svc -n matrix

# Перезапуск deployment
kubectl rollout restart deployment <name> -n matrix

# Shell в pod
kubectl exec -it <pod-name> -n matrix -- /bin/sh

# Удаление pod (автоматически пересоздастся)
kubectl delete pod <pod-name> -n matrix
```

## Часто задаваемые вопросы

### Q: Сколько RAM нужно для K3s?
**A:** Минимум 2GB. K3s (~500MB) + Synapse (~1GB) + PostgreSQL (~500MB).

### Q: Можно ли использовать текущий PostgreSQL из Docker?
**A:** Да, через `host.docker.internal` или IP хост-машины. Настроено в `03-ess-values.yaml`.

### Q: Что делать с 3x-ui и Telegram ботом?
**A:** Оставьте в Docker Compose. Они не конфликтуют с K8s.

### Q: Можно ли вернуться на Docker?
**A:** Да, используйте откат (см. выше). Бэкапы сохранены.

### Q: Traefik или NPM?
**A:** Используем NPM как единую точку входа. K3s Traefik отключён.

## DNS записи

Должны остаться прежними:

```
gigglin.tech            A    37.60.251.4
matrix.gigglin.tech     A    37.60.251.4
auth.gigglin.tech       A    37.60.251.4
app.gigglin.tech        A    37.60.251.4  # новая
call.gigglin.tech       A    37.60.251.4  # новая
livekit.gigglin.tech    A    37.60.251.4
```

## Поддержка

Логи для диагностики:

```bash
# K3s system
journalctl -u k3s -f

# ESS pods
kubectl logs -n matrix --all-containers=true -l app.kubernetes.io/instance=matrix-stack

# NPM
docker logs -f nginx-proxy-manager
```

## Полезные ссылки

- [Element Server Suite Helm](https://github.com/element-hq/ess-helm)
- [K3s Documentation](https://docs.k3s.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Matrix Synapse](https://matrix-org.github.io/synapse/)
