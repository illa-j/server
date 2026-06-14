#!/bin/bash

FTS_DATA_PATH="${FTS_DATA_PATH:-/opt/fts}"

# Ensure data directory exists and is writable
if [[ ! -d "$FTS_DATA_PATH" ]]; then
  mkdir -p "$FTS_DATA_PATH"
fi

# Create required subdirectories
mkdir -p "$FTS_DATA_PATH/certs" "$FTS_DATA_PATH/certs/clientPackages" \
         "$FTS_DATA_PATH/ExCheck/template" "$FTS_DATA_PATH/ExCheck/checklist" \
         "$FTS_DATA_PATH/Logs" "$FTS_DATA_PATH/FreeTAKServerDataPackageFolder" \
         "$FTS_DATA_PATH/enterprise_sync" "$FTS_DATA_PATH/user_persistence"

# Sharing for FTSConfig.yaml
if [[ ! -f "$FTS_DATA_PATH/FTSConfig.yaml" ]]
  then
    python -c "from FreeTAKServer.core.configuration.configuration_wizard import autogenerate_config; autogenerate_config()"
fi

python -m FreeTAKServer.controllers.services.FTS