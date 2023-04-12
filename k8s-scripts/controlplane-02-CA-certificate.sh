#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

# shellcheck disable=SC2086
source common.sh

ca_generate() {
  master_check_dirs_and_create

  cat>$DATA_DIR/$CA_FILE_NAME.cnf<<EOF
[req]
req_extensions = v3_req
[ v3_req ]
basicConstraints = critical, CA:true
keyUsage = critical, keyCertSign, cRLSign, digitalSignature, keyEncipherment
EOF
  openssl genrsa -out $DATA_DIR/$CA_FILE_NAME.key 2048
  openssl req -new -key $DATA_DIR/$CA_FILE_NAME.key \
    -subj "/CN=KUBERNETES-CA/O=Kubernetes" \
    -config $DATA_DIR/$CA_FILE_NAME.cnf \
    -out $DATA_DIR/$CA_FILE_NAME.csr
  openssl x509 -req -in $DATA_DIR/$CA_FILE_NAME.csr \
    -signkey $DATA_DIR/$CA_FILE_NAME.key \
    -extensions v3_req \
    -extfile $DATA_DIR/$CA_FILE_NAME.cnf \
    -CAcreateserial \
    -out $DATA_DIR/$CA_FILE_NAME.crt \
    -days 1000
}

ca_generate_short() {
  openssl req -newkey rsa:2048 -nodes -sha256 -keyout $DATA_DIR/${CA_FILE_NAME}.key \
    -subj "/CN=KUBERNETES-CA/O=Kubernetes" \
    -x509 -days 1000 -out $DATA_DIR/${CA_FILE_NAME}.crt
}

ca_install() {
  sudo cp -fv $DATA_DIR/$CA_FILE_NAME.crt $DATA_DIR/$CA_FILE_NAME.key $MASTER_CERT_DIR

  # TODO make ca file's owner as root
  sudo chown -v $USER:root $MASTER_CERT_DIR/ca*
  sudo chmod -v 600 $MASTER_CERT_DIR/ca*
}

ca_remove() {
  rm -rf $MASTER_CERT_DIR/$CA_FILE_NAME.crt $MASTER_CERT_DIR/$CA_FILE_NAME.key
}

ca_remove_all() {
  ca_remove
  rm -fv $DATA_DIR/$CA_FILE_NAME.crt $DATA_DIR/$CA_FILE_NAME.key $DATA_DIR/$CA_FILE_NAME.csr
}

ca_reinstall() {
  if [ -f "$DATA_DIR/$CA_FILE_NAME.crt" ] && [ -f "$DATA_DIR/$CA_FILE_NAME.key" ]; then
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
"generate_s")
  ca_generate_short
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
