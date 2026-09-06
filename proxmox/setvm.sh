#!/bin/bash
set -e

#Vars
VMID=100
NEWHOSTNAME="debian-neu"

#VM Kommads
qm guest exec "$VMID" --synchronous 1 -- bash -c "
  OLD=\$(hostname)
  NEW='$NEWHOSTNAME'

  # Hostname in /etc/hosts aktualisieren
  sed -i \"s/\$OLD/\$OLD \$NEW/g\" /etc/hosts
  hostnamectl set-hostname \"\$NEW\"
  sed -i \"s/\$OLD //g\" /etc/hosts

  # Machine-ID für saubere DHCP-Vergabe erneuern
  rm -f /etc/machine-id /var/lib/dbus/machine-id
  systemd-machine-id-setup

  # SSH-Host-Keys neu generieren
  rm -f /etc/ssh/ssh_host_*
  dpkg-reconfigure openssh-server
"
