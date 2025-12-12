#!/bin/bash

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./install_media_stack.sh)"
  exit 1
fi

# --- 1. Detect Real User (The Human) ---
if [ $SUDO_USER ]; then
    REAL_USER=$SUDO_USER
    REAL_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
else
    echo "Error: This script must be run via sudo from a regular user account (e.g., sudo ./script.sh)."
    exit 1
fi

echo "--- Configuration ---"
echo "Target User: $REAL_USER"
echo "Target Home: $REAL_HOME"
echo "Target Group: media"
echo "---------------------"

# Install prerequisites
echo "Installing prerequisites..."
apt-get update -qq
apt-get install -y curl gnupg ca-certificates apt-transport-https software-properties-common acl

# --- 2. Create Group and Add Users ---

echo "Configuring 'media' group..."
groupadd -f media
usermod -aG media "$REAL_USER"

# --- 3. Install Jellyfin (Official Docs) ---

echo "--- Checking Jellyfin ---"
if ! command -v jellyfin &> /dev/null; then
    echo "Installing Jellyfin..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg --yes
    export VERSION_OS="$(awk -F= '/^ID=/{print $2}' /etc/os-release)"
    export VERSION_CODENAME="$(awk -F= '/^VERSION_CODENAME=/{print $2}' /etc/os-release)"
    echo "deb [arch=$( dpkg --print-architecture ) signed-by=/etc/apt/keyrings/jellyfin.gpg] https://repo.jellyfin.org/${VERSION_OS} ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/jellyfin.list
    apt-get update -qq
    apt-get install -y jellyfin
else
    echo "Jellyfin already installed."
fi
# Ensure Jellyfin service user is in media group
usermod -aG media jellyfin

# --- 4. Install SABnzbd (Official PPA) ---

echo "--- Checking SABnzbd ---"
if ! command -v sabnzbdplus &> /dev/null; then
    echo "Installing SABnzbd..."
    add-apt-repository -y ppa:jcfp/nobetas
    add-apt-repository -y ppa:jcfp/sab-addons # Required for python libraries often needed
    apt-get update -qq
    apt-get install -y sabnzbdplus python3-sabyenc par2-tbb
else
    echo "SABnzbd already installed."
fi

# Fix SABnzbd Service Config to run as 'sabnzbd' user (Package creates user 'sabnzbd' but often defaults service to root or none)
# We ensure the service runs as the dedicated 'sabnzbd' user.
if [ -f /etc/default/sabnzbdplus ]; then
    sed -i 's/^USER=.*/USER=sabnzbd/' /etc/default/sabnzbdplus
    sed -i 's/^#USER=.*/USER=sabnzbd/' /etc/default/sabnzbdplus
    # Ensure it listens on a port so it doesn't fail start
    sed -i 's/^HOST=.*/HOST=0.0.0.0/' /etc/default/sabnzbdplus
    sed -i 's/^#HOST=.*/HOST=0.0.0.0/' /etc/default/sabnzbdplus
    sed -i 's/^PORT=.*/PORT=8080/' /etc/default/sabnzbdplus
    sed -i 's/^#PORT=.*/PORT=8080/' /etc/default/sabnzbdplus
fi
# Add sabnzbd user to media group
usermod -aG media sabnzbd

# --- 5. Install Sonarr (Official Servarr Docs) ---

echo "--- Checking Sonarr ---"
if ! command -v sonarr &> /dev/null; then
    echo "Installing Sonarr..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0x200983798d5a8619bb6963df0a1029a6ca96fa1f | gpg --dearmor -o /etc/apt/keyrings/sonarr.gpg --yes
    echo "deb [signed-by=/etc/apt/keyrings/sonarr.gpg] https://apt.sonarr.tv/ubuntu focal main" > /etc/apt/sources.list.d/sonarr.list
    apt-get update -qq
    apt-get install -y sonarr
else
    echo "Sonarr already installed."
fi
# Add sonarr user to media group
usermod -aG media sonarr

# --- 6. Install Radarr (Official Servarr Docs) ---

echo "--- Checking Radarr ---"
if ! command -v radarr &> /dev/null; then
    echo "Installing Radarr..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0x90494435a83d537e | gpg --dearmor -o /etc/apt/keyrings/radarr.gpg --yes
    echo "deb [signed-by=/etc/apt/keyrings/radarr.gpg] https://apt.radarr.video/ubuntu focal main" > /etc/apt/sources.list.d/radarr.list
    apt-get update -qq
    apt-get install -y radarr
else
    echo "Radarr already installed."
fi
# Add radarr user to media group
usermod -aG media radarr

# --- 7. Create Directories & Apply Permissions ---

echo "--- Setting Directory Permissions & ACLs ---"

# List of directories to process
# 1. Create them
mkdir -p "$REAL_HOME/Downloads/complete"
mkdir -p "$REAL_HOME/Downloads/incomplete"
mkdir -p "$REAL_HOME/tv"
mkdir -p "$REAL_HOME/movies"

# Function to apply the specific permission logic
apply_perms() {
    local TARGET="$1"
    local RECURSIVE="$2" # "yes" or "no" - though we usually apply to dir only, ACL default handles recursion for new files
    
    if [ -d "$TARGET" ]; then
        echo "Processing: $TARGET"
        
        # 1. Set Ownership: Real User + Media Group
        chown "$REAL_USER:media" "$TARGET"
        
        # 2. Set Permissions: 2775 (drwxrwsr-x)
        # 2 = SetGID (New files inherit group 'media')
        # 7 = Owner RWX
        # 7 = Group RWX
        # 5 = Others R-X
        chmod 2775 "$TARGET"

        # 3. Apply ACLs
        # -m: modify
        # u::rwx owner has access
        # g::rwx group has access
        # o::rx others have read/execute
        setfacl -m u::rwx,g::rwx,o::rx "$TARGET"
        
        # 4. Apply Default ACLs (The "Inherited" permissions)
        # Note: The prompt requested complete downloads to have default:other::---
        # but others to have default:other::r-x (implied by previous context, but we will make it strict where asked)
        
        if [[ "$TARGET" == *"/Downloads/complete"* ]]; then
             # Strict default for complete folder as per prompt request
             setfacl -d -m u::rwx,g::rwx,o::--- "$TARGET"
        else
             # Standard default for others
             setfacl -d -m u::rwx,g::rwx,o::rx "$TARGET"
        fi
    fi
}

# Apply to specific folders
apply_perms "$REAL_HOME/Downloads/complete"
apply_perms "$REAL_HOME/Downloads/incomplete"
apply_perms "$REAL_HOME/tv"
apply_perms "$REAL_HOME/movies"

# --- 8. Restart Services to Apply Group Changes ---
echo "--- Restarting Services ---"
systemctl restart jellyfin
systemctl restart sabnzbdplus
systemctl restart sonarr
systemctl restart radarr

echo "=========================================================="
echo "Installation and Permission Setup Complete!"
echo "Users for applications have been added to group: media"
echo "Directories in $REAL_HOME have been configured with SGID and ACLs."
echo "Please reboot or log out/in for your own group changes to take full effect."
echo "=========================================================="
