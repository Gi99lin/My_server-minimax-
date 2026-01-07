# My Personal Server Utils

A hybrid **K3s (Matrix/Element)** + **Docker (Utils)** setup for a VPS server.

## 🏗 Architecture

| Component | Platform | Port | Description |
|-----------|----------|------|-------------|
| **Element Server Suite (ESS)** | K3s | - | Matrix homeserver, MAS (Auth), Element Web/Call |
| **Nginx Proxy Manager** | Docker | 80, 443, 81 | Reverse proxy, SSL termination |
| **3x-ui** | Docker | 2053, 2083, 2019, 11688 | VPN Panel and V2Ray/Xray protocols |
| **Landing** | Docker | 80 (internal) | Static landing page |

## 📁 Project Structure

```
├── docker-compose.yml     # Docker utilities (NPM, 3x-ui, Landing)
├── setup.sh               # Quick start for Docker utils
│
├── install-k3s.sh         # Step 1: Install K3s cluster
├── install-matrix.sh      # Step 2: Deploy Matrix (ESS)
├── fix-rtc.sh             # Step 3: Fix RTC Calling (LiveKit)
│
├── nginx-landing/         # Static website files
└── docs/                  # Documentation
    ├── NPM-CONFIG.md      # NPM Proxy Hosts guide
    └── K3S-SUMMARY.md     # Detailed K3s architecture docs
```

## 🚀 Quick Start (Fresh Server)

### 1. Install K3s & Matrix (Element)

```bash
# 1. Install K3s
chmod +x install-k3s.sh
./install-k3s.sh

# 2. Deploy Matrix Stack
chmod +x install-matrix.sh
./install-matrix.sh

# 3. Create Admin User
kubectl exec -n ess deployment/ess-matrix-authentication-service -- \
  mas-cli manage register-user --yes -p 'PASSWORD' -a admin
```

### 2. Install Docker Utils

```bash
# Installs Docker & Starts NPM, 3x-ui, Landing
chmod +x setup.sh
./setup.sh
```

### 3. Configure Network

1. **Open Nginx Proxy Manager**: `http://<YOUR_IP>:81`
   - Login: `admin@example.com` / `changeme`
2. **Setup Proxy Hosts**:
   - Follow the guide in: [docs/NPM-CONFIG.md](docs/NPM-CONFIG.md)
3. **Fix RTC Calling**:
   ```bash
   chmod +x fix-rtc.sh
   ./fix-rtc.sh
   ```

## 🔧 Management

### K3s (Matrix)
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get pods -n ess
kubectl logs -n ess -l app.kubernetes.io/name=synapse-main -f
```

### Docker (Utils)
```bash
docker compose logs -f
docker compose restart
```
