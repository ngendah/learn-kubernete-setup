#!/usr/bin/env bash

source common.sh

# certificate authority
openssl genrsa -out ca.key 2048
 openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA/O=Kubernetes" -out ca.csr
openssl x509 -req -in ca.csr -signkey ca.key -CAcreateserial  -out ca.crt -days 1000


sudo mv -v ca.crt ca.key \
		$MASTER_CERT_DIR
