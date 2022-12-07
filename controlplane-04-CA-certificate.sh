#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

# Certificate Authority
openssl genrsa -out $DATA_DIR/ca.key 2048
openssl req -new -key $DATA_DIR/ca.key \
      -subj "/CN=KUBERNETES-CA/O=Kubernetes" \
      -out $DATA_DIR/ca.csr
openssl x509 -req -in $DATA_DIR/ca.csr \
      -signkey $DATA_DIR/ca.key \
      -CAcreateserial \
      -out $DATA_DIR/ca.crt \
      -days 1000


sudo mv -v $DATA_DIR/ca.crt $DATA_DIR/ca.key $MASTER_CERT_DIR

sudo chown -v root:root $MASTER_CERT_DIR/ca.key
sudo chmod -v 600 $MASTER_CERT_DIR/ca*