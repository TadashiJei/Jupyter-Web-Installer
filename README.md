# JupyterHub with Cloudflare Tunnel Installer

```
      _                   _           _   _       _     
     | |_   _ _ __  _   _| |_ ___ _ _| |_| |_   _| |__  
  _  | | | | | '_ \| | | | __/ _ \ '__| __| | | | | '_ \ 
 | |_| | |_| | |_) | |_| | ||  __/ |  | |_| | |_| | |_) |
  \___/ \__,_| .__/ \__, |\__\___|_|   \__|_|\__,_|_.__/ 
             |_|    |___/                                
                                      by Tadashi Jei
```

This repository contains a script to install JupyterHub with Cloudflare Tunnel integration on Ubuntu 22.04 LTS. This setup allows you to securely access your JupyterHub server from anywhere without opening ports on your server.

Created by [Tadashi Jei](https://www.tadashijei.com)

## Prerequisites

- Ubuntu 22.04 LTS server
- Root or sudo access
- A Cloudflare account with a domain
- Internet connection

## Installation

1. Clone this repository or download the installation script:

```bash
git clone https://github.com/tadashijei/jupyterhub-cloudflare-installer.git
# or
wget https://raw.githubusercontent.com/tadashijei/jupyterhub-cloudflare-installer/main/install_jupyterhub_with_cloudflare.sh
```

2. Make the script executable:

```bash
chmod +x install_jupyterhub_with_cloudflare.sh
```

3. Run the script as root or with sudo:

```bash
sudo ./install_jupyterhub_with_cloudflare.sh
```

4. Follow the on-screen instructions to complete the Cloudflare Tunnel setup.

## What the Installer Does

The installer performs the following tasks:

1. Updates system packages
2. Installs Python, pip, and other dependencies
3. Creates a JupyterHub user and necessary directories
4. Installs JupyterHub and its dependencies
5. Configures JupyterHub to listen on localhost only
6. Creates a systemd service for JupyterHub
7. Installs Cloudflare Tunnel (cloudflared)
8. Provides instructions for completing the Cloudflare Tunnel setup

## Cloudflare Tunnel Setup

The installer offers two methods for setting up Cloudflare Tunnel:

### 1. Interactive Setup (Browser-based)

This method will guide you through the following steps:

1. Authenticate cloudflared with your Cloudflare account via browser
2. Create a new tunnel
3. Configure the tunnel to point to your JupyterHub server
4. Route your domain to the tunnel
5. Install and start cloudflared as a service

### 2. Automatic Setup (API Key)

This method uses the Cloudflare API to automatically set up the tunnel without browser authentication:

1. You'll need to create a Cloudflare API token with the following permissions:
   - Zone:DNS:Edit
   - Account:Cloudflare Tunnel:Edit

2. Provide the following information:
   - API token
   - Cloudflare account email
   - Root domain (must be already added to your Cloudflare account)
   - Subdomain for JupyterHub
   - Tunnel name

3. The script will automatically:
   - Create the tunnel
   - Configure DNS records
   - Set up ingress rules
   - Install the service

Detailed instructions are provided during the installation process.

## Accessing Your JupyterHub

Once setup is complete, you can access your JupyterHub at:

```
https://your-subdomain.yourdomain.com
```

## Security Considerations

This setup offers several security benefits:

- No open ports on your server
- All traffic is encrypted through Cloudflare's network
- You can add Cloudflare Access policies for additional authentication
- JupyterHub is only accessible via the Cloudflare Tunnel

## Troubleshooting

If you encounter issues:

- Check JupyterHub logs: `journalctl -u jupyterhub`
- Check cloudflared logs: `journalctl -u cloudflared`
- Verify the tunnel status: `cloudflared tunnel info <Tunnel-UUID>`
- Ensure your Cloudflare DNS settings are correct

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## About the Author

This project was created by [Tadashi Jei](https://www.tadashijei.com). Visit the website for more projects and information.
