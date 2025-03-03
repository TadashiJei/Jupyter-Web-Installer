# JupyterHub Customization Guide

This guide provides instructions for customizing your JupyterHub installation after using the installer scripts.

## JupyterHub Configuration

The main JupyterHub configuration file is located at `/etc/jupyterhub/jupyterhub_config.py`. You can modify this file to customize various aspects of your JupyterHub instance.

### Common Customizations

#### Authentication

By default, JupyterHub uses PAM authentication (system users). You can change this to use other authenticators:

```python
# Example: GitHub OAuth
c.JupyterHub.authenticator_class = 'oauthenticator.GitHubOAuthenticator'
c.GitHubOAuthenticator.oauth_callback_url = 'https://your-domain.com/hub/oauth_callback'
c.GitHubOAuthenticator.client_id = 'your-client-id'
c.GitHubOAuthenticator.client_secret = 'your-client-secret'
```

To use this, install the required package:
```bash
pip install oauthenticator
```

#### User Environment

To customize the user environment (e.g., pre-installed packages):

```python
# Example: Use a custom Docker image
c.DockerSpawner.image = 'yourusername/jupyterhub-user:latest'
```

#### Resource Limits

To set resource limits for user servers:

```python
# Example: Memory limits
c.Spawner.mem_limit = '1G'
c.Spawner.cpu_limit = 1.0
```

## Cloudflare Tunnel Configuration

The Cloudflare Tunnel configuration is located at `~/.cloudflared/config.yml`.

### API Key Setup

If you prefer to use the API key method for setting up Cloudflare Tunnel, you'll need to create an API token with the appropriate permissions:

1. Go to the [Cloudflare dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Select "Create Custom Token"
4. Add the following permissions:
   - Zone > DNS > Edit
   - Account > Cloudflare Tunnel > Edit
5. Set the Zone and Account Resources as needed
6. Create the token and save it securely

This token can be used with the automatic setup option in the installer.

### Common Customizations

#### Access Policies

You can add Cloudflare Access policies to restrict who can access your JupyterHub:

1. Go to the Cloudflare Zero Trust dashboard
2. Navigate to Access > Applications
3. Create a new application
4. Set the application domain to your JupyterHub domain
5. Configure authentication methods and access policies

#### Ingress Rules

You can modify the ingress rules in your config.yml file to route traffic to different services:

```yaml
ingress:
  - hostname: jupyter.yourdomain.com
    service: http://localhost:8000
  - hostname: another.yourdomain.com
    service: http://localhost:8080
  - service: http_status:404
```

#### Logging

To adjust logging settings:

```yaml
tunnel: your-tunnel-uuid
credentials-file: /root/.cloudflared/your-tunnel-uuid.json
logfile: /var/log/cloudflared.log
loglevel: info
```

## Advanced JupyterHub Configuration

For more advanced configuration options, refer to the [JupyterHub documentation](https://jupyterhub.readthedocs.io/en/stable/reference/config-reference.html).

## Troubleshooting

### JupyterHub Issues

- Check logs: `journalctl -u jupyterhub`
- Restart service: `systemctl restart jupyterhub`
- Verify configuration: `jupyterhub -f /etc/jupyterhub/jupyterhub_config.py --debug`

### Cloudflare Tunnel Issues

- Check logs: `journalctl -u cloudflared`
- Restart service: `systemctl restart cloudflared`
- Test connection: `cloudflared tunnel info your-tunnel-uuid`
- Check tunnel status in the Cloudflare dashboard

## Backup and Restore

### Backing Up Configuration

```bash
# JupyterHub config
cp /etc/jupyterhub/jupyterhub_config.py /path/to/backup/

# Cloudflare Tunnel config
cp ~/.cloudflared/config.yml /path/to/backup/
cp ~/.cloudflared/*.json /path/to/backup/
```

### Restoring Configuration

```bash
# JupyterHub config
cp /path/to/backup/jupyterhub_config.py /etc/jupyterhub/
systemctl restart jupyterhub

# Cloudflare Tunnel config
cp /path/to/backup/config.yml ~/.cloudflared/
cp /path/to/backup/*.json ~/.cloudflared/
systemctl restart cloudflared
```
