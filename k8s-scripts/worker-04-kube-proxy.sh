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

KUBE_PROXY_FILE_NAME=kube-proxy
KUBE_PROXY_SETUP_DIR_NAME=kube-proxy
KUBE_PROXY_SETUP_DIR="${DATA_DIR}/$KUBE_PROXY_SETUP_DIR_NAME"

kube_proxy_download() {
  PROXY_DOWNLOAD_FILE_NAME=$KUBE_PROXY_SETUP_DIR/$KUBE_PROXY_FILE_NAME
  if [ ! -f $PROXY_DOWNLOAD_FILE_NAME ]; then
    wget -P $KUBE_PROXY_SETUP_DIR -q --show-progress --https-only --timestamping \
      "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/$KUBE_PROXY_FILE_NAME"
  else
    echo "$PROXY_DOWNLOAD_FILE_NAME already exists, skipping download"
  fi
}

kube_proxy_setup_dirs() {
  master_check_dirs_and_create
  mkdir -p $KUBE_PROXY_SETUP_DIR
  ssh -T $NODE sudo mkdir -vp $(jq -r ".nodes.worker.kubernetes.paths[]" cluster-config.json)
  ssh -T $NODE sudo mkdir -vp $(jq -r ".nodes.worker.kube_proxy.paths[]" cluster-config.json)
}

kube_proxy_copy_ca_certs() {
  cp $MASTER_CERT_DIR/$CA_FILE_NAME.crt $MASTER_CERT_DIR/$CA_FILE_NAME.key $KUBE_PROXY_SETUP_DIR
}

kube_proxy_generate() {
  kube_proxy_setup_dirs
  master_ca_exists
  kube_proxy_copy_ca_certs
  kube_proxy_download

  openssl genrsa -out $KUBE_PROXY_SETUP_DIR/kube-proxy.key 2048
  openssl req -new -key $KUBE_PROXY_SETUP_DIR/kube-proxy.key \
    -subj "/CN=system:kube-proxy/O=system:node-proxier" \
    -out $KUBE_PROXY_SETUP_DIR/kube-proxy.csr
  openssl x509 -req -in $KUBE_PROXY_SETUP_DIR/kube-proxy.csr \
    -CA $KUBE_PROXY_SETUP_DIR/$CA_FILE_NAME.crt \
    -CAkey $KUBE_PROXY_SETUP_DIR/$CA_FILE_NAME.key \
    -CAcreateserial \
    -out $KUBE_PROXY_SETUP_DIR/kube-proxy.crt \
    -days 1000

  kubectl config set-cluster $CLUSTER_NAME \
    --certificate-authority=$KUBE_PROXY_SETUP_DIR/$CA_FILE_NAME.crt \
    --server=https://$MASTER_1:6443 \
    --embed-certs=true \
    --kubeconfig=$KUBE_PROXY_SETUP_DIR/kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=$KUBE_PROXY_SETUP_DIR/kube-proxy.crt \
    --client-key=$KUBE_PROXY_SETUP_DIR/kube-proxy.key \
    --embed-certs=true \
    --kubeconfig=$KUBE_PROXY_SETUP_DIR/kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=$CLUSTER_NAME \
    --user=system:kube-proxy \
    --kubeconfig=$KUBE_PROXY_SETUP_DIR/kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=$KUBE_PROXY_SETUP_DIR/kube-proxy.kubeconfig

  cat <<EOF | tee $KUBE_PROXY_SETUP_DIR/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: $KUBE_PROXY_CONFIG_DIR/kube-proxy.kubeconfig
mode: "iptables"
clusterCIDR: ${POD_CIDR}
EOF

  cat <<EOF | tee $KUBE_PROXY_SETUP_DIR/kube-proxy.service
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
  scp -r $KUBE_PROXY_SETUP_DIR $NODE:~

  cat <<EOF | ssh -T $NODE
sudo cp -v ~/$KUBE_PROXY_SETUP_DIR_NAME/kube-proxy $BIN_DIR

sudo chown -v root:root $BIN_DIR/kube-proxy
sudo chmod -v 500 $BIN_DIR/kube-proxy
EOF

  cat <<EOF | ssh -T $NODE
sudo cp -v ~/$KUBE_PROXY_SETUP_DIR_NAME/$CA_FILE_NAME.crt $WORKER_CERT_DIR

sudo cp -v ~/$KUBE_PROXY_SETUP_DIR_NAME/kube-proxy.key ~/$KUBE_PROXY_SETUP_DIR_NAME/kube-proxy.crt $KUBE_PROXY_CERT_DIR
sudo cp -v ~/$KUBE_PROXY_SETUP_DIR_NAME/kube-proxy-config.yaml $KUBE_PROXY_CONFIG_DIR
sudo cp -v ~/$KUBE_PROXY_SETUP_DIR_NAME/kube-proxy.service $SERVICES_DIR

sudo chown -Rv root:root $KUBE_PROXY_CERT_DIR
sudo chmod -Rv 600 $KUBE_PROXY_CERT_DIR

sudo chown -v root:root $SERVICES_DIR/kube-proxy.service
sudo chmod -v 600 $SERVICES_DIR/kube-proxy.service
EOF

  cat <<EOF | ssh -T $NODE
sudo cp -v ~/$KUBE_PROXY_SETUP_DIR_NAME/kube-proxy.kubeconfig $KUBE_PROXY_CONFIG_DIR

sudo chown -Rv root:root $KUBE_PROXY_CONFIG_DIR
sudo chmod -Rv 600 $KUBE_PROXY_CONFIG_DIR
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
  rm -fr $KUBE_PROXY_SETUP_DIR/*
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
  kube_proxy_remove
  kube_proxy_generate
  kube_proxy_install
}

case $1 in
"setup-dirs")
  kube_proxy_setup_dirs
  ;;
"download")
  kube_proxy_setup_dirs
  kube_proxy_download
  ;;
"remove")
  kube_proxy_stop
  kube_proxy_remove
  ;;
"generate")
  kube_proxy_generate
  ;;
"install")
  kube_proxy_stop
  kube_proxy_install
  kube_proxy_start
  ;;
"reinstall")
  kube_proxy_stop
  kube_proxy_reinstall
  kube_proxy_start
  ;;
"remove-all")
  kube_proxy_stop
  kube_proxy_remove_all
  ;;
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
