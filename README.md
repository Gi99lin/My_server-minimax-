# My HomeLab Server

This repository contains the configuration, deployment scripts, and docker-compose files for a personal HomeLab server infrastructure. It combines **Docker Compose** architectures for most services with **K3s (Kubernetes)** for specific enterprise stacks like Matrix.

## 🏗 Infrastructure Overview
- **Base OS**: Ubuntu (VPS / Local Mini PC)
- **Container Runtimes**: Docker (Portainer/Native) & K3s (Lightweight Kubernetes)
- **Ingress & Proxy**: [Nginx Proxy Manager](https://nginxproxymanager.com/) running via docker in the root directory. Handles SSL termination and subdomains.
- **Landing Page**: Custom nginx-based landing page running alongside NPM.

### 🚀 Quick Start
1. **Basic Host Setup**: Configure your Ubuntu server environment and firewall limits.
2. **Setup Proxy & Landing**: At the root of this project, run `docker compose up -d` to spin up Nginx Proxy Manager and the local Landing page.
3. **Deploy Services**: Navigate to individual directories (e.g., `cd openclaw`) to configure `.env` files and run deployment commands/scripts.

*(For detailed local Matrix deployment and K3s instructions, see [LOCAL_DEPLOY.md](./LOCAL_DEPLOY.md))*

---

## 🤖 AI & LLM Ecosystem

### OpenClaw (Multi-Agent System)
Personal AI assistant framework with persistent memory, multi-agent orchestration, and Telegram bots (Dev Team, QA, FinAnalyst, etc.).
- **Location**: [`openclaw/`](./openclaw)
- **Deployment**: `cd openclaw && docker compose up -d`

### LibreChat
An enterprise-grade, unified web interface for interacting with various LLM providers.
- **Location**: [`librechat/`](./librechat)

### OmniRoute
API routing proxy and load balancer to manage, monitor, and route inference LLM requests (used seamlessly by OpenClaw).
- **Location**: [`omniroute/`](./omniroute)

---

## 🛡️ Privacy, Proxy & VPN

### Marzneshin (Xray Proxy)
Advanced VPN and proxy management interface using the Xray core. Handles secure access workflows.
- **Location**: [`marzneshin/`](./marzneshin)

---

## ☁️ Cloud & Synchronization

### Nextcloud
Self-hosted platform for comprehensive file storage, calendar, and contacts synchronization. Includes Talk integration.
- **Location**: [`nextcloud/`](./nextcloud)

### Syncthing
Decentralized, continuous file synchronization service operating smoothly across devices.
- **Location**: [`syncthing/`](./syncthing)

---

## 💬 Communication

### Matrix Server (Element Server Suite)
A complete federated Matrix messaging stack with built-in VoIP via LiveKit. Deployed entirely on K3s.
- **Location**: [`matrix/`](./matrix)
- **Docs**: [Deployment Walkthrough](./matrix/WALKTHROUGH.md)

---

## 📂 Full Directory Structure
- `dashboard/` - Minimal start dashboard configuration.
- `infrastructure/` - Core host and K3s installation scripts.
- `librechat/` - Chat UI for local and remote LLMs.
- `livekit-config/` - Custom configuration sets for LiveKit services.
- `marzneshin/` - Xray proxy panel configuration.
- `matrix/` - Complete Matrix deployment scripts for K3s.
- `nextcloud/` - Nextcloud deployment files.
- `nginx-landing/` - Source for the web landing page (starts via root docker-compose).
- `omniroute/` - Setup for LLM proxy routing.
- `openclaw/` - The OpenClaw AI Multi-Agent architecture.
- `scripts/` - Maintenance and utility bash scripts.
- `syncthing/` - File synchronization component.
- `_archive/` - Archived templates and legacy files.
- `backup/` - Tools or scripts associated with taking system backups.
