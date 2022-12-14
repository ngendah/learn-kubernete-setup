#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

# Certificate Authority
ca_generate(){
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

ca_install(){
  sudo cp -fv $DATA_DIR/ca.crt $DATA_DIR/ca.key $MASTER_CERT_DIR

  # TODO make ca file's owner as root
  # sudo chown -v root:root $MASTER_CERT_DIR/ca.key
  # sudo chmod -v 600 $MASTER_CERT_DIR/ca*
}

ca_remove(){
  rm -fv $DATA_DIR/ca.crt $DATA_DIR/ca.key $DATA_DIR/ca.csr
}

ca_remove_all(){
 ca_remove
 rm -rf $MASTER_CERT_DIR/ca.crt $MASTER_CERT_DIR/ca.key
}

ca_reinstall(){
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
    ca_generate
  ;;
  "install")
    ca_install
  ;;
  "reinstall")
    ca_reinstall
  ;;
  "remove-all")
  ;;
  "stop")
  ;;
  "start")
  ;;
  *)
    ca_reinstall
  ;;
esac
