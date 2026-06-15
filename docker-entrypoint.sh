#!/bin/bash
set -e

FTS_DATA_PATH="${FTS_DATA_PATH:-/opt/fts}"

# Fix permissions on data path (run as root before dropping to freetak)
if [[ -d "$FTS_DATA_PATH" ]]; then
    chown -R freetak:freetak "$FTS_DATA_PATH" 2>/dev/null || true
fi

# Create required subdirectories
mkdir -p "$FTS_DATA_PATH/certs" "$FTS_DATA_PATH/certs/clientPackages" \
         "$FTS_DATA_PATH/ExCheck/template" "$FTS_DATA_PATH/ExCheck/checklist" \
         "$FTS_DATA_PATH/Logs" "$FTS_DATA_PATH/FreeTAKServerDataPackageFolder" \
         "$FTS_DATA_PATH/enterprise_sync" "$FTS_DATA_PATH/user_persistence"

# Fix digitalpy log dirs permissions
find /usr/local/lib/python3.11/site-packages/digitalpy -type d -name logs -exec chmod 777 {} \; 2>/dev/null || true

# Generate FTSConfig.yaml if missing
if [[ ! -f "$FTS_DATA_PATH/FTSConfig.yaml" ]]; then
    python -c "from FreeTAKServer.core.configuration.configuration_wizard import autogenerate_config; autogenerate_config()"
fi

# Drop to freetak user and run the main process
exec gosu freetak python -m FreeTAKServer.controllers.services.FTS -AutoStart True 2>&1
