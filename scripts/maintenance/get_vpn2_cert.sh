#!/bin/bash
set -e

echo "=== Getting Let's Encrypt certificate for vpn2.gigglin.tech ==="
echo ""

echo "1. Stopping all containers..."
docker-compose stop

echo ""
echo "2. Getting certificate..."
certbot certonly --standalone --non-interactive --agree-tos \
  --email admin@gigglin.tech -d vpn2.gigglin.tech --force-renewal

echo ""
echo "3. Copying certificates..."
mkdir -p /var/lib/docker/volumes/3x-ui_certs/_data
cp /etc/letsencrypt/live/vpn2.gigglin.tech/fullchain.pem \
   /var/lib/docker/volumes/3x-ui_certs/_data/vpn2.gigglin.tech.crt
cp /etc/letsencrypt/live/vpn2.gigglin.tech/privkey.pem \
   /var/lib/docker/volumes/3x-ui_certs/_data/vpn2.gigglin.tech.key

echo ""
echo "4. Setting permissions..."
chmod 644 /var/lib/docker/volumes/3x-ui_certs/_data/vpn2.gigglin.tech.crt
chmod 600 /var/lib/docker/volumes/3x-ui_certs/_data/vpn2.gigglin.tech.key

echo ""
echo "5. Restarting containers..."
docker-compose up -d

echo ""
echo "=== Certificate installed! ==="
echo "Certificate: /etc/certs/vpn2.gigglin.tech.crt"
echo "Key: /etc/certs/vpn2.gigglin.tech.key"
