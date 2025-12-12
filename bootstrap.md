# Initial Setup

Setup process for a new server.<br>

Direcories will be made as per previous designs, locally under the user's home directory, ie.
**SABZBD paths:**<br>
~/Downloads/complete<br>
~/Downloads/incomplete<br>

**Jellyfin paths:**<br>
~/tv<br>
~/movies

External NAS can be considered at a later date, but not necessary with a 2tb SSD and redundancy not a priority. One day, but today is not that day.

## Bootstrap Script
This is tested only for Ubuntu 24.x

- **Environment Setup:** Detects the real user running sudo and creates a dedicated media group to unify access rights across the system.
- **Package Installation:** Installs the latest stable versions of Jellyfin, SABnzbd, Sonarr, and Radarr using their official, third-party repositories.
- **Service Configuration:** automatically adds all service accounts (e.g., sonarr, jellyfin) to the media group and patches the SABnzbd service to run as a dedicated user rather than root.
- **Directory Provisioning:** Creates a standard media hierarchy (~/Downloads, ~/tv, ~/movies) directly in the user's home directory.
- **Permission Enforcement:** Applies SGID (Set Group ID) and ACLs (Access Control Lists) to these folders, ensuring all apps have permanent read/write access and that new files automatically inherit the correct group permissions.
- **Install OpenSSH:** So we're able to actually ssh onto the server
- **Add Firewall Rules:** Open necessary ports for ssh and webui access to each application

Scripts is idempotent.

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
