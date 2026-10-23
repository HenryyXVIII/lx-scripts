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

if [ ! -f /etc/os-release ]; then
  exitsc "${RED}could not find os-release file${NC}"
fi

source /etc/os-release

# is $VERSION_ID?
#if [ -z  $VERSION_ID ]; then
#  log "no VERSION_ID found"
#fi

# is $DIST ?

#if [ -z  $DIST ]; then
#  log "no VERSION_ID found"
#fi

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

getip () {
  if ip addr show $(ip route | awk '/default/ { print $5 }') | grep "inet" | head -n 1 | awk '/inet/ {print $2}' | cut -d'/' -f1 ; then
    HOSTIP=$(ip addr show $(ip route | awk '/default/ { print $5 }') | grep "inet" | head -n 1 | awk '/inet/ {print $2}' | cut -d'/' -f1)
  else
    HOSTIP=$(hostname -i)
  fi
}

VERSION="2.2.6"
ONLYINSTALL=
DATE=$(date '+%F_%H-%M-%S')
LOGFILE="/var/log/icinga2-install-${DATE}.log"
HOSTFQDN=$(hostname -f 2>/dev/null || cat /etc/hostname 2>/dev/null || hostname)
HOSTIP=
CONFIGURE=""

#VarsConnect

HOSTTEMPLATE="<placehosttemplatehere>"
PKIPATH="/etc/icinga2/pki"
CERTPATH="/var/lib/icinga2/certs"
ZONENAME=""

PARENTCN=""
PARENTIP=""
PARENTPORT="5665"

SELHOST=""
SATELITEIP=
SATELITEFQDN=""

#new
declare -A SATELITES

SATELITES["1"]="Satelit1, 192.168.1.1, Satelit1.test.lab, 5665, Sat1"
SATELITES["2"]="Satelit2, 192.168.2.2, Satelit2.herd.lab, 9911, Sat02"
SATELITES["3"]="Satelit3, 192.168.3.3, Satelit3.test.lab, 5185, sAt03"
SATELITES["4"]="Satelit4, 192.168.4.4, Satelit4.ofen.lab, 52265, SAT4"

# depcirated
declare -A HOST
HOST["server1"]="Satelit1, 192.168.1.1, Satelit1.test.lab, 5665, Sat1"
HOST["server2"]="Satelit2, 192.168.2.2, Satelit2.herd.lab, 9911, Sat02"
HOST["server3"]="Satelit3, 192.168.3.3, Satelit3.test.lab, 5185, sAt03"
HOST["server4"]="Satelit4, 192.168.4.4, Satelit4.ofen.lab, 52265, SAT4"



verify_system() {
    if [ -x /sbin/openrc-run ]; then
      HAS_OPENRC=true
      return
    fi
    if [ -x /bin/systemctl ] || type systemctl > /dev/null 2>&1; then
      HAS_SYSTEMD=true
      return
    fi
    echo "Can not find systemd or openrc to use as a process supervisor for k3s"
}



exitsc () {
  echo -e "$1"
  exit "${2:-1}"

}



#################
# Install Agent #
#################
dpkg_valid () {
  #enterfunc
  PACKAGES=("monitoring-plugins" "icinga2" "icinga2-bin" "icinga2-common" "icinga2-doc")
  
  for pkg in "${PACKAGES[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
      log "${YELLOW}Paket '$pkg' is missing or corrupted. start reinstall${NC}"

      apt-get update && apt-get install --reinstall -y "$pkg"
        
    else
      log "${GREEN}Package: $pkg valid${NC}"
    fi
  done

}

installation () {

  # DEBIAN & UBUNTU #
  if [[ "$ID" = "debian" || "$ID" = "ubuntu" ]]; then
    apt update && apt -y install apt-transport-https wget
      
    if [ -n "${VERSION_CODENAME:-}" ]; then
        DIST="$VERSION_CODENAME"
    else
        DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release)
    fi
    

    # Key
    
    if dpkg -s icinga-archive-keyring &>/dev/null; then
      log "${YELLOW}The Icinga2 repo key is already installed, skipping....${NC}"
    else      
      log "${GREEN}The Icinga2 repo key missing, initialize installation.${NC}"
      wget -O ./icinga-archive-keyring.deb "https://packages.icinga.com/icinga-archive-keyring_latest+${ID}${VERSION_ID}.deb"
      apt -y install ./icinga-archive-keyring.deb
      rm ./icinga-archive-keyring.deb        
    fi


    #sourcelist
    FILE=/etc/apt/sources.list.d/${DIST}-icinga.list    
    if [ -f "$FILE" ]; then
      log "${YELLOW}Icinga2 sourcelist file $FILE alreadyexists, skipping....${NC}"
    
    else
      log "${GREEN}Icinga2 sourcelist file $FILE does not exist, creating source file${NC}"

      echo "deb [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/${ID} icinga-${DIST} main" > /etc/apt/sources.list.d/${DIST}-icinga.list
      
      echo "deb-src [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/${ID} icinga-${DIST} main" >> /etc/apt/sources.list.d/${DIST}-icinga.list
      log "${GREEN}sourcelist created${NC}"
    fi


    
    if dpkg -s icinga2 &>/dev/null; then
        log "${YELLOW}The Icinga2 package is already installed, skipping....${NC}"
    else
        log "${GREEN}The Icinga2 package is not installed, install packages.${NC}"        
        apt update && apt -y install icinga2 monitoring-plugins
        log "${GREEN}Icinga2 and monitoring plugins installed${NC}"
        icinga2 daemon -C
        
    fi
    dpkg_valid 


# ALPINE #
  elif [ "$ID" = "alpine" ]; then


      #Pakete
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
    log "update repositories"
    
    apk update
    log "update apk"
    

    apk add icinga2 monitoring-plugins icinga2-vim
    log "add packages"

# RHEL #
  elif [ "$ID" = "rhel" ]; then


    dnf install -y curl wget
    wget https://packages.icinga.com/subscription/rhel/ICINGA-release.repo -O /etc/yum.repos.d/ICINGA-release.repo

    ARCH=$(/bin/arch)
    OSVER=$(. /etc/os-release; echo "${VERSION_ID%%.*}")

    subscription-manager repos --enable "codeready-builder-for-rhel-${OSVER}-${ARCH}-rpms"

    dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSVER}.noarch.rpm

    dnf install icinga2 nagios-plugins-all    
    systemctl enable icinga2
    systemctl start icinga2

  # NONE SUPPORTED #

  else
    log "$ID"
  
    log "${RED}failed${NC}"
    exitsc "no dist found" 1
  fi


    
}

################
# config Agent #
################

read_array () {
    local table_id="$1" # Nimmt das 1. Argument entgegen
    
    # Hier nutzen wir jetzt $table_id für das Array
    IFS=',' read -r name ip fqdn port zone <<< "${SATELITES[$table_id]}"
    
    # Werte trimmen
    name=$(echo "$name" | xargs)
    ip=$(echo "$ip" | xargs)
    fqdn=$(echo "$fqdn" | xargs)
    port=$(echo "$port" | xargs)
    zone=$(echo "$zone" | xargs)
}

# Funktion zur Tabellen-Ausgabe
print_table () {
    echo "======================================================================================"
    printf "%-4s | %-12s | %-16s | %-22s | %-6s | %-8s\n" "ID" "Name" "IP-Adresse" "FQDN" "Port" "Zone"
    echo "--------------------------------------------------------------------------------------"

    for satid in $(echo "${!SATELITES[@]}" | tr ' ' '\n' | sort -n); do
        
        read_array "$satid"
        
        
        printf "%-4s | %-12s | %-16s | %-22s | %-6s | %-8s\n" "$satid" "$name" "$ip" "$fqdn" "$port" "$zone"
    done
    echo "======================================================================================"
}

run_catch() {
    local timeout_sec="$1"
    #erstes Argument in var
    shift
    
    local cmd=("$@")
    local exit_code=0

   
    #wenn timeout das exitcode speichern
    timeout "$timeout_sec" "${cmd[@]}" || exit_code=$?

    # Auswertung des Exit-Codes
    if [ "$exit_code" -eq 124 ]; then
        echo "[CATCH] TIMEOUT: Der Befehl dauerte länger als ${timeout_sec}s!" >&2
        return 124
    elif [ "$exit_code" -ne 0 ]; then
        echo "[CATCH] FEHLER: Befehl schlug fehl mit Exit-Code ${exit_code}!" >&2
        return "$exit_code"
    fi

    return 0
}

catch_icingacmd () {
  local closeloop=""
  while [ -z "$closeloop" ]; do
    log "execute: $@"
    log "timeout set to 10s"
    if run_catch 10s $@; then
      echo -e "${GREEN}Befehl erfolgreich ausgeführt.${NC}"
      break
    else
      echo "timeout/error"
      echo "following command failed: $@"
      read -p "try again Y/n :" RETRY < /dev/tty
      case "$RETRY" in
        [Nn]*)
          #closeloop="true"
          break
          ;;
        [Yy]*)
          log "Wiederhole Befehl..."
          # Kein break nötig: Die while-Schleife läuft einfach von vorne an
          ;;
      esac
    fi
  done
}

configure_icinga () {

  if [ -z  $PARENTCN ]; then
    print_table
    read -p "wich Satelite choose by ID: " sid < /dev/tty
    # hier muss die Abfrage rein für welchen sat 
    read_array $sid
    PARENTIP=$ip
    PARENTPORT=$port
    PARENTCN=$fqdn
    AGENTCN=$HOSTFQDN
    ZONENAME=$zone
  fi

  log "config for $name  $PARENTIP  $PARENTCN  $PARENTPORT => $AGENTCN  $CERTPATH"
  catch_icingacmd icinga2 pki save-cert --trustedcert "$CERTPATH/ca.crt" --host "$PARENTIP" --port "$PARENTPORT"
  log "generating local Key und CSR..."
  catch_icingacmd icinga2 pki new-cert --cn "$AGENTCN" --key "$CERTPATH/$AGENTCN.key" --csr "$CERTPATH/$AGENTCN.csr"
  log "Sende PKI-Request an Master..."
  log "Starte Node Setup..."
  catch_icingacmd icinga2 node setup --cn "$AGENTCN" --endpoint "$PARENTCN,$PARENTIP,$PARENTPORT" --zone "$AGENTCN" --parent_zone "$PARENTZONE" \
  --parent_host "$PARENTCN" --trustedcert "$CERTPATH/ca.crt" --accept-commands --accept-config --disable-confd 

  log "${GREEN}Node Setup erfolgreich abgeschlossen!${NC}"

  icinga2 daemon -C
  log "config validierung"


}




finish () {

  ICINGACLI="icingacli director host create ${AGENTCN} --display_name ${AGENTCN} --address ${HOSTIP} --imports ${HOSTTEMPLATE} --zone ${ZONENAME}"
  log "Host erfolgreich konfiguriert"
  log "---------------------------------"
  log "${GREEN}please signe the request on your icinga2 master instance${NC}"
  log "Tipp: icinga2 ca list"
  log "Tipp: icinga2 ca signe <Fingerprint>"
  log "---------------------------------"
  log "Hosteintrag in Director:"
  log "Hostname $AGENTCN"
  log "Hostadresse $(hostname -i | awk '{print $1}')"
  #log "Hostadresse $(hostname -i)"
  log "---------------------------------"
  log "oder via Icingacli"
  log "${GREEN}${ICINGACLI}${NC}"
  log "---------------------------------" 
  log "       == setup done =="
  log "---------------------------------"

}

############# START ###############

# is root?

if [[ $EUID -ne 0 ]]; then
   exitsc "${RED}This script must be run as root${NC}"
fi

# is bash?

if [ -z "$BASH" ]; then
  exitsc "${RED}Please use BASH, currently ${SHELL}.${NC}"
fi

# is /etc/os-release?





log "detect $NAME"
installation "$ID"



while true
do
    #Ist Return bereits gesetzt?
  if [ -z "$CONFIGURE" ]; then
    log "${GREEN}-- please input y,w or n --${NC}"
    read -p "Do you want configure Agent (Yes,Node-Wizard,No)? (Y/w/n): " CONFIGURE < /dev/tty
  fi

  case "$CONFIGURE" in
    [Yy][Jj]|[Yy]|[Jj]|"")
      log "start icinga2 configuration"
      configure_icinga

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