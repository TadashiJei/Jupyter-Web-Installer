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

# Function to display completion ASCII art with installation details
show_completion_art() {
  local domain=$1
  echo -e "${GREEN}"
  cat << "EOF"

  _____                 _       _       _   _             
 |_   _|               | |     | |     | | (_)            
   | |  _ __  ___  __ _| | __ _| |_ ___| |  _  ___  _ __  
   | | | '_ \/ __|/ _` | |/ _` | __/ _ \ | | |/ _ \| '_ \ 
  _| |_| | | \__ \ (_| | | (_| | ||  __/ | | | (_) | | | |
 |_____|_| |_|___/\__,_|_|\__,_|\__\___|_| |_|\___/|_| |_|
                                                          
   _____                      _      _           _ 
  / ____|                    | |    | |         | |
 | (___  _   _  ___ ___ ___  | |    | |__   __ _| |
  \___ \| | | |/ __/ __/ _ \ | |    | '_ \ / _` | |
  ____) | |_| | (_| (_|  __/ | |____| | | | (_| |_|
 |_____/ \__,_|\___\___\___| |______|_| |_|\__,_(_)
                                                   

EOF
  echo -e "${NC}"
  
  echo -e "${GREEN}=== Installation Complete! ===${NC}"
  echo -e "\nYour JupyterHub is now accessible at: ${BLUE}https://$domain${NC}"
  echo -e "\n${YELLOW}Installation Details:${NC}"
  echo -e "  - JupyterHub Status: $(systemctl is-active jupyterhub &>/dev/null && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Not Running${NC}")"
  echo -e "  - Cloudflare Tunnel Status: $(systemctl is-active cloudflared &>/dev/null && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Not Running${NC}")"
  echo -e "  - JupyterHub Config: /etc/jupyterhub/jupyterhub_config.py"
  echo -e "  - Cloudflare Tunnel Config: ~/.cloudflared/config.yml"
  
  echo -e "\n${BLUE}Thank you for using the JupyterHub with Cloudflare Tunnel Installer!${NC}"
  echo -e "If this tool was helpful, please consider starring the repository at:"
  echo -e "${BLUE}https://github.com/TadashiJei/Jupyter-Web-Installer${NC}"
  echo -e "\nCreated with ♥ by Tadashi Jei (https://tadashijei.com)"
}

# Function to check service status
check_service_status() {
  local service_name=$1
  if systemctl is-active --quiet $service_name; then
    echo -e "${GREEN}$service_name is running${NC}"
    return 0
  else
    echo -e "${RED}$service_name is not running${NC}"
    return 1
  fi
}

# Function for automatic Cloudflare setup using API Token
automatic_cloudflare_setup() {
  echo -e "\n${YELLOW}Starting automatic Cloudflare setup with API Token...${NC}"
  local api_key=$1
  local email=$2
  local domain=$3
  local subdomain=$4
  local tunnel_name=$5
  local account_id
  local zone_id
  local tunnel_id
  local tunnel_token
  
  # Check if curl and jq are installed
  if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed.${NC}"
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed.${NC}"
    return 1
  fi
  
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
  
  # Check if account_id is null or empty
  if [ "$account_id" = "null" ] || [ -z "$account_id" ]; then
    echo -e "${RED}Failed to get a valid Account ID (received: $account_id)${NC}"
    echo -e "${YELLOW}This typically happens when:${NC}"
    echo -e "1. The API token doesn't have sufficient permissions"
    echo -e "2. The API token belongs to a different Cloudflare account than the domain"
    echo -e "\n${YELLOW}Debug information:${NC}"
    echo -e "API Response:\n$(echo "$account_response" | jq . 2>/dev/null || echo "$account_response")"
    
    echo -e "\n${YELLOW}Please ensure your API token:${NC}"
    echo -e "1. Was created in the same Cloudflare account that manages your domain"
    echo -e "2. Has the following permissions:\n   - Account:Cloudflare Tunnel:Edit\n   - Zone:DNS:Edit"
    echo -e "3. Has access to your account and specific zone resources"
    
    return 1
  fi
  
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

# Function for automatic Cloudflare setup using Global API Key
automatic_cloudflare_setup_global() {
  echo -e "\n${YELLOW}Starting automatic Cloudflare setup with Global API Key...${NC}"
  local api_key=$1
  local email=$2
  local domain=$3
  local subdomain=$4
  local tunnel_name=$5
  local account_id
  local zone_id
  local tunnel_id
  local tunnel_token
  
  # Check if curl and jq are installed
  if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed.${NC}"
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed.${NC}"
    return 1
  fi
  
  echo -e "${BLUE}Starting automatic Cloudflare Tunnel setup...${NC}"
  
  # Get Account ID
  echo -e "${YELLOW}Fetching Cloudflare account information...${NC}"
  account_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
    -H "X-Auth-Email: $email" \
    -H "X-Auth-Key: $api_key" \
    -H "Content-Type: application/json")
  
  # Check if the API call was successful
  if ! echo "$account_response" | jq -e '.success' &>/dev/null; then
    echo -e "${RED}Failed to fetch account information. Please check your Global API Key.${NC}"
    echo "Error: $(echo "$account_response" | jq -r '.errors[0].message')"
    return 1
  fi
  
  # Check if API call was successful
  if ! echo "$account_response" | jq -e '.success' &>/dev/null; then
    echo -e "${RED}Failed to fetch account information. API call failed.${NC}"
    echo -e "Error: $(echo "$account_response" | jq -r '.errors[0].message' 2>/dev/null || echo "Unknown error")"
    if echo "$account_response" | jq -e '.errors[0].error_chain' &>/dev/null; then
      echo -e "${YELLOW}Detailed errors:${NC}"
      echo "$account_response" | jq -r '.errors[0].error_chain[] | "  - " + .message' 2>/dev/null
    fi
    return 1
  fi
  
  # Check if results array is empty
  if [ "$(echo "$account_response" | jq '.result | length')" -eq 0 ]; then
    echo -e "${RED}No accounts found in the API response.${NC}"
    echo -e "${YELLOW}This typically happens when:${NC}"
    echo -e "1. The Global API Key doesn't have access to any accounts"
    echo -e "2. Your Cloudflare account might have issues"
    echo -e "\n${YELLOW}Full API Response:${NC}"
    echo "$account_response" | jq .
    return 1
  fi
  
  # Extract the account ID
  account_id=$(echo "$account_response" | jq -r '.result[0].id')
  
  # Check if account_id is null or empty
  if [ "$account_id" = "null" ] || [ -z "$account_id" ]; then
    echo -e "${RED}Failed to get a valid Account ID (received: $account_id)${NC}"
    echo -e "${YELLOW}This typically happens when the account data structure is unexpected.${NC}"
    
    # List all available accounts for debugging
    echo -e "\n${YELLOW}Available accounts in response:${NC}"
    echo "$account_response" | jq -r '.result[] | "ID: " + .id + ", Name: " + .name' 2>/dev/null || echo "Could not parse account data"
    
    # Try to get account ID in a different way - look for any account with a name
    echo -e "\n${YELLOW}Attempting alternative account ID extraction...${NC}"
    account_id=$(echo "$account_response" | jq -r '.result[] | select(.name != null) | .id' | head -n 1)
    
    if [ "$account_id" = "null" ] || [ -z "$account_id" ]; then
      # Final fallback - just take any account ID from the array
      account_id=$(echo "$account_response" | jq -r '.result[].id' | head -n 1)
      
      if [ "$account_id" = "null" ] || [ -z "$account_id" ]; then
        echo -e "${RED}All extraction methods failed. Cannot proceed without a valid account ID.${NC}"
        echo -e "\n${YELLOW}Full API Response:${NC}"
        echo "$account_response" | jq .
        return 1
      else
        echo -e "${GREEN}Found account ID using fallback method: $account_id${NC}"
      fi
    else
      echo -e "${GREEN}Found account ID using alternative method: $account_id${NC}"
    fi
  fi
  
  echo -e "${GREEN}Account ID: $account_id${NC}"
  
  # Get Zone ID for the domain
  echo -e "${YELLOW}Fetching zone information for domain $domain...${NC}"
  zone_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
    -H "X-Auth-Email: $email" \
    -H "X-Auth-Key: $api_key" \
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
    -H "X-Auth-Email: $email" \
    -H "X-Auth-Key: $api_key" \
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
    -H "X-Auth-Email: $email" \
    -H "X-Auth-Key: $api_key" \
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
    -H "X-Auth-Email: $email" \
    -H "X-Auth-Key: $api_key" \
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

# Check if cloudflared service is already installed and running
if systemctl list-unit-files | grep -q cloudflared.service; then
  section "Cloudflare Tunnel Service Check"
  echo -e "${YELLOW}Cloudflare Tunnel service is already installed.${NC}"
  check_service_status "cloudflared"
  
  echo -e "\nDo you want to reconfigure the Cloudflare Tunnel? This will overwrite existing configuration."
  read -p "Continue? (Y/n): " CONTINUE
  if [[ "$CONTINUE" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Setup canceled by user.${NC}"
    exit 0
  fi
  
  # Stop the service before reconfiguring
  echo -e "${YELLOW}Stopping cloudflared service...${NC}"
  systemctl stop cloudflared
fi

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
    echo -e "You have two authentication options:"
    echo -e "${BLUE}Option 1: API Token (Recommended for security)${NC}"
    echo -e "  Requires token with the following permissions:"
    echo -e "  - Zone:DNS:Edit"
    echo -e "  - Account:Cloudflare Tunnel:Edit"
    
    echo -e "${BLUE}Option 2: Global API Key (Easier but less secure)${NC}"
    echo -e "  The Global API Key grants full access to your account"
    echo -e "  You'll need your Cloudflare email and Global API Key"
    echo
    
    # Let user choose authentication method
    echo -e "Choose your authentication method:"
    echo -e "  1) API Token (recommended)"
    echo -e "  2) Global API Key"
    read -p "Enter your choice (1 or 2): " AUTH_METHOD
    echo
    
    # Get authentication credentials based on chosen method
    if [[ "$AUTH_METHOD" == "2" ]]; then
      # Global API Key method
      read -p "Enter your Cloudflare email: " CF_EMAIL
      if [ -z "$CF_EMAIL" ]; then
        echo -e "${RED}Email cannot be empty.${NC}"
        exit 1
      fi
      
      read -p "Enter your Cloudflare Global API Key: " GLOBAL_API_KEY
      if [ -z "$GLOBAL_API_KEY" ]; then
        echo -e "${RED}Global API Key cannot be empty.${NC}"
        exit 1
      fi
      
      # Set variables for use in API calls
      API_EMAIL="$CF_EMAIL"
      API_KEY="$GLOBAL_API_KEY"
      USE_GLOBAL_KEY=true
      echo -e "${YELLOW}Using Global API Key authentication method${NC}"
    else
      # API Token method (default)
      read -p "Enter your Cloudflare API token: " API_KEY
      if [ -z "$API_KEY" ]; then
        echo -e "${RED}API token cannot be empty.${NC}"
        exit 1
      fi
      USE_GLOBAL_KEY=false
      echo -e "${YELLOW}Using API Token authentication method${NC}"
    fi
    
    # Verify the credentials work and check for necessary permissions
    if [ "$USE_GLOBAL_KEY" = true ]; then
      # For Global API Key, we verify by checking if we can list zones
      echo -e "${YELLOW}Step 1/3: Verifying Global API Key...${NC}"
      verify_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
        -H "X-Auth-Email: $API_EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json")
      
      if ! echo "$verify_response" | jq -e '.success' &>/dev/null; then
        echo -e "${RED}Global API Key verification failed. Please check your credentials.${NC}"
        echo "Error: $(echo "$verify_response" | jq -r '.errors[0].message' 2>/dev/null || echo "Unknown error")"
        exit 1
      fi
    else
      # For API Token
      echo -e "${YELLOW}Step 1/3: Verifying API token...${NC}"
      verify_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json")
      
      if ! echo "$verify_response" | jq -e '.success' &>/dev/null; then
        echo -e "${RED}API token verification failed. Please check your token.${NC}"
        echo "Error: $(echo "$verify_response" | jq -r '.errors[0].message' 2>/dev/null || echo "Unknown error")"
        exit 1
      fi
    fi
    
    echo -e "${GREEN}Authentication is valid!${NC}"
    
    # Check account access
    echo -e "${YELLOW}Step 2/3: Checking account access...${NC}"
    if [ "$USE_GLOBAL_KEY" = true ]; then
      accounts_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
        -H "X-Auth-Email: $API_EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json")
    else
      accounts_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json")
    fi
    
    if ! echo "$accounts_response" | jq -e '.success' &>/dev/null || [ "$(echo "$accounts_response" | jq '.result | length')" -eq 0 ]; then
      echo -e "${RED}API token verification failed: No access to any Cloudflare accounts.${NC}"
      echo -e "${YELLOW}Your API token needs Account:Cloudflare Tunnel:Edit permission.${NC}"
      echo -e "Please check your token permissions and ensure it has access to the account resources."
      exit 1
    fi
    
    # Show available accounts to help with debugging
    echo -e "${GREEN}Account access confirmed. Available accounts:${NC}"
    echo "$accounts_response" | jq -r '.result[] | "  - " + .name + " (" + .id + ")"'
    
    # Check zone access for DNS
    echo -e "${YELLOW}Step 3/3: Testing DNS zone access for $ROOT_DOMAIN...${NC}"
    if [ "$USE_GLOBAL_KEY" = true ]; then
      zones_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ROOT_DOMAIN" \
        -H "X-Auth-Email: $API_EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json")
    else
      zones_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ROOT_DOMAIN" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json")
    fi
    
    if ! echo "$zones_response" | jq -e '.success' &>/dev/null || [ "$(echo "$zones_response" | jq '.result | length')" -eq 0 ]; then
      echo -e "${RED}Warning: No access to DNS zone for $ROOT_DOMAIN${NC}"
      echo -e "${YELLOW}1. Ensure domain $ROOT_DOMAIN is added to Cloudflare${NC}"
      echo -e "${YELLOW}2. Ensure API token has Zone:DNS:Edit permission for this domain${NC}"
      echo -e "${YELLOW}3. Verify the domain name is correct${NC}"
      echo -e "Would you like to continue anyway? This might fail when creating DNS records."
      read -p "Continue anyway? (y/N): " CONTINUE_ZONE
      if [[ ! "$CONTINUE_ZONE" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup canceled.${NC}"
        exit 1
      fi
    else
      echo -e "${GREEN}DNS zone access confirmed for $ROOT_DOMAIN${NC}"
    fi
    
    echo -e "${GREEN}API token verified with all required permissions!${NC}"
    
    # Get Cloudflare account email if using API Token method
    if [ "$USE_GLOBAL_KEY" = false ]; then
      read -p "Enter your Cloudflare account email: " CF_EMAIL
      if [ -z "$CF_EMAIL" ]; then
        echo -e "${RED}Email cannot be empty.${NC}"
        exit 1
      fi
    else
      # We already have the email from earlier if using Global API Key
      CF_EMAIL="$API_EMAIL"
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
    
    # Confirm before proceeding
    echo -e "\n${YELLOW}Ready to set up Cloudflare Tunnel with the following settings:${NC}"
    echo -e "  - Root Domain: ${BLUE}$ROOT_DOMAIN${NC}"
    echo -e "  - Subdomain: ${BLUE}$SUBDOMAIN${NC}"
    echo -e "  - Tunnel Name: ${BLUE}$TUNNEL_NAME${NC}"
    echo -e "  - JupyterHub URL will be: ${BLUE}https://$SUBDOMAIN.$ROOT_DOMAIN${NC}"
    echo
    read -p "Continue with these settings? (Y/n): " CONTINUE
    if [[ "$CONTINUE" =~ ^[Nn]$ ]]; then
      echo -e "${YELLOW}Setup canceled by user.${NC}"
      exit 0
    fi
    
    # Run automatic setup with progress updates
    echo -e "${YELLOW}Starting automatic setup process...${NC}"
    
    # Set strict error handling
    set +e  # Temporarily disable exit on error to capture function return
    
    # Call the function and capture its output and return value
    if [ "$USE_GLOBAL_KEY" = true ]; then
      TUNNEL_UUID_OUTPUT=$(automatic_cloudflare_setup_global "$API_KEY" "$CF_EMAIL" "$ROOT_DOMAIN" "$SUBDOMAIN" "$TUNNEL_NAME" 2>&1)
    else
      TUNNEL_UUID_OUTPUT=$(automatic_cloudflare_setup "$API_KEY" "$CF_EMAIL" "$ROOT_DOMAIN" "$SUBDOMAIN" "$TUNNEL_NAME" 2>&1)
    fi
    SETUP_STATUS=$?
    
    # Re-enable exit on error
    set -e
    
    # Extract the TUNNEL_UUID from the last line of output
    TUNNEL_UUID=$(echo "$TUNNEL_UUID_OUTPUT" | tail -n1)
    
    # Check if automatic setup was successful
    if [ $SETUP_STATUS -ne 0 ]; then
      echo -e "${RED}Automatic setup failed. Error details:${NC}"
      echo "$TUNNEL_UUID_OUTPUT"
      exit 1
    fi
    
    # Additional validation that we have a valid UUID
    if ! [[ $TUNNEL_UUID =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
      echo -e "${RED}Failed to get a valid tunnel UUID. Process output:${NC}"
      echo "$TUNNEL_UUID_OUTPUT"
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
echo -e "Now we'll install cloudflared as a systemd service to ensure it starts automatically on boot."

# Create the service file
cat > /etc/systemd/system/cloudflared.service << EOF
[Unit]
Description=Cloudflare Tunnel daemon
After=network.target

[Service]
TimeoutStartSec=0
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/cloudflared tunnel run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
echo -e "${YELLOW}Enabling and starting cloudflared service...${NC}"
systemctl daemon-reload
systemctl enable cloudflared
systemctl start cloudflared

# Verify the service is running
sleep 3  # Give it a moment to start
if systemctl is-active --quiet cloudflared; then
  echo -e "${GREEN}Cloudflared service installed and started successfully!${NC}"
else
  echo -e "${RED}Warning: Cloudflared service is not running. Check logs with: sudo journalctl -u cloudflared${NC}"
fi

# Check if JupyterHub is running
if systemctl is-active --quiet jupyterhub; then
  echo -e "${GREEN}JupyterHub service is running.${NC}"
else
  echo -e "${RED}Warning: JupyterHub service is not running. Check logs with: sudo journalctl -u jupyterhub${NC}"
fi

# Show the completion ASCII art and installation details
show_completion_art "$DOMAIN"

# Final instructions
section "Additional Information"
echo -e "${YELLOW}Important Notes:${NC}"
echo -e "1. It may take a few minutes for DNS changes to propagate."
echo -e "2. If you encounter any issues, check the service status with: sudo systemctl status cloudflared"
echo -e "3. View logs with: sudo journalctl -u cloudflared"

# Check if the services are enabled to start on boot
if systemctl is-enabled --quiet cloudflared; then
  echo -e "${GREEN}Cloudflared service is configured to start on boot.${NC}"
else
  echo -e "${RED}Warning: Cloudflared service is not configured to start on boot.${NC}"
  echo -e "Run: sudo systemctl enable cloudflared"
fi

if systemctl is-enabled --quiet jupyterhub; then
  echo -e "${GREEN}JupyterHub service is configured to start on boot.${NC}"
else
  echo -e "${RED}Warning: JupyterHub service is not configured to start on boot.${NC}"
  echo -e "Run: sudo systemctl enable jupyterhub"
fi

# Do additional checks to ensure the service is properly installed and configured
echo -e "${YELLOW}Finalizing cloudflared service configuration...${NC}"

# Double-check that the service file exists
if [ ! -f /etc/systemd/system/cloudflared.service ]; then
  echo -e "${YELLOW}Service file not found, creating it again...${NC}"
  cloudflared service install
  systemctl daemon-reload
fi

# Ensure the service is enabled and started
systemctl enable cloudflared
systemctl restart cloudflared

# Final check to ensure the service is running
sleep 2
if ! systemctl is-active --quiet cloudflared; then
  echo -e "${RED}Warning: The cloudflared service is not running after installation.${NC}"
  echo -e "${YELLOW}Manual troubleshooting steps:${NC}"
  echo -e "1. Check service status: sudo systemctl status cloudflared"
  echo -e "2. Check logs: sudo journalctl -u cloudflared"
  echo -e "3. Try manual restart: sudo systemctl restart cloudflared"
fi

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
