#!/bin/bash

echo "🧠 Sonarr Auto-Update (Idempotent Edition)"
echo "=========================================="
set -e

# Prompt for API key (no echo for secrecy)
read -rsp "🔑 Enter your Sonarr API Key: " API_KEY
echo

# Check prerequisites
for tool in curl jq wget; do
  if ! command -v $tool &>/dev/null; then
    echo "❌ Missing required tool: $tool"
    exit 1
  fi
done

# 🔍 Get local version
echo "➡️  Checking current Sonarr version..."
LOCAL_VERSION=$(curl -s -H "X-Api-Key: $API_KEY" http://localhost:8989/api/v3/system/status | jq -r '.version')

if [[ -z "$LOCAL_VERSION" || "$LOCAL_VERSION" == "null" ]]; then
  echo "❌ Could not fetch local version. Sonarr must be running on port 8989 and accept the API key."
  echo "💤 Aborting update."
  exit 1
else
  echo "Local version: $LOCAL_VERSION"
fi

# 🔍 Get latest version from GitHub
echo "➡️  Checking latest available version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/Sonarr/Sonarr/releases/latest | jq -r '.tag_name' | sed 's/^v//')

if [[ -z "$LATEST_VERSION" || "$LATEST_VERSION" == "null" ]]; then
  echo "❌ Could not fetch remote version."
  exit 1
else
  if [[ "$LOCAL_VERSION" == "$LATEST_VERSION" ]]; then
    echo "✅ Already up to date (version $LATEST_VERSION). No update needed."
    exit 0
  else
    echo "🔄 Update available: $LOCAL_VERSION → $LATEST_VERSION"
  fi
fi

# 🛑 Stop Sonarr
SERVICE_NAME=$(systemctl list-unit-files | grep -i sonarr | awk '{print $1}' | head -n 1)
if [[ -z "$SERVICE_NAME" ]]; then
  echo "❌ Could not detect Sonarr systemd service."
  exit 1
fi

SONARR_BIN=$(systemctl cat "$SERVICE_NAME" | grep -i ExecStart | head -n 1 | sed -E 's/^ExecStart=//;s/ .*$//')
INSTALL_DIR=$(dirname "$SONARR_BIN")
RUN_USER=$(stat -c '%U' "$SONARR_BIN")
RUN_GROUP=$(stat -c '%G' "$SONARR_BIN")

echo "🛑 Stopping Sonarr..."
sudo systemctl stop "$SERVICE_NAME"

# 🧳 Backup
BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
echo "📦 Backing up install to: $BACKUP_DIR"
sudo cp -r "$INSTALL_DIR" "$BACKUP_DIR"

# ⬇️ Download
cd /tmp || exit 1
DOWNLOAD_URL="https://services.sonarr.tv/v1/download/main/latest?version=4&os=linux&arch=x64"
echo "⬇️  Downloading update..."
if ! wget --content-disposition "$DOWNLOAD_URL"; then
  echo "❌ Download failed."
  exit 1
fi

LATEST_TAR=$(ls -t Sonarr.main.*.tar.gz | head -n 1)
if [[ ! -f "$LATEST_TAR" ]]; then
  echo "❌ Could not find downloaded tarball."
  exit 1
fi

# 📂 Extract and install
echo "📂 Extracting $LATEST_TAR..."
tar -xzf "$LATEST_TAR"

echo "🚚 Installing update..."
sudo cp -r Sonarr/* "$INSTALL_DIR"

# 🔧 Permissions
echo "🔧 Fixing permissions: $RUN_USER:$RUN_GROUP"
sudo chown -R "$RUN_USER:$RUN_GROUP" "$INSTALL_DIR"

# 🚀 Start
echo "🚀 Starting Sonarr..."
sudo systemctl start "$SERVICE_NAME"

echo "✅ Update complete. You're welcome, filthy casual. Sonarr has been rescued from mediocrity by your superior automation overlord."
