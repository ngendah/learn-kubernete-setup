#!/usr/bin/env bash

# shellcheck disable=SC2155
export MASTER_1=$(jq -r '.nodes.control_plane.ip' cluster-config.json)
export WORKER_1=$(jq -r '.nodes.worker.ip' cluster-config.json)
export SERVICE_CIDR=$(jq -r '.service_cidr' cluster-config.json)
export CLUSTER_NAME=$(jq '.cluster_name' cluster-config.json)
export POD_CIDR=$(jq -r '.pod_cidr' cluster-config.json)
export KUBERNETES_VERSION=$(jq -r '.version.kubernetes' cluster-config.json)
export API_SERVICE=$(echo "$SERVICE_CIDR" | sed 's/0\/24/1/g')
export CLUSTER_DNS=$(echo "$SERVICE_CIDR" | sed 's/0\/24/10/g')
export ETCD_NAME=$(hostname -s)
export ETCD_VERSION=$(jq -r '.version.etcd' cluster-config.json)
export ETCD_DOWNLOAD_FILE="etcd-$ETCD_VERSION-linux-amd64"
export DATA_DIR=$(jq -r '.script_data_dir')
export MASTER_HOME_DIR=$(jq -r 'nodes.control_plane.paths.home')
export MASTER_CERT_DIR=$(jq -r 'nodes.control_plane.paths.certificates')
export MASTER_BIN_DIR=$(jq -r 'nodes.control_plane.paths.bin')
export MASTER_SERVICES_DIR=$(jq -r 'nodes.control_plane.paths.services')
export MASTER_ETCD_DIR=$(jq -r 'nodes.control_plane.paths.etcd')
export WORKER_HOME_DIR=$(jq -r 'nodes.worker.paths.home')
export WORKER_CERT_DIR=$(jq -r 'nodes.control_plane.paths.certificates')
export WORKER_BIN_DIR=$(jq -r 'nodes.control_plane.paths.bin')
export WORKER_SERVICES_DIR=$(jq -r 'nodes.control_plane.paths.services')
export INTERNAL_IP=$MASTER_1
export NODE=$WORKER_1
