#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

# shellcheck disable=SC2155
export MASTER_1=$(jq -r '.nodes.control_plane.ip' cluster-config.json)
export WORKER_1=$(jq -r '.nodes.worker.ip' cluster-config.json)
export SERVICE_CIDR=$(jq -r '.service_cidr' cluster-config.json)
export CLUSTER_NAME=$(jq '.cluster_name' cluster-config.json)
export CLUSTER_DOMAIN_NAME=$(jq '.domain_name' cluster-config.json)
export POD_CIDR=$(jq -r '.pod_cidr' cluster-config.json)
export KUBERNETES_VERSION=$(jq -r '.version' cluster-config.json)
export API_SERVICE=$(echo "$SERVICE_CIDR" | sed 's/0\/24/1/g')
export CLUSTER_DNS=$(echo "$SERVICE_CIDR" | sed 's/0\/24/10/g')

export DATA_DIR=$(pwd)/$(jq -r '.script_data_dir' cluster-config.json)
export BIN_DIR=$(jq -r '.nodes.paths.bin' cluster-config.json)
export SERVICES_DIR=$(jq -r '.nodes.paths.services' cluster-config.json)
export CA_FILE_NAME="ca"

export MASTER_HOME_DIR=$(jq -r '.nodes.control_plane.kubernetes.paths.config' cluster-config.json)
export MASTER_CERT_DIR=$(jq -r '.nodes.control_plane.kubernetes.paths.certificates' cluster-config.json)
export MASTER_AUDIT_LOG_DIR=$(jq -r '.nodes.control_plane.kubernetes.paths.audit_log' cluster-config.json)
export MASTER_CONFIG_DIR=$MASTER_HOME_DIR
export MASTER_BIN_DIR=$BIN_DIR
export MASTER_SERVICES_DIR=$SERVICES_DIR

export WORKER_HOME_DIR=$(jq -r '.nodes.worker.kubernetes.paths.config' cluster-config.json)
export WORKER_CERT_DIR=$(jq -r '.nodes.worker.kubernetes.paths.certificates' cluster-config.json)
export WORKER_CONFIG_DIR=$WORKER_HOME_DIR
export WORKER_BIN_DIR=$BIN_DIR
export WORKER_SERVICES_DIR=$SERVICES_DIR

export KUBELET_HOME_DIR=$(jq -r '.nodes.worker.kubelet.paths.config' cluster-config.json)
export KUBELET_CERT_DIR=$(jq -r '.nodes.worker.kubelet.paths.certificates' cluster-config.json)
export KUBELET_CONFIG_DIR=$KUBELET_HOME_DIR

export KUBE_PROXY_HOME_DIR=$(jq -r '.nodes.worker.kube_proxy.paths.config' cluster-config.json)
export KUBE_PROXY_CERT_DIR=$(jq -r '.nodes.worker.kube_proxy.paths.certificates' cluster-config.json)
export KUBE_PROXY_CONFIG_DIR=$KUBE_PROXY_HOME_DIR

export ETCD_NAME=$(hostname -s)
export ETCD_VERSION=$(jq -r '.nodes.control_plane.etcd.version' cluster-config.json)
export ETCD_DIR=$(jq -r '.nodes.control_plane.etcd.paths.config' cluster-config.json)
export ETCD_DATA_DIR=$(jq -r '.nodes.control_plane.etcd.paths.data_dir' cluster-config.json)

export INTERNAL_IP=$MASTER_1
export NODE=$WORKER_1

# check control node ip address
count=0
for IP in $(hostname -I); do
  if [ "$IP" == "$MASTER_1" ]; then
    ((count += 1))
  fi
done

if [ $count -eq 0 ]; then
  echo "control node IP has not been set"
  exit 1
fi

# check worker node ip address
count=0
for IP in $(ssh -o ConnectTimeout=1 $NODE hostname -I); do
  if [ "$IP" == "$NODE" ]; then
    ((count += 1))
  fi
done

if [ $count -eq 0 ]; then
  echo "worker node is unreachable on IP: $NODE, using the command: ssh $NODE"
  exit 1
fi

# check node user sudo permission doesn't require password
if [ "$(ssh $NODE sudo find /etc/sudoers.d/ -name $USER -type f)" == "" ]; then
  echo "enable node user $USER sudoers, by adding $USER to sudoers.d directory"
  exit 1
fi

# check swap is off
if [ "$(ssh -o ConnectTimeout=1 $NODE sudo swapon -s)" != "" ]; then
  echo "disable swap on worker node"
  exit 1
fi

master_check_dirs_and_create() {
  if [ ! -f $DATA_DIR ]; then
    mkdir -p $DATA_DIR
  fi
  DIRS=$(jq ".nodes.control_plane.kubernetes.paths[]" cluster-config.json | tr -d '\n' | sed 's/""/" "/g' | sed 's/"//g')
  for DIR in $DIRS; do
    if [ ! -f $DIR ]; then
      sudo mkdir -vp $DIR
    fi
  done
  DIRS=$(jq ".nodes.control_plane.etcd.paths[]" cluster-config.json | tr -d '\n' | sed 's/""/" "/g' | sed 's/"//g')
  for DIR in $DIRS; do
    if [ ! -f $DIR ]; then
      sudo mkdir -vp $DIR
    fi
  done
}

worker_check_dirs_and_create() {
  ssh -T $NODE sudo mkdir -vp $(jq ".nodes.worker.kubernetes.paths[]" cluster-config.json | tr -d '\n' | sed 's/""/" "/g' | sed 's/"//g')
  ssh -T $NODE sudo mkdir -vp $(jq ".nodes.worker.kubelet.paths[]" cluster-config.json | tr -d '\n' | sed 's/""/" "/g' | sed 's/"//g')
  ssh -T $NODE sudo mkdir -vp $(jq ".nodes.worker.kube_proxy.paths[]" cluster-config.json | tr -d '\n' | sed 's/""/" "/g' | sed 's/"//g')
}

master_ca_exists() {
  if [ ! -f $MASTER_CERT_DIR/$CA_FILE_NAME.key ] || [ ! -f $MASTER_CERT_DIR/$CA_FILE_NAME.crt ]; then
    echo "Certificate authority has not been created, run CA-certificate.sh script first"
    exit 1
  fi
  if [ -f $DATA_DIR/$CA_FILE_NAME.crt ] && [ -f $MASTER_CERT_DIR/$CA_FILE_NAME.crt ]; then
    shaf1=$(sha256sum $DATA_DIR/$CA_FILE_NAME.crt | cut -d " " -f1)
    shaf2=$(sha256sum $MASTER_CERT_DIR/$CA_FILE_NAME.crt | cut -d " " -f1)
    if [ $shaf1 != $shaf2 ]; then
      echo "! Differing Certificate authority files, remove-all and restart"
      exit 1
    fi
  fi
}
