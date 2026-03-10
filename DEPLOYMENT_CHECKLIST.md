# Deployment Checklist

Use this checklist when deploying step-certctl to a new node.

## Pre-Deployment

- [ ] Package built successfully: `step-certctl_0.1.0_all.deb` exists
- [ ] You have the Smallstep CA root certificate (`root_ca.crt`)
- [ ] You have access to the Smallstep CA at the configured URL
- [ ] Target node is Debian-based (Debian, Ubuntu, Proxmox VE)
- [ ] You have root/sudo access to the target node

## Installation

- [ ] Copy package to target node
  ```bash
  scp step-certctl_0.1.0_all.deb root@node:/tmp/
  ```

- [ ] Install the package
  ```bash
  ssh root@node
  apt install /tmp/step-certctl_0.1.0_all.deb
  ```

- [ ] Verify installation
  ```bash
  step-certctl version
  ```

## Configuration

- [ ] Create `/etc/step/certs` directory
  ```bash
  mkdir -p /etc/step/certs
  ```

- [ ] Copy root CA certificate
  ```bash
  cp /path/to/root_ca.crt /etc/step/certs/root_ca.crt
  chmod 644 /etc/step/certs/root_ca.crt
  ```

- [ ] Create certificate config file
  ```bash
  vi /etc/step-certctl/pveproxy.conf
  ```

- [ ] (If using a provisioner password) Create and secure the password file
  ```bash
  echo "your-provisioner-password" > /etc/step-certctl/provisioner.pass
  chmod 600 /etc/step-certctl/provisioner.pass
  ```

- [ ] (If using a cert template) Place template file and reference it in config
  ```bash
  mkdir -p /etc/step-certctl/templates
  cp /path/to/default.tpl /etc/step-certctl/templates/default.tpl
  ```

- [ ] Verify config syntax
  ```bash
  source /etc/step-certctl/pveproxy.conf
  echo "COMMON_NAME: ${COMMON_NAME}"
  echo "CA_URL: ${CA_URL}"
  ```

## Certificate Issuance

- [ ] Test CA connectivity
  ```bash
  curl --cacert /etc/step/certs/root_ca.crt ${CA_URL}/health
  ```

- [ ] Issue the certificate
  ```bash
  step-certctl issue pveproxy
  ```

- [ ] Verify certificate was created
  ```bash
  ls -la /etc/pve/local/pveproxy-ssl.pem
  ls -la /etc/pve/local/pveproxy-ssl.key
  ```

- [ ] Check certificate details
  ```bash
  openssl x509 -in /etc/pve/local/pveproxy-ssl.pem -text -noout
  ```

- [ ] Verify service reloaded (if applicable)
  ```bash
  systemctl status pveproxy
  ```

## Automatic Renewal Setup

- [ ] Install systemd timer
  ```bash
  step-certctl install-timer pveproxy
  ```

- [ ] Verify timer is active
  ```bash
  systemctl status step-certctl@pveproxy.timer
  ```

- [ ] Check timer schedule
  ```bash
  systemctl list-timers step-certctl@*
  ```

- [ ] Verify service unit exists
  ```bash
  systemctl cat step-certctl@pveproxy.service
  ```

## Testing

- [ ] Run validation
  ```bash
  step-certctl validate pveproxy
  ```

- [ ] Test manual renewal
  ```bash
  step-certctl renew pveproxy
  ```

- [ ] Check renewal logs
  ```bash
  journalctl -u step-certctl@pveproxy.service -n 20
  ```

- [ ] Verify service still works after renewal
  ```bash
  # For Proxmox: access web UI
  # For nginx: curl https://hostname
  # For other services: test accordingly
  ```

## Monitoring Setup (Optional)

- [ ] Set up log monitoring
  ```bash
  # Add to your log aggregation system
  journalctl -u step-certctl@pveproxy.service -f
  ```

- [ ] Document certificate expiry dates
  ```bash
  step-certctl list > /root/cert-status.txt
  ```

- [ ] Add to your monitoring dashboard
  ```bash
  # Monitor timer status
  # Alert if timer stops running
  # Alert if certificate nears expiry
  ```

## Documentation

- [ ] Document node-specific configuration
  - Hostname: _______________
  - IP address: _______________
  - SANs used: _______________
  - Reload command: _______________

- [ ] Add to infrastructure documentation

- [ ] Note any issues encountered and resolutions

## Troubleshooting (If Issues Occur)

### Certificate Issuance Failed

- [ ] Check CA connectivity
  ```bash
  curl -v --cacert /etc/step/certs/root_ca.crt ${CA_URL}/health
  ```

- [ ] Verify DNS resolution
  ```bash
  dig $(echo ${CA_URL} | cut -d/ -f3 | cut -d: -f1)
  ```

- [ ] Check firewall rules
  ```bash
  iptables -L -n | grep 9000
  ```

- [ ] Verify root CA is correct
  ```bash
  openssl x509 -in /etc/step/certs/root_ca.crt -text -noout
  ```

### Timer Not Running

- [ ] Check systemd timer status
  ```bash
  systemctl status step-certctl@pveproxy.timer
  ```

- [ ] Reload systemd daemon
  ```bash
  systemctl daemon-reload
  ```

- [ ] Re-enable timer
  ```bash
  step-certctl remove-timer pveproxy
  step-certctl install-timer pveproxy
  ```

### Permission Issues

- [ ] Check file permissions
  ```bash
  ls -la /etc/pve/local/pveproxy-ssl.*
  ```

- [ ] Re-issue certificate to fix permissions
  ```bash
  step-certctl issue pveproxy
  ```

## Post-Deployment

- [ ] Mark node as deployed in inventory
- [ ] Schedule follow-up check in 24 hours
- [ ] Schedule follow-up check in 1 week
- [ ] Add to regular maintenance schedule

## Rollback Plan (If Needed)

- [ ] Backup old certificate (automatic during renewal)
  ```bash
  ls -la /etc/pve/local/pveproxy-ssl.pem.bak
  ```

- [ ] Restore old certificate if needed
  ```bash
  cp /etc/pve/local/pveproxy-ssl.pem.bak /etc/pve/local/pveproxy-ssl.pem
  cp /etc/pve/local/pveproxy-ssl.key.bak /etc/pve/local/pveproxy-ssl.key
  systemctl reload pveproxy
  ```

- [ ] Remove timer if needed
  ```bash
  step-certctl remove-timer pveproxy
  ```

- [ ] Uninstall package if needed
  ```bash
  apt remove step-certctl
  ```

## Success Criteria

Deployment is successful when:

- [ ] Certificate issued and installed
- [ ] Service using new certificate
- [ ] Timer enabled and scheduled
- [ ] Manual renewal test successful
- [ ] Validation check passes
- [ ] No errors in logs

## Sign-Off

- Deployed by: _______________
- Date: _______________
- Node: _______________
- Certificate name: _______________
- Next review date: _______________

---

**Notes:**

Use this checklist for each node deployment. Keep a copy of completed checklists for audit purposes.
