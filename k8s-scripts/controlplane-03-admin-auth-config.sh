#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

# shellcheck disable=SC2086
source common.sh

admin_generate() {
  master_check_dirs_and_create
  master_ca_exists

  openssl genrsa -out $DATA_DIR/admin.key 2048
  openssl req -new -key $DATA_DIR/admin.key \
    -subj "/CN=admin/O=system:masters" \
    -out $DATA_DIR/admin.csr
  openssl x509 -req -in $DATA_DIR/admin.csr \
    -CA $DATA_DIR/$CA_FILE_NAME.crt \
    -CAkey $DATA_DIR/$CA_FILE_NAME.key \
    -CAcreateserial \
    -out $DATA_DIR/admin.crt \
    -days 1000

  # Kube-config
  kubectl config set-cluster "$CLUSTER_NAME" \
    --certificate-authority=$DATA_DIR/$CA_FILE_NAME.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=$DATA_DIR/admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=$DATA_DIR/admin.crt \
    --client-key=$DATA_DIR/admin.key \
    --embed-certs=true \
    --kubeconfig=$DATA_DIR/admin.kubeconfig

  kubectl config set-context default \
    --cluster="$CLUSTER_NAME" \
    --user=admin \
    --kubeconfig=$DATA_DIR/admin.kubeconfig

  kubectl config use-context default --kubeconfig=$DATA_DIR/admin.kubeconfig
}

admin_install() {
  sudo cp -v $DATA_DIR/admin.crt $DATA_DIR/admin.key $MASTER_CERT_DIR

  sudo cp -v $DATA_DIR/admin.kubeconfig $MASTER_CONFIG_DIR
  sudo chown -v root:root $MASTER_CONFIG_DIR/admin.kubeconfig
  sudo chmod -v 600 $MASTER_CONFIG_DIR/admin.kubeconfig

  mkdir -p $HOME/.kube
  sudo cp $MASTER_CONFIG_DIR/admin.kubeconfig $HOME/.kube/config
  sudo chown -v $USER $HOME/.kube/config
}

admin_remove() {
  sudo rm -fv $MASTER_CERT_DIR/admin.crt $MASTER_CERT_DIR/admin.key \
    $MASTER_CERT_DIR/admin.kubeconfig $HOME/.kube/config
}

admin_remove_all() {
  admin_remove
  sudo rm -fv $DATA_DIR/admin.crt $DATA_DIR/admin.key $DATA_DIR/admin.csr $DATA_DIR/admin.kubeconfig
}

admin_reinstall() {
  if [ -f $DATA_DIR/admin.crt ] && [ -f $DATA_DIR/admin.key ] && [ -f $DATA_DIR/admin.kubeconfig ]; then
    admin_remove
    admin_install
  else
    admin_remove_all
    admin_generate
    admin_install
  fi
}

case $1 in
"remove")
  admin_remove
  ;;
"generate")
  admin_generate
  ;;
"install")
  admin_install
  ;;
"reinstall")
  admin_reinstall
  ;;
"remove-all") ;;

"stop") ;;

"start") ;;

"restart") ;;

*)
  admin_reinstall
  ;;
esac
