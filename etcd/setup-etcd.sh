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

etcd_version=v3.5.11
etcd_url=https://github.com/etcd-io/etcd/releases/download

prompt "Enter the node name (e.g. k8setcd1)" node_name 
prompt "Enter the etcd vesion" etcd_version ${etcd_version}
prompt "Enter the etcd download URL" etcd_url ${etcd_url}

echo "Downloading etcd ${etcd_version}"
etcd_temp_dir=/tmp/etcd-${etcd_version}-temp

#rm -f /tmp/etcd-${etcd_version}-linux-amd64.tar.gz
rm -rf ${etcd_temp_dir}
mkdir -p ${etcd_temp_dir}

curl --silent --location ${etcd_url}/${etcd_version}/etcd-${etcd_version}-linux-amd64.tar.gz -o ${etcd_temp_dir}/etcd-${etcd_version}-linux-amd64.tar.gz
tar xzvf ${etcd_temp_dir}/etcd-${etcd_version}-linux-amd64.tar.gz -C ${etcd_temp_dir} --strip-components=1
rm -f ${etcd_temp_dir}/etcd-${etcd_version}-linux-amd64.tar.gz


