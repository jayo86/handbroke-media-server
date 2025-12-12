#!/bin/bash

echo "🍿 Radarr Auto-Update Script (Idempotent Edition)"
echo "==============================================="
set -e

# Prompt for API key (no echo for secrecy)
read -rsp "🔑 Enter your Radarr API Key: " API_KEY
echo

# Check prerequisites
for tool in curl jq wget; do
  if ! command -v $tool &>/dev/null; then
    echo "❌ Missing required tool: $tool"
    exit 1
  fi
done

# ➡️ Check systemd service name
echo "➡️  Checking systemd service..."
SERVICE_NAME=$(systemctl list-unit-files | grep -i radarr | awk '{print $1}' | head -n 1)
if [[ -z "$SERVICE_NAME" ]]; then
  echo "❌ Could not detect Radarr service name."
  exit 1
fi

# ➡️ Get binary path from service definition
RADARR_BIN=$(systemctl cat "$SERVICE_NAME" | grep -i ExecStart | head -n 1 | sed -E 's/^ExecStart=//;s/ .*$//')
if [[ ! -x "$RADARR_BIN" ]]; then
  echo "❌ Could not detect Radarr binary path from service."
  exit 1
fi
INSTALL_DIR=$(dirname "$RADARR_BIN")
RUN_USER=$(stat -c '%U' "$RADARR_BIN")
RUN_GROUP=$(stat -c '%G' "$RADARR_BIN")

# 🔍 Get local version
echo "➡️  Checking current Radarr version..."
LOCAL_VERSION=$(curl -s -H "X-Api-Key: $API_KEY" http://localhost:7878/api/v3/system/status | jq -r '.version')

if [[ -z "$LOCAL_VERSION" || "$LOCAL_VERSION" == "null" ]]; then
  echo "❌ Could not fetch local version. Radarr must be running and API key valid."
  exit 1
fi

echo "Local version: $LOCAL_VERSION"

# 🔍 Get latest version from GitHub
echo "➡️  Checking latest available version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/Radarr/Radarr/releases/latest | jq -r '.tag_name' | sed 's/^v//')

if [[ -z "$LATEST_VERSION" ]]; then
  echo "❌ Could not fetch remote version."
  exit 1
fi

echo "Latest version: $LATEST_VERSION"

if [[ "$LOCAL_VERSION" == "$LATEST_VERSION" ]]; then
  echo "✅ Already up to date (version $LOCAL_VERSION). No update needed."
  exit 0
else
  echo "🔄 Update available: $LOCAL_VERSION → $LATEST_VERSION"
fi

# 🛑 Stop Radarr
echo "🛑 Stopping Radarr..."
sudo systemctl stop "$SERVICE_NAME"

# 🧳 Backup
BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
echo "📦 Backing up current install to: $BACKUP_DIR"
sudo cp -r "$INSTALL_DIR" "$BACKUP_DIR"

# ⬇️ Download and extract
echo "🔍 Fetching latest release asset URL..."
ASSET_URL=$(curl -s https://api.github.com/repos/Radarr/Radarr/releases/latest \
  | jq -r '.assets[] | select(.name | test("linux-core-x64.tar.gz$")) | .browser_download_url')

if [[ -z "$ASSET_URL" ]]; then
  echo "❌ Could not find matching tar.gz asset in latest release."
  exit 1
fi

cd /tmp || exit 1
FILENAME=$(basename "$ASSET_URL")
echo "⬇️  Downloading: $FILENAME"
wget -O "$FILENAME" "$ASSET_URL" || { echo "❌ Download failed."; exit 1; }

echo "📂 Extracting $FILENAME..."
tar -xzf "$FILENAME"

# 🚚 Install
echo "🚚 Installing update..."
sudo cp -r Radarr/* "$INSTALL_DIR"

# 🔧 Permissions
echo "🔧 Fixing permissions: $RUN_USER:$RUN_GROUP"
sudo chown -R "$RUN_USER:$RUN_GROUP" "$INSTALL_DIR"

# 🚀 Start Radarr
echo "🚀 Starting Radarr..."
sudo systemctl start "$SERVICE_NAME"

echo "✅ Radarr update complete."
