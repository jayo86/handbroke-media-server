# Updating Sonarr and Radarr
*arr applications don't update when running usual OS patching like Jellyfin and SABNZBD.

## Script
The scripts do the following:<br>

- **Environment & Prerequisite Checks:** Validates that necessary tools (curl, jq, wget) are present and automatically detects the active Radarr systemd service, installation path, and user permissions.
- **Intelligent Version Comparison:** Queries the local Radarr API and the GitHub Releases API to compare versions, proceeding only if a newer version is available (idempotency).
- **Safety & Backup:** Automatically stops the Radarr service and creates a timestamped backup of the current installation directory before applying any changes to ensure a safe rollback path.
- **Asset Retrieval & Installation:** Fetches the latest Linux (x64) release url, downloads the archive to a temporary location, and overwrites the existing binary files with the new version.
- **Service Restoration:** Reapplies the correct user/group ownership permissions to the installation directory and restarts the Radarr service to bring the application back online.

Scripts are idempotent.

### Steps
Add the following to the server and run when update's are available

[radarr_update.sh](scripts/radarr_update.sh)<br>
[sonarr_update.sh](scripts/sonarr_update.sh)
