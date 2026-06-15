# FreeTAKServer on AWS EC2 — Deployment Guide

This guide covers deploying FreeTAKServer on an AWS EC2 instance using Docker Compose with persistent EBS storage.

## 1. Launch an EC2 Instance

### Recommended sizing

| Parameter | Value |
|-----------|-------|
| AMI | Ubuntu 24.04 LTS (ami-…) |
| Instance type | `t3.medium` (2 vCPU / 4 GB) minimum |
| Root volume | 30 GB gp3 |
| Data volume (EBS) | 10–20 GB gp3, mounted at `/mnt/fts` |
| Key pair | Your existing SSH key |

> `t3.small` (2 vCPU / 2 GB) works for light use; `t3.medium` is recommended if you enable CoT-to-DB logging or run multiple routing workers.

### Security Group

Create a security group with these inbound rules:

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Your IP | SSH |
| 8087 | TCP | 0.0.0.0/0 | CoT (ATAK connections) |
| 8089 | TCP | 0.0.0.0/0 | SSL CoT |
| 8080 | TCP | 0.0.0.0/0 | Data Package API |
| 8443 | TCP | 0.0.0.0/0 | SSL Data Package |
| 19023 | TCP | Your IP / restricted | Web UI / REST API |

> For production, restrict CoT/Data ports to known client CIDRs instead of `0.0.0.0/0`.

## 2. Prepare the EBS Data Volume

Attach a separate EBS volume for persistent data so it survives instance replacement.

```bash
# Find the attached device (typically /dev/xvdf or /dev/nvme1n1)
lsblk

# Format and mount (replace device name as needed)
sudo mkfs -t xfs /dev/nvme1n1
sudo mkdir -p /mnt/fts
sudo mount /dev/nvme1n1 /mnt/fts

# Persist the mount across reboots
echo '/dev/nvme1n1 /mnt/fts xfs defaults,nofail 0 2' | sudo tee -a /etc/fstab

# Give the Docker user access
sudo chown -R 1000:1000 /mnt/fts
```

> **NVMe note:** On Nitro-based instances (t3, m5, c5), EBS volumes appear as `/dev/nvme*n1`. On older instances they appear as `/dev/xvd*`. Adjust the device name accordingly.

## 3. Bootstrap with User-Data

Paste the contents of `ec2-bootstrap.sh` (see below) into the **User data** field when launching the instance. This installs Docker, creates directories, and starts FTS automatically.

Alternatively, run it manually after SSH:

```bash
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
bash ec2-bootstrap.sh
```

## 4. Configure Environment

```bash
cd /opt/fts-deploy
cp .env.example .env
nano .env                # fill in secrets and ports
```

Key variables for EC2:

| Variable | EC2 value | Notes |
|----------|-----------|-------|
| `FTS_DP_ADDRESS` | `0.0.0.0` | Listen on all interfaces |
| `FTS_USER_ADDRESS` | `0.0.0.0` | |
| `FTS_API_ADDRESS` | `0.0.0.0` | |
| `FTS_SECRET_KEY` | Random 32-char string | **Change this!** |
| `FTS_NODE_ID` | Random 32-char string | **Change this!** |
| `FTS_DATA_PATH` | `/mnt/fts` | Matches EBS mount |

## 5. Start / Stop / Update

```bash
# Start
cd /opt/fts-deploy
docker compose up -d

# Check health
docker compose ps
curl http://localhost:8080/

# View logs
docker compose logs -f freetakserver

# Stop
docker compose down

# Update (pull latest image or rebuild)
docker compose build --pull
docker compose up -d
```

## 6. Auto-Start on Reboot

The `ec2-bootstrap.sh` script installs a systemd unit (`fts-docker.service`) so the container starts automatically after a reboot or Docker restart.

Check status:

```bash
sudo systemctl status fts-docker
```

## 7. TLS / SSL Certificates

FreeTAKServer generates self-signed certs on first startup. For production, replace them with proper certs:

1. Place your fullchain + private key in `/mnt/fts/certs/`
2. Set `FTS_CLIENT_CERT_PASSWORD` to match the key passphrase
3. Restart: `docker compose restart`

For free certs, consider [Let's Encrypt + certbot](https://certbot.eff.org/) on the host, then mount the certs into the container.

## 8. Monitoring & Backups

### CloudWatch agent (optional)

```bash
sudo apt install -y amazon-cloudwatch-agent
# Configure logs from /mnt/fts/Logs/ → CloudWatch
```

### EBS snapshot backup

```bash
# One-time snapshot
aws ec2 create-snapshot --volume-id vol-xxxxx --description "FTS daily"

# Automated: use AWS Backup or a cron job
aws ec2 create-snapshot --volume-id vol-xxxxx --description "FTS auto $(date +%F)"
```

## 9. Troubleshooting

| Problem | Check |
|---------|-------|
| Container exits immediately | `docker compose logs` — usually a config or permission error |
| Can't connect from ATAK | Verify security group ports; check `FTS_DP_ADDRESS=0.0.0.0` |
| Data lost after reboot | Verify EBS mount in `/etc/fstab`; check `/mnt/fts/FTSConfig.yaml` exists |
| Port conflict | `sudo ss -tlnp | grep 8087` — ensure nothing else binds the port |

## File Reference

| File | Purpose |
|------|---------|
| `ec2-bootstrap.sh` | User-data script: installs Docker, clones config, starts FTS |
| `compose.ec2.yaml` | Docker Compose override for EC2 (bind-mounts `/mnt/fts`) |
| `fts-docker.service` | systemd unit for auto-start |
| `.env.example` | Template with EC2-specific comments |
