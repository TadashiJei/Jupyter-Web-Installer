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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script as root or with sudo.${NC}"
  exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Step 1: Run the JupyterHub installation script
echo -e "${GREEN}=== Step 1: Installing JupyterHub ===${NC}"
bash "$SCRIPT_DIR/install_jupyterhub_with_cloudflare.sh"

# Check if the installation was successful
if [ $? -ne 0 ]; then
  echo -e "${RED}JupyterHub installation failed. Please check the logs above.${NC}"
  exit 1
fi

# Step 2: Run the Cloudflare Tunnel setup script
echo -e "${GREEN}=== Step 2: Setting up Cloudflare Tunnel ===${NC}"
bash "$SCRIPT_DIR/setup_cloudflare_tunnel.sh"

# Check if the setup was successful
if [ $? -ne 0 ]; then
  echo -e "${RED}Cloudflare Tunnel setup failed. Please check the logs above.${NC}"
  exit 1
fi

echo -e "${GREEN}=== Installation and Setup Complete! ===${NC}"
echo -e "Your JupyterHub server with Cloudflare Tunnel is now ready to use."
echo -e "You can access it using the domain you configured during the setup process."
echo
echo -e "Thank you for using this installer!"
