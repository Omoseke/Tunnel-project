# Tunneling script

Show your application to the world! This tool reverse forwards you applications on the localhost to a dynamically created URL that anybody can view at any point in the world.

## How this script works under the hood - The tunnel script

This script begins by defining the tool's domain, the path to the file that contains the ports, the base ports, and a random 8-digit number to create a subdomain.


```sh
DOMAIN="tunnelprime.online"
PORTS_FILE="/home/tunnel/used_ports.txt"
BASE_PORT=10000
SUBDOMAIN=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)

```

Next, create a `getport()` function that generates a random port number within a specific range and ensures that the port is not already in use

```
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
```

After creating the `getport()` function, next create a `newconnection()` 

```
function newsubdomain() {
    cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1
}
```
 
After creating the random subdomain, next create a `new_connection()` function. This function creates a new subdomain connection with these parts:


```
function newconnection() {
    local remote_port=$(getport)

    # Set up iptables rule for this specific SUBDOMAIN
    sudo iptables -t nat -A PREROUTING -p tcp -d "$SUBDOMAIN.$DOMAIN" --dport 80 -j REDIRECT --to-port $remote_port
    sudo iptables -t nat -A PREROUTING -p tcp -d "$SUBDOMAIN.$DOMAIN" --dport 443 -j REDIRECT --to-port $remote_port

    # Update Nginx configuration
    sudo tee /etc/nginx/sites-available/$SUBDOMAIN.conf > /dev/null <<EOF
server {
    listen 80;
    server_name $SUBDOMAIN.$DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $SUBDOMAIN.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/tunnelprime.online/fullchain.pem
    ssl_certificate_key /etc/letsencrypt/live/tunnelprime.online/privkey.pem

    location / {
        proxy_pass http://localhost:$remote_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    sudo ln -s /etc/nginx/sites-available/$SUBDOMAIN.conf /etc/nginx/sites-enabled/
    sudo nginx -s reload

    # Keep the script running
    while true; do
        sleep 10
    done 
}


newconnection 3000

```

The function above is made of different parts:
1. Generates a random port using the `getport` function

```
local remote_port=$(getport)
```

2. Set up the iptables

```
# Set up iptables rule for this specific SUBDOMAIN
sudo iptables -t nat -A PREROUTING -p tcp -d "$SUBDOMAIN.$DOMAIN" --dport 80 -j REDIRECT --to-port $remote_port
sudo iptables -t nat -A PREROUTING -p tcp -d "$SUBDOMAIN.$DOMAIN" --dport 443 -j REDIRECT --to-port $remote_port

```
These two lines creates two rules for the subdomain:
- The first rule redirects incoming HTTP traffic (port 80) destined for `SUBDOMAIN.DOMAIN` to the `remote_port`.
- The second rule redirects incoming HTTPS traffic (port 443) for the same subdomain to the `remote_port`.

3. Use Nginx for reverse proxy

```
sudo tee /etc/nginx/sites-available/$SUBDOMAIN.conf > /dev/null <<EOF
server {
    listen 80;
    server_name $SUBDOMAIN.$DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $SUBDOMAIN.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/tunnelprime.online/fullchain.pem
    ssl_certificate_key /etc/letsencrypt/live/tunnelprime.online/privkey.pem

    location / {
        proxy_pass http://localhost:$remote_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
```

4. Enable the Nginx Configuration and Reload Nginx

```
sudo ln -s /etc/nginx/sites-available/$SUBDOMAIN.conf /etc/nginx/sites-enabled/
sudo nginx -s reload
```
Creates a symbolic link to enable the new Nginx configuration and then reload Nginx to apply the changes.

6. Calls the `handle_connection` function and logs the ou:
```
while true; do
    sleep 10
done 

```
Puts the script in an infinite loop where it simply sleeps for 10 seconds repeatedly creating an uninteractive shell.

## How to use this script
To use this script, open your terminal, and run this command:

```
ssh -v -R 8080:localhost:3000 server@tunnelprime.online
```
