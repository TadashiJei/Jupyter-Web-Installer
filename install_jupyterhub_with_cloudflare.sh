#!/bin/bash

# JupyterHub with Cloudflare Tunnel Installer for Ubuntu 22.04 LTS
# This script installs JupyterHub and configures a Cloudflare Tunnel for secure remote access
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
                                      by Tadashi Jei
EOF
echo

echo -e "${BLUE}=== JupyterHub with Cloudflare Tunnel Installer for Ubuntu 22.04 LTS ===${NC}"
echo -e "${BLUE}This script will install JupyterHub and configure a Cloudflare Tunnel for secure remote access.${NC}"
echo -e "${BLUE}You will need a Cloudflare account to set up the tunnel.${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script as root or with sudo.${NC}"
  exit 1
fi

# Check Ubuntu version
if ! grep -q "Ubuntu 22.04" /etc/os-release; then
  echo -e "${RED}This script is designed for Ubuntu 22.04 LTS. Your system may not be compatible.${NC}"
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to display section headers
section() {
  echo
  echo -e "${GREEN}=== $1 ===${NC}"
}

# Update system packages
section "Updating System Packages"
apt update
apt upgrade -y

# Install dependencies
section "Installing Dependencies"
apt install -y python3 python3-pip python3-venv nodejs npm curl wget

# Upgrade pip
python3 -m pip install --upgrade pip

# Create jupyterhub user if it doesn't exist
section "Setting up JupyterHub User"
if ! id "jupyter" &>/dev/null; then
  useradd -m -s /bin/bash jupyter
  echo "Created jupyter user"
else
  echo "Jupyter user already exists"
fi

# Create necessary directories
mkdir -p /etc/jupyterhub
mkdir -p /var/log/jupyterhub

# Install JupyterHub and its dependencies
section "Installing JupyterHub and Dependencies"
python3 -m pip install jupyterhub jupyterlab notebook
npm install -g configurable-http-proxy

# Generate JupyterHub configuration
section "Generating JupyterHub Configuration"
cd /etc/jupyterhub
jupyterhub --generate-config

# Modify the configuration file to listen on localhost only (for Cloudflare Tunnel)
sed -i "s/# c.JupyterHub.bind_url = 'http:\/\/:8000'/c.JupyterHub.bind_url = 'http:\/\/127.0.0.1:8000'/" /etc/jupyterhub/jupyterhub_config.py
sed -i "s/# c.JupyterHub.hub_ip = ''/c.JupyterHub.hub_ip = '127.0.0.1'/" /etc/jupyterhub/jupyterhub_config.py

# Create systemd service for JupyterHub
section "Creating JupyterHub Service"
cat > /etc/systemd/system/jupyterhub.service << EOF
[Unit]
Description=JupyterHub
After=network.target

[Service]
User=root
Environment="PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
ExecStart=/usr/local/bin/jupyterhub -f /etc/jupyterhub/jupyterhub_config.py
WorkingDirectory=/etc/jupyterhub
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start JupyterHub service
systemctl daemon-reload
systemctl enable jupyterhub
systemctl start jupyterhub

# Check if JupyterHub is running
if systemctl is-active --quiet jupyterhub; then
  echo -e "${GREEN}JupyterHub service started successfully!${NC}"
else
  echo -e "${RED}Failed to start JupyterHub service. Check the logs with 'journalctl -u jupyterhub'${NC}"
  exit 1
fi

# Install Cloudflare Tunnel
section "Installing Cloudflare Tunnel (cloudflared)"

# Download and install cloudflared
if [ "$(uname -m)" == "x86_64" ]; then
  # For 64-bit x86 systems
  curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  dpkg -i cloudflared.deb
elif [ "$(uname -m)" == "aarch64" ]; then
  # For ARM64 systems
  curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
  dpkg -i cloudflared.deb
else
  echo -e "${RED}Unsupported architecture: $(uname -m)${NC}"
  exit 1
fi

# Clean up the downloaded .deb file
rm cloudflared.deb

# Verify cloudflared installation
if command_exists cloudflared; then
  echo -e "${GREEN}cloudflared installed successfully!${NC}"
  cloudflared version
else
  echo -e "${RED}Failed to install cloudflared.${NC}"
  exit 1
fi

# Cloudflare Tunnel setup instructions
section "Cloudflare Tunnel Setup Instructions"
echo -e "To complete the Cloudflare Tunnel setup, follow these steps:"
echo
echo -e "1. Authenticate cloudflared with your Cloudflare account:"
echo -e "   ${BLUE}cloudflared tunnel login${NC}"
echo
echo -e "2. Create a new tunnel (replace 'jupyterhub-tunnel' with your preferred name):"
echo -e "   ${BLUE}cloudflared tunnel create jupyterhub-tunnel${NC}"
echo
echo -e "3. Create a configuration file for your tunnel:"
echo -e "   ${BLUE}mkdir -p ~/.cloudflared${NC}"
echo -e "   ${BLUE}nano ~/.cloudflared/config.yml${NC}"
echo
echo -e "   Add the following content (replace <Tunnel-UUID> with your tunnel UUID):"
echo -e "   ${BLUE}url: http://localhost:8000${NC}"
echo -e "   ${BLUE}tunnel: <Tunnel-UUID>${NC}"
echo -e "   ${BLUE}credentials-file: /root/.cloudflared/<Tunnel-UUID>.json${NC}"
echo
echo -e "4. Route your domain to the tunnel (replace 'your-subdomain.yourdomain.com' with your domain):"
echo -e "   ${BLUE}cloudflared tunnel route dns <Tunnel-UUID> your-subdomain.yourdomain.com${NC}"
echo
echo -e "5. Install cloudflared as a service:"
echo -e "   ${BLUE}cloudflared service install${NC}"
echo
echo -e "6. Start the cloudflared service:"
echo -e "   ${BLUE}systemctl start cloudflared${NC}"
echo -e "   ${BLUE}systemctl enable cloudflared${NC}"
echo
echo -e "7. Check the status of your tunnel:"
echo -e "   ${BLUE}cloudflared tunnel info <Tunnel-UUID>${NC}"
echo

# Final instructions
section "Final Steps"
echo -e "JupyterHub is now installed and running on localhost:8000"
echo -e "Complete the Cloudflare Tunnel setup as described above to access your JupyterHub securely over the internet."
echo -e "After setup, you'll be able to access your JupyterHub at: https://your-subdomain.yourdomain.com"
echo
echo -e "${GREEN}Installation completed successfully!${NC}"
