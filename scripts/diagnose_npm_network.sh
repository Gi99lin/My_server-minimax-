#!/bin/bash

echo "=== Nginx Proxy Manager Network Diagnostics ==="

# 1. Check NPM container status
echo "1. NPM Container Status:"
docker ps --filter name=nginx-proxy-manager --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. Check NPM network mode
echo ""
echo "2. NPM Network Configuration:"
docker inspect nginx-proxy-manager --format '{{.HostConfig.NetworkMode}}'

# 3. Check which networks NPM is connected to
echo ""
echo "3. NPM Connected Networks:"
docker inspect nginx-proxy-manager --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'

# 4. Get NPM container IP
echo ""
echo "4. NPM Container IP:"
NPM_IP=$(docker inspect nginx-proxy-manager --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "   $NPM_IP"

# 5. Test connectivity from NPM to host
echo ""
echo "5. Testing connectivity from NPM to host (192.168.1.11:31840):"
docker exec nginx-proxy-manager curl -I -m 5 http://192.168.1.11:31840 2>&1 || echo "   ❌ Cannot reach host IP"

# 6. Test connectivity from NPM to localhost
echo ""
echo "6. Testing connectivity from NPM to host via gateway:"
GATEWAY=$(docker inspect nginx-proxy-manager --format '{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}')
echo "   Gateway IP: $GATEWAY"
docker exec nginx-proxy-manager curl -I -m 5 http://$GATEWAY:31840 2>&1 || echo "   ❌ Cannot reach via gateway"

# 7. Check if NPM can resolve host
echo ""
echo "7. Testing if NPM can reach host.docker.internal:"
docker exec nginx-proxy-manager ping -c 2 host.docker.internal 2>&1 || echo "   ⚠️  host.docker.internal not available"

echo ""
echo "=== Diagnostics Complete ==="
echo ""
echo "💡 If NPM cannot reach 192.168.1.11:31840, the issue is network isolation."
echo "   Solution: Use 'host' network mode or use the gateway IP instead."
