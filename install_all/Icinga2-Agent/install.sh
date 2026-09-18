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

trap 'echo "${RED}ERROR on line $LINENO: $BASH_COMMAND${NC}" >&2' ERR

############
# LOG-FILE #
############
log() {
    echo -e "=> [$(date '+%F %T')] $*" | tee -a "$LOGFILE"
}


########
# HELP #
########

show_help() {
cat <<EOF
Verwendung:
  $(basename "$0") [OPTIONEN]

Optionen:
  -H, --parenthost IP     IP-Adresse des Parent-Hosts (Satelit)
  -p, --port PORT         Port des Parent-Hosts (Satelit) default 5665
  -pcn, --parentcn NAME   DNS Name des Parent-Host (Satelit)
  -z, --zone ZONE         Parent-Zone (Zone des Parents)
  -l, --localzone NAME    Lokale Zone 
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

########
# VARS #
########
VERSION=1.2.4

RETURN=""
DATE=$(date '+%F_%H-%M-%S')
LOGFILE="/var/log/icinga2-install-${DATE}.log"
AGENTCN=$(hostname -f 2>/dev/null || cat /etc/hostname 2>/dev/null || hostname)
PARENTCN=""
PARENTIP=""
PARENTZONE=$PARENTCN
PARENTPORT="5665"
PKIPATH="/etc/icinga2/pki"
CERTPATH="/var/lib/icinga2/certs"

declare -A HOST
HOST["server1"]="Satelit1, 192.168.1.1, Satelit1.test.lab, 5665"
HOST["server2"]="Satelit2, 192.168.2.2, Satelit2.herd.lab, 9911"
HOST["server3"]="Satelit3, 192.168.3.3, Satelit3.test.lab, 5185"
HOST["server4"]="Satelit4, 192.168.4.4, Satelit4.ofen.lab, 52265"



#if [ -n "$PARENTCN" ] && [ -z "$PARENTZONE" ]; then
#   PARENTZONE=$PARENTCN
#   log "Parent Zone set to CNAME of PARENT"
#fi

###############
# Script Vars #
###############

while [[ $# -gt 0 ]]; do
   case "$1" in
      -H|--parenthost)
         PARENTIP="$2"
         shift 2
         ;;
      -p|--port)
         PARENTPORT="$2"
         shift 2
         ;;
      -pcn|--parentcn)
         PARENTCN="$2"
         shift 2
         ;;
      -z|--zone)
         PARENTZONE="$2"
         shift 2
         ;;
      -l|--localzone)
         AGENTCN="$2"
         shift 2
         ;;
       -r|--return)
         RETURN="$2"
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

if [ -n "$PARENTIP" ] && [ -z "$RETURN" ]; then
   RETURN='y'
   log "Autoconfig enabled"
fi

echo "${GREEN}Script is running on Version: $VERSION${NC}"

####################
# test permissions #
####################

# for sudo
#sudo -n true
#test $? -eq 0 || {
#    echo "you should have sudo privilege to run this script"
#    exit 1
#    }
# Testet ob SUDO rechte



# test if runn as root #
if [[ $EUID -ne 0 ]]; then
   echo "${RED}This script must be run as root${NC}" 
   exit 1
fi

if [ -z "$BASH" ]; then
  echo "${RED}Please use BASH, currently ${SHELL}${NC}."
  exit 3
fi

####################
# read OS Env Vars #
####################

source /etc/os-release

log "${GREEN}OS detektion${NC}"
log "detect $NAME"
log "${GREEN}Install for $ID${NC}"

#####################
# Install functions #
#####################

apt_install_basics () {
    #enterfunc
    log "$ID"
    log "${GREEN}Paketlisten Aktualisieren${NC}"
    log "${GREEN}Abhängikeiten installieren${NC}"
    apt update && apt -y install apt-transport-https wget
}



#func-add-sourcelist deb/ubuntu
add_sourcelists () {
    #enterfunc
    wget -O ./icinga-archive-keyring.deb "https://packages.icinga.com/icinga-archive-keyring_latest+${ID}${VERSION_ID}.deb"
    log "${GREEN}icinga2 key downloaden${NC}"
    #installation key
    apt -y install ./icinga-archive-keyring.deb
    log "${GREEN}installation key${NC}"
    
    rm ./icinga-archive-keyring.deb
    log "${GREEN}löschen des keys${NC}"
           
    #Icinga in die apt sourecliste
    echo "deb [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/${ID} icinga-${DIST} main" > \
    /etc/apt/sources.list.d/${DIST}-icinga.list
      
    echo "deb-src [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/${ID} icinga-${DIST} main" >> \
    /etc/apt/sources.list.d/${DIST}-icinga.list
    log "${GREEN}schreiben der source list"
}

#func-install-icinga  deb/ubuntu
install_icinga () {
    #enterfunc
    echo "${GREEN}installation Icinga and monitoring plugins${NC}"
    apt update && apt -y install icinga2 monitoring-plugins
    #verifizierung
    icinga2 daemon -C
}

test_installed(){

    #test sourcelist already exist
    FILE=/etc/apt/sources.list.d/${DIST}-icinga.list    
    if [ -f "$FILE" ]; then
       log "${YELLOW}Icinga2 sourcelist file $FILE alreadyexists, skipping installation.${NC}"
    else
       log "${GREEN}Icinga2 sourcelist file $FILE does not exist, start installation.${NC}"
       add_sourcelists
    fi
    
    #test icinga2 package installed?    
    if dpkg -s icinga2 &>/dev/null; then
        log "${YELLOW}The Icinga2 package is already installed, skipping installation.${NC}"
    else
        log "${GREEN}The Icinga2 package is not installed, initialize installation.${NC}"
        install_icinga
    fi

}

#function-dpkg-valid
dpkg_valid () {
    #enterfunc
    PACKAGES=("monitoring-plugins" "icinga2" "icinga2-bin")
    
    for pkg in "${PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            log "${YELLOW}Paket '$pkg' is missing or corrupted. start reinstall${NC}"
    
            apt-get update && apt-get install --reinstall -y "$pkg"
            
        else
            log "${GREEN}Package: $pkg valid${NC}"
        fi
    done

}


################
# Installation #
################

log "Distro Wahl"
if [ "$ID" = "debian" ]; then
  
    #Basisprogramme
    apt_install_basics
    
    #set enviroments    
    log "$ID"
    if [ -n "${VERSION_CODENAME:-}" ]; then
        DIST="$VERSION_CODENAME"
    else
        DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release)
    fi
            
    test_installed    
    dpkg_valid


    


elif [ "$ID" = "ubuntu" ]; then

    apt_install_basics
    . /etc/os-release
    
    if [ ! -z ${UBUNTU_CODENAME+x} ]; then 
    DIST="${UBUNTU_CODENAME}"
    else DIST="$(lsb_release -c| awk '{print $2}')"
    fi
 
    test_installed
    dpkg_valid

elif [ "$ID" = "rhel" ]; then

    log "$ID"
    dnf install -y curl wget
    wget https://packages.icinga.com/subscription/rhel/ICINGA-release.repo -O /etc/yum.repos.d/ICINGA-release.repo

    ARCH=$(/bin/arch)
    OSVER=$(. /etc/os-release; echo "${VERSION_ID%%.*}")

    subscription-manager repos --enable "codeready-builder-for-rhel-${OSVER}-${ARCH}-rpms"

    dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSVER}.noarch.rpm

    dnf install icinga2 nagios-plugins-all
    systemctl enable icinga2
    systemctl start icinga2


elif [ "$ID" = "fedora" ]; then

    log "$ID"
    dnf install -y curl
    rpm --import https://packages.icinga.com/icinga.key
    curl -o /etc/yum.repos.d/ICINGA-release.repo https://packages.icinga.com/fedora/ICINGA-release.repo

    dnf install icinga2
    systemctl enable icinga2
    systemctl start icinga2
    icinga2 daemon -C


elif [ "$ID" = "alpine" ]; then

   log "install for $ID"
    #Pakete
   echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories
   echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
   log "update repositories"
   
   apk update
   log "update apk"
   
   #Installation
   apk add icinga2 monitoring-plugins icinga2-vim
   log "add packages"

# FEHLER #
else
    log "$ID"
    exit 1
    log "${RED}failed${NC}"
    log "${YELLOW}distro not found${NC}"

fi

#################
# CONFIGURATION #
#################

log "${GREEN}installation done succesfully, choose how to proceed${NC}"

select_server () {

    #keys=("${!HOST[@]}")
    readarray -t keys < <(printf '%s\n' "${!HOST[@]}" | sort -V)
    echo "${PINK}-- please enter, ONLY NUMBERS --${NC}"
    PS3="please Type in the number of the icinga2-satelite you want to connect to (enter number): "

    # WICHTIG: Am Ende der select-Schleife "< /dev/tty" hinzufügen
    select selected_key in "${keys[@]}"; do
        if [[ -n "$selected_key" ]]; then
            echo "you choose the satelite: $selected_key ."
            
            IFS=',' read -r server_name server_ip server_domain server_port <<< "${HOST[$selected_key]}"
            
            server_name=$(echo "$server_name" | xargs)
            server_ip=$(echo "$server_ip" | xargs)
            server_domain=$(echo "$server_domain" | xargs)
            server_port=$(echo "$server_port" | xargs)


            PARENTCN=$server_domain
            PARENTIP=$server_ip
            PARENTZONE=$server_domain
            PARENTPORT=$server_port

            
            
            break
        else
            echo "${RED}invalid selection, please try again.${NC}"
        fi
    done < /dev/tty
    
    echo "--- ${GREEN}icinga2-satelite detailes${NC} ---"
    echo "Name:   $server_name"
    echo "IP:     $server_ip"
    echo "Domain: $server_domain"
    echo "PORT: $server_port"

}

###

while true
do
    #Ist Return bereits gesetzt?
    log "Debbug info value RETURN: $RETURN"
    if [ -z "${RETURN:-}" ]; then
        log "return not set via ops"
        echo "${GREEN}-- please input y,w or n --${NC}"
        read -p " - experimental - Do you want configure Agent (Yes,Node-Wizard,No)? (Y/w/n)" RETURN < /dev/tty
    fi
    case "$RETURN" in
        [Yy][Jj]|[Yy]|[Jj]|"")
        
            #konfiguration           
            log "start autoconfig"
            select_server

            
            log "current vars"
            
            echo "=> Host CN: $AGENTCN"
            echo "=> Parent CN: $PARENTCN"
            echo "=> Parent IP: $PARENTIP"
            echo "=> Parent Port: $PARENTPORT"
            echo "=> Cluster Zone: $PARENTZONE"
            echo "=> Cert Path: $PKIPATH"
            echo "=> Cert Path: $CERTPATH"
            
                
            if [ ! -d "$CERTPATH" ]; then
                log "${YELLOW}The certificat directory $CERTPATH does not exist, creating${NC}"
                mkdir $CERTPATH
                chown nagios:nagios $CERTPATH
                chmod 755 $CERTPATH
            else
               log "${GREEN}The directory for the certifcates $CERTPATH exist, skipping creating${NC}"
              
            fi
            


            log "getting master certificat"
            #icinga2 pki save-cert \
            #  --trustedcert "$PKIPATH/trusted-parent.crt" \
            #  --host "$PARENTIP" \
            #  --port "$PARENTPORT"
            icinga2 pki save-cert \
              --trustedcert "$CERTPATH/ca.crt" \
              --host "$PARENTIP" \
              --port "$PARENTPORT"            
            

            log "generating local Key und CSR..."
            icinga2 pki new-cert \
              --cn "$AGENTCN" \
              --key "$CERTPATH/$AGENTCN.key" \
              --csr "$CERTPATH/$AGENTCN.csr"
            

            log "Sende PKI-Request an Master..."

              
#            icinga2 pki request \
#              --host "$PARENTIP" \
#              --port "$PARENTPORT" \
#              --trustedcert "$PKIPATH/trusted-parent.crt" \
#              --cert "$PKIPATH/$AGENTCN.crt" \
#              --key "$PKIPATH/$AGENTCN.key" \
#              --ca "$PKIPATH/ca.crt" 
#              --csr "$PKIPATH/$AGENTCN.csr" \
#              --ticket "$TICKET"

            log "${PINK}please signe the request on your icinga2 master instance${NC}"
            log "Tipp: icinga2 ca list"
            log "Tipp: icinga2 ca signe <Fingerprint>"
            

            log "Starte Node Setup..."
            icinga2 node setup \
              --cn "$AGENTCN" \
              --endpoint "$PARENTCN,$PARENTIP,$PARENTPORT" \
              --zone "$AGENTCN" \
              --parent_zone "$PARENTZONE" \
              --parent_host "$PARENTCN" \
              --trustedcert "$CERTPATH/ca.crt" \
              --accept-commands \
              --accept-config \
              --disable-confd 

            
            log "${GREEN}Node Setup erfolgreich abgeschlossen!${NC}"

            icinga2 daemon -C
            log "config validierung"

            #restart Service
            log "neustart icinga2.service"
            
            #rc-service
            if [ "$ID" = "alpine" ]; then
                log "Verwende OpenRC für $ID"
                rc-update add icinga2 default
                rc-service icinga2 restart
            #systemd
            elif [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ] || [ "$ID" = "fedora" ] || [ "$ID" = "rhel" ]; then
                # Systemd (Ubuntu / Debian / Fedora / RHEL)
                log "Verwende Systemd für $ID"
                systemctl restart icinga2.service
            else
                log "${RED}service neustart fehlgeschlagen, OS unbekannt: $ID${NC}"
                exit 1
            fi

            break
            ;;
         [Ww])
            #nodewizard
            log "start nodewizard"
            icinga2 node wizard
            break
            ;;    
        [Nn])
            #keine konfig
            log "keine weiteren konfigurationen nötig"

            break
            ;;
        *)
            #falsche eingabe
          
            log "${RED}eingabe ungültig${NC}"
            ;;
    esac
done

########
# DONE #
########

log "Host erfolgreich konfiguriert"
log "Hosteintrag in Director:"
log "Hostname $AGENTCN"
log "Hostadresse $(hostname -i | awk '{print $1}')"
#log "Hostadresse $(hostname -i)"
log ""
log "oder via Icingacli"
log "icingacli director host create --name $AGENTCN --display_name $AGENTCN --address $(hostname -i) --imports linux_host"
log "----" 
log "installation abgeschlossen"
log "----"

exit
