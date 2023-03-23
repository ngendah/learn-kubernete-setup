#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

# shellcheck disable=SC2086
source common.sh

# shellcheck disable=SC2155
export NODE_HOSTNAME=$(ssh $NODE sudo hostname -s)

kube_proxy_generate() {
  master_ca_exists

  openssl genrsa -out $DATA_DIR/kube-proxy.key 2048
  openssl req -new -key $DATA_DIR/kube-proxy.key \
    -subj "/CN=system:kube-proxy/O=system:node-proxier" \
    -out $DATA_DIR/kube-proxy.csr
  openssl x509 -req -in $DATA_DIR/kube-proxy.csr \
    -CA $MASTER_CERT_DIR/$CA_FILE_NAME.crt \
    -CAkey $MASTER_CERT_DIR/$CA_FILE_NAME.key \
    -CAcreateserial \
    -out $DATA_DIR/kube-proxy.crt \
    -days 1000

  cat <<EOF | tee $DATA_DIR/kube-proxy-config.yaml
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
}

kube_proxy_install() {
  cat <<EOF | ssh -T $NODE
echo "Downloading kube-proxy-$KUBERNETES_VERSION"
wget -q --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/KUBERNETES_VERSION/bin/linux/amd64/kube-proxy
sudo mv -v ./kube-proxy $BIN_DIR

sudo chown -v root:root $BIN_DIR/kube-proxy
sudo chmod -v 500 $BIN_DIR/kube-proxy
EOF

  scp $MASTER_CERT_DIR/$CA_FILE_NAME.crt $DATA_DIR/kube-proxy.key \
    $DATA_DIR/kube-proxy.crt \
    $DATA_DIR/kube-proxy-config.yaml \
    $DATA_DIR/kube-proxy.service \
    $NODE:~

  cat <<EOF | ssh -T $NODE
kubectl config set-cluster $CLUSTER_NAME \
    --certificate-authority=$WORKER_CERT_DIR/$CA_FILE_NAME.crt \
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

  cat <<EOF | ssh -T $NODE
sudo mv -v ~/$CA_FILE_NAME.crt $WORKER_CERT_DIR

sudo mv -v ~/kube-proxy.key ~/kube-proxy.crt $KUBE_PROXY_CERT_DIR
sudo mv -v ~/kube-proxy-config.yaml $KUBE_PROXY_CONFIG_DIR
sudo mv -v ~/kube-proxy.service $SERVICES_DIR

sudo chown -Rv root:root $KUBE_PROXY_CERT_DIR
sudo chmod -Rv 600 $KUBE_PROXY_CERT_DIR
sudo chown -v root:root $SERVICES_DIR/kube-proxy.service
sudo chmod -v 600 $SERVICES_DIR/kube-proxy.service
EOF
}

kube_proxy_remove() {
  cat <<EOF | ssh -T $NODE
# sudo rm -fv $WORKER_CERT_DIR/$CA_FILE_NAME.crt
sudo rm -fv $BIN_DIR/kube-proxy
sudo rm -fv $KUBE_PROXY_CONFIG_DIR/kube-proxy.kubeconfig
sudo rm -fv $KUBE_PROXY_CERT_DIR/kube-proxy.key
sudo rm -fv $KUBE_PROXY_CERT_DIR/kube-proxy.crt
sudo rm -fv $KUBE_PROXY_CONFIG_DIR/kube-proxy-config.yaml
sudo rm -fv $SERVICES_DIR/kube-proxy.service

EOF
}

kube_proxy_remove_all() {
  kube_proxy_remove
  rm -fr $DATA_DIR/kube-proxy*
}

kube_proxy_start() {
  cat <<EOF | ssh -T $NODE
sudo systemctl enable kube-proxy.service
sudo systemctl start kube-proxy.service
EOF
}

kube_proxy_stop() {
  cat <<EOF | ssh -T $NODE
sudo systemctl stop kube-proxy.service
sudo systemctl disable kube-proxy.service
EOF
}

kube_proxy_restart() {
  kube_proxy_stop
  kube_proxy_start
}

kube_proxy_reinstall() {
  kube_proxy_remove_all
  kube_proxy_generate
  kube_proxy_install
}

case $1 in
"remove") ;;

"generate") ;;

"install") ;;

"reinstall")
  kube_proxy_stop
  kube_proxy_reinstall
  kube_proxy_start
  ;;
"remove-all") ;;

"stop")
  kube_proxy_stop
  ;;

"start")
  kube_proxy_start
  ;;

"restart")
  kube_proxy_restart
  ;;

*)
  kube_proxy_stop
  kube_proxy_reinstall
  kube_proxy_start
  ;;
esac
