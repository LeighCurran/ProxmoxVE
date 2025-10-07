#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Leigh Curran
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://ironmansoftware.com/

# Import Functions and Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Installing Dependencies
msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  wget \
  unzip \
  apt-transport-https \
  software-properties-common
msg_ok "Installed Dependencies"

# Install PowerShell
msg_info "Installing PowerShell"
source /etc/os-release
wget -q "https://packages.microsoft.com/config/debian/$VERSION_ID/packages-microsoft-prod.deb"
$STD dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
$STD apt-get update
$STD apt-get install -y powershell
msg_ok "Installed PowerShell"

# Get Latest PowerShell Universal Version
msg_info "Getting Latest Version"
RELEASE=$(curl -fsSL https://ironmansoftware.com/release/powershell-universal | grep -oP '(?<=<td>)[0-9]+\.[0-9]+\.[0-9]+(?=</td>)' | head -1)
msg_ok "Version: ${RELEASE}"

# Download and Install PowerShell Universal
msg_info "Installing PowerShell Universal v${RELEASE}"
cd /tmp || exit
wget -q "https://imsreleases.blob.core.windows.net/universal/production/${RELEASE}/Universal.linux-x64.${RELEASE}.zip"
mkdir -p /opt/psuniversal
unzip -o -qq "Universal.linux-x64.${RELEASE}.zip" -d /opt/psuniversal
chmod +x /opt/psuniversal/Universal.Server
echo "${RELEASE}" >/opt/psuniversal_version.txt
msg_ok "Installed PowerShell Universal v${RELEASE}"

# Create Service User
msg_info "Creating Service User"
useradd -r -s /bin/bash -d /home/psuniversal -m psuniversal
chown -R psuniversal:psuniversal /opt/psuniversal
msg_ok "Created Service User"

# Creating Service
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
SyslogIdentifier=psuniversal
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q --now psuniversal
msg_ok "Created Service"

# Create Credentials File
msg_info "Storing Credentials"
{
  echo "PowerShell Universal Credentials"
  echo ""
  echo "Web Interface: http://${IP}:5000"
  echo "Username: admin"
  echo "Password: admin"
  echo ""
  echo "NOTE: Please change the default password after first login!"
} >>~/powershell-universal.creds
msg_ok "Stored Credentials"

motd_ssh
customize

# Cleanup
msg_info "Cleaning up"
rm -f /tmp/Universal.linux-x64."${RELEASE}".zip
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
