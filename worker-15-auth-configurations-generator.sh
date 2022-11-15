# SETUP WORKER NODE

# Run the script on the master node

export MASTER_1=192.168.122.204
export WORKER_1=192.168.122.4
export SERVICE_CIDR=10.96.0.0/24
export API_SERVICE=10.96.0.1
export CLUSTER_DNS=10.96.0.10
export CLUSTER_NAME="kubernetes"
export POD_CIDR=10.244.0.0/16


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