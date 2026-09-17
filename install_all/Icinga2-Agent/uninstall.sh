#!/bin/bash

## Autor


# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0;37m' # No Color

set -Eeuo pipefail

############
# LOG-FILE #
############
LOGFILE="/var/log/icinga2_uninstall.log"

log() {
    echo -e "=> [$(date '+%F %T')] $*" | tee -a "$LOGFILE"
}

# Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

PACKAGES=("icinga2" "icinga2-bin" "icinga2-common" "monitoring-plugins")

# 1. Stop the service safely
log "${YELLOW}Stopping Icinga2 service...${NC}"
systemctl stop icinga2 2>/dev/null || true

# 2. Remove packages completely (including configs)
remove_pkg () {
    log "${YELLOW}Starting package removal...${NC}"
    for pkg in "${PACKAGES[@]}"; do
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            log "${GREEN}Paket '$pkg' is installed, purging it...${NC}"
            apt-get purge -y "$pkg"
            log "${GREEN}Package $pkg purged.${NC}"
        else
            log "${YELLOW}Package $pkg is not installed. Skipping.${NC}"
        fi
    done
    
    log "${YELLOW}Running autoremove to clean up dependencies...${NC}"
    apt-get autoremove -y
}

# 3. Force delete leftover directories
delet_file () {
    log "${YELLOW}Deleting leftover configuration and data directories...${NC}"
    rm -rf /etc/icinga2
    log "${GREEN}Removed /etc/icinga2${NC}"
    rm -rf /var/lib/icinga2
    log "${GREEN}Removed /var/lib/icinga2${NC}"
    rm -rf /var/log/icinga2
    log "${GREEN}Removed /var/log/icinga2${NC}"
}



############
# EXECUTION#
############
remove_pkg
delet_file


log "${GREEN}uninstall Icinga2 successfully!${NC}"
