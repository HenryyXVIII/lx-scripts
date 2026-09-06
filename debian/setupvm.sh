#!/bin/bash


show_help() {
cat <<EOF
Verwendung:
  -n, --hostname          Neuer Hostname
  -h, --help              Diese Hilfe anzeigen
EOF
}

log() {
    echo "=> [$(date '+%F %T')] $*"
}

OLDHOSTNAME=$HOSTNAME
NEWHOSTNAME

set -Eeuo pipefail
sudo -n true
test $? -eq 0 || {
    echo "you should have sudo privilege to run this script"
    exit 1
}

while [[ $# -gt 0 ]]; do
   case "$1" in
      -n|--hostname)
         NEWHOSTNAME="$2"
         shift 2
         ;;
       -h|--help)
         show_help
         exit 0
         ;;
       *)
         echo "Unknown option: $1"
         exit 1
         ;;
         esac
done

log "start"

sed -i 's/$OLDHOSTNAME/$NEWHOSTNAME/g' /etc/hosts
hostnamectl set-hostname $NEWHOSTNAME
sed -i 's/bookworm //g' /etc/hosts

rm -f /etc/machine-id /var/lib/dbus/machine-id
systemd-machine-id-setup

rm -f /etc/ssh/ssh_host_*

