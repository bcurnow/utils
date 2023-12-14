#!/bin/bash
#
# Reconfigures the VM to be a proxmox template
#
if [ ${EUID} -eq 0 ]
then
  echo "This script must not be run as root" >&2
  exit 1
fi

echo "Ensuring hostname is 'k8s-template'"
echo "k8s-template" | sudo tee /etc/hostname > /dev/null

echo "Updating /etc/hosts"
sudo tee /etc/hosts << EOF
127.0.0.1	localhost
127.0.0.1	k8s-template.internal.curnowtopia.com	k8s-template
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
sudo rm -rf /home/bcurnow/.ssh/
sudo rm -rf /home/bcurnow/anaconda-ks.cfg
sudo rm -rf /home/bcurnow/.bash_history

echo "Clearing root configuration and history"
sudo rm -rf /root/.ssh/
sudo rm -rf /root/anaconda-ks.cfg
sudo rm -rf /root/.bash_history

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

echo "Shutting down"
sudo /usr/sbin/shutdown now
