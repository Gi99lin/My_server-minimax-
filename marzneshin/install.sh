#!/bin/bash
set -e

echo "Deploying Marzneshin (Master) setup..."

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./install.sh <admin_username> <admin_password>"
    echo "Example: ./install.sh myadmin mysecurepass"
    exit 1
fi

ADMIN_USER=$1
ADMIN_PASS=$2

echo "Preparing environment..."
if [ ! -f .env ]; then
    cp .env.example .env
    # Generate random secure passwords
    SECURE_JWT=$(openssl rand -hex 32)
    DB_ROOT_PASS=$(openssl rand -hex 16)
    DB_PASS=$(openssl rand -hex 16)
    
    sed -i "s/c4a7b9d2e1f8c3b5a0d6f4e9c2b1a8d7f3e5c9a0b1d2f4e6c8a3b7d5f9e1c2a4/$SECURE_JWT/" .env
    sed -i "s/8f9c2b4e7d1a5f6c3b8a9d0e1f2c4b5a/$DB_ROOT_PASS/g" .env
    sed -i "s/3d7f1a9c2e8b4d6f5a0c1b3e9d7f8a2c/$DB_PASS/g" .env
    
    # Set default admin
    sed -i "s/SUDO_USERNAME=admin/SUDO_USERNAME=$ADMIN_USER/" .env
    sed -i "s/SUDO_PASSWORD=admin/SUDO_PASSWORD=$ADMIN_PASS/" .env
    echo "Created .env file with secure secrets and credentials."
else
    echo ".env file already exists. Skipping recreation."
fi

echo "Pulling latest Marzneshin image..."
docker compose pull

echo "Starting Marzneshin stack..."
docker compose up -d

echo "---------------------------------------------------------"
echo "Marzneshin deployment initiated."
echo "Wait a few seconds and visit: http://<your_server_ip>:8000/dashboard/"
echo "Username: $ADMIN_USER"
echo "Password: $ADMIN_PASS"
echo "Remember to login and change the password or add further 2FA!"
echo "---------------------------------------------------------"
