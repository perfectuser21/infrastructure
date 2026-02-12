---
id: nas-sync-configuration
version: 1.0.0
created: 2026-02-12
changelog:
  - 1.0.0: 初始版本 - NAS 同步配置文档
---

# NAS Synchronization Configuration

This document describes how to configure automatic synchronization from the US VPS to the NAS located in Xi'an.

## Architecture

```
US VPS (146.190.52.84) ──rsync──> NAS (100.110.241.76, Xi'an)
                           │
                           └──> via Tailscale network
```

**Existing Sync:**
- US VPS → HK VPS: Configured (hourly via rsync)

**New Sync:**
- US VPS → NAS: This configuration

## Prerequisites

### 1. Tailscale Connection

Tailscale must be running and connected to the NAS:

```bash
# Verify Tailscale is running
sudo systemctl status tailscaled

# Check NAS is reachable
ping -c 3 100.110.241.76

# Check SSH port is accessible
nc -zv 100.110.241.76 22
```

### 2. SSH Key Authentication

Configure SSH key-based authentication to the NAS:

```bash
# Generate SSH key if not exists
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
fi

# Copy public key to NAS
ssh-copy-id xx@100.110.241.76

# Test connection
ssh xx@100.110.241.76 "echo 'SSH OK'"
```

**Note:** If `ssh-copy-id` doesn't work, manually add the public key to NAS:

```bash
# On US VPS: Get public key
cat ~/.ssh/id_rsa.pub

# On NAS: Add to authorized_keys
# SSH to NAS and run:
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "<paste-public-key-here>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 3. NAS Storage Path

Ensure the destination path exists on the NAS:

```bash
# SSH to NAS and create directory
ssh xx@100.110.241.76 "mkdir -p /volume1/backups/us-vps"
```

## Manual Synchronization

### Basic Sync

```bash
# Dry run (see what would be synced)
bash scripts/sync-to-nas.sh --dry-run

# Actual sync
bash scripts/sync-to-nas.sh

# Sync with verbose output
bash scripts/sync-to-nas.sh --verbose
```

### Custom Configuration

Use environment variables to override defaults:

```bash
# Sync specific directory
SOURCE_PATH=/home/xx/perfect21 bash scripts/sync-to-nas.sh

# Use different NAS path
NAS_PATH=/volume1/backups/specific-project bash scripts/sync-to-nas.sh

# Custom log file
LOG_FILE=/tmp/nas-sync.log bash scripts/sync-to-nas.sh
```

## Automatic Synchronization

### Cron Configuration

Add to crontab for automatic hourly sync:

```bash
# Edit crontab
crontab -e

# Add this line (sync every hour at :15)
15 * * * * /home/xx/perfect21/infrastructure/scripts/sync-to-nas.sh >> /var/log/nas-sync-cron.log 2>&1
```

**Alternative schedules:**

```bash
# Every 6 hours
0 */6 * * * /home/xx/perfect21/infrastructure/scripts/sync-to-nas.sh

# Daily at 2 AM
0 2 * * * /home/xx/perfect21/infrastructure/scripts/sync-to-nas.sh

# Twice daily (2 AM and 2 PM)
0 2,14 * * * /home/xx/perfect21/infrastructure/scripts/sync-to-nas.sh
```

### Verify Cron

```bash
# List current cron jobs
crontab -l

# Check cron logs
tail -f /var/log/nas-sync-cron.log

# Check sync logs
tail -f /var/log/nas-sync.log
```

## Monitoring

### Check Sync Status

```bash
# View recent sync logs
tail -50 /var/log/nas-sync.log

# Check last sync time
stat /var/log/nas-sync.log | grep Modify

# Verify NAS connectivity
ping -c 3 100.110.241.76
```

### Check NAS Disk Space

```bash
# SSH to NAS and check disk usage
ssh xx@100.110.241.76 "df -h /volume1"

# Check backup directory size
ssh xx@100.110.241.76 "du -sh /volume1/backups/us-vps"
```

## Troubleshooting

### Issue: NAS not reachable

```bash
# Check Tailscale is running
sudo systemctl status tailscaled

# Restart Tailscale if needed
sudo systemctl restart tailscaled

# Verify NAS is in Tailscale network
tailscale status | grep 100.110.241.76

# Ping test
ping -c 5 100.110.241.76
```

### Issue: SSH authentication failed

```bash
# Test SSH connection
ssh -v xx@100.110.241.76

# Verify SSH key is loaded
ssh-add -l

# Add SSH key to agent if needed
ssh-add ~/.ssh/id_rsa

# Check NAS authorized_keys
ssh xx@100.110.241.76 "cat ~/.ssh/authorized_keys"
```

### Issue: Permission denied on NAS

```bash
# Check NAS directory permissions
ssh xx@100.110.241.76 "ls -ld /volume1/backups/us-vps"

# Fix permissions if needed
ssh xx@100.110.241.76 "chmod 755 /volume1/backups/us-vps"
```

### Issue: Sync is slow

```bash
# Check network latency
ping -c 10 100.110.241.76

# Check bandwidth usage during sync
ssh xx@100.110.241.76 "nload"

# Use compression (already enabled in script with -z flag)
# Consider reducing sync frequency if bandwidth is limited
```

### Issue: Disk full on NAS

```bash
# Check NAS disk space
ssh xx@100.110.241.76 "df -h /volume1"

# Find large files
ssh xx@100.110.241.76 "du -sh /volume1/backups/us-vps/* | sort -h"

# Clean up old backups if needed
# (implement retention policy based on requirements)
```

## Excluded Files

The sync script automatically excludes:

- `.git` directories (Git repositories)
- `node_modules` (Node.js dependencies)
- `*.log` files (Log files)
- `.cache` directories (Cache)
- `.npm` (NPM cache)
- `.nvm` (NVM installation)
- `tmp` directories (Temporary files)

To modify exclusions, edit `scripts/sync-to-nas.sh` and update the `--exclude` flags in the rsync command.

## Security Considerations

1. **SSH Keys**: Use SSH key authentication only, disable password authentication on NAS
2. **Tailscale**: Keep Tailscale updated and use secure authentication
3. **Firewall**: Ensure NAS firewall only allows Tailscale network connections
4. **Encryption**: rsync data is encrypted via SSH tunnel
5. **Access Control**: Limit SSH access to NAS to specific users

## Performance Tips

1. **Bandwidth**: Sync during off-peak hours to avoid network congestion
2. **Compression**: rsync `-z` flag is already enabled for compression
3. **Incremental**: rsync only transfers changed files
4. **Exclude**: Add more exclusions for files that don't need backup

## Related Documentation

- Network Topology: `docs/network/topology.md`
- NAS Setup: `docs/nas/setup.md`
- Tailscale Configuration: `docs/network/tailscale-detailed.md`
