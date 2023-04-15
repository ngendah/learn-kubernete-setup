#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

# shellcheck disable=SC2086
source common.sh

SCHEDULER_FILE_NAME=kube-scheduler
SCHEDULER_SETUP_DIR="${DATA_DIR}/scheduler"

scheduler_download() {
  SCHEDULER_DOWNLOAD_FILE_NAME=$SCHEDULER_SETUP_DIR/$SCHEDULER_FILE_NAME
  if [ ! -f $SCHEDULER_DOWNLOAD_FILE_NAME ]; then
    wget -P $SCHEDULER_SETUP_DIR -q --show-progress --https-only --timestamping \
      "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/$SCHEDULER_FILE_NAME"
  else
    echo "$SCHEDULER_DOWNLOAD_FILE_NAME already exists, skipping download"
  fi
}

scheduler_setup_dirs() {
  master_check_dirs_and_create
  mkdir -p $SCHEDULER_SETUP_DIR
}

scheduler_generate() {
  scheduler_setup_dirs
  master_ca_exists
  scheduler_download

  openssl genrsa -out $SCHEDULER_SETUP_DIR/kube-scheduler.key 2048
  openssl req -new -key $SCHEDULER_SETUP_DIR/kube-scheduler.key \
    -subj "/CN=system:kube-scheduler/O=system:kube-scheduler" \
    -out $SCHEDULER_SETUP_DIR/kube-scheduler.csr
  openssl x509 -req -in $SCHEDULER_SETUP_DIR/kube-scheduler.csr \
    -CA $DATA_DIR/$CA_FILE_NAME.crt \
    -CAkey $DATA_DIR/$CA_FILE_NAME.key \
    -CAcreateserial \
    -out $SCHEDULER_SETUP_DIR/kube-scheduler.crt -days 1000

  kubectl config set-cluster "$CLUSTER_NAME" \
    --certificate-authority=$MASTER_CERT_DIR/$CA_FILE_NAME.crt \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=$SCHEDULER_SETUP_DIR/kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=$SCHEDULER_SETUP_DIR/kube-scheduler.crt \
    --embed-certs=true \
    --client-key=$SCHEDULER_SETUP_DIR/kube-scheduler.key \
    --kubeconfig=$SCHEDULER_SETUP_DIR/kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster="$CLUSTER_NAME" \
    --user=system:kube-scheduler \
    --kubeconfig=$SCHEDULER_SETUP_DIR/kube-scheduler.kubeconfig

  kubectl config use-context default \
    --kubeconfig=$SCHEDULER_SETUP_DIR/kube-scheduler.kubeconfig

  cat <<EOF | tee $SCHEDULER_SETUP_DIR/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=$BIN_DIR/kube-scheduler \\
  --kubeconfig=$MASTER_CONFIG_DIR/kube-scheduler.kubeconfig \\
  --leader-elect=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

scheduler_install() {
  sudo cp -v $SCHEDULER_SETUP_DIR/kube-scheduler $BIN_DIR/
  sudo cp -v $SCHEDULER_SETUP_DIR/kube-scheduler.key $SCHEDULER_SETUP_DIR/kube-scheduler.crt $MASTER_CERT_DIR
  sudo cp -v $SCHEDULER_SETUP_DIR/kube-scheduler.kubeconfig $MASTER_CONFIG_DIR
  sudo cp -v $SCHEDULER_SETUP_DIR/kube-scheduler.service $SERVICES_DIR

  sudo chmod -v 500 $BIN_DIR/kube-scheduler
  sudo chmod -Rv 600 $MASTER_CERT_DIR/kube-scheduler* $MASTER_CONFIG_DIR/kube-scheduler*
  sudo chown -Rv root:root $BIN_DIR/kube-scheduler $MASTER_CERT_DIR/kube-scheduler* \
    $MASTER_CONFIG_DIR/kube-scheduler* $SERVICES_DIR/kube-scheduler*
}

scheduler_remove() {
  sudo rm -fr $BIN_DIR/kube-scheduler $MASTER_CERT_DIR/kube-scheduler* \
    $MASTER_CONFIG_DIR/kube-scheduler* $SERVICES_DIR/kube-scheduler*
}

scheduler_remove_all() {
  scheduler_remove
  rm -fr $SCHEDULER_SETUP_DIR/*
}

scheduler_start() {
  sudo systemctl enable kube-scheduler.service
  sudo systemctl start kube-scheduler.service
}

scheduler_stop() {
  sudo systemctl disable kube-scheduler.service
  sudo systemctl stop kube-scheduler.service
}

scheduler_restart() {
  scheduler_stop
  scheduler_start
}

scheduler_reinstall() {
  if [ -f $SCHEDULER_SETUP_DIR/kube-scheduler.key ] && [ -f $SCHEDULER_SETUP_DIR/kube-scheduler.crt ] && \
    [ -f $SCHEDULER_SETUP_DIR/kube-scheduler.kubeconfig ] && [ -f $SCHEDULER_SETUP_DIR/kube-scheduler.service ]; then
    scheduler_remove
    scheduler_install
  else
    scheduler_remove_all
    scheduler_generate
    scheduler_install
  fi
}

case $1 in
"setup-dirs")
  scheduler_setup_dirs
  ;;
"download")
  scheduler_setup_dirs
  scheduler_download
  ;;
"remove")
  scheduler_stop
  scheduler_remove
  ;;
"generate")
  scheduler_generate
  ;;
"install")
  scheduler_install
  scheduler_start
  ;;
"reinstall")
  scheduler_stop
  scheduler_reinstall
  scheduler_start
  ;;
"remove-all")
  scheduler_stop
  scheduler_remove_all
  ;;
"stop")
  scheduler_stop
  ;;
"start")
  scheduler_start
  ;;

"restart")
  scheduler_restart
  ;;

*)
  scheduler_stop
  scheduler_reinstall
  scheduler_start
  ;;
esac
