#!/bin/bash
#
# To be run after cloning a VM that was prepared with make-template.sh
#

prompt () {
  local prompt=$1
  local result_name=$2
  local validation_function=$3
  local default_value=$4

  if [ -z "${prompt}" ]
  then
    echo "You must provide a prompt" >&2
    return 1
  fi

  if [ -z "${validation_function}" ]
  then
    validation_function=check_yes
  fi

  if [ -z "${result_name}" ]
  then
    echo "You must provide a result variable name" >&2
    return 1
  fi

  if [ -n "${default_value}" ]
  then
    prompt="${prompt} [${default_value}]"
  fi

  # Make the result variable a nameref this means we'll write the result to a variable that the caller can view
  local -n result_var="${result_name}"

  while true
  do
    read -p "${prompt}: " ${result_name}

    if [ -z "${result_var}" ]
    then
      if [ -n "${default_value}" ]
      then
        printf -v "${result_name}" "%s" "${default_value}"
      fi
    fi

    if [ -n "${result_var}" ]
    then
      if ! $(${validation_function} "${result_var}")
      then
        unset "${result_name}"
      fi
    fi
    [ -z "${result_var}" ] || break
  done
}

confirm () {
  local prompt=$1

  if [ -z "${prompt}" ]
  then
    echo "You must provide a prompt" >&2
    return 1
  fi

  read -p "${prompt} (Y/n): " -n 1 -r
  echo ""
  [[ ${REPLY} =~ ^[Yy]$ ]]
}

function check_yes () {
  return 0
}

check_numeric () {
  local type=$1
  local -i nbr=$2
  local -i min=$3
  local -i max=$4
  local quiet=$5

  if [ -z "${type}" ]
  then
    echo "You must provide a type" >&2
  fi

  if [ -z "${nbr}" ]
  then
    echo "${type} must have a value" >&2
    return 1
  fi

  if [ -z "${min}" ]
  then
    min=0
  fi

  if [ -z "${max}" ]
  then
    max=255
  fi

  if [ -z "${quiet}" ]
  then
    quiet=true
  fi

  if [ ${nbr} -lt ${min} ] || [ ${nbr} -gt ${max} ]
  then
    echo "Invalid ${type} '${nbr}', must be in the range ${min}-${max}" >&2
    return 1
  fi

  return 0
}

check_ip_addr () {
  local ip=$1

  if [ -z "${ip}" ]
  then
    echo "You must provide an IP address to check" >&2
    return 1
  fi

  local octets=($(echo "${ip}" | tr "." " "))

  if [ "${#octets[@]}" -lt 4 ] || [ "${#octets[@]}" -gt 4 ]
  then
    echo "Wrong number of octets, expected 4 but got ${#octets[@]}" >&2
    return 1
  fi

  local min
  for i in "${!octets[@]}"
  do
    if [ ${i} -eq 0 ]
    then
      min=1
    else
       min=0
    fi

    if ! check_numeric "IP octet" "${octets[i]}" ${min} 255 false
    then
      return 1
    fi
  done

  return 0
}

check_ip_prefix () {
  local -i prefix=$1

  if check_numeric "prefix" ${prefix} 1 32
  then
    return 0
  fi

  return 1
}

check_dns_servers () {
  local servers=($1)

  if [ ${#servers[@]} -eq 0 ]
  then
    echo "You must provide a list of servers" >&2
    return 1
  fi

  for i in ${!servers[@]}
  do
    echo "Validating DNS server '${servers[i]}'" >&2
    if ! check_ip_addr ${servers[i]}
    then
      return 1
    fi
  done

  return 0
}

if [ ${EUID} -ne 0 ]
then
  echo "You must run as root" >&2
  exit 1
fi

dns_servers="10.0.0.100 10.0.0.200"
gateway=10.0.0.1
broadcast=10.255.255.255
domain=internal.curnowtopia.com


prompt "Enter the new IP address" ip_addr check_ip_addr
prompt "Enter the IP prefix length" ip_prefix check_ip_prefix "8"
prompt "Enter the gatway address" gateway check_ip_addr "${gateway}"
prompt "Enter the broadcast address" broadcast check_ip_addr "${broadcast}"
prompt "Enter the DNS servers" dns_servers check_dns_servers "${dns_servers}"
prompt "Enter the DNS search domain" domain check_yes "${domain}"
prompt "Enter the new hostname" hostname
echo "---"
echo "New VM config:"
echo "  IP Address: ${ip_addr}/${ip_prefix}"
echo "  Gateway: ${gateway}"
echo "  Broadcast: ${broadcast}"
echo "  Hostname: ${hostname}"
echo "  DNS Servers:"
for dns_server in ${dns_servers}
do
  echo "    ${dns_server}"
done
echo "  DNS Search Domain: ${domain}"
echo "---"

if ! confirm "Is the above correct?"
then
  exit 1
fi

echo "Removing template network config"
rm /etc/systemd/network/*.network

echo "Creating static network config for ens18"
cat <<EOF > /etc/systemd/network/ens18.network
[Match]
Name=ens18

[Network]
# Do not provision an ipv6 address
IPv6LinkLocalAddressGenerationMode=none

[Route]
Gateway=${gateway}

[Address]
Address=${ip_addr}/${ip_prefix}
Broadcast=${broadcast}
EOF

echo "Updating hostname"
echo "${hostname}" > /etc/hostname

echo "Updating /etc/hosts"
cat <<EOF > /etc/hosts
127.0.0.1	localhost
127.0.0.1	${hostname}.${domain}	${hostname}
EOF

echo "Creating /etc/systemd/resolved.conf"
echo "[Resolve]" > /etc/systemd/resolved.conf
for dns_server in ${dns_servers}
do
  echo "DNS=${dns_server}" >> /etc/systemd/resolved.conf
done
echo "Domains=${domain}" >> /etc/systemd/resolved.conf

echo "Regenerating SSH host keys"
ssh-keygen -A

echo "Cleaning out /opt/template-config"
rm -rf /opt/template-config

read -p "Press any key to reboot..." -n 1 -r

reboot
