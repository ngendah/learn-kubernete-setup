# SETUP WORKER NODE

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

# execute commands on worker node
cat<<EOF | ssh $NODE
wget -q --show-progress --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kubectl
sudo mv -v ./kubectl /usr/local/bin/
sudo chmod -v +x /usr/local/bin/kubectl
sudo chown -v root:root /usr/local/bin/kubectl
sudo chmod -v 600 /usr/local/bin/kubectl
EOF
