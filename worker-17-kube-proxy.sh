# SETUP WORKER NODE
# KUBE-PROXY

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


export NODE=WORKER_1

# get node host name
chmod +x worker-hostname.sh
scp worker-hostname.sh $NODE:~
export NODE_HOSTNAME=`ssh $NODE "bash -c ~/worker-hostname.sh"`

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
