#!/bin/bash

prompt () {
  local prompt=$1
  local result_name=$2
  local default_value=$3

  if [ -z "${prompt}" ]
  then
    echo "You must provide a prompt" >&2
    return 1
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

    [ -z "${result_var}" ] || break
  done
}

if [ ${EUID} -ne 0 ]
then
  echo "You must run as root" >&2
  exit 1
fi

node_name=$(hostname --short) 
node_ip=$(hostname -I)
fqdn=$(hostname --long) 
etcd_version=3.5.11
etcd_url=https://github.com/etcd-io/etcd/releases/download

prompt "Enter the node IP" node_ip ${node_ip}
prompt "Enter the node name" node_name ${node_name}
prompt "Enter the FQDN" fqdn ${fqdn}
prompt "Enter the etcd vesion" etcd_version ${etcd_version}
prompt "Enter the etcd download URL" etcd_url ${etcd_url}

echo "Installing etcd ${etcd_version} in /usr/bin"
adduser --quiet --comment "etcd user" --home /var/lib/etcd --no-create-home --shell /bin/false --disabled-password etcd

etcd_temp_dir=/tmp/etcd-v${etcd_version}-temp
rm -rf ${etcd_temp_dir}
mkdir -p ${etcd_temp_dir}
curl --silent --location ${etcd_url}/v${etcd_version}/etcd-v${etcd_version}-linux-amd64.tar.gz -o ${etcd_temp_dir}/etcd-v${etcd_version}-linux-amd64.tar.gz
tar xzf ${etcd_temp_dir}/etcd-v${etcd_version}-linux-amd64.tar.gz -C ${etcd_temp_dir} --strip-components=1
rm -f ${etcd_temp_dir}/etcd-v${etcd_version}-linux-amd64.tar.gz

mv ${etcd_temp_dir}/etcd /usr/bin/etcd
mv ${etcd_temp_dir}/etcdctl /usr/bin/etcdctl
mv ${etcd_temp_dir}/etcdutl /usr/bin/etcdutl

/usr/bin/etcd --version | grep ${etcd_version} >/dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "Wrong etcd version installed" >&2
  /usr/bin/etcd --version
  exit 1
fi

/usr/bin/etcdctl version | grep ${etcd_version} >/dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "Wrong etcdctl version installed" >&2
  /usr/bin/etcdctl version
  exit 1
fi

/usr/bin/etcdutl version | grep ${etcd_version} >/dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "Wrong etcdutl version installed" >&2
  /usr/bin/etcdutl version
  exit 1
fi

mkdir -p /etc/etcd
mkdir -p /var/lib/etcd
chown etcd:etcd /var/lib/etcd
chmod 700 /var/lib/etcd

echo "Setting up etcd certificates"
scp pi@atomicpi.internal.curnowtopia.com:/etc/docker-certs/client-auth/etcd-bundle.tar.gz ${etcd_temp_dir}/
tar xzf ${etcd_temp_dir}/etcd-bundle.tar.gz -C ${etcd_temp_dir} --strip-components=1
for file in ${node_name}.crt ${node_name}.key ca.crt
do
  mv ${etcd_temp_dir}/${file} /etc/etcd/
  chown etcd:etcd /etc/etcd/${file}
  chmod 400 /etc/etcd/${file}
done

echo "Setting up /etc/etcd/etcd.conf.yml"
cat <<EOF > /etc/etcd/etcd.conf.yml
name: ${node_name}
data-dir: /var/lib/etcd
heartbeat-interval: 1000
election-timeout: 5000
log-level: warn
discovery-srv: k8setcd.internal.curnowtopia.com
initial-cluster-token: k8setcd-cluster
initial-cluster-state: new
initial-advertise-peer-urls: https://${fqdn}:2380 
listen-peer-urls: https://${node_ip}:2380
listen-client-urls: https://${node_ip}:2379,https://127.0.0.1:2379
advertise-client-urls: https://${fqdn}:2379
tls-min-version: 'TLS1.3'
client-transport-security:
  cert-file: /etc/etcd/${node_name}.crt
  key-file: /etc/etcd/${node_name}.key
  client-cert-auth: true
  trusted-ca-file: /etc/etcd/ca.crt
peer-transport-security:
  cert-file: /etc/etcd/${node_name}.crt
  key-file: /etc/etcd/${node_name}.key
  client-cert-auth: true
  trusted-ca-file: /etc/etcd/ca.crt
EOF

echo "Setting up systemd"
cat <<EOF > /lib/systemd/system/etcd.service
[Unit]
Description=etcd service
Documentation=https://github.com/coreos/etcd

[Service]
User=etcd
Type=notify
ExecStart=/usr/bin/etcd --config-file=/etc/etcd/etcd.conf.yml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl enable etcd.service
systemctl start etcd.service
