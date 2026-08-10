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

RETURN=""
DATE=$(date '+%F_%H-%M-%S')
LOGFILE="/var/log/icinga2-install-${DATE}.log"
AGENTCN=$(hostname -f 2>/dev/null || cat /etc/hostname 2>/dev/null || hostname)
PARENTCN=satelite.locales.lab
PARENTIP="192.168.69.42"
PARENTZONE=""
PARENTPORT="5665"
PKIPATH="/etc/icinga2/pki"
CERTPATH="/var/lib/icinga2/certs"

if [ -n "$PARENTIP" ] && [ -z "$RETURN" ]; then
   RETURN='y'
   log "Autoconfig enabled"
fi

if [ -n "$PARENTCN" ] && [ -z "$PARENTZONE" ]; then
   PARENTZONE=$PARENTCN
   log "Parent Zone set to CNAME of PARENT"
fi

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

# test if runn as root #
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

###############
# Auslesen OS #
###############

source /etc/os-release

log "OS detektion"
log "detect $NAME"
log "Install for $ID"


################
# Installation #
################

log "Distro Wahl"
if [ "$ID" = "debian" ]; then

    log "$ID"
    if [ -n "${VERSION_CODENAME:-}" ]; then
    DIST="$VERSION_CODENAME"
    else
    DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release)
    fi

    #Basisprogramme
    apt update && apt -y install apt-transport-https wget
    log "Paketlisten Aktualisieren"
    log "Abhängikeiten installieren"
    #key
    wget -O ./icinga-archive-keyring.deb "https://packages.icinga.com/icinga-archive-keyring_latest+debian$VERSION_ID.deb"
    log "icinga2 key downloaden"
    #installation key
    apt -y install ./icinga-archive-keyring.deb
    log "installation key"
    
    #Icinga in die apt sourecliste
    echo "deb [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/debian icinga-${DIST} main" > \
    /etc/apt/sources.list.d/${DIST}-icinga.list

    echo "deb-src [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/debian icinga-${DIST} main" >> \
    /etc/apt/sources.list.d/${DIST}-icinga.list
    log "schreiben der source list"
    
    #installation Icinga
    echo "installation Icinga"
    apt update && apt -y install icinga2 monitoring-plugins
    log "installation icinga2 und monitoring plugins"

    #verifizierung
    icinga2 daemon -C
    
    #echo "installation Plugins"
    #apt -y install monitoring-plugins

    rm ./icinga-archive-keyring.deb
    log "löschen des keys"



elif [ "$ID" = "ubuntu" ]; then

    log "$ID"
    log "Paketlisten Aktualisieren"
    log "Abhängikeiten installieren"
    apt update && apt -y install apt-transport-https wget

    wget -O icinga-archive-keyring.deb "https://packages.icinga.com/icinga-archive-keyring_latest+ubuntu$VERSION_ID.deb"
    log "icinga2 key downloaden"

    apt -y install ./icinga-archive-keyring.deb
    log "installation key"

    . /etc/os-release
    
    if [ ! -z ${UBUNTU_CODENAME+x} ]; then 
    DIST="${UBUNTU_CODENAME}"
    else DIST="$(lsb_release -c| awk '{print $2}')"
    fi
 
    echo "deb [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/ubuntu icinga-${DIST} main" > \
    /etc/apt/sources.list.d/${DIST}-icinga.list
 
    echo "deb-src [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/ubuntu icinga-${DIST} main" >> \
    /etc/apt/sources.list.d/${DIST}-icinga.list
    log "add sourcelist"

    apt install icinga2 monitoring-plugins
    log "install icinga and monitoring Plugins"

    icinga2 daemon -C
    rm ./icinga-archive-keyring.deb
    log "löschen des keys"



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
            log "konfiguration automatisch"

            log "variablen"
            
            echo "=> Host CN: $AGENTCN"
            echo "=> Parent CN: $PARENTCN"
            echo "=> Parent IP: $PARENTIP"
            echo "=> Parent Port: $PARENTPORT"
            echo "=> Cluster Zone: $PARENTZONE"
            echo "=> Cert Path: $PKIPATH"
            echo "=> Cert Path: $CERTPATH"


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
              --disable-confd \

            
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
log "Hostadresse $(Hostname -I | awk '{print $1}')"
log ""
log "oder via Icingacli"
log "icingacli director host create --name $AGENTCN --display_name $AGENTCN --address $(Hostname -I | awk '{print $1}') --imports linux_host"
log "----" 
log "installation abgeschlossen"
log "----"

exit