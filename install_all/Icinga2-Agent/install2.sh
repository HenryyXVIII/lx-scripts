#!/bin/bash

## Autor: HenryyXVIII
#
# testet on debi, ubu
# shell: bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PINK='\035[1;35m'
NC='\033[0;37m' # No Color



set -Eeuo pipefail
set -o nounset
#Abbruch Wenn Fehler

trap 'echo -e "${RED}ERROR on line $LINENO: $BASH_COMMAND${NC}" >&2' ERR

############
# LOG-FILE #
############
log() {
    echo -e "= [$(date '+%F %T')] => $*" | tee -a "$LOGFILE"
}


########
# HELP #
########

show_help() {
cat <<EOF
Verwendung:
  $(basename "$0") [OPTIONEN]

Optionen:
  -H, --parenthost_IP     IP-Adresse des Parent-Hosts (Satelit)
  -p, --port PORT         Port des Parent-Hosts (Satelit) default 5665
  -pcn, --parentcn NAME   DNS Name des Parent-Host (Satelit)
  -a, --agentcname        Agent FQDN
  -r, --return y|w|n      y=Autoconfig w=node Wizard n=nein

  => IF PARENT-HOST IP (-H) IS SET AUTOCONFIGURE WILL BE STARTET AUTOMATIC <=
  set -r to n to avoid it

  -h, --help              Diese Hilfe anzeigen

Beispiel:
  $(basename "$0") \
    -H 192.168.1.10 \
    -p 5665 \
    -pcn master \
    -z dmz \
    -l web01 \
    -r y
EOF
}
