# SETUP WORKER NODE
# KUBELET

# Run the script on the master node
export MASTER_1=$(jq '.master_node_ip' cluster-config.json)
export WORKER_1=$(jq '.worker_node_ip' cluster-config.json)
export SERVICE_CIDR=$(jq '.service_cidr' cluster-config.json)
export CLUSTER_NAME=$(jq '.cluster_name' cluster-config.json)
export POD_CIDR=$(jq '.pod_cidr' cluster-config.json)
export KUBERNETES_VERSION=$(jq '.kubernetes_version' cluster-config.json | sed 's/"//g')
export API_SERVICE=$(echo $SERVICE_CIDR | sed 's/0\/24/1/g')
export CLUSTER_DNS=$(echo $SERVICE_CIDR | sed 's/0\/24/10/g')
export INTERNAL_IP=$MASTER_1


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
