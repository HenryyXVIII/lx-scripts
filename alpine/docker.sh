#!/bin/sh

## Autor: HenryyXVIII

#run check
set -Eeuo pipefail

#scipt help
show_help() {
cat <<EOF
Verwendung:
  $(basename "$0") [OPTIONEN]

Optionen:

  -e, --extra             Install extra usefull packages like btop, fastfetch curl and nano
  -h, --help              show help
  -u, --user              add user to docker group

Beispiel:
  $(basename "$0") -e
EOF
}

#log funktion
log() {
    echo "[$(date '+%F %T')] $*" >> "$LOGFILE"
}

source /etc/os-release

#VARS
DATE=$(date '+%F_%H-%M-%S')
LOGFILE="/var/log/installdocker-${DATE}.log"
EXTRA="false"
USER=""
ALPINE_VERSION=VERSION_ID

# test if runn as root #
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    log "script was not run by root, exiting"
    exit 1
fi

while [[ $# -gt 0 ]]; do
   case "$1" in
      -e|--extra)
         EXTRA="true"
         shift
         ;;
       -h|--help)
         show_help
         exit 0
         ;;
       -u|--user)
         USER="$2"
         shift 2
         ;;
       *)
         echo "Unknown option: $1"
         exit 1
         ;;
         esac
done













log "OS detektion"
log "detect $NAME"

#is system Alpine?
if [ ! "$ID" = "alpine" ]; then
    log "This script is designed for Alpine Linux only"
    exit 1
fi

log "Install for $ID"
log "enable repositories"
ALPINEV==$($VERSION_ID | cut -d. -f1)
COMMUNITY_REPO=grep 'http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}*/community' /etc/apk/repositories



if [-z COMMUNITY-REPO]; then

    log "adding community repository"
    echo "http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community" >> /etc/apk/repositories

elif $(COMMUNITY-REPO | grep -q '^#'); then
    log "enabling community repository"
    sed -i 's/^#\(http.*community\)/\1/' /etc/apk/repositories

else


fi




log "install docker"

apk update
apk add docker docker-compose

if [ "$EXTRA" = "true" ]; then
    log "install extra packages"
    apk add btop fastfetch curl wget nano
fi


log "add user to docker group"

addgroup $USER docker
#extra users to add?
if [ -n "$USER" ]; then
    log "adding user $USER to docker group"
    adduser "$USER" docker
fi

log "enable docker service"

rc-update add docker boot
service docker start
service docker status

log "Docker installation completed successfully"