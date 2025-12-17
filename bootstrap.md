# Initial Setup

Setup process for a new server.<br>

## Storage info
### M.2 NVME
**SABZBD paths:**<br>
/usenet_nvme_cache/complete<br>
/usenet_nvme_cache/incomplete<br>

### 2tb Sata SSD
**Jellyfin/Sonarr/Radarr paths:**<br>
/usenet/tv<br>
/usenet/movies

ℹ️ If no 2nd drive detected, it will prompt if you want to continue and if yes, will then prompt you where you want to the folders.

## Bootstrap Script
This is tested only for Ubuntu 24.x
- Verifies root access and identifies the target user.
- Updates and upgrades all system packages to latest versions.
- Installs dependencies and increases system file watcher limits.
- Auto-detects, wipes, formats, and mounts the storage drive.
- Installs OpenSSH
- Installs the Jellyfin media server application.
- Installs SABnzbd and force-creates its system user.
- Installs Sonarr using the official installer script.
- Downloads Radarr, creates user, and configures system service.
- Creates folder structure and enforces group permissions.
- Enables firewall and opens ports for all applications.
- Add monthly cronjob (1st of every month at 3am) to update packages and reboots
- Checks if kernel updates require a system reboot.

Script is idempotent.

### Steps
1. Install git, clone repo, update perms to be able to run
    ```bash
    sudo apt update
    sudo apt install git -y
    mkdir ~/repos
    cd ~/repos
    git clone https://github.com/jayo86/handbroke-media-server.git
    cd scripts
    sudo chmod +x bootstrap.sh
    ```
2. Run
    ```bash
    sudo ./bootstrap.sh
    ```
## Manual Config
Log into each app's UI to:
- Jellyfin
    - Create User
    - Set libraries and folder paths
    - Install additional plugins (optional)
- SABZBD
    - Configure provider
    - Set CHMOD 777 for newly downloaded files (important)
    - Set folder paths for complete/incomplete, ie. `/usenet_nvme_cache/complete`,`/usenet_nvme_cache/incomplete`
- Sonarr & Radarr
    - Add download client (SABNZBD)
    - Add Indexer (GeekNZB)
    - set paths, ie. `/usenet/tv`,`/usenet/movies`
- Twingate
    - Setup from website and follow install instructions


## Testing
Other than the usual things (ensure things download, to the right folders, detected by Jellyfin, videos play), reboot the server and then test things again.
