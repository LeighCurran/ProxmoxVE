#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/LeighCurran/ProxmoxVE/refs/heads/Add-Powershell-Universal/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Leigh Curran
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://powershelluniversal.com/



header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  # Check if installation is present
  if [[ ! -f /opt/psuniversal/Universal.Server ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # Crawling the new version and checking whether an update is required
  RELEASE=$(curl -fsSL https://ironmansoftware.com/release/powershell-universal | grep -oP '(?<=<td>)[0-9]+\.[0-9]+\.[0-9]+(?=</td>)' | head -1)
  if [[ "${RELEASE}" != "$(cat /opt/"${APP}"_version.txt)" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
    # Stopping Services
    msg_info "Stopping $APP"
    systemctl stop psuniversal
    msg_ok "Stopped $APP"

    # Creating Backup
    msg_info "Creating Backup"
    BACKUP_DATE=$(date +%Y%m%d)
    tar -czf "/opt/${APP}_backup_${BACKUP_DATE}.tar.gz" -C /home/psuniversal/.PowerShellUniversal --exclude='Repository' .
    msg_ok "Backup Created"

    # Execute Update
    msg_info "Updating $APP to v${RELEASE}"
    cd /tmp || exit
    wget -q "https://imsreleases.blob.core.windows.net/universal/production/${RELEASE}/Universal.linux-x64.${RELEASE}.zip"
    rm -rf /opt/psuniversal/*
    unzip -o -qq "Universal.linux-x64.${RELEASE}.zip" -d /opt/psuniversal
    chmod +x /opt/psuniversal/Universal.Server
    chown -R psuniversal:psuniversal /opt/psuniversal
    msg_ok "Updated $APP to v${RELEASE}"

    # Starting Services
    msg_info "Starting $APP"
    systemctl start psuniversal
    msg_ok "Started $APP"

    # Cleaning up
    msg_info "Cleaning Up"
    rm -f "/tmp/Universal.linux-x64.${RELEASE}.zip"
    msg_ok "Cleanup Completed"

    # Last Action
    echo "${RELEASE}" >/opt/"${APP}"_version.txt
    msg_ok "Update Successful"
  else
    msg_ok "No update required. ${APP} is already at v${RELEASE}"
  fi
  exit
}

start
build_container
description

# Install Dependencies
msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y wget
$STD apt-get install -y unzip
msg_ok "Installed Dependencies"

# Install PowerShell
msg_info "Installing PowerShell"
$STD apt-get install -y apt-transport-https software-properties-common
source /etc/os-release
wget -q https://packages.microsoft.com/config/debian/"$VERSION_ID"/packages-microsoft-prod.deb
$STD dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
$STD apt-get update
$STD apt-get install -y powershell
msg_ok "Installed PowerShell"

# Get Latest Version
msg_info "Getting Latest Version"
RELEASE=$(curl -fsSL https://ironmansoftware.com/release/powershell-universal | grep -oP '(?<=<td>)[0-9]+\.[0-9]+\.[0-9]+(?=</td>)' | head -1)
msg_ok "Version: ${RELEASE}"

# Install PowerShell Universal
msg_info "Installing $APP v${RELEASE}"
cd /tmp || exit
wget -q "https://imsreleases.blob.core.windows.net/universal/production/${RELEASE}/Universal.linux-x64.${RELEASE}.zip"
mkdir -p /opt/psuniversal
unzip -o -qq "Universal.linux-x64.${RELEASE}.zip" -d /opt/psuniversal
chmod +x /opt/psuniversal/Universal.Server
rm -f "Universal.linux-x64.${RELEASE}.zip"
echo "${RELEASE}" >/opt/"${APP}"_version.txt
msg_ok "Installed $APP v${RELEASE}"

# Create Service User
msg_info "Creating Service User"
useradd -r -s /bin/bash -d /home/psuniversal -m psuniversal
chown -R psuniversal:psuniversal /opt/psuniversal
msg_ok "Created Service User"

# Create Systemd Service
msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/psuniversal.service
[Unit]
Description=PowerShell Universal
After=network.target

[Service]
Type=simple
User=psuniversal
WorkingDirectory=/opt/psuniversal
ExecStart=/opt/psuniversal/Universal.Server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now psuniversal
msg_ok "Created Service"

motd_ssh
customize

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:5000${CL}"
echo -e "${INFO}${YW} Default credentials:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Username: admin${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Password: admin${CL}"




#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Leigh Curran
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://ironmansoftware.com/

source <(curl -s https://raw.githubusercontent.com/LeighCurran/ProxmoxVE/main/misc/build.func)
# For community-scripts repo, use:
# source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# App Default Values
APP="Powershell-Universal"
var_tags="${var_tags:-automation;powershell}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  
  # Check if PowerShell Universal is installed
  if [[ ! -d /opt/psuniversal ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  
  PSU_VERSION="5.6.10" # Change this to the current version

  # Check if update is needed
  if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${PSU_VERSION}" != "$(cat /opt/${APP}_version.txt)" ]]; then
    msg_info "Updating ${APP} to v${PSU_VERSION}"
    
    # Stop the service
    systemctl stop psuniversal &>/dev/null
    
    # Backup configuration and data
    msg_info "Backing up configuration"
    mkdir -p /tmp/psu-backup
    cp -r /opt/psuniversal/*.config /tmp/psu-backup/ 2>/dev/null || true
    cp -r /opt/psuniversal/appsettings.json /tmp/psu-backup/ 2>/dev/null || true
    
    # Download new version
    PSU_ARCH="x64" # Change this to your desired architecture
    PSU_FILE="Universal.linux-${PSU_ARCH}.${PSU_VERSION}.zip"
    PSU_URL="https://imsreleases.blob.core.windows.net/universal/production/${PSU_VERSION}/${PSU_FILE}"
    
    msg_info "Downloading PowerShell Universal v${PSU_VERSION}"
    wget -q "$PSU_URL" -O /tmp/"$PSU_FILE"
    
    # Remove old installation but preserve data
    msg_info "Removing old installation"
    rm -rf /opt/psuniversal/*
    
    # Extract new version
    msg_info "Extracting new version"
    unzip -o -qq /tmp/"$PSU_FILE" -d /opt/psuniversal
    
    # Restore configuration
    msg_info "Restoring configuration"
    cp -r /tmp/psu-backup/* /opt/psuniversal/ 2>/dev/null || true
    
    # Set permissions
    chmod +x /opt/psuniversal/Universal.Server
    chown -R psuniversal:psuniversal /opt/psuniversal
    
    # Start service
    systemctl start psuniversal &>/dev/null
    
    # Cleanup
    rm -rf /tmp/"$PSU_FILE"
    rm -rf /tmp/psu-backup
    
    # Save version
    echo "${PSU_VERSION}" > /opt/${APP}_version.txt
    
    msg_ok "Updated ${APP} to v${RELEASE}"
  else
    msg_ok "No update required. ${APP} is already at v${PSU_VERSION}"
  fi
  
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:5000${CL}"
echo -e "${INFO}${YW} Default credentials:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Username: admin${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Password: admin${CL}"
