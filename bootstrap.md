# Initial Setup

Setup process for a new server.

## Bootstrap Script

- **Environment Setup:** Detects the real user running sudo and creates a dedicated media group to unify access rights across the system.
- **Package Installation:** Installs the latest stable versions of Jellyfin, SABnzbd, Sonarr, and Radarr using their official, third-party repositories.
- **Service Configuration:** automatically adds all service accounts (e.g., sonarr, jellyfin) to the media group and patches the SABnzbd service to run as a dedicated user rather than root.
- **Directory Provisioning:** Creates a standard media hierarchy (~/Downloads, ~/tv, ~/movies) directly in the user's home directory.
- **Permission Enforcement:** Applies SGID (Set Group ID) and ACLs (Access Control Lists) to these folders, ensuring all apps have permanent read/write access and that new files automatically inherit the correct group permissions.
- **Install OpenSSH:** So we're able to actually ssh onto the server
- **Add Firewall Rules:** Open necessary ports for ssh and webui access to each application

### Steps
1. Copy [bootstrap.sh](scripts/bootstrap.sh) to server
2. Apply perms to the script so it can run
    ```
    sudo chmod +x bootstrap.sh
    ```
3. Run
    ```
    sudo ./install_media_stack.sh
    ```
## Manual Config
Log into each app's UI to:
- Jellyfin
    - Create User
    - Set libraries
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
