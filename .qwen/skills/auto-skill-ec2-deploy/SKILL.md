---
name: ec2-deploy
description: Adapt a Docker Compose project for AWS EC2 deployment — EBS bind mounts, security groups, systemd auto-start, user-data bootstrap
source: auto-skill
extracted_at: '2026-06-15T08:50:40.612Z'
---

# Deploy Docker Compose Projects to AWS EC2

When a project uses Docker Compose and the user asks to "configure for AWS EC2 VPS", follow this structured approach rather than modifying the main compose file.

## Step 1 — Create a separate compose override file

**Never modify the original `compose.yaml`.** Create `compose.ec2.yaml` (or similar) that:

- Changes `volumes` from named Docker volumes to **bind mounts** pointing at the EBS mount path (e.g. `/mnt/fts`). Named volumes live inside Docker's graph driver and are harder to back up; EBS bind mounts let you snapshot via AWS.
- Adds a `healthcheck` block matching the Dockerfile's `HEALTHCHECK` or the project's existing health endpoint.
- Adds `logging` with `json-file` driver and `max-size/max-file` rotation (EC2 root volumes are small; unbounded logs fill them fast).
- Sets `restart: unless-stopped`.
- Sets `FTS_DATA_PATH` (or equivalent) via `environment` to match the EBS mount, not the Docker default.
- Restricts admin-only ports (like REST API) to `127.0.0.1:port:port` instead of exposing them publicly.

## Step 2 — Create a systemd service unit

Create `fts-docker.service` (project-specific name) that:

- `Requires=docker.service` and `After=docker.service`
- `WorkingDirectory=/opt/fts-deploy` (or wherever the repo is cloned)
- `ExecStart=/usr/bin/docker compose -f compose.ec2.yaml up -d`
- `ExecStop=/usr/bin/docker compose -f compose.ec2.yaml down`
- `Type=oneshot` with `RemainAfterExit=yes`
- `WantedBy=multi-user.target`

## Step 3 — Create a user-data bootstrap script (`ec2-bootstrap.sh`)

The script runs on first boot and should:

1. **Install Docker** using the official apt repo (not snap, which has volume-mount issues).
2. **Detect and mount EBS data volume** — handle both Nitro (`/dev/nvme*n1`) and older (`/dev/xvd*`) device names. Wait up to 60s for the device to appear after attach. Format with `xfs`, add to `/etc/fstab` with `nofail`.
3. **Clone the repo** to `/opt/fts-deploy`.
4. **Auto-generate secrets** if `.env` doesn't exist: copy `.env.example`, use `python3 -c "import secrets; print(secrets.token_hex(16))"` for each secret field, then `sed -i` to replace placeholders.
5. **Create data subdirectories** on the EBS mount (certs, logs, etc.) matching what `docker-run.sh` or the entrypoint expects.
6. **Build and start** with `docker compose -f compose.ec2.yaml build && up -d`.
7. **Install the systemd unit** by copying it to `/etc/systemd/system/` and enabling it.

## Step 4 — Write a deployment README (`README_AWS_EC2.md`)

Include:

- **Instance sizing table** — recommend minimum (t3.small for light use, t3.medium for production).
- **Security group inbound rules table** — derive ports from the Dockerfile's `EXPOSE` lines and compose port mappings. Mark admin ports as restricted.
- **EBS mount instructions** — format, mount, fstab, chown for Docker UID.
- **Env configuration** — key variables for EC2 (`0.0.0.0` bind addresses, EBS data path).
- **Start/stop/update commands** using the EC2 compose file.
- **TLS guidance** — self-signed vs. proper certs.
- **Backup** — EBS snapshots via `aws ec2 create-snapshot` or AWS Backup.
- **Troubleshooting table** — common issues (container exit, connectivity, data loss).

## Step 5 — Update `.env.example` with EC2 hints

Add inline comments for:
- Secret fields noting that `ec2-bootstrap.sh` auto-generates them.
- Address fields explaining `0.0.0.0` is required on EC2.
- A commented `FTS_DATA_PATH` section showing both the default and EC2 paths.

## Key principles

- **Separation**: EC2-specific compose override, not modified original. This keeps the generic compose.yaml clean for local/dev use.
- **Persistence**: EBS bind mount, not Docker named volumes. Enables AWS snapshots and survives instance replacement.
- **Auto-start**: systemd unit, not just `restart: unless-stopped` in compose (covers Docker daemon restarts too).
- **Security**: Restrict admin API ports to localhost in compose; security group rules enforce external access.
- **NVMe awareness**: EC2 Nitro instances expose EBS as NVMe devices — the bootstrap script must handle both naming conventions.
