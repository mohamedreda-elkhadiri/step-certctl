# Quick Start Guide

Get up and running with step-certctl in 5 minutes.

## Prerequisites

- Debian-based system (Debian, Ubuntu, Proxmox VE)
- Access to a Smallstep CA
- Root CA certificate from your Smallstep CA
- Root/sudo access

## Installation

### Option 1: Install from .deb (Recommended)

```bash
# Build the package
./build.sh

# Install it
sudo apt install ./step-certctl_0.1.0_all.deb
```

### Option 2: Quick Install Script

```bash
./build.sh install
```

## Initial Setup

### 1. Copy Root CA Certificate

```bash
sudo mkdir -p /etc/step/certs
sudo cp /path/to/your/root_ca.crt /etc/step/certs/root_ca.crt
```

### 2. Create Your First Config

For Proxmox pveproxy:

```bash
sudo tee /etc/step-certctl/pveproxy.conf > /dev/null <<EOF
CERT_FILE=/etc/pve/local/pveproxy-ssl.pem
KEY_FILE=/etc/pve/local/pveproxy-ssl.key
CA_URL=https://stepca.elkhadiri.net:9000
ROOT_CA=/etc/step/certs/root_ca.crt
COMMON_NAME=$(hostname -f)
SAN=$(hostname -f),$(hostname),IP:$(hostname -I | awk '{print $1}')
EXPIRES_IN=8h
RELOAD_CMD=systemctl reload pveproxy
OWNER=root
GROUP=www-data
CERT_MODE=0644
KEY_MODE=0600
EOF
```

For nginx:

```bash
sudo tee /etc/step-certctl/nginx.conf > /dev/null <<EOF
CERT_FILE=/etc/nginx/tls/fullchain.pem
KEY_FILE=/etc/nginx/tls/privkey.pem
CA_URL=https://stepca.elkhadiri.net:9000
ROOT_CA=/etc/step/certs/root_ca.crt
COMMON_NAME=$(hostname -f)
SAN=$(hostname -f),$(hostname)
EXPIRES_IN=8h
RELOAD_CMD=systemctl reload nginx
OWNER=root
GROUP=root
CERT_MODE=0644
KEY_MODE=0600
EOF
```

### 3. Issue Your First Certificate

```bash
sudo step-certctl issue pveproxy
```

Expected output:
```
[INFO] Issuing certificate for pve01.elkhadiri.net
[INFO] Config: /etc/step-certctl/pveproxy.conf
[SUCCESS] Certificate issued successfully
[INFO] Set ownership to root:www-data
[INFO] Set permissions: cert=0644, key=0600
[SUCCESS] Reload command executed successfully
```

### 4. Enable Automatic Renewal

```bash
sudo step-certctl install-timer pveproxy
```

Expected output:
```
[INFO] Installing systemd timer for pveproxy
[SUCCESS] Timer enabled: step-certctl@pveproxy.timer
[SUCCESS] Timer started: step-certctl@pveproxy.timer
```

### 5. Verify Everything Works

```bash
# Check certificate
sudo step-certctl validate pveproxy

# Check timer
sudo systemctl list-timers step-certctl@*

# Check logs
sudo journalctl -u step-certctl@pveproxy.service -f
```

## Testing Renewal

Trigger a manual renewal to test:

```bash
sudo step-certctl renew pveproxy
```

## Common Use Cases

### Proxmox Cluster (7 nodes)

On each node:

```bash
# 1. Install package
sudo apt install ./step-certctl_0.1.0_all.deb

# 2. Copy root CA
sudo cp root_ca.crt /etc/step/certs/root_ca.crt

# 3. Create config (adjust COMMON_NAME and SAN per node)
sudo vi /etc/step-certctl/pveproxy.conf

# 4. Issue and enable
sudo step-certctl issue pveproxy
sudo step-certctl install-timer pveproxy
```

### Multiple Certificates on Same Host

```bash
# Web server
sudo step-certctl issue nginx
sudo step-certctl install-timer nginx

# API server
sudo step-certctl issue api
sudo step-certctl install-timer api
```

### Ansible Deployment

```yaml
---
- hosts: all
  tasks:
    - name: Copy package
      copy:
        src: step-certctl_0.1.0_all.deb
        dest: /tmp/

    - name: Install package
      apt:
        deb: /tmp/step-certctl_0.1.0_all.deb

    - name: Copy root CA
      copy:
        src: root_ca.crt
        dest: /etc/step/certs/root_ca.crt

    - name: Create config
      template:
        src: pveproxy.conf.j2
        dest: /etc/step-certctl/pveproxy.conf

    - name: Issue certificate
      command: step-certctl issue pveproxy
      args:
        creates: /etc/pve/local/pveproxy-ssl.pem

    - name: Enable timer
      command: step-certctl install-timer pveproxy
```

## Troubleshooting

### CA Not Reachable

```bash
# Test connectivity
curl --cacert /etc/step/certs/root_ca.crt https://stepca.elkhadiri.net:9000/health

# Check DNS
dig stepca.elkhadiri.net

# Check firewall
sudo iptables -L -n | grep 9000
```

### Certificate Not Renewing

```bash
# Check timer status
systemctl status step-certctl@pveproxy.timer

# Check service logs
journalctl -u step-certctl@pveproxy.service -n 50

# Test manual renewal
sudo step-certctl renew pveproxy
```

### Permission Denied

```bash
# Ensure script is executable
ls -la /usr/bin/step-certctl

# Run with sudo
sudo step-certctl issue pveproxy
```

## Next Steps

- Read the full [README.md](README.md)
- Check [example configs](examples/)
- Set up monitoring for certificate expiry
- Deploy across your infrastructure with Ansible

## Support

For issues and questions:
- Check the [README.md](README.md)
- Review logs: `journalctl -u step-certctl@<name>.service`
- Run validation: `step-certctl validate <name>`
