#!/bin/bash
#
# Sets up a server to be used with Ansible
#

if [ ${EUID} -ne 0 ]
then
  echo "You must run as root" >&2
  exit 1
fi

if [ ! -d /opt/ansible/.ssh ]
then
  echo "Missing /opt/ansible/.ssh, can not continue" >&2
  exit 2
fi

if [ ! -r /opt/ansible/.ssh/id_rsa ]
then
  echo "Missing /opt/ansible/ssh/id_rsa, can not continue" >&2
fi

hostname=
while [ -z "${hostname}" ]
do
  read -p "Hostname to bootstrap: " hostname
done

default_username=bcurnow
username=
while [ -z "${username}" ]
do
  read -p "Username to bootstrap with [${default_username}]: " username

  if [ -z "${username}" ]
  then
    username=${default_username}
  fi
done

# Generate the bootstrap script
cat <<BOOTSTRAP > /tmp/${username}@${hostname}.bootstrap

echo "Sudo permissions:"
sudo -l

echo "Adding ansible user"
sudo /usr/sbin/adduser --quiet --comment "Ansible User" --home /home/ansible --shell /bin/bash --disabled-password ansible

echo "Setting up sudo permissions for ansible user"
sudo tee /etc/sudoers.d/ansible >/dev/null <<EOF
ansible ALL=(ALL) NOPASSWD: ALL
EOF

echo "Setting up certificate login for ansible user"
sudo tee /home/ansible/.ssh/authorized_keys >/dev/null <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDI/D0pCrYAm2YLhG0mjxo3UCFYJu/UqByGqcXg6T8eXb0Ctcy4kB1KAdWi6S/rSurw0Ph6MXDV6U9yIwBHjXmWfsqAKPJyHyKWZliZAmcmME0sTg7j3QGpyUtI83ufe/Ic9jSzQjLz6/pTaV+A68ppySlK2bwmJz/wYBkxgOu1sfGm8QdTI8uVtkHtaJQEBywkLNgkVfdmPrfnUd8g3zpWtXupWygJxN4TuMY3EASzeaCTSu3l3S8RHUFVjN6YQkbHT7D1KVxrzxpdTPOrwkwcOL5u2392l0fQ8h+Iz9PHd/IXahf7J11tuXjlw/CklyyiN5x+i+c8lFrlqTqmv5ld05O1ImYA6ObZ7wGgDgTFkDpczdhO7z6fWCg8SKOSHty4GRbjbBJWWi2c31hn/wbFNax6+pbYhAL8G+oMRn1qqUU5HSFYb6o/iL75u5gKZeKYaubTyEqV+aREAgSlPP16gfSX1IhcPMjm9zoF/VUCiXzfF1e/tdBAN3efPrB6B/8= Ansible ssh login key
EOF
BOOTSTRAP

echo "Bootstrapping ${hostname} as ${username}"
ssh ${username}@${hostname} 'bash -s' < /tmp/${username}@${hostname}.bootstrap

if [ $? -eq 0 ]
then
  echo "Bootstrap script successful, validating setup"
  ssh ansible@${hostname} -i /opt/ansible/.ssh/id_rsa 'echo "Setup validated"'

  if [ $? -ne 0 ]
  then
    echo "Validation failed!" >&2
    exit 1
  fi
  # Only cleanup the script if everything was successful
  rm /tmp/${username}@${hostname}.bootstrap
else
  echo "Bootstrap script failed, see /tmp/${username}@${hostname}.bootstrap and log above >&s
  exit 1
fi

