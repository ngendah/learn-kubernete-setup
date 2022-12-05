#!/usr/bin/env bash

source common.sh

# get worker host name
export NODE_HOSTNAME=$(ssh $NODE sudo hostname -s)

# download kubelet binary
cat<<EOF | ssh -T $NODE
echo "Downloading kubelet-$KUBERNETES_VERSION"
wget -q --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/KUBERNETES_VERSION/bin/linux/amd64/kubelet
sudo mv -v ./kubectl /usr/local/bin/
sudo chmod -v +x /usr/local/bin/kubelet
sudo chown -v root:root /usr/local/bin/kubelet
sudo chmod -v 600 /usr/local/bin/kubelet
EOF


cat<<EOF | tee $NODE_HOSTNAME-kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: $WORKER_CERT_DIR/ca.crt
authorization:
  mode: Webhook
clusterDomain: cluster.local
clusterDNS:
  - ${CLUSTER_DNS}
resolvConf: /run/systemd/resolve/resolv.conf
runtimeRequestTimeout: "15m"
tlsCertFile: $WORKER_CERT_DIR/kubelet.crt
tlsPrivateKeyFile: $WORKER_CERT_DIR/kubelet.key
registerNode: true
EOF

cat<<EOF | tee $NODE_HOSTNAME-kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=/var/lib/kubelet/kubelet.kubeconfig \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# copy generated files
scp $NODE_HOSTNAME.kubelet-config.yaml $NODE_HOSTNAME.kubelet.service $NODE:~

# execute commands on worker node
cat<<EOF | ssh -T $NODE
sudo mv -v ~/$NODE_HOSTNAME.kubelet-config.yaml /var/lib/kubelet/kubelet-config.yaml
sudo mv -v ~/"$NODE_HOSTNAME".kubelet.service /etc/systemd/system/kubelet.service
EOF
