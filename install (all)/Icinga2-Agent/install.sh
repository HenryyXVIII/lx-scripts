#!/bin/bash

## Autor



set -Eeuo pipefail
set -o nounset
#Abbruch Wenn Fehler

############
# LOG-FILE #
############
log() {
    echo "=> [$(date '+%F %T')] $*" | tee -a "$LOGFILE"
}

exit_trap {
  local exit_code=$1
  local line_no=$2

  if [ "$exit_code" != "0" ]; then
    echo "Error $exit_code occurred on $line_no"
  fi

  echo -n "Exit, cleanup ... "
#  rm -rf "$TEMP_FILE"
  echo "ok"
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
VERSION=1.2.2

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
IP=$(ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1 | grep -E '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)')

if [ -n "$PARENTIP" ] && [ -z "$RETURN" ]; then
   RETURN='y'
   log "Autoconfig enabled"
fi

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

# sudo? #
#sudo -n true
#test $? -eq 0 || {
#    echo "you should have sudo privilege to run this script"
#    exit 1
#    }
# Testet ob SUDO rechte
echo "$VERSION"
# test if runn as root #
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

####################
# read OS Env Vars #
####################

source /etc/os-release

log "OS detektion"
log "detect $NAME"
log "Install for $ID"

#####################
# Install functions #
#####################

apt_install_basics () {
    #enterfunc
    log "$ID"
    log "Paketlisten Aktualisieren"
    log "Abhängikeiten installieren"
    apt update && apt -y install apt-transport-https wget
}



#func-add-sourcelist deb/ubuntu
add_sourcelists () {
    #enterfunc
    wget -O ./icinga-archive-keyring.deb "https://packages.icinga.com/icinga-archive-keyring_latest+${ID}${VERSION_ID}.deb"
    log "icinga2 key downloaden"
    #installation key
    apt -y install ./icinga-archive-keyring.deb
    log "installation key"
    
    rm ./icinga-archive-keyring.deb
    log "löschen des keys"
           
    #Icinga in die apt sourecliste
    echo "deb [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/${ID} icinga-${DIST} main" > \
    /etc/apt/sources.list.d/${DIST}-icinga.list
      
    echo "deb-src [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/${ID} icinga-${DIST} main" >> \
    /etc/apt/sources.list.d/${DIST}-icinga.list
    log "schreiben der source list"
}

#func-install-icinga  deb/ubuntu
install_icinga () {
    #enterfunc
    echo "installation Icinga"
    apt update && apt -y install icinga2 monitoring-plugins
    log "installation icinga2 und monitoring plugins"
    #verifizierung
    icinga2 daemon -C
}

test_installed(){

    #test sourcelist already exist
    FILE=/etc/apt/sources.list.d/${DIST}-icinga.list    
    if [ -f "$FILE" ]; then
       log "Icinga2 sourcelist file $FILE alreadyexists, skipping installation."
    else
       log "Icinga2 sourcelist file $FILE does not exist, start installation."
       add_sourcelists
    fi
    
    #test icinga2 package installed?    
    if dpkg -s icinga2 &>/dev/null; then
        log "The Icinga2 package is already installed, skipping installation."
    else
        log "The Icinga2 package is not installed, initialize installation"
        install_icinga
    fi

}

#function-dpkg-valid
dpkg_valid () {
    #enterfunc
    PACKAGES=("monitoring-plugins" "icinga2" "icinga2-bin")
    
    for pkg in "${PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            log "Paket '$pkg' fehlt oder ist beschädigt. Starte Neuinstallation..."
    
            apt-get update && apt-get install --reinstall -y "$pkg"
            
            if [ "$pkg" = "icinga2" ]; then
            exit 1
            fi
        else
            log "Vorhanden: $pkg"
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
    log "fehlgeschlagen"
    log "distro not found"

fi

#################
# CONFIGURATION #
#################

log "erfolgreich"
log "installation done, choose how to proceed"

while true
do
    #Ist Return bereits gesetzt?
    log "Vorausgabe: $RETURN"
    if [ -z "${RETURN:-}" ]; then
        log "Variable Return nicht gesetzt"
        read -p " - experimental - Do you want configure Agent (Yes,Wizard,No)? (Y/w/n) " RETURN < /dev/tty
    fi
    case "$RETURN" in
        [Yy][Jj]|[Yy]|[Jj]|"")
        
            #konfiguration
            log "start autoconfig"
            log "current vars"
            
            echo "=> Host CN: $AGENTCN"
            echo "=> Parent CN: $PARENTCN"
            echo "=> Parent IP: $PARENTIP"
            echo "=> Parent Port: $PARENTPORT"
            echo "=> Cluster Zone: $PARENTZONE"
            echo "=> Cert Path: $PKIPATH"
            echo "=> Cert Path: $CERTPATH"

            mkdir $CERTPATH
            chown -aG nagios:nagios $CERTPATH

            log "Hole Master-Zertifikat..."
            #icinga2 pki save-cert \
            #  --trustedcert "$PKIPATH/trusted-parent.crt" \
            #  --host "$PARENTIP" \
            #  --port "$PARENTPORT"
            icinga2 pki save-cert \
              --trustedcert "$CERTPATH/ca.crt" \
              --host "$PARENTIP" \
              --port "$PARENTPORT"            
            

            log "Generiere lokalen Key und CSR..."
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

            log "Signiere certifikat auf dem Icinga Master!"
            log "Tipp: icinga2 ca list"
            

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

            
            log "Node Setup erfolgreich abgeschlossen!"

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
                log "service neustart fehlgeschlagen, OS unbekannt: $ID"
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
          
            log "eingabe ungültig"
            ;;
    esac
done

########
# DONE #
########

log "Host erfolgreich konfiguriert"
log "Hosteintrag in Director:"
log "Hostname $AGENTCN"
#log "Hostadresse $(hostname -i | awk '{print $1}')"
log "Hostadresse $IP)"
log ""
log "oder via Icingacli"
log "icingacli director host create --name $AGENTCN --display_name $AGENTCN --address $IP --imports linux_host"
log "----" 
log "installation abgeschlossen"
log "----"

exit
