#!/bin/bash

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

echo "--- Target: $REAL_USER ($REAL_HOME) ---"

# --- 2. System Update & Upgrade (Best Practice) ---
echo "--- Updating System Packages ---"
# Update package lists
apt-get update -qq
# Upgrade installed packages (non-interactive)
# DEBIAN_FRONTEND=noninteractive prevents popups asking about config files
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# --- 3. Install Prerequisites ---
echo "--- Installing Dependencies ---"
# sqlite3 and mediainfo are required for Radarr/Sonarr
apt-get install -y curl sqlite3 mediainfo ufw software-properties-common gnupg ca-certificates apt-transport-https

# Create shared group 'media'
groupadd -f media
usermod -aG media "$REAL_USER"

# --- 4. Install Jellyfin (Official Script) ---
echo "--- Installing Jellyfin ---"
curl https://repo.jellyfin.org/install-debuntu.sh | bash
usermod -aG media jellyfin

# --- 5. Install SABnzbd (Official PPA) ---
echo "--- Installing SABnzbd ---"
add-apt-repository -y ppa:jcfp/nobetas
add-apt-repository -y ppa:jcfp/sab-addons
apt-get update -qq
apt-get install -y sabnzbdplus python3-sabyenc par2-tbb

# Configure SABnzbd user
if [ -f /etc/default/sabnzbdplus ]; then
    sed -i 's/^USER=.*/USER=sabnzbd/' /etc/default/sabnzbdplus
    sed -i 's/^HOST=.*/HOST=0.0.0.0/' /etc/default/sabnzbdplus
    sed -i 's/^PORT=.*/PORT=8080/' /etc/default/sabnzbdplus
fi
usermod -aG media sabnzbd
systemctl restart sabnzbdplus

# --- 6. Install Sonarr (Official Install Script) ---
# Source: https://sonarr.tv/ (Linux section)
echo "--- Installing Sonarr ---"
curl -o install-sonarr.sh https://raw.githubusercontent.com/Sonarr/Sonarr/develop/distribution/debian/install.sh
chmod +x install-sonarr.sh
# Run the installer.
bash install-sonarr.sh
# Cleanup
rm install-sonarr.sh
# Ensure sonarr user is in media group
usermod -aG media sonarr

# --- 7. Install Radarr (Official "Manual" Method) ---
# Source: https://wiki.servarr.com/radarr/installation/linux
echo "--- Installing Radarr ---"

# 7a. Create Radarr user
if ! id -u radarr &>/dev/null; then
    useradd -r -s /usr/sbin/nologin -g media -m -d /var/lib/radarr radarr
else
    usermod -aG media radarr
fi

# 7b. Download and Install
echo "Downloading Radarr..."
# Only download if directory doesn't exist to prevent overwriting/errors if run twice
if [ ! -d "/opt/Radarr" ]; then
    wget --content-disposition 'http://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64' -O Radarr.tar.gz
    echo "Extracting to /opt/Radarr..."
    tar -xzf Radarr.tar.gz -C /opt/
    rm Radarr.tar.gz
fi

# Fix permissions so 'radarr' user owns the files
chown -R radarr:media /opt/Radarr
chmod -R 775 /opt/Radarr

# 7c. Create Systemd Service
echo "Creating Radarr Service..."
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

# 7d. Start Radarr
systemctl daemon-reload
systemctl enable --now radarr

# --- 8. Directories & Permissions ---
echo "--- Configuring Directories ---"
mkdir -p "$REAL_HOME/Downloads/complete"
mkdir -p "$REAL_HOME/Downloads/incomplete"
mkdir -p "$REAL_HOME/tv"
mkdir -p "$REAL_HOME/movies"

# Apply permissions (Owner: User, Group: Media, 775)
chown -R "$REAL_USER:media" "$REAL_HOME/Downloads" "$REAL_HOME/tv" "$REAL_HOME/movies"
chmod -R 775 "$REAL_HOME/Downloads" "$REAL_HOME/tv" "$REAL_HOME/movies"
# Set SGID (New files inherit 'media' group)
chmod -R g+s "$REAL_HOME/Downloads" "$REAL_HOME/tv" "$REAL_HOME/movies"

# ACLs: Ensure 'media' group always has write access
setfacl -R -m g:media:rwx "$REAL_HOME/Downloads" "$REAL_HOME/tv" "$REAL_HOME/movies"
setfacl -d -R -m g:media:rwx "$REAL_HOME/Downloads" "$REAL_HOME/tv" "$REAL_HOME/movies"

# --- 9. Firewall ---
echo "--- Configuring UFW ---"
ufw allow 22/tcp
ufw allow 8080/tcp # SABnzbd
ufw allow 8096/tcp # Jellyfin
ufw allow 8989/tcp # Sonarr
ufw allow 7878/tcp # Radarr
ufw --force enable

echo "Done! Access your apps at:"
echo "Jellyfin: http://$(hostname -I | awk '{print $1}'):8096"
echo "Sonarr:   http://$(hostname -I | awk '{print $1}'):8989"
echo "Radarr:   http://$(hostname -I | awk '{print $1}'):7878"
echo "SABnzbd:  http://$(hostname -I | awk '{print $1}'):8080"
