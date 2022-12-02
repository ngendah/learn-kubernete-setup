#!/usr/bin/env bash

# Run the script on the master node
# shellcheck disable=SC2155
export MASTER_1=$(jq -r '.master_node_ip' cluster-config.json)
export WORKER_1=$(jq -r '.worker_node_ip' cluster-config.json)
export SERVICE_CIDR=$(jq -r '.service_cidr' cluster-config.json)
export CLUSTER_NAME=$(jq '.cluster_name' cluster-config.json)
export POD_CIDR=$(jq -r '.pod_cidr' cluster-config.json)
export KUBERNETES_VERSION=$(jq -r '.kubernetes_version' cluster-config.json)
export API_SERVICE=$(echo "$SERVICE_CIDR" | sed 's/0\/24/1/g')
export CLUSTER_DNS=$(echo "$SERVICE_CIDR" | sed 's/0\/24/10/g')
export INTERNAL_IP=$MASTER_1

export NODE=$WORKER_1

# execute commands on worker node
cat<<EOF | ssh -T $NODE
echo "Downloading kubectl-$KUBERNETES_VERSION"
wget -q --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kubectl
sudo mv -v ./kubectl /usr/local/bin/
sudo chmod -v +x /usr/local/bin/kubectl
sudo chown -v root:root /usr/local/bin/kubectl
sudo chmod -v 600 /usr/local/bin/kubectl
EOF
