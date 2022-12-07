#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

# shellcheck disable=SC2155
export NODE_HOSTNAME=$(ssh $NODE sudo hostname -s)

# Binary
cat<<EOF | ssh -T $NODE
echo "Downloading kube-proxy-$KUBERNETES_VERSION"
wget -q --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/KUBERNETES_VERSION/bin/linux/amd64/kube-proxy
sudo mv -v ./kube-proxy $BIN_DIR

sudo chown -v root:root $BIN_DIR/kube-proxy
sudo chmod -v 500 $BIN_DIR/kube-proxy
EOF

# Certificate
openssl genrsa -out $DATA_DIR/kube-proxy.key 2048
openssl req -new -key $DATA_DIR/kube-proxy.key \
    -subj "/CN=system:kube-proxy/O=system:node-proxier" \
    -out $DATA_DIR/kube-proxy.csr
openssl x509 -req -in $DATA_DIR/kube-proxy.csr \
    -CA $MASTER_CERT_DIR/ca.crt \
    -CAkey $MASTER_CERT_DIR/ca.key \
    -CAcreateserial \
    -out $DATA_DIR/kube-proxy.crt \
    -days 1000

cat<<EOF | tee $DATA_DIR/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: $KUBE_PROXY_CONFIG_DIR/kube-proxy.kubeconfig
mode: "iptables"
clusterCIDR: ${POD_CIDR}
EOF

cat <<EOF | tee $DATA_DIR/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=$BIN_DIR/kube-proxy \\
  --config=$KUBE_PROXY_CONFIG_DIR/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

scp $MASTER_CERT_DIR/ca.crt\
    $DATA_DIR/kube-proxy.key \
    $DATA_DIR/kube-proxy.crt \
    $DATA_DIR/kube-proxy-config.yaml \
    $DATA_DIR/kube-proxy.service \
    $NODE:~

# Kube-config
cat<<EOF | ssh -T $NODE
kubectl config set-cluster $CLUSTER_NAME \
    --certificate-authority=$WORKER_CERT_DIR/ca.crt \
    --server=https://$MASTER_1:6443 \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
    --client-certificate=$KUBE_PROXY_CERT_DIR/kube-proxy.crt \
    --client-key=$KUBE_PROXY_CERT_DIR/kube-proxy.key \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
    --cluster=$CLUSTER_NAME \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

sudo mv -v ~/kube-proxy.kubeconfig $KUBE_PROXY_CONFIG_DIR

sudo chown -Rv root:root $KUBE_PROXY_KUBE_PROXY_CONFIG_DIR
sudo chmod -Rv 600 $KUBE_PROXY_KUBE_PROXY_CONFIG_DIR
EOF


cat<<EOF | ssh -T $NODE
sudo mv -v ~/ca.crt $WORKER_CERT_DIR

sudo mv -v ~/kube-proxy.key ~/kube-proxy.crt $KUBE_PROXY_CERT_DIR
sudo mv -v ~/kube-proxy-config.yaml $KUBE_PROXY_CONFIG_DIR
sudo mv -v ~/kube-proxy.service $SERVICES_DIR

sudo chown -Rv root:root $KUBE_PROXY_CERT_DIR
sudo chmod -Rv 600 $KUBE_PROXY_CERT_DIR
sudo chown -v root:root $SERVICES_DIR/kube-proxy.service
sudo chmod -v 600 $SERVICES_DIR/kube-proxy.service

sudo systemctl enable kube-proxy*
sudo systemctl start kube-proxy*
EOF