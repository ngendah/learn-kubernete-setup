#!/usr/bin/env bash

# shellcheck disable=SC2155
export MASTER_1=$(jq -r '.nodes.control_plane.ip' cluster-config.json)
export WORKER_1=$(jq -r '.nodes.worker.ip' cluster-config.json)
export SERVICE_CIDR=$(jq -r '.service_cidr' cluster-config.json)
export CLUSTER_NAME=$(jq '.cluster_name' cluster-config.json)
export POD_CIDR=$(jq -r '.pod_cidr' cluster-config.json)
export KUBERNETES_VERSION=$(jq -r '.version' cluster-config.json)
export API_SERVICE=$(echo "$SERVICE_CIDR" | sed 's/0\/24/1/g')
export CLUSTER_DNS=$(echo "$SERVICE_CIDR" | sed 's/0\/24/10/g')

export DATA_DIR=$(jq -r '.script_data_dir' cluster-config.json)
export BIN_DIR=$(jq -r '.nodes.paths.bin' cluster-config.json)
export SERVICES_DIR=$(jq -r '.nodes.paths.services' cluster-config.json)

export MASTER_HOME_DIR=$(jq -r '.nodes.control_plane.kubernetes.paths.config' cluster-config.json)
export MASTER_CERT_DIR=$(jq -r '.nodes.control_plane.kubernetes.paths.certificates' cluster-config.json)
export MASTER_BIN_DIR=$BIN_DIR
export MASTER_SERVICES_DIR=$SERVICES_DIR

export WORKER_HOME_DIR=$(jq -r '.nodes.worker.kubernetes.paths.config' cluster-config.json)
export WORKER_CERT_DIR=$(jq -r '.nodes.worker.kubernetes.paths.certificates' cluster-config.json)
export WORKER_BIN_DIR=$BIN_DIR
export WORKER_SERVICES_DIR=$SERVICES_DIR

export KUBELET_HOME_DIR=$(jq -r '.nodes.worker.kubelet.paths.config' cluster-config.json)
export KUBELET_CERT_DIR=$(jq -r '.nodes.worker.kubelet.paths.certificates' cluster-config.json)

export KUBE_PROXY_HOME_DIR=$(jq -r '.nodes.worker.kube_proxy.paths.config' cluster-config.json)
export KUBE_PROXY_CERT_DIR=$(jq -r '.nodes.worker.kube_proxy.paths.certificates' cluster-config.json)

export ETCD_NAME=$(hostname -s)
export ETCD_VERSION=$(jq -r '.nodes.control_plane.etcd.version' cluster-config.json)
export ETCD_DOWNLOAD_FILE="etcd-$ETCD_VERSION-linux-amd64"
export ETCD_DIR=$(jq -r '.nodes.control_plane.etcd.paths.config' cluster-config.json)
export ETCD_DATA_DIR=$(jq -r '.nodes.control_plane.etcd.paths.data_dir' cluster-config.json)

export INTERNAL_IP=$MASTER_1
export NODE=$WORKER_1