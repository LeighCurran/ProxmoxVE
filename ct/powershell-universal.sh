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
  
  # Crawling the new version and checking whether an update is required
  #RELEASE=$(curl -fsSL [RELEASE_URL] | [PARSE_RELEASE_COMMAND])
  #if [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then

  RELEASE="5.6.10"

  #PSU_VERSION="5.6.10" # Change this to the current version

  # Check if update is needed
  if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
    msg_info "Updating ${APP} to v${RELEASE}"
    
    # Stop the service
    msg_info "Stopping $APP"
    systemctl stop psuniversal &>/dev/null
    msg_ok "Stopped $APP"
    
    # Backup configuration and data
    msg_info "Backing up configuration"
    mkdir -p /tmp/psu-backup
    cp -r /opt/psuniversal/*.config /tmp/psu-backup/ 2>/dev/null || true
    cp -r /opt/psuniversal/appsettings.json /tmp/psu-backup/ 2>/dev/null || true
    msg_ok "Configuration backed up"
    
    # Download new version
    PSU_ARCH="x64" # Change this to your desired architecture
    PSU_FILE="Universal.linux-${PSU_ARCH}.${RELEASE}.zip"
    PSU_URL="https://imsreleases.blob.core.windows.net/universal/production/${RELEASE}/${PSU_FILE}"
    
    msg_info "Downloading ${APP} v${RELEASE}"
    wget -q "$PSU_URL" -O /tmp/"$PSU_FILE"
    msg_ok "Downloaded ${APP}"

    # Remove old installation but preserve data
    msg_info "Removing old installation"
    rm -rf /opt/psuniversal/*
    msg_ok "Removed old installation"
    
    # Extract new version
    msg_info "Extracting new version"
    unzip -o -qq /tmp/"$PSU_FILE" -d /opt/psuniversal
    msg_ok "Extracted ${APP}"
    
    # Restore configuration
    msg_info "Restoring configuration"
    cp -r /tmp/psu-backup/* /opt/psuniversal/ 2>/dev/null || true
    msg_ok "Configuration restored"
    
    # Set permissions
    msg_info "Setting Permissions"
    chmod +x /opt/psuniversal/Universal.Server
    chown -R psuniversal:psuniversal /opt/psuniversal
    msg_ok "Permissions set"

    # Start service
    msg_info "Starting $APP"
    systemctl start psuniversal &>/dev/null
    msg_ok "Started $APP"

    # Cleanup
    msg_info "Cleaning Up"
    rm -rf /tmp/"$PSU_FILE"
    rm -rf /tmp/psu-backup
    msg_ok "Cleanup Completed"
    
    # Save version
    echo "${RELEASE}" > /opt/${APP}_version.txt 
    msg_ok "Updated ${APP} to v${RELEASE}"
    msg_ok "Update Successful"
  else
    msg_ok "No update required. ${APP} is already at v${RELEASE}"
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
