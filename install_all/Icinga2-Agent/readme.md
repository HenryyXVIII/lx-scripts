# Script for automatically installing Icinga2 according to the official documentation on DEBIAN, UBUNTU, RHEL, FEDORA, and ALPINE

# Initial installation script; still in the testing/development phase

# Functions:

Installs the Icinga2 agent and monitoring plugins

testet on:
- debian 13
- alpine v3.23
- ubuntu 22.04.4 LTS

# How to run?
## Install on debian/ubuntu
```bash

sudo apt install -y curl wget

curl -fsSL https://github.com/HenryyXVIII/scripts/raw/refs/heads/main/install/icinga2-Agent/install.sh | sudo bash

# Specific Variables can be changed to auto confgure the host
curl -fsSL https://github.com/HenryyXVIII/scripts/raw/refs/heads/main/install/icinga2-Agent/install.sh | sudo bash -s -- \
-h, --parenthost <Parent-IP> \
-p, --port <Parent-Port> \
-pcn, --parentcn <Parent-CName> \
-z <masterzone> \
-l <Host-CN>

```

Exampel
```
curl -fsSL https://github.com/HenryyXVIII/scripts/raw/refs/heads/main/install/icinga2-Agent/install.sh | sudo bash -s -- \
-h 10.192.5.3 \
-p 1882 \
-z masterzone3000 \
-l toblerone

#Output

=> [2026-07-31 11:16:01] variablen
=> Host CN: toblerone
=> Parent CN: satelite.locales.lab
=> Parent IP: 10.192.5.3
=> Parent Port: 1882
=> Cluster Zone: masterzone3000
=> Cert Path: /etc/icinga2/pki
=> [2026-07-31 11:16:01] Hole Master-Zertifikat...


```

## Install on Alpine

```bash
# ALPINE
apk update && apk add curl wget bash

wget -O - https://github.com/HenryyXVIII/scripts/raw/refs/heads/main/install/icinga2-Agent/install.sh | bash


```

# Adding Features:

automatic configuration (enpoint/parent)