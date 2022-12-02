#!/usr/bin/env bash

# SETUP CONTROL-PLANE ON MASTER NODE
# KUBE-SCHEDULER
# shellcheck disable=SC2155
export MASTER_1=$(jq -r '.master_node_ip' cluster-config.json)
export WORKER_1=$(jq -r '.worker_node_ip' cluster-config.json)
export SERVICE_CIDR=$(jq -r '.service_cidr' cluster-config.json)
export CLUSTER_NAME=$(jq '.cluster_name' cluster-config.json)
export POD_CIDR=$(jq -r '.pod_cidr' cluster-config.json)
export KUBERNETES_VERSION=$(jq -r '.kubernetes_version' cluster-config.json)
export API_SERVICE=$(echo "$SERVICE_CIDR" | sed 's/0\/24/1/g')

export INTERNAL_IP=$MASTER_1

wget --show-progress --https-only --timestamping \
        "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kube-scheduler"

sudo mv -v kube-scheduler /usr/local/bin/

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \\
  --leader-elect=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
