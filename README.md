# My HomeLab Server

This repository contains the configuration and deployment scripts for a personal HomeLab server running on **K3s (Kubernetes)** and **Docker**.

## 🏗 Infrastructure
- **Base OS**: Ubuntu (Orange Pi / VPS)
- **CRI**: K3s (Lightweight Kubernetes)
- **Ingress/Proxy**: Nginx Proxy Manager (Docker) - Handles SSL and external access for all services.
- **VPN**: 3X-UI / Xray (Managed via scripts in `_archive` or manual setup).

### Quick Start
1. **Setup Host**: Run `./infrastructure/setup.sh` (installs Docker, UFW).
2. **Install K3s**: Run `./infrastructure/install-k3s.sh`.
3. **Start NPM**: `docker-compose up -d` (in root).

---

## 💬 Matrix Server (Element Server Suite)
A complete Matrix stack with built-in VoIP (LiveKit).

- **Location**: [`matrix/`](./matrix)
- **Deployment**: `cd matrix && ./install.sh`
- **Diagnose**: `cd matrix && ./diagnose.sh`
- **Docs**: [Deployment Walkthrough](./matrix/WALKTHROUGH.md)

---

## ☁️ Nextcloud
Personal cloud storage with Talk (Video Calls).

- **Location**: [`nextcloud/`](./nextcloud)
- **Deployment**: `cd nextcloud && ./install.sh`
- **Features**:
    - File Storage (10Gi+ PVC)
    - Talk (P2P Calls enabled)
    - Redis & MariaDB optimizations

---

## 📂 Directory Structure
- `infrastructure/` - Core setup scripts.
- `matrix/` - Matrix-specific scripts and docs.
- `nextcloud/` - Nextcloud-specific scripts.
- `scripts/` - Maintenance and debug utilities.
- `_archive/` - Old configs and temporary files.
