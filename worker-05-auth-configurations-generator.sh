#!/usr/bin/env bash

source common.sh

export NODE=$WORKER_1

# get node host name
export NODE_HOSTNAME=$(ssh $NODE sudo hostname -s)


# generate kubelet configuration node
cat<<EOF | ssh -T $NODE
kubectl config set-cluster $CLUSTER_NAME \\
    --certificate-authority=$WORKER_CERT_DIR/ca.crt \\
    --server=https://${MASTER_1}:6443 \\
    --kubeconfig=kubelet.kubeconfig

kubectl config set-credentials system:node:$NODE_HOSTNAME \\
    --client-certificate=$WORKER_CERT_DIR/$NODE_HOSTNAME.crt \\
    --client-key=$WORKER_CERT_DIR/$NODE_HOSTNAME.key \\
    --kubeconfig=kubelet.kubeconfig

kubectl config set-context default \\
    --cluster=$CLUSTER_NAME \\
    --user=system:node:$NODE_HOSTNAME \\
    --kubeconfig=kubelet.kubeconfig

kubectl config use-context default --kubeconfig=kubelet.kubeconfig
sudo mv -v ~/kubelet.kubeconfig /var/lib/kubelet/kubelet.kubeconfig
EOF
