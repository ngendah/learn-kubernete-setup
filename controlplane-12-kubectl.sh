# SETUP CONTROL-PLANE ON MASTER NODE
# KUBECTL

export MASTER_1=$(jq '.master_node_ip' cluster-config.json)
export WORKER_1=$(jq '.worker_node_ip' cluster-config.json)
export SERVICE_CIDR=$(jq '.service_cidr' cluster-config.json)
export CLUSTER_NAME=$(jq '.cluster_name' cluster-config.json)
export POD_CIDR=$(jq '.pod_cidr' cluster-config.json)
export KUBERNETES_VERSION=$(jq '.kubernetes_version' cluster-config.json | sed 's/"//g')
export API_SERVICE=$(echo $SERVICE_CIDR | sed 's/0\/24/1/g')

wget --show-progress --https-only --timestamping \
        "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kubectl"

sudo mv -v kubectl /usr/local/bin/
