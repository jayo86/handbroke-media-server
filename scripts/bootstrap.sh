#!/bin/bash
# Stop script on any error (Safety First)
set -e
# Stop script if a pipe fails
set -o pipefail

# --- COLORS ---
# ANSI Color Codes for "Ansible-style" output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- LOGGING FUNCTIONS ---
log_ok() { echo -e "${GREEN}[OK]      $1${NC}"; }
log_change() { echo -e "${YELLOW}[CHANGED] $1${NC}"; }
log_err() { echo -e "${RED}[FAILED]  $1${NC}"; }

# --- ERROR TRAP ---
# If any command fails, this runs automatically before exiting
error_handler() {
    echo ""
    log_err "Script encountered an error on line $1."
    log_err "Exiting..."
}
trap 'error_handler $LINENO' ERR

# --- Configuration ---
TARGET_MOUNT="/usenet"
VG_NAME="usenet_vg"
LV_NAME="media_lv"

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  log_err "Please run as root (sudo ./install_media_stack.sh)"
  exit 1
fi

# --- 1. Detect Real User ---
if [ $SUDO_USER ]; then
    REAL_USER=$SUDO_USER
    REAL_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
else
    log_err "Run via sudo from a regular user (e.g., sudo ./script.sh)."
    exit 1
fi

echo -e "--- Target User: ${YELLOW}$REAL_USER${NC} ---"

# --- 2. System Update & Upgrade ---
echo "--- System Updates ---"
log_change "Updating Package Lists..."
apt-get update -qq

if apt-get -s upgrade | grep -q "0 upgraded, 0 newly installed"; then
    log_ok "System packages are up to date."
else
    log_change "Upgrading installed packages..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
fi

# --- 3. Install Prerequisites ---
echo "--- Dependencies ---"
# Check if a random dependency is missing to decide if we log 'change' or 'ok'
if ! dpkg -s lvm2 >/dev/null 2>&1; then
    log_change "Installing Dependencies (LVM, SSH, UFW, ACL, Git)..."
    apt-get install -y curl sqlite3 mediainfo ufw software-properties-common gnupg ca-certificates apt-transport-https acl openssh-server lvm2 git
else
    log_ok "Dependencies already installed."
fi

# Create shared group 'media'
if getent group media >/dev/null; then
    log_ok "Group 'media' already exists."
else
    log_change "Creating group 'media'."
    groupadd -f media
fi
usermod -aG media "$REAL_USER"

# --- 4. STORAGE SETUP ---
echo "--- Storage Configuration ---"

# Check if the Volume Group already exists
if vgs $VG_NAME >/dev/null 2>&1; then
    if mount | grep -q "$TARGET_MOUNT"; then
        log_ok "Volume Group '$VG_NAME' exists and is mounted at $TARGET_MOUNT."
    else
        log_change "Volume exists but unmounted. Mounting $TARGET_MOUNT..."
        mkdir -p "$TARGET_MOUNT"
        mount "/dev/$VG_NAME/$LV_NAME" "$TARGET_MOUNT"
    fi
else
    # --- DRIVE DETECTION LOGIC ---
    log_change "Scanning for storage drives..."
    
    ROOT_SOURCE=$(findmnt -n -o SOURCE /)
    ROOT_DISK_NAME=$(lsblk -no pkname "$ROOT_SOURCE" | head -n 1)
    
    # || true prevents grep failure from triggering the error trap
    CANDIDATE_DISK=$(lsblk -dno NAME,SIZE,TYPE | grep disk | grep -v "$ROOT_DISK_NAME" | head -n 1 || true)
    
    if [ -z "$CANDIDATE_DISK" ]; then
        # --- NO SECONDARY DRIVE ---
        FREE_SPACE=$(df -h / --output=avail | tail -n 1 | xargs)
        
        echo -e "${YELLOW}WARNING: No secondary drive found!${NC}"
        read -p "Configure video directories on $ROOT_SOURCE ($FREE_SPACE free)? [y/N] " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_err "User cancelled installation."
            exit 1
        fi

        read -p "Enter path for media storage [Default: $TARGET_MOUNT]: " USER_PATH
        TARGET_MOUNT=${USER_PATH:-$TARGET_MOUNT}
        log_change "Configuring local storage at: $TARGET_MOUNT"

    else
        # --- SECONDARY DRIVE FOUND ---
        DISK_NAME=$(echo "$CANDIDATE_DISK" | awk '{print $1}')
        DISK_SIZE=$(echo "$CANDIDATE_DISK" | awk '{print $2}')
        DISK_PATH="/dev/$DISK_NAME"

        echo -e "${YELLOW}FOUND DRIVE: $DISK_PATH ($DISK_SIZE)${NC}"
        echo "WARNING: This will WIPE ALL DATA on $DISK_PATH (including old OS/Partitions)."
        read -p "Do you want to WIPE and FORMAT $DISK_PATH? [y/N] " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_change "Wiping filesystem signatures (wipefs)..."
            wipefs -a -f "$DISK_PATH"
            sleep 2
            
            log_change "Initializing LVM..."
            pvcreate -y -ff "$DISK_PATH"
            vgcreate "$VG_NAME" "$DISK_PATH"
            lvcreate -y -l 100%FREE -n "$LV_NAME" "$VG_NAME"
            
            log_change "Formatting ext4..."
            mkfs.ext4 "/dev/$VG_NAME/$LV_NAME"
            
            log_change "Mounting to $TARGET_MOUNT..."
            mkdir -p "$TARGET_MOUNT"
            mount "/dev/$VG_NAME/$LV_NAME" "$TARGET_MOUNT"
            
            if ! grep -qs "$TARGET_MOUNT" /etc/fstab; then
                echo "/dev/$VG_NAME/$LV_NAME $TARGET_MOUNT ext4 defaults 0 0" >> /etc/fstab
                log_change "Added to /etc/fstab"
            fi
        else
            log_err "User declined format. Aborting safety check."
            exit 1
        fi
    fi
fi

# --- 5. Install Jellyfin ---
echo "--- Application: Jellyfin ---"
if ! dpkg -s jellyfin >/dev/null 2>&1; then
    log_change "Installing Jellyfin..."
    curl -s https://repo.jellyfin.org/install-debuntu.sh | bash
    usermod -aG media jellyfin
else
    log_ok "Jellyfin is already installed."
fi

# --- 6. Install SABnzbd ---
echo "--- Application: SABnzbd ---"
if ! dpkg -s sabnzbdplus >/dev/null 2>&1; then
    log_change "Installing SABnzbd..."
    add-apt-repository -y ppa:jcfp/nobetas
    add-apt-repository -y ppa:jcfp/sab-addons
    apt-get update -qq
    # FIXED: Removed 'python3-sabyenc' and 'par2-tbb' (Old/Deprecated)
    # The main package 'sabnzbdplus' will automatically pull the correct new dependencies.
    apt-get install -y sabnzbdplus

    # Configure defaults
    if [ -f /etc/default/sabnzbdplus ]; then
        sed -i 's/^USER=.*/USER=sabnzbd/' /etc/default/sabnzbdplus
        sed -i 's/^HOST=.*/HOST=0.0.0.0/' /etc/default/sabnzbdplus
        sed -i 's/^PORT=.*/PORT=8080/' /etc/default/sabnzbdplus
    fi
    usermod -aG media sabnzbd
    systemctl restart sabnzbdplus
else
    log_ok "SABnzbd is already installed."
fi

# --- 7. Install Sonarr ---
echo "--- Application: Sonarr ---"
if ! dpkg -s sonarr >/dev/null 2>&1; then
    log_change "Installing Sonarr..."
    curl -o install-sonarr.sh https://raw.githubusercontent.com/Sonarr/Sonarr/develop/distribution/debian/install.sh
    chmod +x install-sonarr.sh
    bash install-sonarr.sh
    rm install-sonarr.sh
    usermod -aG media sonarr
else
    log_ok "Sonarr is already installed."
fi

# --- 8. Install Radarr ---
echo "--- Application: Radarr ---"
# Check User
if ! id -u radarr &>/dev/null; then
    log_change "Creating User 'radarr'..."
    useradd -r -s /usr/sbin/nologin -g media -m -d /var/lib/radarr radarr
else
    log_ok "User 'radarr' exists."
    usermod -aG media radarr
fi

# Check Files
if [ ! -d "/opt/Radarr" ]; then
    log_change "Downloading Radarr..."
    wget -q --content-disposition 'http://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64' -O Radarr.tar.gz
    tar -xzf Radarr.tar.gz -C /opt/
    rm Radarr.tar.gz
    
    # Permissions
    chown -R radarr:media /opt/Radarr
    chmod -R 775 /opt/Radarr
    
    # Service
    log_change "Creating Systemd Service..."
cat << EOF > /etc/systemd/system/radarr.service
[Unit]
Description=Radarr Daemon
After=syslog.target network.target

[Service]
User=radarr
Group=media
Type=simple
ExecStart=/opt/Radarr/Radarr -nobrowser -data=/var/lib/radarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now radarr
else
    log_ok "Radarr is already installed in /opt/Radarr."
fi

# --- 9. Directories & Permissions ---
echo "--- Permissions & Structure ---"
# Loop through folders to see if we need to create them
for dir in "$TARGET_MOUNT/Downloads/complete" "$TARGET_MOUNT/Downloads/incomplete" "$TARGET_MOUNT/tv" "$TARGET_MOUNT/movies"; do
    if [ ! -d "$dir" ]; then
        log_change "Creating directory: $dir"
        mkdir -p "$dir"
    fi
done

log_change "Applying Ownership & ACLs (Recursive)..."
chown -R "$REAL_USER:media" "$TARGET_MOUNT"
chmod -R 775 "$TARGET_MOUNT"
chmod -R g+s "$TARGET_MOUNT"
setfacl -R -m g:media:rwx "$TARGET_MOUNT"
setfacl -d -R -m g:media:rwx "$TARGET_MOUNT"

# --- 10. Firewall ---
echo "--- Firewall (UFW) ---"
# We force enable it, so we mark it as Changed/Yellow to be safe
log_change "Enabling UFW and allowing ports..."
ufw allow 22/tcp   > /dev/null
ufw allow 8080/tcp > /dev/null
ufw allow 8096/tcp > /dev/null
ufw allow 8989/tcp > /dev/null
ufw allow 7878/tcp > /dev/null
ufw --force enable > /dev/null

# --- 11. Done ---
IP_ADDR=$(hostname -I | awk '{print $1}')
echo ""
echo "------------------------------------------------"
echo -e "${GREEN}       INSTALLATION COMPLETE       ${NC}"
echo "------------------------------------------------"
echo " Storage Location: $TARGET_MOUNT"
echo ""
echo " Access your applications:"
echo -e " * Jellyfin: ${YELLOW}http://$IP_ADDR:8096${NC}"
echo -e " * Sonarr:   ${YELLOW}http://$IP_ADDR:8989${NC}"
echo -e " * Radarr:   ${YELLOW}http://$IP_ADDR:7878${NC}"
echo -e " * SABnzbd:  ${YELLOW}http://$IP_ADDR:8080${NC}"
echo "------------------------------------------------"
