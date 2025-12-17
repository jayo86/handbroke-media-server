#!/bin/bash
# Stop script on any error (Safety First)
set -e
# Stop script if a pipe fails
set -o pipefail

# --- COLORS ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- LOGGING FUNCTIONS ---
log_ok() { echo -e "${GREEN}[OK]      $1${NC}"; }
log_change() { echo -e "${YELLOW}[CHANGED] $1${NC}"; }
log_err() { echo -e "${RED}[FAILED]  $1${NC}"; }
log_skip() { echo -e "${CYAN}$1${NC}"; }

# --- ARGUMENT PARSING ---
SKIP_ACL=false
for arg in "$@"; do
  if [[ "$arg" == "-s" ]] || [[ "$arg" == "--skip-acl" ]]; then
    SKIP_ACL=true
  fi
done

# --- ERROR TRAP ---
error_handler() {
    echo ""
    log_err "Script encountered an error on line $1."
    log_err "Exiting..."
}
trap 'error_handler $LINENO' ERR

# --- Configuration ---
TARGET_MOUNT="/usenet"      # Slow Storage (SATA SSD)
CACHE_MOUNT="/mnt/nvme_cache" # Fast Cache (NVMe Boot Drive)
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
else
    log_err "Run via sudo from a regular user."
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

# --- 3. Install Prerequisites & System Tuning ---
echo "--- Dependencies & Tuning ---"
if ! dpkg -s lvm2 >/dev/null 2>&1; then
    log_change "Installing Dependencies..."
    apt-get install -y curl sqlite3 mediainfo ufw software-properties-common gnupg ca-certificates apt-transport-https acl openssh-server lvm2 git
else
    log_ok "Dependencies already installed."
fi

# Fix: Increase inotify user watches (Essential for Jellyfin/Sonarr monitoring)
if [ ! -f /etc/sysctl.d/40-max-user-watches.conf ]; then
    log_change "increasing fs.inotify.max_user_watches to 524288..."
    echo "fs.inotify.max_user_watches=524288" > /etc/sysctl.d/40-max-user-watches.conf
    sysctl -p /etc/sysctl.d/40-max-user-watches.conf
else
    log_ok "Inotify limit already configured."
fi

# Create shared group 'media'
groupadd -f media
usermod -aG media "$REAL_USER"

# --- 4. STORAGE SETUP (SATA DRIVE) ---
echo "--- Storage Configuration (SATA) ---"

if vgs $VG_NAME >/dev/null 2>&1; then
    if mount | grep -q "$TARGET_MOUNT"; then
        log_ok "Volume Group '$VG_NAME' exists and is mounted."
    else
        log_change "Mounting existing volume to $TARGET_MOUNT..."
        mkdir -p "$TARGET_MOUNT"
        mount "/dev/$VG_NAME/$LV_NAME" "$TARGET_MOUNT"
    fi
else
    # Scanning for drives
    ROOT_SOURCE=$(findmnt -n -o SOURCE /)
    ROOT_DISK_NAME=$(lsblk -no pkname "$ROOT_SOURCE" | head -n 1)
    
    # Find candidate (First disk that is NOT the OS drive)
    CANDIDATE_DISK=$(lsblk -dno NAME,SIZE,TYPE | grep disk | grep -v "$ROOT_DISK_NAME" | head -n 1 || true)
    
    if [ -z "$CANDIDATE_DISK" ]; then
        # --- NO SECONDARY DRIVE ---
        echo -e "${YELLOW}WARNING: No secondary drive found.${NC}"
        log_change "Auto-configuring local storage at: $TARGET_MOUNT"
    else
        # --- SECONDARY DRIVE FOUND ---
        DISK_NAME=$(echo "$CANDIDATE_DISK" | awk '{print $1}')
        DISK_PATH="/dev/$DISK_NAME"

        echo -e "${YELLOW}FOUND DRIVE: $DISK_PATH${NC}"
        log_change "Auto-Wiping and Formatting $DISK_PATH..."
        
        # Zero-Touch Wipe & Format
        wipefs -a -f "$DISK_PATH"
        sleep 2
        
        pvcreate -y -ff "$DISK_PATH"
        vgcreate "$VG_NAME" "$DISK_PATH"
        lvcreate -y -l 100%FREE -n "$LV_NAME" "$VG_NAME"
        mkfs.ext4 "/dev/$VG_NAME/$LV_NAME"
        
        mkdir -p "$TARGET_MOUNT"
        mount "/dev/$VG_NAME/$LV_NAME" "$TARGET_MOUNT"
        
        if ! grep -qs "$TARGET_MOUNT" /etc/fstab; then
            echo "/dev/$VG_NAME/$LV_NAME $TARGET_MOUNT ext4 defaults 0 0" >> /etc/fstab
            log_change "Added to /etc/fstab"
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
if ! dpkg -s sabnzbdplus >/dev/null 2>&1 || ! id -u sabnzbd >/dev/null 2>&1; then
    log_change "Installing or Repairing SABnzbd..."
    add-apt-repository -y ppa:jcfp/nobetas
    add-apt-repository -y ppa:jcfp/sab-addons
    apt-get update -qq
    dpkg --configure -a || true
    apt-get install -y sabnzbdplus

    # Explicit User Creation Check
    if ! id -u sabnzbd >/dev/null 2>&1; then
        log_change "Creating user 'sabnzbd' manually..."
        useradd -r -s /usr/sbin/nologin -g media -m -d /var/lib/sabnzbd sabnzbd
    fi

    if [ -f /etc/default/sabnzbdplus ]; then
        sed -i 's/^USER=.*/USER=sabnzbd/' /etc/default/sabnzbdplus
        sed -i 's/^HOST=.*/HOST=0.0.0.0/' /etc/default/sabnzbdplus
        sed -i 's/^PORT=.*/PORT=8080/' /etc/default/sabnzbdplus
    fi
    usermod -aG media sabnzbd
    systemctl restart sabnzbdplus
else
    log_ok "SABnzbd is correctly installed."
fi

# --- 7. Install Sonarr ---
echo "--- Application: Sonarr ---"
# CHECK UPDATE: Checks for the executable file itself (handles empty folders)
if ! dpkg -s sonarr >/dev/null 2>&1 && [ ! -f "/opt/Sonarr/Sonarr" ] && [ ! -f "/usr/lib/sonarr/bin/Sonarr" ]; then
    log_change "Installing Sonarr..."
    # Running Sonarr installer headlessly
    curl -o install-sonarr.sh https://raw.githubusercontent.com/Sonarr/Sonarr/develop/distribution/debian/install.sh
    chmod +x install-sonarr.sh
    bash install-sonarr.sh -user sonarr -group media
    rm install-sonarr.sh
    usermod -aG media sonarr
else
    log_ok "Sonarr is already installed."
fi

# --- 8. Install Radarr ---
echo "--- Application: Radarr ---"
if ! id -u radarr &>/dev/null; then
    log_change "Creating User 'radarr'..."
    useradd -r -s /usr/sbin/nologin -g media -m -d /var/lib/radarr radarr
else
    log_ok "User 'radarr' exists."
    usermod -aG media radarr
fi

if [ ! -f "/opt/Radarr/Radarr" ]; then
    log_change "Downloading Radarr..."
    wget -q --content-disposition 'http://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64' -O Radarr.tar.gz
    tar -xzf Radarr.tar.gz -C /opt/
    rm Radarr.tar.gz
    
    chown -R radarr:media /opt/Radarr
    chmod -R 775 /opt/Radarr
    
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
    log_ok "Radarr is already installed."
fi

# --- 9. Directories & Permissions (UPDATED FOR NVME CACHE) ---
echo "--- Permissions & Structure ---"

# A. Create NVMe Cache Structure (The Fast Zone)
log_change "Configuring NVMe Cache at $CACHE_MOUNT..."
mkdir -p "$CACHE_MOUNT/complete"
mkdir -p "$CACHE_MOUNT/incomplete"

# B. Create SATA Storage Structure (The Library)
log_change "Configuring Library Storage at $TARGET_MOUNT..."
mkdir -p "$TARGET_MOUNT/tv"
mkdir -p "$TARGET_MOUNT/movies"

if [ "$SKIP_ACL" = true ]; then
    log_skip "Skipping Ownership and ACLs task"
else
    log_change "Applying Ownership & ACLs..."
    
    # 1. Apply to SATA Storage (/usenet)
    chown -R "$REAL_USER:media" "$TARGET_MOUNT"
    chmod -R 775 "$TARGET_MOUNT"
    chmod -R g+s "$TARGET_MOUNT"
    setfacl -R -m g:media:rwx "$TARGET_MOUNT"
    setfacl -d -R -m g:media:rwx "$TARGET_MOUNT"

    # 2. Apply to NVMe Cache (/mnt/nvme_cache)
    chown -R "$REAL_USER:media" "$CACHE_MOUNT"
    chmod -R 775 "$CACHE_MOUNT"
    chmod -R g+s "$CACHE_MOUNT"
    setfacl -R -m g:media:rwx "$CACHE_MOUNT"
    setfacl -d -R -m g:media:rwx "$CACHE_MOUNT"
fi

# --- 10. Firewall ---
echo "--- Firewall (UFW) ---"
# Add rules silently (ufw is smart enough not to duplicate)
ufw allow 22/tcp    > /dev/null
ufw allow 8080/tcp > /dev/null
ufw allow 8096/tcp > /dev/null
ufw allow 8989/tcp > /dev/null
ufw allow 7878/tcp > /dev/null

# Check status before trying to enable
if ufw status | grep -q "Status: active"; then
    log_ok "Firewall (UFW) is already active."
else
    log_change "Enabling UFW..."
    ufw --force enable > /dev/null
fi

# --- 11. Automated Maintenance ---
echo "--- Maintenance Schedule ---"
# Create a cron file in /etc/cron.d (cleaner than user crontabs)
CRON_FILE="/etc/cron.d/media_auto_update"
if [ ! -f "$CRON_FILE" ]; then
    log_change "Setting up monthly update & reboot (1st of month @ 3am)..."
    # Format: m h  dom mon dow user command
    # 0 3 1 * * = 03:00 AM on the 1st of every month
    echo "0 3 1 * * root apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && /sbin/shutdown -r now" > "$CRON_FILE"
    chmod 644 "$CRON_FILE"
else
    log_ok "Maintenance cron job already exists."
fi

# --- 12. Summary ---
IP_ADDR=$(hostname -I | awk '{print $1}')
echo ""
echo "------------------------------------------------"
echo -e "${GREEN}        INSTALLATION COMPLETE        ${NC}"
echo "------------------------------------------------"
echo " Storage Location: $TARGET_MOUNT (SATA)"
echo " Cache Location:   $CACHE_MOUNT (NVMe)"
echo ""
echo -e " * Jellyfin: ${YELLOW}http://$IP_ADDR:8096${NC}"
echo -e " * Sonarr:   ${YELLOW}http://$IP_ADDR:8989${NC}"
echo -e " * Radarr:   ${YELLOW}http://$IP_ADDR:7878${NC}"
echo -e " * SABnzbd:  ${YELLOW}http://$IP_ADDR:8080${NC}"
echo "------------------------------------------------"
echo -e " * Updates:  ${YELLOW}Scheduled for 1st of month @ 3:00 AM${NC}"
echo "------------------------------------------------"

# --- 13. Reboot Check ---
if [ -f /var/run/reboot-required ]; then
    echo ""
    echo -e "${YELLOW}NOTE: A system reboot is required to complete updates.${NC}"
    read -p "Do you want to reboot now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_change "Rebooting system..."
        reboot
    else
        log_ok "Reboot skipped. Please reboot manually later!"
    fi
fi
