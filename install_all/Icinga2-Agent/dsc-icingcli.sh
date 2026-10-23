#!/bin/bash
# Author HenryyXVIII
# Dirty Service Cloner with IcingaCLI
# This script is dirty
# it performs an export of the Current Source-Host as JSON Format via IcingaCLI
# removes unnecesarry fields with jq
# change the SourceHost with the Target-Host and imports it as JSON
# duplicated services are getting imported as well, but the icingacli only outputs an error so no preoblem
# you need the Icingadirector and IcingaCLI Module enabled on Icingaweb


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PINK='\035[1;35m'
NC='\033[0;37m'

set -Eeuo pipefail
set -o nounset


show_help() {
cat <<EOF

transfer von servicen eines hosts

        --help          show Help
        -O | --hosobject        selected HOST

EOF
}

OBJECT=""
SERVICENAME=""
NEWHOST=""
COMMAND=""
CMDOUT=""

while [[ $# -gt 0 ]]; do
   case "$1" in
        -O|--hostobject)
         OBJECT="$2"
         shift 2
         ;;
        -N|--newhost)
         NEWHOST="$2"
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


icingacli director host show ${OBJECT} --with-services --json > input.json

jq '.services | map(del(.fields, .uuid))' input.json > output.json
jq '(.. | .host?) |= "'${NEWHOST}'"' output.json > OUTPUT.json


echo -e "ALT= $OBJECT"
echo -e "NEU= $NEWHOST"

jq -c '.[]' OUTPUT.json | while read -r service; do
        SERVICENAME=$(echo "$service" | jq -r '.object_name')

        echo -e "${PINK}Aktueller Service${NC}: $service"
        #service=$(echo "$service" | sed 's/${OBJECT}/${NEWHOST}/g')
        #echo "$service"


        if icingacli director service create "${SERVICENAME}" --json "$service" ; then
                echo -e "${GREEN}service clone succesfull${NC}"
        else
                rc=$?
                echo -e "${RED}error, maybe duplicat${NC}"

        fi


done

#jq 'del(.[].fields)' output.json

#sed -i '/^fields/d' output.json
#sed -i '/^uuid/d' output.json

