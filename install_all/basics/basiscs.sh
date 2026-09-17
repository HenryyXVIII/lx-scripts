#!/bin/bash

set -Eeuo pipefail
sudo -n true
test $? -eq 0 || {
    echo "you should have sudo privilege to run this script"
    exit 1
}

apt update && apt install -y bat eza btop nano wget curl ufw fastfetch

#INSTALLED=$(apt list --installed | grep -e 'fastfetch' -e 'neofetch' | awk '{print $1}' | awk -F/ '{print $1}' 2> /dev/null)
#WICHFETCH=$(dpkg -l | awk '$1 == "ii" && ($2 == "fastfetch" || $2 == "neofetch") {print $2}')

#if [ $($WICHFETCH | wc -l) -gt 1 ]; then
#    WICHFETCH=fastfetch
#
#fi
if ! grep -q 'fastfetch' /etc/update-motd.d/10-uname; then
    echo 'fastfetch' >> /etc/update-motd.d/10-uname
fi

if ! grep -q 'ufw status' /etc/update-motd.d/10-uname; then
    echo 'ufw status' >> /etc/update-motd.d/10-uname
fi
