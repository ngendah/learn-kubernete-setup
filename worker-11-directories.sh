# SETUP WORKER NODE
# create required directories

export MASTER_1=192.168.122.204
export WORKER_1=192.168.122.4

cat<<EOF | ssh $WORKER_1
sudo mkdir -vp \\
  /var/lib/kubelet \\
  /var/lib/kube-proxy \\
  /etc/kubernetes/pki
EOF