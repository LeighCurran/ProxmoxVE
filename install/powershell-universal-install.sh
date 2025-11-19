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
  acl
msg_ok "Installed Dependencies"

# Install PowerShell
# These are used to derive the download URL
PSU_VERSION="5.6.10" # Change this to the current version
PSU_ARCH="x64" # Change this to your desired architecture
PSU_FILE="Universal.linux-${PSU_ARCH}.${PSU_VERSION}.zip"
PSU_URL="https://imsreleases.blob.core.windows.net/universal/production/${PSU_VERSION}/${PSU_FILE}"

# These are used for installing PowerShell Universal
# If you'd like to use a different path, change this
PSU_PATH="/opt/psuniversal"
PSU_EXEC="${PSU_PATH}/Universal.Server"

# These are for installing it as a service
PSU_SERVICE="psuniversal"
PSU_USER="psuniversal"

#msg_info "Creating $PSU_PATH and granting access to $USER"
#mkdir $PSU_PATH
#setfacl -m "u:${USER}:rwx" $PSU_PATH
#msg_ok "Created $PSU_PATH"

msg_info "Creating user $PSU_USER and making it the owner of $PSU_PATH"
useradd $PSU_USER -m
chown $PSU_USER -R $PSU_PATH
msg_ok "Created user $PSU_USER"

msg_info "Downloading PowerShell Universal $PSU_VERSION ($PSU_ARCH)"
wget -q $PSU_URL -O $PSU_FILE
msg_ok "PowerShell Universal $PSU_VERSION downloaded"

msg_info "Extracting $PSU_FILE to $PSU_PATH"
unzip -o -q $PSU_FILE -d $PSU_PATH

msg_info "Make $PSU_EXEC executable"
chmod +x $PSU_EXEC

msg_info "Creating service configuration"
cat <<EOF > /etc/systemd/system/$PSU_SERVICE.service
[Unit]
Description=PowerShell Universal

[Service]
ExecStart=$PSU_EXEC
SyslogIdentifier=psuniversal
User=$PSU_USER
Restart=always
RestartSec=5
WorkingDirectory=$PSU_PATH

[Install]
WantedBy=multi-user.target
EOF

msg_info  "Creating and starting service"
cp -f ~/$PSU_SERVICE.service /etc/systemd/system
systemctl daemon-reload
systemctl enable -q --now $PSU_SERVICE
#systemctl status $PSU_SERVICE --no-pager

# If you don't use UFW, you can comment this out
#msg_info  "Allow port 5000/tcp"
#ufw allow 5000/tcp

# Create Credentials File
#msg_info "Storing Credentials"
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
rm -f $PSU_FILE
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
