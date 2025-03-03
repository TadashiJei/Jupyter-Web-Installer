#!/bin/bash

# Cloudflare Tunnel Setup Script for JupyterHub
# This script automates the Cloudflare Tunnel setup process after JupyterHub installation
# Created by Tadashi Jei (www.tadashijei.com)

set -e

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# ASCII Art
cat << "EOF"
      _                   _           _   _       _     
     | |_   _ _ __  _   _| |_ ___ _ _| |_| |_   _| |__  
  _  | | | | | '_ \| | | | __/ _ \ '__| __| | | | | '_ \ 
 | |_| | |_| | |_) | |_| | ||  __/ |  | |_| | |_| | |_) |
  \___/ \__,_| .__/ \__, |\__\___|_|   \__|_|\__,_|_.__/ 
             |_|    |___/                                
  _____                        _   _____      _               
 / ____|                      | | |  __ \    | |              
| |     ___  _ __  _ __   ___| |_| |__) |___| |_ _   _ _ __  
| |    / _ \| '_ \| '_ \ / _ \ __|  _  // _ \ __| | | | '_ \ 
| |___| (_) | | | | | | |  __/ |_| | \ \  __/ |_| |_| | | | |
 \_____\___/|_| |_|_| |_|\___|\__|_|  \_\___|\__|\__,_|_| |_|
                                      by Tadashi Jei
EOF
echo

echo -e "${BLUE}=== Cloudflare Tunnel Setup for JupyterHub ===${NC}"
echo -e "${BLUE}This script will guide you through setting up a Cloudflare Tunnel for your JupyterHub server.${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script as root or with sudo.${NC}"
  exit 1
fi

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
  echo -e "${RED}cloudflared is not installed. Please run the main installer script first.${NC}"
  exit 1
fi

# Check if JupyterHub is running
if ! systemctl is-active --quiet jupyterhub; then
  echo -e "${RED}JupyterHub service is not running. Please ensure JupyterHub is installed and running.${NC}"
  exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
  echo -e "${YELLOW}Installing curl...${NC}"
  apt update && apt install -y curl
fi

# Check if jq is installed (needed for API processing)
if ! command -v jq &> /dev/null; then
  echo -e "${YELLOW}Installing jq for JSON processing...${NC}"
  apt update && apt install -y jq
fi

# Function to display section headers
section() {
  echo
  echo -e "${GREEN}=== $1 ===${NC}"
}

# Function for automatic Cloudflare setup using API
automatic_cloudflare_setup() {
  local api_key=$1
  local email=$2
  local domain=$3
  local subdomain=$4
  local tunnel_name=$5
  local account_id
  local zone_id
  local tunnel_id
  local tunnel_token
  
  echo -e "${BLUE}Starting automatic Cloudflare Tunnel setup...${NC}"
  
  # Get Account ID
  echo -e "${YELLOW}Fetching Cloudflare account information...${NC}"
  account_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json")
  
  # Check if the API call was successful
  if ! echo "$account_response" | jq -e '.success' &>/dev/null; then
    echo -e "${RED}Failed to fetch account information. Please check your API key.${NC}"
    echo "Error: $(echo "$account_response" | jq -r '.errors[0].message')"
    return 1
  fi
  
  # Extract the account ID
  account_id=$(echo "$account_response" | jq -r '.result[0].id')
  echo -e "${GREEN}Account ID: $account_id${NC}"
  
  # Get Zone ID for the domain
  echo -e "${YELLOW}Fetching zone information for domain $domain...${NC}"
  zone_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json")
  
  # Check if the domain exists in Cloudflare
  if ! echo "$zone_response" | jq -e '.success' &>/dev/null || [ "$(echo "$zone_response" | jq '.result | length')" -eq 0 ]; then
    echo -e "${RED}Domain $domain not found in your Cloudflare account.${NC}"
    echo -e "${YELLOW}Please add the domain to your Cloudflare account first.${NC}"
    return 1
  fi
  
  # Extract the zone ID
  zone_id=$(echo "$zone_response" | jq -r '.result[0].id')
  echo -e "${GREEN}Zone ID: $zone_id${NC}"
  
  # Create a tunnel
  echo -e "${YELLOW}Creating Cloudflare Tunnel: $tunnel_name...${NC}"
  tunnel_response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$account_id/tunnels" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    --data "{\"name\":\"$tunnel_name\",\"tunnel_secret\":\"$(openssl rand -hex 32)\"}")
  
  # Check if tunnel creation was successful
  if ! echo "$tunnel_response" | jq -e '.success' &>/dev/null; then
    echo -e "${RED}Failed to create tunnel.${NC}"
    echo "Error: $(echo "$tunnel_response" | jq -r '.errors[0].message')"
    return 1
  fi
  
  # Extract tunnel ID and token
  tunnel_id=$(echo "$tunnel_response" | jq -r '.result.id')
  tunnel_token=$(echo "$tunnel_response" | jq -r '.result.token')
  echo -e "${GREEN}Tunnel created with ID: $tunnel_id${NC}"
  
  # Save the tunnel credentials
  mkdir -p ~/.cloudflared
  echo "{\"AccountTag\":\"$account_id\",\"TunnelID\":\"$tunnel_id\",\"TunnelName\":\"$tunnel_name\",\"TunnelSecret\":\"$tunnel_token\"}" > ~/.cloudflared/$tunnel_id.json
  
  # Create config file
  cat > ~/.cloudflared/config.yml << EOF
url: http://localhost:8000
tunnel: $tunnel_id
credentials-file: /root/.cloudflared/$tunnel_id.json
EOF
  
  echo -e "${GREEN}Tunnel configuration created at ~/.cloudflared/config.yml${NC}"
  
  # Create DNS record for the tunnel
  echo -e "${YELLOW}Creating DNS record for $subdomain.$domain...${NC}"
  dns_response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"CNAME\",\"name\":\"$subdomain\",\"content\":\"$tunnel_id.cfargotunnel.com\",\"ttl\":1,\"proxied\":true}")
  
  # Check if DNS record creation was successful
  if ! echo "$dns_response" | jq -e '.success' &>/dev/null; then
    echo -e "${RED}Failed to create DNS record.${NC}"
    echo "Error: $(echo "$dns_response" | jq -r '.errors[0].message')"
    return 1
  fi
  
  echo -e "${GREEN}DNS record created for $subdomain.$domain${NC}"
  
  # Configure tunnel ingress
  echo -e "${YELLOW}Configuring tunnel ingress...${NC}"
  ingress_config="{\"ingress\":[{\"hostname\":\"$subdomain.$domain\",\"service\":\"http://localhost:8000\"},{\"service\":\"http_status:404\"}]}"
  ingress_response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$account_id/tunnels/$tunnel_id/configurations" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    --data "$ingress_config")
  
  # Check if ingress configuration was successful
  if ! echo "$ingress_response" | jq -e '.success' &>/dev/null; then
    echo -e "${RED}Failed to configure tunnel ingress.${NC}"
    echo "Error: $(echo "$ingress_response" | jq -r '.errors[0].message')"
    return 1
  fi
  
  echo -e "${GREEN}Tunnel ingress configured successfully${NC}"
  
  # Return the tunnel ID for future reference
  echo "$tunnel_id"
}

# Setup mode selection
section "Setup Mode Selection"
echo -e "Choose a setup method for Cloudflare Tunnel:"
echo -e "  ${BLUE}1${NC} - Interactive setup (browser-based authentication)"
echo -e "  ${BLUE}2${NC} - Automatic setup (using Cloudflare API key)"
echo
read -p "Enter your choice (1 or 2): " SETUP_MODE

case $SETUP_MODE in
  1)
    # Interactive setup
    section "Step 1: Authenticate with Cloudflare"
    echo -e "You need to authenticate cloudflared with your Cloudflare account."
    echo -e "This will open a browser window. Log in to your Cloudflare account and authorize the application."
    echo
    read -p "Press Enter to continue with authentication..."

    cloudflared tunnel login

    # Check if authentication was successful
    if [ ! -f ~/.cloudflared/cert.pem ]; then
      echo -e "${RED}Authentication failed. cert.pem not found.${NC}"
      exit 1
    fi

    echo -e "${GREEN}Authentication successful!${NC}"

    # Step 2: Create a tunnel
    section "Step 2: Create a Tunnel"
    echo -e "Now we'll create a new Cloudflare Tunnel for your JupyterHub server."
    echo
    read -p "Enter a name for your tunnel (e.g., jupyterhub-tunnel): " TUNNEL_NAME

    if [ -z "$TUNNEL_NAME" ]; then
      TUNNEL_NAME="jupyterhub-tunnel"
      echo -e "Using default name: ${YELLOW}$TUNNEL_NAME${NC}"
    fi

    # Create the tunnel
    echo -e "Creating tunnel '$TUNNEL_NAME'..."
    TUNNEL_OUTPUT=$(cloudflared tunnel create "$TUNNEL_NAME")
    echo "$TUNNEL_OUTPUT"

    # Extract tunnel UUID
    TUNNEL_UUID=$(echo "$TUNNEL_OUTPUT" | grep -oP "(?<=Created tunnel )([a-f0-9\-]+)")

    if [ -z "$TUNNEL_UUID" ]; then
      echo -e "${RED}Failed to extract tunnel UUID. Please check the output above.${NC}"
      exit 1
    fi

    echo -e "${GREEN}Tunnel created with UUID: $TUNNEL_UUID${NC}"

    # Step 3: Create config file
    section "Step 3: Creating Configuration File"
    echo -e "Creating configuration file for your tunnel..."

    mkdir -p ~/.cloudflared

    cat > ~/.cloudflared/config.yml << EOF
url: http://localhost:8000
tunnel: $TUNNEL_UUID
credentials-file: /root/.cloudflared/$TUNNEL_UUID.json
EOF

    echo -e "${GREEN}Configuration file created at ~/.cloudflared/config.yml${NC}"

    # Step 4: Route domain to tunnel
    section "Step 4: Route Domain to Tunnel"
    echo -e "Now we'll route a domain to your tunnel."
    echo -e "This domain must be managed by Cloudflare (added to your Cloudflare account)."
    echo

    read -p "Enter the domain to route to your tunnel (e.g., jupyter.yourdomain.com): " DOMAIN

    if [ -z "$DOMAIN" ]; then
      echo -e "${RED}Domain cannot be empty.${NC}"
      exit 1
    fi

    echo -e "Routing $DOMAIN to your tunnel..."
    cloudflared tunnel route dns "$TUNNEL_UUID" "$DOMAIN"
    ;;

  2)
    # Automatic setup using API key
    section "Automatic Setup with Cloudflare API"
    echo -e "This setup method uses the Cloudflare API to automatically configure your tunnel."
    echo -e "You will need your Cloudflare API token with the following permissions:"
    echo -e "  - Zone:DNS:Edit"
    echo -e "  - Account:Cloudflare Tunnel:Edit"
    echo
    
    # Get API key
    read -p "Enter your Cloudflare API token: " API_KEY
    if [ -z "$API_KEY" ]; then
      echo -e "${RED}API token cannot be empty.${NC}"
      exit 1
    fi
    
    # Get Cloudflare account email
    read -p "Enter your Cloudflare account email: " CF_EMAIL
    if [ -z "$CF_EMAIL" ]; then
      echo -e "${RED}Email cannot be empty.${NC}"
      exit 1
    fi
    
    # Get domain information
    read -p "Enter your root domain (e.g., example.com): " ROOT_DOMAIN
    if [ -z "$ROOT_DOMAIN" ]; then
      echo -e "${RED}Domain cannot be empty.${NC}"
      exit 1
    fi
    
    read -p "Enter subdomain for JupyterHub (e.g., jupyter): " SUBDOMAIN
    if [ -z "$SUBDOMAIN" ]; then
      SUBDOMAIN="jupyter"
      echo -e "Using default subdomain: ${YELLOW}$SUBDOMAIN${NC}"
    fi
    
    # Get tunnel name
    read -p "Enter a name for your tunnel (e.g., jupyterhub-tunnel): " TUNNEL_NAME
    if [ -z "$TUNNEL_NAME" ]; then
      TUNNEL_NAME="jupyterhub-tunnel"
      echo -e "Using default name: ${YELLOW}$TUNNEL_NAME${NC}"
    fi
    
    # Run automatic setup
    TUNNEL_UUID=$(automatic_cloudflare_setup "$API_KEY" "$CF_EMAIL" "$ROOT_DOMAIN" "$SUBDOMAIN" "$TUNNEL_NAME")
    
    # Check if automatic setup was successful
    if [ $? -ne 0 ]; then
      echo -e "${RED}Automatic setup failed. Please check the errors above.${NC}"
      exit 1
    fi
    
    echo -e "${GREEN}Automatic setup completed successfully!${NC}"
    echo -e "Your JupyterHub will be accessible at: ${BLUE}https://$SUBDOMAIN.$ROOT_DOMAIN${NC}"
    DOMAIN="$SUBDOMAIN.$ROOT_DOMAIN"
    ;;
    
  *)
    echo -e "${RED}Invalid choice. Please run the script again and select 1 or 2.${NC}"
    exit 1
    ;;
esac

# Step 5: Install as a service
section "Step 5: Installing as a Service"
echo -e "Installing cloudflared as a system service..."

cloudflared service install
systemctl enable cloudflared
systemctl start cloudflared

# Check if service is running
if systemctl is-active --quiet cloudflared; then
  echo -e "${GREEN}cloudflared service started successfully!${NC}"
else
  echo -e "${RED}Failed to start cloudflared service. Check logs with 'journalctl -u cloudflared'${NC}"
  exit 1
fi

# Final instructions
section "Setup Complete!"
echo -e "Your JupyterHub server is now accessible via Cloudflare Tunnel at:"
echo -e "${BLUE}https://$DOMAIN${NC}"
echo
echo -e "It may take a few minutes for DNS changes to propagate."
echo
echo -e "To check the status of your tunnel, run:"
echo -e "${YELLOW}cloudflared tunnel info $TUNNEL_UUID${NC}"
echo
echo -e "To view logs from the cloudflared service, run:"
echo -e "${YELLOW}journalctl -u cloudflared${NC}"
echo
echo -e "${GREEN}Setup completed successfully!${NC}"
