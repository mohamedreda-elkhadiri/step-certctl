# step-certctl

Generic certificate renewal manager for Smallstep CA. Designed for homelabs and internal infrastructure.

## Overview

`step-certctl` provides a simple, config-driven approach to managing TLS certificates issued by [Smallstep CA](https://smallstep.com/certificates/). It's designed to scale from a single Proxmox node to entire fleets of VMs, containers, and services.

### Features

- **Config-driven**: One config file per certificate
- **Automatic renewal**: Systemd timer-based background renewal
- **Multi-service support**: One package handles Proxmox, nginx, custom apps, etc.
- **Smart reloading**: Compares public keys to avoid unnecessary service restarts
- **Flexible**: Custom ownership, permissions, and reload commands per certificate
- **Scalable**: Templated systemd units handle multiple certificates per host

## Architecture

### Components

```
/usr/bin/step-certctl                      # Main command
/usr/lib/step-certctl/functions.sh         # Shared functions
/etc/step-certctl/*.conf                   # Per-certificate configs
/etc/systemd/system/step-certctl@.service  # Templated service
/etc/systemd/system/step-certctl@.timer    # Templated timer
```

### How It Works

1. You create a config file: `/etc/step-certctl/pveproxy.conf`
2. Issue the certificate: `step-certctl issue pveproxy`
3. Enable automatic renewal: `step-certctl install-timer pveproxy`
4. The timer runs every 6 hours, renewing the certificate when needed
5. If the certificate changes, the reload command runs automatically

## Installation

### From .deb Package

```bash
# Install the package
sudo apt install ./step-certctl_0.1.1_all.deb

# Copy your Smallstep CA root certificate
sudo cp root_ca.crt /etc/step/certs/root_ca.crt
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/step-certctl.git
cd step-certctl

# Run the build script
sudo ./build.sh install
```

## Quick Start

### 1. Create a Configuration File

Create `/etc/step-certctl/pveproxy.conf`:

```ini
# Certificate and key file paths
CERT_FILE=/etc/pve/local/pveproxy-ssl.pem
KEY_FILE=/etc/pve/local/pveproxy-ssl.key

# Smallstep CA configuration
CA_URL=https://stepca.example.com:9000
ROOT_CA=/etc/step/certs/root_ca.crt

# Certificate details
COMMON_NAME=pve01.example.com
SAN=pve01.example.com,pve01,IP:10.0.0.10

# Renewal settings
EXPIRES_IN=8h

# Post-renewal action
RELOAD_CMD=systemctl reload pveproxy

# File ownership and permissions
OWNER=root
GROUP=www-data
CERT_MODE=0644
KEY_MODE=0600
```

See `examples/` directory for more configurations.

### 2. Issue the Certificate

```bash
sudo step-certctl issue pveproxy
```

This will:
- Request a new certificate from your CA
- Save it to the configured paths
- Set ownership and permissions
- Run the reload command

### 3. Enable Automatic Renewal

```bash
sudo step-certctl install-timer pveproxy
```

This creates a systemd timer that renews the certificate every 6 hours.

### 4. Verify Everything Works

```bash
# Check certificate status
sudo step-certctl validate pveproxy

# Check timer status
sudo systemctl status step-certctl@pveproxy.timer

# View upcoming renewal times
sudo systemctl list-timers step-certctl@*

# Check logs
sudo journalctl -u step-certctl@pveproxy.service
```

## Commands

### Issue a Certificate

```bash
step-certctl issue <name>
```

Issues a new certificate based on the config file. Use this for:
- Initial certificate issuance
- Changing SANs or other certificate properties
- Recovering from expired certificates

### Renew a Certificate

```bash
step-certctl renew <name>
```

Renews an existing certificate. The systemd timer calls this automatically.

Features:
- Compares public keys before/after renewal
- Only reloads service if certificate actually changed
- Backs up old certificate before replacing

### Validate Configuration

```bash
step-certctl validate <name>
```

Validates:
- Config file exists and is readable
- Certificate and key files exist
- Certificate is not expired
- Root CA is accessible
- CA endpoint is reachable

### Install Systemd Timer

```bash
step-certctl install-timer <name>
```

Enables and starts the systemd timer for automatic renewal.

### Remove Systemd Timer

```bash
step-certctl remove-timer <name>
```

Stops and disables the systemd timer. The certificate remains unchanged.

### List All Certificates

```bash
step-certctl list
```

Shows all configured certificates with their status, expiry, and timer state.

### Version Information

```bash
step-certctl version
```

Shows version and dependency information.

## Configuration Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `CERT_FILE` | Path to certificate file | `/etc/nginx/tls/cert.pem` |
| `KEY_FILE` | Path to private key file | `/etc/nginx/tls/key.pem` |
| `CA_URL` | Smallstep CA URL | `https://stepca.example.com:9000` |
| `ROOT_CA` | Path to root CA certificate | `/etc/step/certs/root_ca.crt` |
| `COMMON_NAME` | Certificate common name | `server.example.com` |

### Optional Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `SAN` | Subject alternative names | `${COMMON_NAME}` | `server.example.com,IP:10.0.0.1` |
| `EXPIRES_IN` | Certificate lifetime (hours: `8h`, `24h`; days: `1d`, `7d`) | `8h` | `24h`, `4d`, `168h` |
| `RELOAD_CMD` | Command to run after renewal | _(none)_ | `systemctl reload nginx` |
| `OWNER` | Certificate file owner | `root` | `nginx`, `www-data` |
| `GROUP` | Certificate file group | `root` | `nginx`, `www-data` |
| `CERT_MODE` | Certificate file permissions | `0644` | `0640` |
| `KEY_MODE` | Private key file permissions | `0600` | `0600` |
| `PROVISIONER` | Smallstep CA provisioner name | _(CA default)_ | `my-jwk`, `acme` |
| `PROVISIONER_PASSWORD_FILE` | Path to provisioner key password file | _(none)_ | `/etc/step-certctl/provisioner.pass` |
| `CERT_TEMPLATE` | Path to JSON file for certificate subject metadata | _(none)_ | `/etc/step-certctl/templates/default.tpl` |

### Provisioner Configuration

By default `step ca certificate` uses the CA's default provisioner. To select one explicitly and provide its password non-interactively:

```ini
PROVISIONER=my-jwk-provisioner
PROVISIONER_PASSWORD_FILE=/etc/step-certctl/provisioner.pass
```

The password file should be owned by root and mode `0600`:

```bash
echo "your-provisioner-password" | sudo tee /etc/step-certctl/provisioner.pass
sudo chmod 600 /etc/step-certctl/provisioner.pass
```

### Certificate Templates

To embed subject metadata (O, OU, C, etc.) in issued certificates, create a JSON file and reference it with `CERT_TEMPLATE`:

```ini
CERT_TEMPLATE=/etc/step-certctl/templates/default.tpl
```

Example template file (`default.tpl`):

```json
{
    "O":  "My Org",
    "OU": "Infrastructure",
    "C":  "US"
}
```

The template is passed to `step ca certificate` via `--set-file`. CN and SANs are always sourced from `COMMON_NAME` and `SAN` in the config — they do not need to be in the template file.

See `examples/templates/default.tpl` for a starter template.

## Use Cases

### Proxmox VE Nodes

Manage pveproxy certificates across multiple Proxmox hosts:

```bash
# On each node, create /etc/step-certctl/pveproxy.conf
# Adjust COMMON_NAME and SAN per node

step-certctl issue pveproxy
step-certctl install-timer pveproxy
```

### Nginx Web Servers

```bash
# Create /etc/step-certctl/nginx.conf
CERT_FILE=/etc/nginx/tls/fullchain.pem
KEY_FILE=/etc/nginx/tls/privkey.pem
CA_URL=https://stepca.example.com:9000
ROOT_CA=/etc/step/certs/root_ca.crt
COMMON_NAME=www.example.com
SAN=www.example.com,example.com,*.example.com
EXPIRES_IN=8h          # hours (8h, 24h) or days (1d, 7d)
RELOAD_CMD=systemctl reload nginx
OWNER=root
GROUP=root
```

### Custom Applications

```bash
# Create /etc/step-certctl/myapp.conf
CERT_FILE=/opt/myapp/tls/tls.crt
KEY_FILE=/opt/myapp/tls/tls.key
CA_URL=https://stepca.example.com:9000
ROOT_CA=/etc/step/certs/root_ca.crt
COMMON_NAME=myapp.example.com
EXPIRES_IN=8h          # hours (8h, 24h) or days (1d, 7d)
RELOAD_CMD=systemctl restart myapp
OWNER=myapp
GROUP=myapp
```

### Multiple Certificates Per Host

You can manage multiple certificates on the same host:

```bash
# Web server certificate
step-certctl issue nginx
step-certctl install-timer nginx

# API server certificate
step-certctl issue api
step-certctl install-timer api

# Internal service certificate
step-certctl issue internal
step-certctl install-timer internal
```

Each gets its own config file and systemd timer instance.

## Systemd Timer Details

The timer runs:
- 5 minutes after boot
- Every 6 hours after that
- With a randomized 15-minute delay to avoid thundering herd

View timer schedule:

```bash
systemctl list-timers step-certctl@*
```

View service logs:

```bash
journalctl -u step-certctl@pveproxy.service
```

## Troubleshooting

### Certificate Not Renewing

```bash
# Check timer is enabled
systemctl status step-certctl@pveproxy.timer

# Check recent service runs
journalctl -u step-certctl@pveproxy.service -n 50

# Manually trigger renewal to see errors
sudo step-certctl renew pveproxy
```

### CA Connection Issues

```bash
# Validate configuration
sudo step-certctl validate pveproxy

# Test CA connectivity
curl --cacert /etc/step/certs/root_ca.crt https://stepca.example.com:9000/health
```

### Permission Issues

```bash
# Check current permissions
ls -la /etc/pve/local/pveproxy-ssl.*

# Re-issue to fix permissions
sudo step-certctl issue pveproxy
```

### Service Not Reloading

The service only reloads if the certificate's public key changes. This is intentional to avoid unnecessary restarts.

To force a reload:

```bash
# Re-issue the certificate
sudo step-certctl issue pveproxy
```

## Building the Package

### Using the Build Script

```bash
./build.sh
```

This creates `step-certctl_0.1.1_all.deb`.

### Manual Build

```bash
# Prepare package directory
mkdir -p pkg/usr/bin
mkdir -p pkg/usr/lib/step-certctl
mkdir -p pkg/etc/systemd/system
mkdir -p pkg/usr/share/doc/step-certctl/examples
mkdir -p pkg/DEBIAN

# Copy files
cp bin/step-certctl pkg/usr/bin/
cp lib/step-certctl-functions.sh pkg/usr/lib/step-certctl/
cp systemd/*.service systemd/*.timer pkg/etc/systemd/system/
cp examples/* pkg/usr/share/doc/step-certctl/examples/
cp debian/* pkg/DEBIAN/

# Build package
dpkg-deb --build pkg step-certctl_0.1.1_all.deb
```

## Deployment at Scale

### Using Ansible

Create a role that:

1. Installs the `step-certctl` package
2. Copies the root CA
3. Templates config files per host
4. Issues initial certificates
5. Enables timers

Example playbook:

```yaml
- hosts: proxmox_nodes
  tasks:
    - name: Install step-certctl
      apt:
        deb: /path/to/step-certctl_0.1.1_all.deb

    - name: Copy root CA
      copy:
        src: root_ca.crt
        dest: /etc/step/certs/root_ca.crt

    - name: Create pveproxy config
      template:
        src: pveproxy.conf.j2
        dest: /etc/step-certctl/pveproxy.conf

    - name: Issue certificate
      command: step-certctl issue pveproxy
      args:
        creates: /etc/pve/local/pveproxy-ssl.pem

    - name: Enable renewal timer
      command: step-certctl install-timer pveproxy
```

### Using a Local APT Repository

Host the `.deb` file in a local repository for easier distribution:

```bash
# On repo server
mkdir -p /var/www/apt/pool/main
cp step-certctl_0.1.1_all.deb /var/www/apt/pool/main/
cd /var/www/apt
dpkg-scanpackages pool/main /dev/null | gzip -9c > dists/stable/main/binary-amd64/Packages.gz

# On clients
echo "deb [trusted=yes] http://repo.example.com/apt stable main" | sudo tee /etc/apt/sources.list.d/local.list
sudo apt update
sudo apt install step-certctl
```

## Security Considerations

- Private keys are set to `0600` permissions by default
- The systemd service runs as root (required to write to protected directories)
- Security hardening is applied: `PrivateTmp`, `ProtectSystem`, `NoNewPrivileges`
- Config files should be readable only by root: `chmod 600 /etc/step-certctl/*.conf`
- The root CA certificate must be authentic and protected

## Contributing

Contributions welcome. Please:

1. Test on Debian/Proxmox systems
2. Follow existing code style
3. Update documentation for new features
4. Add example configs for new use cases

## License

MIT License - see LICENSE file

## Credits

Built for managing certificates across homelab infrastructure using [Smallstep CA](https://smallstep.com/).

Inspired by the need to move beyond one-off scripts to a maintainable, scalable solution.
