#!/bin/bash

set -Eeuo pipefail
sudo -n true
test $? -eq 0 || {
    echo "you should have sudo privilege to run this script"
    exit 1
}

apt update && apt install -y fastfetch btop nano wget curl neofetch ufw

#INSTALLED=$(apt list --installed | grep -e 'fastfetch' -e 'neofetch' | awk '{print $1}' | awk -F/ '{print $1}' 2> /dev/null)
WICHFETCH=$(dpkg -l | awk '$1 == "ii" && ($2 == "fastfetch" || $2 == "neofetch") {print $2}')

if [ $($WICHFETCH | wc -l) -gt 1 ]; then
    WICHFETCH=fastfetch

fi

echo "$WICHFETCH" >> /etc/update-motd.d/10-uname
echo "ufw status" >> /etc/update-motd.d/10-uname
