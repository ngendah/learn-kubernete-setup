# SETUP WORKER NODE
# KUBELET

# Run the script on the master node

export MASTER_1=192.168.122.204
export WORKER_1=192.168.122.4
export SERVICE_CIDR=10.96.0.0/24
export API_SERVICE=10.96.0.1
export CLUSTER_DNS=10.96.0.10
export CLUSTER_NAME="kubernetes"
export POD_CIDR=10.244.0.0/16
export INTERNAL_IP=$MASTER_1
export KUBERNETES_VERSION=v1.24.3


export NODE=$WORKER_1

# get worker host name
chmod +x worker-hostname.sh
scp worker-hostname.sh $NODE:~
export NODE_HOSTNAME=`ssh $NODE "bash -c ~/worker-hostname.sh"`

# download kubelet binary
cat<<EOF | ssh $NODE
wget -q --show-progress --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/KUBERNETES_VERSION/bin/linux/amd64/kubelet
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
    clientCAFile: /var/lib/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
clusterDomain: cluster.local
clusterDNS:
  - ${CLUSTER_DNS}
resolvConf: /run/systemd/resolve/resolv.conf
runtimeRequestTimeout: "15m"
tlsCertFile: /var/lib/kubernetes/pki/kubelet.crt
tlsPrivateKeyFile: /var/lib/kubernetes/pki/kubelet.key
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
  --config=/var/lib/kubelet/$NODE_HOSTNAME-kubelet-config.yaml \\
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
cat<<EOF | ssh $NODE
sudo mv -v ~/$NODE_HOSTNAME.kubelet-config.yaml /var/lib/kubernetes/
sudo mv -v ~/"$NODE_HOSTNAME".kubelet.service /etc/systemd/system/
sudo chmod -v 600 /var/lib/kubernetes/$NODE_HOSTNAME.kubelet-config.yaml
sudo chmod -v 600 /etc/systemd/system/$NODE_HOSTNAME.kubelet.service
EOF
