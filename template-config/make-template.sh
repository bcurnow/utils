#!/bin/bash
#
# Reconfigures the VM to be a proxmox template
#
if [ ${EUID} -eq 0 ]
then
  echo "This script must not be run as root" >&2
  echo "Please ensure the following commands are run as the non-root user before executing:"
  echo "  set +o history # Turns off history for the current shell"
  echo "  history -c     # Clears current history"
  echo "This will ensure there's no extraneous command history when the template is cloned"
  exit 1
fi

echo "Checking /opt/template-config scripts for changes"
mkdir -p /tmp/template-config
curl --silent -o /tmp/template-config/make-template.sh --location  https://github.com/bcurnow/utils/raw/main/template-config/make-template.sh
if [ $? -ne 0 ]
then
  echo "Download of make-template.sh failed" >&2
  exit 1
fi
curl --silent -o /tmp/template-config/config-template.sh --location  https://github.com/bcurnow/utils/raw/main/template-config/config-template.sh
if [ $? -ne 0 ]
then
  echo "Download of config-template.sh failed" >&2
  exit 1
fi

scripts_changed=false
diff /opt/template-config/make-template.sh /tmp/template-config/make-template.sh >/dev/null
if [ $? -ne 0 ]
then
  scripts_changed=true
fi

diff /opt/template-config/config-template.sh /tmp/template-config/config-template.sh >/dev/null
if [ $? -ne 0 ]
then
  scripts_changed=true
fi

rm -rf /tmp/template-config
if ${scripts_changed}
then
  echo "/opt/template-config scripts changes, can not make templates until the content is synced with GitHub" >&2
  exit 1
fi

echo "Clearing /opt/template-config"
sudo rm -rf /opt/template-config

echo "Ensuring hostname is 'debian-template'"
echo "debian-template" | sudo tee /etc/hostname > /dev/null

echo "Updating /etc/hosts"
sudo tee /etc/hosts << EOF
127.0.0.1	localhost
127.0.0.1	debian-template.internal.curnowtopia.com	debian-template
EOF

echo "Clearing the machine id"
sudo tee /etc/machine-id < /dev/null > /dev/null

echo "Removing systemd-networkd configurations"
sudo rm /etc/systemd/network/*.network

echo "Setting up DHCP systemd-networkd configuration"
sudo tee /etc/systemd/network/template.network > /dev/null << EOF
[Match]
Name=ens18

[Network]
# Do not provision an ipv6 address
IPv6LinkLocalAddressGenerationMode=none
DHCP=yes
EOF

echo "Clearing SSH keys"
sudo rm -f /etc/ssh/ssh_host_*

echo "Clearing bcurnow configuration and history"
rm -rf /home/bcurnow/.ssh/
rm -f /home/bcurnow/anaconda-ks.cfg
rm -f /home/bcurnow/.bash_history
rm -f /home/bcurnow/.lesshst
rm -rf /home/bcurnow/.local

# Setup authorized key login for the bcurnow user
mkdir -p /home/bcurnow/.ssh
chmod 500 /home/bcurnow/.ssh
cat <<EOF >/home/bcurnow/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDJMQ7gGnSRqhGbeiFm3MAfJ2DzJc3UMPBazhZIoXYLbKXaUFKPV2YuvTDeaXEa1UiAoxQJmhq94ABc2kPBfdfPSVd0elOKiKBbdpwO5PrKxK3DpxdX46GgKp0kRW8a3UgAUOuo0nigaEd7pWlkJ8+zxR0aFzfpbRiqIHTT8L3gVsRiQIrs0vkwn7sUMQs7ODJGz2bBuL6aI5aPyiyxoMlLfeo7AabnBIXCM5Bfym6m0/KmUkSugWyOgKXMCscBNiclC3QO/ExjouKnrlXQg9f/+I2J3FAex/QRRl1m7G1NPYygd1NIVcoNCIrU4g5aZkKqCk0DZC08mKVZ2zuRtqaluGMEfYd6LMGXSjuaFYDmtybvwEgvSlT9fkDCZcwF65YBnHXdr/QNWG4D5U3tXh5o4H202o6rsdsVhIsKIAkFqiiiC3yeCWiDVR2wQNENNkMbL/7tZMSqRm31iJjvQNuCBPpu6Z59DNkmZqb8dDgrOyi8SREBKf7FLuKx/jp7R4k= Brian.Curnow@T07M6PT2TT
EOF

echo "Clearing root configuration and history"
sudo rm -rf /root/.ssh/
sudo rm -f /root/anaconda-ks.cfg
sudo rm -f /root/.bash_history
sudo rm -f /root/.lesshst
sudo rm -rf /root/.local

echo "Clearing ansible configuration and history"
sudo rm -f /home/ansible/.ssh/known_hosts
sudo rm -f /home/ansible/anaconda-ks.cfg
sudo rm -f /home/ansible/.bash_history
sudo rm -f /home/ansible/.lesshst
sudo rm -rf /home/ansible/.local

echo "Clearing apt caches"
sudo apt-get autoremove -y
sudo apt-get clean -y
sudo apt-get autoclean -y

echo "Removing logs"
sudo rm -f /var/log/boot.log
sudo rm -f /var/log/cron
sudo rm -f /var/log/dmesg
sudo rm -f /var/log/grubby
sudo rm -f /var/log/lastlog
sudo rm -f /var/log/maillog
sudo rm -f /var/log/messages
sudo rm -f /var/log/secure
sudo rm -f /var/log/spooler
sudo rm -f /var/log/tallylog
sudo rm -f /var/log/wpa_supplicant.log
sudo rm -f /var/log/wtmp
sudo rm -f /var/log/yum.log
sudo rm -f /var/log/audit/audit.log
sudo rm -f /var/log/ovirt-guest-agent/ovirt-guest-agent.log
sudo rm -f /var/log/tuned/tuned.log

read -p "Press any key to shutdown" -n 1 -r

echo "Shutting down"
sudo /usr/sbin/shutdown now
