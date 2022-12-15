#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

scheduler_download() {
  FILE_NAME=kube-scheduler
  if [ ! -f $DATA_DIR/$FILE_NAME ]; then
    wget --show-progress --https-only --timestamping \
      "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/$FILE_NAME"
    mv $FILE_NAME $DATA_DIR/
  fi
}

scheduler_generate() {
  scheduler_download

  openssl genrsa -out $DATA_DIR/kube-scheduler.key 2048
  openssl req -new -key $DATA_DIR/kube-scheduler.key \
    -subj "/CN=system:kube-scheduler/O=system:kube-scheduler" \
    -out $DATA_DIR/kube-scheduler.csr
  openssl x509 -req -in $DATA_DIR/kube-scheduler.csr \
    -CA $MASTER_CERT_DIR/ca.crt \
    -CAkey $MASTER_CERT_DIR/ca.key \
    -CAcreateserial \
    -out $DATA_DIR/kube-scheduler.crt -days 1000

  kubectl config set-cluster "$CLUSTER_NAME" \
    --certificate-authority=$MASTER_CERT_DIR/ca.crt \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=$DATA_DIR/kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=$MASTER_CERT_DIR/kube-scheduler.crt \
    --client-key=$MASTER_CERT_DIR/kube-scheduler.key \
    --kubeconfig=$DATA_DIR/kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster="$CLUSTER_NAME" \
    --user=system:kube-scheduler \
    --kubeconfig=$DATA_DIR/kube-scheduler.kubeconfig

  kubectl config use-context default \
    --kubeconfig=$DATA_DIR/kube-scheduler.kubeconfig

  cat <<EOF | tee $DATA_DIR/kube-scheduler.service
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
  sudo cp -v kube-scheduler $BIN_DIR/
  sudo cp -v $DATA_DIR/kube-scheduler.key $DATA_DIR/kube-scheduler.crt $MASTER_CERT_DIR
  sudo cp -v $DATA_DIR/kube-scheduler.kubeconfig $MASTER_CONFIG_DIR
  sudo cp -v $DATA_DIR/kube-scheduler.service $SERVICES_DIR

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
  rm -fr $DATA_DIR/kube-scheduler*
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
  if [ -f $DATA_DIR/kube-scheduler.key ] && [ -f $DATA_DIR/kube-scheduler.crt ] &&
    [ -f $DATA_DIR/kube-scheduler.kubeconfig ] && [ -f $DATA_DIR/kube-scheduler.service ]; then
    scheduler_remove
    scheduler_install
  else
    scheduler_remove_all
    scheduler_generate
    scheduler_install
  fi
}

case $1 in
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
"remove-all") ;;

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
