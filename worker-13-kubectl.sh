# SETUP WORKER NODE

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

# execute commands on worker node
cat<<EOF | ssh $NODE
wget -q --show-progress --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kubectl
sudo mv -v ./kubectl /usr/local/bin/
sudo chmod -v +x /usr/local/bin/kubectl
sudo chown -v root:root /usr/local/bin/kubectl
sudo chmod -v 600 /usr/local/bin/kubectl
EOF
