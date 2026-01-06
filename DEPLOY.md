# Deploy Instructions

## DNS Setup (IMPORTANT!)

| Type | Host | Value |
|------|------|-------|
| A | @ | 37.60.251.4 |
| A | www | 37.60.251.4 |
| CNAME | vpn | gigglin.tech |
| CNAME | matrix | gigglin.tech |

## On Your Local Machine

```bash
# Create GitHub repository and push
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git push -u origin main
```

## On VPS (37.60.251.4)

```bash
# Connect to VPS
ssh root@37.60.251.4

# Install Docker if not installed
curl -fsSL https://get.docker.com | sh

# Clone repository
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git /opt/vps-server
cd /opt/vps-server

# Create .env from example
cp .env.example .env

# Edit .env
nano .env
# Set:
# - TELEGRAM_BOT_TOKEN=your_bot_token
# - POSTGRES_PASSWORD=secure_password
# - MATRIX_DOMAIN=gigglin.tech

# Start all services
docker-compose up -d

# Check status
docker-compose ps
```

## Nginx Proxy Manager Setup

Access: http://37.60.251.4:81
Default login: admin@example.com / changeme

### Create Proxy Hosts

**1. Landing Page - gigglin.tech**
```
Domain Names: gigglin.tech, www.gigglin.tech
Forward Hostname/IP: landing
Forward Port: 80
SSL: Let's Encrypt
```

**2. VPN Panel - vpn.gigglin.tech**
```
Domain Names: vpn.gigglin.tech
Forward Hostname/IP: 3x-ui
Forward Port: 2053
SSL: Let's Encrypt
```

**3. Matrix - matrix.gigglin.tech**
```
Domain Names: matrix.gigglin.tech
Forward Hostname/IP: matrix-synapse
Forward Port: 8008
SSL: Let's Encrypt
```

## First Login

| Service | URL | Credentials |
|---------|-----|-------------|
| NPM Admin | http://37.60.251.4:81 | admin@example.com / changeme |
| 3x-ui | https://vpn.gigglin.tech | admin / admin |

## Matrix Setup

```bash
# Wait 2-3 minutes for initialization
docker exec -it matrix-synapse register_new_matrix_user http://localhost:8008 -c /data/config/homeserver.yaml

# Then use Element: https://app.element.io
```

## Landing Page

Accessible at: https://gigglin.tech
Shows "В разработке" (Under Construction) page with service info.
