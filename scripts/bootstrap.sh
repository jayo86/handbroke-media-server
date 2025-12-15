#!/bin/bash

# --- Configuration ---
# Default fallback path if no secondary drive is found
TARGET_MOUNT="/usenet"
VG_NAME="usenet_vg"
LV_NAME="media_lv"

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./install_media_stack.sh)"
  exit 1
fi

# --- 1. Detect Real User ---
if [ $SUDO_USER ]; then
    REAL_USER=$SUDO_USER
    REAL_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
else
    echo "Error: Run via sudo from a regular user (e.g., sudo ./script.sh)."
    exit 1
fi

echo "--- Target User: $REAL_USER ---"

# --- 2. System Update & Upgrade ---
echo "--- Updating System Packages ---"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# --- 3. Install Prerequisites (Including SSH) ---
echo "--- Installing Dependencies & SSH ---"
apt-get install -y curl sqlite3 mediainfo ufw software-properties-common gnupg ca-certificates apt-transport-https acl openssh-server lvm2

# Create shared group 'media'
groupadd -f media
usermod -aG media "$REAL_USER"

# --- 4. STORAGE SETUP (Smart Detection & Wipe) ---
echo "--- Checking Storage Configuration ---"

# Check if the Volume Group already exists (Idempotency)
if vgs $VG_NAME >/dev/null 2>&1; then
    echo "Existing Volume Group '$VG_NAME' detected."
    if mount | grep -q "$TARGET_MOUNT"; then
        echo "Storage is already mounted at $TARGET_MOUNT. Skipping format."
    else
        echo "Volume exists but not mounted. Mounting now..."
        mkdir -p "$TARGET_MOUNT"
        mount "/dev/$VG_NAME/$LV_NAME" "$TARGET_MOUNT"
    fi
else
    # --- DRIVE DETECTION LOGIC ---
    echo "No existing volume group found. Scanning for secondary drives..."
    
    # Identify the Root Disk source (e.g., /dev/sda2)
    ROOT_SOURCE=$(findmnt -n -o SOURCE /)
    # Attempt to find the base disk name (e.g., sda) just for exclusion logic
    ROOT_DISK_NAME=$(lsblk -no pkname "$ROOT_SOURCE" | head -n 1)
    
    # Find a candidate disk (Type=disk, NOT the root disk parent)
    # We use grep -v to ensure we don't pick the disk hosting the OS
    CANDIDATE_DISK=$(lsblk -dno NAME,SIZE,TYPE | grep disk | grep -v "$ROOT_DISK_NAME" | head -n 1)
    
    if [ -z "$CANDIDATE_DISK" ]; then
        # --- NO SECONDARY DRIVE FOUND ---
        # Calculate Free Space on Root
        FREE_SPACE=$(df -h / --output=avail | tail -n 1 | xargs)
        
        echo "WARNING: No secondary drive found!"
        read -p "Do you want to configure video directories on $ROOT_SOURCE with total free space of $FREE_SPACE? [y/N] " -n 1 -r
        echo # move to a new line

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "ABORTING: User cancelled installation."
            exit 1
        fi

        # Ask for Custom Path
        read -p "Enter the desired path for media storage [Default: $TARGET_MOUNT]: " USER_PATH
        
        # Update TARGET_MOUNT variable. If USER_PATH is empty, keep default.
        TARGET_MOUNT=${USER_PATH:-$TARGET_MOUNT}
        
        echo "Proceeding with local storage at: $TARGET_MOUNT"

    else
        # --- SECONDARY DRIVE FOUND ---
        DISK_NAME=$(echo "$CANDIDATE_DISK" | awk '{print $1}')
        DISK_SIZE=$(echo "$CANDIDATE_DISK" | awk '{print $2}')
        DISK_PATH="/dev/$DISK_NAME"

        echo "----------------------------------------------------"
        echo "FOUND SECONDARY DRIVE: $DISK_PATH (Size: $DISK_SIZE)"
        echo "----------------------------------------------------"
        echo "WARNING: This drive appears to be: $DISK_PATH"
        echo "If this drive has an old OS (Ubuntu/Windows), this step will"
        echo "completely remove all boot partitions, EFI, and data."
        echo "----------------------------------------------------"
        read -p "Do you want to WIPE and FORMAT $DISK_PATH for $TARGET_MOUNT? [y/N] " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "--- Cleaning drive (The 'Nuke' Step) ---"
            # 1. Wipe all filesystem signatures and partition tables
            # This ensures no old Ubuntu boot partitions remain to confuse LVM
            wipefs -a -f "$DISK_PATH"
            
            # Sleep to let the kernel update device list
            sleep 2
            
            echo "--- Formatting Drive (LVM) ---"
            # 2. Initialize Physical Volume (Force just in case)
            pvcreate -y -ff "$DISK_PATH"
            
            # 3. Create Volume Group
            vgcreate "$VG_NAME" "$DISK_PATH"
            
            # 4. Create Logical Volume (Uses 100% of space)
            # The -y flag answers "yes" to any signature warnings
            lvcreate -y -l 100%FREE -n "$LV_NAME" "$VG_NAME"
            
            # 5. Format to ext4
            mkfs.ext4 "/dev/$VG_NAME/$LV_NAME"
            
            # 6. Mount and Persist
            mkdir -p "$TARGET_MOUNT"
            mount "/dev/$VG_NAME/$LV_NAME" "$TARGET_MOUNT"
            
            if ! grep -qs "$TARGET_MOUNT" /etc/fstab; then
                echo "/dev/$VG_NAME/$LV_NAME $TARGET_MOUNT ext4 defaults 0 0" >> /etc/fstab
            fi
            echo "Storage setup complete!"
        else
            echo "Skipping drive formatting. Aborting to be safe."
            exit 1
        fi
    fi
fi

# --- 5. Install Jellyfin ---
echo "--- Installing Jellyfin ---"
curl https://repo.jellyfin.org/install-debuntu.sh | bash
usermod -aG media jellyfin

# --- 6. Install SABnzbd ---
echo "--- Installing SABnzbd ---"
add-apt-repository -y ppa:jcfp/nobetas
add-apt-repository -y ppa:jcfp/sab-addons
apt-get update -qq
apt-get install -y sabnzbdplus python3-sabyenc par2-tbb

if [ -f /etc/default/sabnzbdplus ]; then
    sed -i 's/^USER=.*/USER=sabnzbd/' /etc/default/sabnzbdplus
    sed -i 's/^HOST=.*/HOST=0.0.0.0/' /etc/default/sabnzbdplus
    sed -i 's/^PORT=.*/PORT=8080/' /etc/default/sabnzbdplus
fi
usermod -aG media sabnzbd
systemctl restart sabnzbdplus

# --- 7. Install Sonarr ---
echo "--- Installing Sonarr ---"
curl -o install-sonarr.sh https://raw.githubusercontent.com/Sonarr/Sonarr/develop/distribution/debian/install.sh
chmod +x install-sonarr.sh
bash install-sonarr.sh
rm install-sonarr.sh
usermod -aG media sonarr

# --- 8. Install Radarr ---
echo "--- Installing Radarr ---"
if ! id -u radarr &>/dev/null; then
    useradd -r -s /usr/sbin/nologin -g media -m -d /var/lib/radarr radarr
else
    usermod -aG media radarr
fi

if [ ! -d "/opt/Radarr" ]; then
    echo "Downloading Radarr..."
    wget --content-disposition 'http://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64' -O Radarr.tar.gz
    echo "Extracting..."
    tar -xzf Radarr.tar.gz -C /opt/
    rm Radarr.tar.gz
fi

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

# --- 9. Directories & Permissions ---
# Note: Uses $TARGET_MOUNT which might have been changed by user in Step 4
echo "--- Configuring Directories in $TARGET_MOUNT ---"

mkdir -p "$TARGET_MOUNT"
mkdir -p "$TARGET_MOUNT/Downloads/complete"
mkdir -p "$TARGET_MOUNT/Downloads/incomplete"
mkdir -p "$TARGET_MOUNT/tv"
mkdir -p "$TARGET_MOUNT/movies"

echo "Setting permissions..."
chown -R "$REAL_USER:media" "$TARGET_MOUNT"
chmod -R 775 "$TARGET_MOUNT"
chmod -R g+s "$TARGET_MOUNT"
setfacl -R -m g:media:rwx "$TARGET_MOUNT"
setfacl -d -R -m g:media:rwx "$TARGET_MOUNT"

# --- 10. Firewall ---
echo "--- Configuring UFW ---"
ufw allow 22/tcp   # SSH
ufw allow 8080/tcp # SABnzbd
ufw allow 8096/tcp # Jellyfin
ufw allow 8989/tcp # Sonarr
ufw allow 7878/tcp # Radarr
ufw --force enable

# --- 11. Done ---
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "------------------------------------------------"
echo "INSTALLATION COMPLETE"
echo "------------------------------------------------"
echo "Storage Location: $TARGET_MOUNT"
if mount | grep -q "$TARGET_MOUNT"; then
    echo "Status: MOUNTED (LVM Configured)"
else
    echo "Status: Using Local Storage (Not Mounted)"
fi
echo ""
echo "Access your applications here:"
echo " * Jellyfin: http://$IP_ADDR:8096"
echo " * Sonarr:   http://$IP_ADDR:8989"
echo " * Radarr:   http://$IP_ADDR:7878"
echo " * SABnzbd:  http://$IP_ADDR:8080"
echo "------------------------------------------------"
