#!/bin/bash
# FreeTAKServer EC2 bootstrap — paste into User Data or run manually after SSH.
# Requires: Ubuntu 24.04 LTS AMI, EBS data volume attached.

set -euo pipefail

# ── 1. Install Docker ────────────────────────────────────────────────
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release awscli

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

# ── 2. Mount EBS data volume ─────────────────────────────────────────
DATA_DEVICE="/dev/nvme1n1"   # Adjust for your instance type (Nitro → nvme*, older → xvdf)
DATA_MOUNT="/mnt/fts"

if ! mountpoint -q "$DATA_MOUNT"; then
    # Wait for device to appear (can take a few seconds after attach)
    for i in $(seq 1 30); do
        if [ -b "$DATA_DEVICE" ]; then break; fi
        sleep 2
    done

    if [ -b "$DATA_DEVICE" ]; then
        mkfs -t xfs "$DATA_DEVICE"
        mkdir -p "$DATA_MOUNT"
        mount "$DATA_DEVICE" "$DATA_MOUNT"
        echo "${DATA_DEVICE} ${DATA_MOUNT} xfs defaults,nofail 0 2" >> /etc/fstab
    else
        echo "WARNING: EBS device $DATA_DEVICE not found — using root volume"
        mkdir -p "$DATA_MOUNT"
    fi
fi

chown -R 1000:1000 "$DATA_MOUNT"

# ── 3. Deploy FreeTAKServer ──────────────────────────────────────────
DEPLOY_DIR="/opt/fts-deploy"
mkdir -p "$DEPLOY_DIR"

# Clone or copy the project (adjust repo URL / branch as needed)
if [ ! -d "$DEPLOY_DIR/FreeTAKServer" ]; then
    git clone https://github.com/FreeTAKTeam/FreeTakServer.git "$DEPLOY_DIR"
fi

cd "$DEPLOY_DIR"

# Generate .env from example if not present
if [ ! -f .env ]; then
    cp .env.example .env
    # Auto-generate secrets
    SECRET=$(python3 -c "import secrets; print(secrets.token_hex(16))")
    NODE_ID=$(python3 -c "import secrets; print(secrets.token_hex(16))")
    WS_KEY=$(python3 -c "import secrets; print(secrets.token_hex(16))")
    sed -i "s/^FTS_SECRET_KEY=change-me-to-a-random-string/FTS_SECRET_KEY=${SECRET}/" .env
    sed -i "s/^FTS_NODE_ID=change-me-to-a-random-32-char-id/FTS_NODE_ID=${NODE_ID}/" .env
    sed -i "s/^FTS_WEBSOCKET_KEY=change-me-websocket-key/FTS_WEBSOCKET_KEY=${WS_KEY}/" .env
    sed -i "s|^FTS_DATA_PATH=.*|FTS_DATA_PATH=${DATA_MOUNT}|" .env
fi

# Create required subdirectories on the data volume
mkdir -p "${DATA_MOUNT}/certs" "${DATA_MOUNT}/certs/clientPackages" \
         "${DATA_MOUNT}/ExCheck/template" "${DATA_MOUNT}/ExCheck/checklist" \
         "${DATA_MOUNT}/Logs" "${DATA_MOUNT}/FreeTAKServerDataPackageFolder" \
         "${DATA_MOUNT}/enterprise_sync" "${DATA_MOUNT}/user_persistence"

# Build and start
docker compose -f compose.ec2.yaml build
docker compose -f compose.ec2.yaml up -d

# ── 4. Install systemd unit for auto-start ────────────────────────────
cp "$DEPLOY_DIR/fts-docker.service" /etc/systemd/system/fts-docker.service
systemctl daemon-reload
systemctl enable fts-docker

echo "FreeTAKServer deployed. Check status: docker compose -f compose.ec2.yaml ps"
