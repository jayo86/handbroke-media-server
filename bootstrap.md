# Initial Setup

Setup process for a new server.<br>

If a 2nd drive's detected, directories will be.
**SABZBD paths:**<br>
usenet/Downloads/complete<br>
usenet/Downloads/incomplete<br>

**Jellyfin paths:**<br>
usenet/tv<br>
usenet/movies

If no 2nd drive detected, it will prompt if you want to continue and if yes, will then prompt you where you want to the folders.

External NAS can be considered at a later date, but not necessary with a 2tb SSD and redundancy not a priority. One day, but today is not that day.

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
- Checks if kernel updates require a system reboot.

Script is idempotent.

### Steps
1. Copy [bootstrap.sh](scripts/bootstrap.sh) to server
2. Apply perms to the script so it can run
    ```
    sudo chmod +x bootstrap.sh
    ```
3. Run
    ```
    sudo ./bootstrap.sh
    ```
## Manual Config
Log into each app's UI to:
- Jellyfin
    - Create User
    - Set libraries and folder paths
    - Install additional plugins (optional)
- SABZBD
    - Configure indexer
    - Set CHMOD 777 for newly downloaded files (important)
    - Set folder paths
- Sonarr & Radarr
    - Add download client (SABNZBD)
    - Add Indexer (GeekNZB)
 
  ..probably other things I haven't thought of right now, but thats fundamental stuff. Maybe script all this one day

  ## Testing
  Other than the usual things (ensure things download, to the right folders, detected by Jellyfin, videos play), reboot the server and then test things again.
