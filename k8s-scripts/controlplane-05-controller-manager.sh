#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

# shellcheck disable=SC2086
source common.sh

CM_FILE_NAME=kube-controller-manager
CM_SETUP_DIR="${DATA_DIR}/controller-manager"

cm_download() {
  CM_DOWNLOAD_FILE_NAME=$CM_SETUP_DIR/$CM_FILE_NAME
  if [ ! -f $CM_DOWNLOAD_FILE_NAME ]; then
    wget -P $CM_SETUP_DIR --show-progress --https-only --timestamping \
      "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/$CM_FILE_NAME"
  else
    echo "$CM_DOWNLOAD_FILE_NAME already exists, skipping download"
  fi
}

cm_setup_dirs() {
  master_check_dirs_and_create
  mkdir -p $CM_SETUP_DIR
}

cm_generate() {
  cm_setup_dirs
  master_ca_exists
  cm_download

  # TODO: change kube-controller-manager to $CM_FILE_NAME
  # TODO: mv cert generation to own fn
  openssl genrsa -out $CM_SETUP_DIR/kube-controller-manager.key 2048
  openssl req -new -key $CM_SETUP_DIR/kube-controller-manager.key \
    -subj "/CN=system:kube-controller-manager/O=system:kube-controller-manager" \
    -out $CM_SETUP_DIR/kube-controller-manager.csr
  openssl x509 -req -in $CM_SETUP_DIR/kube-controller-manager.csr \
    -CA $DATA_DIR/$CA_FILE_NAME.crt \
    -CAkey $DATA_DIR/$CA_FILE_NAME.key \
    -CAcreateserial \
    -out $CM_SETUP_DIR/kube-controller-manager.crt -days 1000

  kubectl config set-cluster "$CLUSTER_NAME" \
    --certificate-authority=$MASTER_CERT_DIR/$CA_FILE_NAME.crt \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=$CM_SETUP_DIR/kube-controller-manager.kubeconfig

  # TODO: remove --embed-certs option
  # TODO: mv kube-config generation to own fn
  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=$CM_SETUP_DIR/kube-controller-manager.crt \
    --embed-certs=true \
    --client-key=$CM_SETUP_DIR/kube-controller-manager.key \
    --kubeconfig=$CM_SETUP_DIR/kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster="$CLUSTER_NAME" \
    --user=system:kube-controller-manager \
    --kubeconfig=$CM_SETUP_DIR/kube-controller-manager.kubeconfig

  kubectl config use-context default \
    --kubeconfig=$CM_SETUP_DIR/kube-controller-manager.kubeconfig

  # TODO: mv service generation to own fn
  cat <<EOF | tee $CM_SETUP_DIR/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=$BIN_DIR/kube-controller-manager \\
  --allocate-node-cidrs=true \\
  --authentication-kubeconfig=$MASTER_CONFIG_DIR/kube-controller-manager.kubeconfig \\
  --authorization-kubeconfig=$MASTER_CONFIG_DIR/kube-controller-manager.kubeconfig \\
  --bind-address=127.0.0.1 \\
  --client-ca-file=$MASTER_CERT_DIR/$CA_FILE_NAME.crt \\
  --cluster-cidr=${POD_CIDR} \\
  --cluster-name=${CLUSTER_NAME} \\
  --cluster-signing-cert-file=$MASTER_CERT_DIR/$CA_FILE_NAME.crt \\
  --cluster-signing-key-file=$MASTER_CERT_DIR/$CA_FILE_NAME.key \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --kubeconfig=$MASTER_CONFIG_DIR/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --node-cidr-mask-size=24 \\
  --requestheader-client-ca-file=$MASTER_CERT_DIR/$CA_FILE_NAME.crt \\
  --root-ca-file=$MASTER_CERT_DIR/$CA_FILE_NAME.crt \\
  --service-account-private-key-file=$MASTER_CERT_DIR/service-account.key \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

cm_install() {
  sudo cp -v $CM_SETUP_DIR/kube-controller-manager $BIN_DIR/
  sudo cp -v $CM_SETUP_DIR/kube-controller-manager.key $CM_SETUP_DIR/kube-controller-manager.crt $MASTER_CERT_DIR
  sudo cp -v $CM_SETUP_DIR/kube-controller-manager.kubeconfig $MASTER_CONFIG_DIR
  sudo cp -v $CM_SETUP_DIR/kube-controller-manager.service $SERVICES_DIR

  sudo chmod -v 500 $BIN_DIR/kube-controller-manager
  sudo chmod -Rv 600 $MASTER_CERT_DIR/kube-controller* \
    $MASTER_CONFIG_DIR/kube-controller* $SERVICES_DIR/kube-controller*
  sudo chown -Rv root:root $BIN_DIR/kube-controller* $MASTER_CERT_DIR/kube-controller* \
    $MASTER_CONFIG_DIR/kube-controller* $SERVICES_DIR/kube-controller*
}

cm_remove() {
  sudo rm -fr $MASTER_CERT_DIR/kube-controller* \
    $MASTER_CONFIG_DIR/kube-controller* $SERVICES_DIR/kube-controller*
}

cm_remove_all() {
  cm_remove
  rm -fr $CM_SETUP_DIR/*
}

cm_start() {
  sudo systemctl enable kube-controller-manager.service
  sudo systemctl start kube-controller-manager.service
}

cm_stop() {
  sudo systemctl disable kube-controller-manager.service
  sudo systemctl stop kube-controller-manager.service
}

cm_restart() {
  cm_stop
  cm_start
}

cm_reinstall() {
  if [ -f $CM_SETUP_DIR/kube-controller-manager.key ] && [ -f $CM_SETUP_DIR/kube-controller-manager.crt ] &&
    [ -f $CM_SETUP_DIR/kube-controller-manager.kubeconfig ] && [ -f $CM_SETUP_DIR/kube-controller-manager.service ]; then
    cm_remove
    cm_install
  else
    cm_remove_all
    cm_generate
    cm_install
  fi
}

case $1 in
"setup-dirs")
  cm_setup_dirs
  ;;
"download")
  cm_setup_dirs
  cm_download
  ;;
"remove")
  cm_stop
  cm_remove
  ;;
"generate")
  cm_generate
  ;;
"install")
  cm_install
  cm_start
  ;;
"reinstall")
  cm_stop
  cm_reinstall
  cm_start
  ;;
"remove-all") ;;

"stop")
  cm_stop
  ;;

"start")
  cm_start
  ;;

"restart")
  cm_restart
  ;;

*)
  cm_stop
  cm_reinstall
  cm_start
  ;;
esac
