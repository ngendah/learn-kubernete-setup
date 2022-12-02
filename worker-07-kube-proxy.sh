#!/usr/bin/env bash

# SETUP WORKER NODE
# KUBE-PROXY

# Run the script on the master node
# shellcheck disable=SC2155
export MASTER_1=$(jq -r '.master_node_ip' cluster-config.json)
export WORKER_1=$(jq -r  '.worker_node_ip' cluster-config.json)
export SERVICE_CIDR=$(jq -r '.service_cidr' cluster-config.json)
export CLUSTER_NAME=$(jq '.cluster_name' cluster-config.json)
export POD_CIDR=$(jq -r '.pod_cidr' cluster-config.json)
export KUBERNETES_VERSION=$(jq -r '.kubernetes_version' cluster-config.json)
export API_SERVICE=$(echo "$SERVICE_CIDR" | sed 's/0\/24/1/g')
export CLUSTER_DNS=$(echo "$SERVICE_CIDR" | sed 's/0\/24/10/g')
export INTERNAL_IP=$MASTER_1

export NODE=WORKER_1

# get node host name
export NODE_HOSTNAME=$(ssh $NODE sudo hostname -s)

# download kube-proxy binary
cat<<EOF | ssh $NODE
wget -q --show-progress --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/KUBERNETES_VERSION/bin/linux/amd64/kube-proxy
sudo mv -v ./kubectl /usr/local/bin/
sudo chmod -v +x /usr/local/bin/kube-proxy
sudo chown -v root:root /usr/local/bin/kube-proxy
sudo chmod -v 600 /usr/local/bin/kube-proxy
EOF

# create kube-proxy configurations
cat<<EOF | tee kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kube-proxy.kubeconfig"
mode: "iptables"
clusterCIDR: ${POD_CIDR}
EOF

cat <<EOF | tee kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

scp kube-proxy-config.yaml kube-proxy.service $NODE:~
cat<<EOF | ssh $NODE
sudo mv -v ~/kube-proxy-config.yaml /var/lib/kube-proxy/
sudo mv -v ~/kube-proxy.service /etc/systemd/system/
sudo chmod -v 600 /var/lib/kube-proxy/kube-proxy-config.yaml
sudo chmod -v 600 /etc/systemd/system/kube-proxy.service
EOF
