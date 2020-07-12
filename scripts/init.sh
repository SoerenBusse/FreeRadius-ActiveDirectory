#!/bin/bash
# Statische Parameter
HOSTNAME_FILE="/etc/hostname"
HOSTS_FILE="/etc/hosts"
RESOLV_CONF_FILE="/etc/resolv.conf"
RAIDUS_VLAN_GROUP_MAPPING_POLICY_FILE="/etc/freeradius/radius/policy.d/vlan-group-mapping"

# FreeRadius Template for assining a ldap group to a VLAN
read -d '' RADIUS_VLAN_GROUP_TEMPLATE << EOF
if (LDAP-Group == "__VLAN_NAME__") {
    update reply {
        Tunnel-Type := VLAN,
        Tunnel-Medium-Type := IEEE-802,
        Tunnel-Private-Group-Id := "__VLAN_ID__"
    }

    return
}
EOF

# Required environment variables
export REALM
export DOMAIN
export RADIUS_TLS_CERTIFICATE_FILE
export RADIUS_TLS_KEY_FILE
export JOIN_USER
export LAN_IP

export LDAP_SERVER
export LDAP_PORT
export LDAP_USERNAME
export LDAP_PASSWORD
export LDAP_BIND_DN

# Optional environment variables
export TLS_DIRECTORY=${TLS_DIRECTORY:-/cert}
export LOG_LEVEL=${LOG_LEVEL:-1}
export POLL_INTERVALL=${POLL_INTERVALL:-3600}

function checkDcState() {
  nc -w 1 -z $1 389
  echo $?
}

function configureDNS() {
  # Hostname abrufen
  hostname=$(cat ${HOSTNAME_FILE})

  echo "127.0.0.1 localhost.${REALM} localhost" >${HOSTS_FILE}
  echo "${LAN_IP} ${hostname}.${REALM} ${hostname}" >>${HOSTS_FILE}

  echo "search ${REALM}" >>${RESOLV_CONF_FILE}
}

# Reads a secret from a file or an environment
# $1: Value of environment name for file
# $2: Value of environment name for variable
# $3: Name of environment variable for error reporting
function getSecretFromFileOrEnvironment() {
  secret_file="${1}"
  secret_variable="${2}"
  secret_name="${3}"

  secret_result=""

  # Try to read Accesspoint Secret from file if set
  if [[ -n "${secret_file}" ]]; then
    secret_result=$(cat "${secret_file}")

    if [[ -z "${secret_result}" ]]; then
      echo "Error while reading Secret from file ${secret_file}"
      exit 1
    fi

  else
    # Check if ACCESS_POINT_SECRET is set
    if [[ -z "${secret_variable}" ]]; then
      echo "Missing ${secret_name} environment variable"
      exit 1
    fi

    secret_result="${secret_variable}"
  fi

  echo "${secret_result}"
}

# Returns a group template for FreeRadius to assign a specific vlan to a group
# $1: Name of the group in ActiveDirectory
# $2: VLAN ID for this group
function writeVLANGroupTemplateToPolicyFile() {
    replacedTemplate="${RADIUS_VLAN_GROUP_TEMPLATE/__VLAN_NAME__/$1}"
    replacedTemplate="${replacedTemplate/__VLAN_ID__/$2}"

    echo -e "$replacedTemplate" >> $RAIDUS_VLAN_GROUP_MAPPING_POLICY_FILE
}

function writeVLANGroupTemplatesToPolicyFile() {
    RADIUS_GROUP_VLAN_MAPPING=""

    # Get all environment varibles with VLAN_MAPPING Prefix
    vlan_mappings=( ${!VLAN_MAPPING_@} )

    if [[ ${#vlan_mappings[@]} == 0 ]]; then
      echo "No VLAN_MAPPING_X environment variables set. Exiting..."
      exit 1;
    fi

    # Build vlan-group-mapping policy file
    echo "vlan-group-mapping {" >> $RAIDUS_VLAN_GROUP_MAPPING_POLICY_FILE

    # Iterate over each mapping and create a template definition
    for vlan_mapping in "${vlan_mappings[@]}"; do
        # Split string at delimiter
        IFS=':';
        vlan_info=(${!vlan_mapping})
        unset IFS;

        vlan_group_template=$(writeVLANGroupTemplateToPolicyFile "${vlan_info[0]}" "${vlan_info[1]}")
        RADIUS_GROUP_VLAN_MAPPING="${RADIUS_GROUP_VLAN_MAPPING}${vlan_group_template}\n"
    done

    echo "}" >> $RAIDUS_VLAN_GROUP_MAPPING_POLICY_FILE
}

/usr/local/bin/environment-validator.sh REALM DOMAIN RADIUS_TLS_KEY_FILE RADIUS_TLS_CERTIFICATE_FILE JOIN_USER LAN_IP LDAP_SERVER LDAP_PORT LDAP_USERNAME LDAP_BIND_DN

if [[ $? != 0 ]]; then
  echo "Missing environment variables. Exiting..."
  exit 1;
fi

ACCESS_POINT_SECRET=$(getSecretFromFileOrEnvironment "${ACCESS_POINT_SECRET_FILE}" "${ACCESS_POINT_SECRET}" "ACCESS_POINT_SECRET")
JOIN_USER_SECRET=$(getSecretFromFileOrEnvironment "${JOIN_USER_SECRET_FILE}" "${JOIN_USER_SECRET}" "JOIN_USER_SECRET")
LDAP_SECRET=$(getSecretFromFileOrEnvironment "${LDAP_SECRET_FILE}" "${LDAP_SECRET}" "LDAP_SECRET")

export ACCESS_POINT_SECRET
export LDAP_SECRET

FREERADIUS_DEBUG=""
WINBINDD_DEBUG="--debuglevel=0"

if [[ -n $DEBUG ]]; then
  echo "Enable Debug Mode"
  FREERADIUS_DEBUG="-xx"
  WINBINDD_DEBUG="--debuglevel=10"
fi

export FREERADIUS_DEBUG
export WINBINDD_DEBUG

# Generate vlan group mapping template
writeVLANGroupTemplatesToPolicyFile

# DNS konfigurieren
configureDNS

# Variabeln ersetzen
# Supervisor
if ! gucci /etc/supervisor.tpl >/etc/supervisor.conf; then
  echo "Cannot apply template to supervisor.conf"
  exit 1
fi

# Freeradius Global Configuration
if ! gucci /etc/freeradius/radius/radiusd.tpl >/etc/freeradius/radius/radiusd.conf; then
  echo "Cannot apply template to radiusd.conf"
  exit 1
fi

if ! gucci /etc/freeradius/radius/sites/radius-inner-tunnel.tpl >/etc/freeradius/radius/sites/radius-inner-tunnel; then
  echo "Cannot apply template to radius-inner-template";
  exit 1
fi

# Samba
if ! gucci /etc/samba/smb.tpl >/etc/samba/smb.conf; then
  echo "Cannot apply template to smb.conf"
  exit 1
fi

# Remove template files
rm /etc/supervisor.tpl
rm /etc/freeradius/radius/radiusd.tpl
rm /etc/freeradius/radius/sites/radius-inner-tunnel.tpl
rm /etc/samba/smb.tpl

# Warten bis der DC gestartet ist
while [[ $(checkDcState "${REALM}") == 1 ]]; do
  echo "Wait for DC to come up"
  sleep 1
done

# Da Samba von außen keine weitere Funktion besitzt müssen wir auch DNS nicht anpassen
# Würde sowieso nur auf die interne Docker IP zeigen
if ! net ads join -U"${JOIN_USER}"%"${JOIN_USER_SECRET}"; then
  echo "Error while joining the DC"
  exit 1
fi

exec supervisord -c /etc/supervisor.conf
