# SETUP CONTROL-PLANE ON MASTER NODE
# KUBECTL

export MASTER_1=192.168.122.204
export WORKER_1=192.168.122.4
export SERVICE_CIDR=10.96.0.0/24
export API_SERVICE=10.96.0.1
export CLUSTER_NAME="kubernetes"
export POD_CIDR=10.244.0.0/16

export INTERNAL_IP=$MASTER_1
export KUBERNETES_VERSION=v1.24.3

wget --show-progress --https-only --timestamping \
        "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kubectl"

sudo mv -v kubectl /usr/local/bin/
