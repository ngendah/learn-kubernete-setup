#!/usr/bin/env bash

source common.sh

# get node host name
export NODE_HOSTNAME=$(ssh $NODE sudo hostname -s)

# download kube-proxy binary
cat<<EOF | ssh -T $NODE
echo "Downloading kube-proxy-$KUBERNETES_VERSION"
wget -q --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/KUBERNETES_VERSION/bin/linux/amd64/kube-proxy
sudo mv -v ./kubectl /usr/local/bin/
sudo chmod -v +x /usr/local/bin/kube-proxy
EOF

# create kube-proxy configurations
cat<<EOF | tee kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kube-proxy.kubeconfig
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
cat<<EOF | ssh -T $NODE
sudo mv -v ~/kube-proxy-config.yaml /var/lib/kube-proxy/
sudo mv -v ~/kube-proxy.service /etc/systemd/system/
EOF
