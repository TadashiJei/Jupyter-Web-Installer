#!/bin/bash

# JupyterHub with Cloudflare Tunnel Complete Installer
# This script runs both the JupyterHub installation and Cloudflare Tunnel setup
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
  _____                 _      _         _____           _        _ _           
 |_   _|               | |    | |       |_   _|         | |      | | |          
   | |  _ __  ___  ___| |_ __| |_ __     | |  _ __  ___| |_ __ _| | | ___ _ __ 
   | | | '_ \/ __|/ _ \ __/ _` | '__|    | | | '_ \/ __| __/ _` | | |/ _ \ '__|
  _| |_| | | \__ \  __/ || (_| | |      _| |_| | | \__ \ || (_| | | |  __/ |   
 |_____|_| |_|___/\___|\__\__,_|_|     |_____|_| |_|___/\__\__,_|_|_|\___|_|   
                                      by Tadashi Jei
EOF
echo

echo -e "${BLUE}=== JupyterHub with Cloudflare Tunnel Complete Installer ===${NC}"
echo -e "${BLUE}This script will install JupyterHub and set up a Cloudflare Tunnel for secure remote access.${NC}"
echo

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

# Function to display completion ASCII art
show_completion_art() {
  echo -e "${GREEN}"
  cat << "EOF"

  _____           _        _ _       _   _             
 |_   _|         | |      | | |     | | (_)            
   | |  _ __  ___| |_ __ _| | | __ _| |_ _  ___  _ __  
   | | | '_ \/ __| __/ _` | | |/ _` | __| |/ _ \| '_ \ 
  _| |_| | | \__ \ || (_| | | | (_| | |_| | (_) | | | |
 |_____|_| |_|___/\__\__,_|_|_|\__,_|\__|_|\___/|_| |_|
                                                       
   _____                      _      _           _ 
  / ____|                    | |    | |         | |
 | (___  _   _  ___ ___ ___  | |    | |__   __ _| |
  \___ \| | | |/ __/ __/ _ \ | |    | '_ \ / _` | |
  ____) | |_| | (_| (_|  __/ | |____| | | | (_| |_|
 |_____/ \__,_|\___\___\___| |______|_| |_|\__,_(_)
                                                   

EOF
  echo -e "${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script as root or with sudo.${NC}"
  exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Display welcome message and confirm installation
echo -e "${YELLOW}Welcome to the JupyterHub with Cloudflare Tunnel All-in-One Installer!${NC}"
echo -e "This script will:"
echo -e "  1. Install JupyterHub and configure it to run on localhost"
echo -e "  2. Install Cloudflared (Cloudflare Tunnel client)"
echo -e "  3. Set up a Cloudflare Tunnel to securely expose your JupyterHub"
echo -e "  4. Configure services to start automatically on boot"
echo
read -p "Do you want to proceed with the installation? (Y/n): " PROCEED
if [[ "$PROCEED" =~ ^[Nn]$ ]]; then
  echo -e "${YELLOW}Installation canceled by user.${NC}"
  exit 0
fi

# Step 1: Run the JupyterHub installation script
echo -e "${GREEN}=== Step 1: Installing JupyterHub ===${NC}"
bash "$SCRIPT_DIR/install_jupyterhub_with_cloudflare.sh"

# Check if the installation was successful
if [ $? -ne 0 ]; then
  echo -e "${RED}JupyterHub installation failed. Please check the logs above.${NC}"
  exit 1
fi

# Ask before continuing to the next step
echo
read -p "Continue with Cloudflare Tunnel setup? (Y/n): " CONTINUE_TUNNEL
if [[ "$CONTINUE_TUNNEL" =~ ^[Nn]$ ]]; then
  echo -e "${YELLOW}Cloudflare Tunnel setup skipped. You can run it later with:${NC}"
  echo -e "  sudo bash $SCRIPT_DIR/setup_cloudflare_tunnel.sh"
  exit 0
fi

# Step 2: Run the Cloudflare Tunnel setup script
echo -e "${GREEN}=== Step 2: Setting up Cloudflare Tunnel ===${NC}"
bash "$SCRIPT_DIR/setup_cloudflare_tunnel.sh"

# Check if the setup was successful
if [ $? -ne 0 ]; then
  echo -e "${RED}Cloudflare Tunnel setup failed. Please check the logs above.${NC}"
  exit 1
fi

# Show completion message and status
show_completion_art
echo -e "${GREEN}=== Installation and Setup Complete! ===${NC}"
echo -e "Your JupyterHub server with Cloudflare Tunnel is now ready to use."
echo -e "You can access it using the domain you configured during the setup process."

# Display detailed status information
echo -e "\n${YELLOW}Installation Details:${NC}"
echo -e "  - JupyterHub Config: /etc/jupyterhub/jupyterhub_config.py"
echo -e "  - Cloudflare Tunnel Config: ~/.cloudflared/config.yml"

echo -e "\n${YELLOW}Service Status:${NC}"
echo -n "JupyterHub: "
if systemctl is-active --quiet jupyterhub; then
  echo -e "${GREEN}Running${NC}"
  echo -e "  Start on Boot: $(systemctl is-enabled --quiet jupyterhub && echo -e "${GREEN}Enabled${NC}" || echo -e "${RED}Disabled${NC}")"
else
  echo -e "${RED}Not Running${NC}"
  echo -e "  Check logs with: sudo journalctl -u jupyterhub"
fi

echo -n "Cloudflared: "
if systemctl is-active --quiet cloudflared; then
  echo -e "${GREEN}Running${NC}"
  echo -e "  Start on Boot: $(systemctl is-enabled --quiet cloudflared && echo -e "${GREEN}Enabled${NC}" || echo -e "${RED}Disabled${NC}")"
else
  echo -e "${RED}Not Running${NC}"
  echo -e "  Check logs with: sudo journalctl -u cloudflared"
fi

echo -e "\n${BLUE}Thank you for using the JupyterHub with Cloudflare Tunnel Installer!${NC}"
echo -e "If this tool was helpful, please consider starring the repository at:"
echo -e "${BLUE}https://github.com/TadashiJei/Jupyter-Web-Installer${NC}"
echo -e "\nCreated with \u2665 by Tadashi Jei (https://tadashijei.com)"
