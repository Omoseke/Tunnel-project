#!/bin/bash

DOMAIN="tunnelprime.online"
PORTS_FILE="/home/tunnel/used_ports.txt"
BASE_PORT=10000

function log() {
    echo "$(date): $1" >> "/home/server/tunnel_debug.log"
}

function getport() {
    while true; do
        PORT=$((BASE_PORT + RANDOM % 55535))
        if ! grep -q "^$PORT$" "$PORTS_FILE" 2>/dev/null; then
            echo "$PORT" >> "$PORTS_FILE"
            echo "$PORT"
            return
        fi
    done
}

function remove_port() {
    local port=$1
    sed -i "/^$port$/d" "$PORTS_FILE"
}

function newconnection() {
    local local_port=$1
    local remote_port=$(getport)
    local subdomain=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)

    log "Handling connection: $subdomain.$DOMAIN -> localhost:$local_port (Remote port: $remote_port)"
    echo "Tunnel established: http://$subdomain.$DOMAIN" | tee /home/server/tunnel_url.txt

    # Set up iptables rule for this specific subdomain
    sudo iptables -t nat -A PREROUTING -p tcp -d "$subdomain.$DOMAIN" --dport 80 -j REDIRECT --to-port $remote_port || { log "Failed to set iptables rule for port 80"; exit 1; }
    sudo iptables -t nat -A PREROUTING -p tcp -d "$subdomain.$DOMAIN" --dport 443 -j REDIRECT --to-port $remote_port || { log "Failed to set iptables rule for port 443"; exit 1; }

    # Update Nginx configuration
    sudo tee /etc/nginx/sites-available/$subdomain.conf > /dev/null <<EOF
server {
    listen 80;
    server_name $subdomain.$DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $subdomain.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/tunnelprime.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/tunnelprime.online/privkey.pem;

    location / {
        proxy_pass http://localhost:$remote_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    sudo ln -s /etc/nginx/sites-available/$subdomain.conf /etc/nginx/sites-enabled/ || { log "Failed to create symlink for Nginx"; exit 1; }
    sudo nginx -s reload 2>/dev/null || { log "Failed to reload Nginx"; exit 1; }

    log "Tunnel active. Press Ctrl+C to exit."
    # Keep the script running
    while true; do
        sleep 10
    done
}

newconnection 3000
