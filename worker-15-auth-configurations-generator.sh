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

# get node host name
chmod +x worker-hostname.sh
scp worker-hostname.sh $NODE:~
export NODE_HOSTNAME=`ssh $NODE "bash -c ~/worker-hostname.sh"`


# generate kubectl configuration node
cat<<EOF | ssh $NODE
kubectl config set-cluster $CLUSTER_NAME \\
    --certificate-authority=/var/lib/kubernetes/pki/ca.crt \\
    --server=https://${MASTER_1}:6443 \\
    --kubeconfig=kubelet.kubeconfig

kubectl config set-credentials system:node:$NODE_HOSTNAME \\
    --client-certificate=/var/lib/kubernetes/pki/$NODE_HOSTNAME.crt \\
    --client-key=/var/lib/kubernetes/pki/$NODE_HOSTNAME.key \\
    --kubeconfig=kubelet.kubeconfig

kubectl config set-context default \\
    --cluster=$CLUSTER_NAME \\
    --user=system:node:$NODE_HOSTNAME \\
    --kubeconfig=kubelet.kubeconfig

kubectl config use-context default --kubeconfig=kubelet.kubeconfig
sudo mv -v ~/$NODE_HOSTNAME.kubeconfig /var/lib/kubernetes/
sudo chmod -v 600 /var/lib/kubernetes/kubelet.kubeconfig
EOF

# generate kube-proxy configuration
cat<<EOF | ssh $NODE
# kube-proxy configuration
kubectl config set-cluster $CLUSTER_NAME \
    --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
    --server=https://$MASTER_1:6443 \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
    --client-certificate=/var/lib/kubernetes/pki/kube-proxy.crt \
    --client-key=/var/lib/kubernetes/pki/kube-proxy.key \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
    --cluster=$CLUSTER_NAME \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
EOF