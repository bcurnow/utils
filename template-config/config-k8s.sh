#!/bin/bash
#
# To be run after cloning a VM that was prepared with make-template.sh
#

prompt () {
  local prompt=$1

  if [ -z "${prompt}" ]
  then
    echo "You must provide a prompt" >&2
    exit 1
  fi

  if [ -z "${2}" ]
  then
    echo "You must provide a result variable" >&2
    exit 1
  fi

  # Make the result variable a nameref this means we'll write the result to a variable that the caller can view
  local -n result=$2

  while [ -z "${result}" ]
  do
    read -p "${prompt}" result
  done
}

confirm () {
  local prompt=$1

  if [ -z "${prompt}" ]
  then
    echo "You must provide a prompt" >&2
    exit 1
  fi

  read -p "${prompt}" -n 1 -r
  echo ""
  [[ ${REPLY} =~ ^[Yy]$ ]]
}

NETWORK_PREFIX=10.10.10
PREFIX_LENGTH=8
GATEWAY=10.0.0.1
BROADCAST=10.255.255.255
DNS="10.0.0.100 10.0.0.200"
DOMAIN=internal.curnowtopia.com

while [ -z ${ip_last_octet} ]
do
  prompt "Enter last octet of the desired IP address: " ip_last_octet
  if [ $((${ip_last_octet})) -lt 1 ] || [ $((${ip_last_octet})) -gt 255 ]
  then
    echo "Invalid IP format must be in the range 1-255" >&2
    unset ip_last_octet
  else
    if ! confirm "New IP: '${NETWORK_PREFIX}.${ip_last_octet}', is this correct? (Y/n): "
    then
      unset ip_last_octet
    fi
  fi
done


echo "Removing template network config"
rm /etc/systemd/network/*.network

echo "Creating static network config for ens18 with IP '${NETWORK_PREFIX}.${ip_last_octet}'"
cat <<EOF > /etc/systemd/network/ens18.network
[Match]
Name=ens18

[Network]
# Do not provision an ipv6 address
IPv6LinkLocalAddressGenerationMode=none

[Route]
Gateway=${GATEWAY}

[Address]
Address=${NETWORK_PREFIX}.${ip_last_octet}/${PREFIX_LENGTH}
Broadcast=${BROADCAST}
EOF

echo "Regenerating SSH host keys"
ssh-keygen -A
