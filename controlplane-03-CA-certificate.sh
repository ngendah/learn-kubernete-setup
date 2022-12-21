#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

ca_generate() {
  master_check_dirs_and_create

  openssl genrsa -out $DATA_DIR/ca.key 2048
  openssl req -new -key $DATA_DIR/ca.key \
    -subj "/CN=KUBERNETES-CA/O=Kubernetes" \
    -out $DATA_DIR/ca.csr
  openssl x509 -req -in $DATA_DIR/ca.csr \
    -signkey $DATA_DIR/ca.key \
    -CAcreateserial \
    -out $DATA_DIR/ca.crt \
    -days 1000
}

ca_install() {
  sudo cp -fv $DATA_DIR/ca.crt $DATA_DIR/ca.key $MASTER_CERT_DIR

  # TODO make ca file's owner as root
  sudo chown -v $USER:root $MASTER_CERT_DIR/ca*
  sudo chmod -v 600 $MASTER_CERT_DIR/ca*
}

ca_remove() {
  rm -rf $MASTER_CERT_DIR/ca.crt $MASTER_CERT_DIR/ca.key
}

ca_remove_all() {
  ca_remove
  rm -fv $DATA_DIR/ca.crt $DATA_DIR/ca.key $DATA_DIR/ca.csr
}

ca_reinstall() {
  if [ -f "$DATA_DIR/ca.crt" ] && [ -f "$DATA_DIR/ca.key" ]; then
    ca_install
  else
    ca_remove
    ca_generate
    ca_install
  fi
}

case $1 in
"remove")
  ;;
"generate")
  ;;
"install")
  ;;
"reinstall")
  ca_reinstall
  ;;
"remove-all") ;;

"stop") ;;

"start") ;;

"restart") ;;

*)
  ca_reinstall
  ;;
esac