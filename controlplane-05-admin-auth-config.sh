#!/usr/bin/env bash

source common.sh

# Certificate
openssl genrsa -out $DATA_DIR/admin.key 2048
openssl req -new -key $DATA_DIR/admin.key \
      -subj "/CN=admin/O=system:masters" \
      -out $DATA_DIR/admin.csr
openssl x509 -req -in $DATA_DIR/admin.csr \
      -CA $MASTER_CERT_DIR/ca.crt \
      -CAkey $MASTER_CERT_DIR/ca.key \
      -CAcreateserial  \
      -out $DATA_DIR/admin.crt \
      -days 1000

sudo mv -v $DATA_DIR/admin.crt $DATA_DIR/admin.key \
        $MASTER_CERT_DIR

# Kube-config
kubectl config set-cluster "$CLUSTER_NAME" \
    --certificate-authority=$MASTER_CERT_DIR/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
    --client-certificate=$MASTER_CERT_DIR/admin.crt \
    --client-key=$MASTER_CERT_DIR/admin.key \
    --embed-certs=true \
    --kubeconfig=$DATA_DIR/admin.kubeconfig

 kubectl config set-context default \
    --cluster="$CLUSTER_NAME" \
    --user=admin \
    --kubeconfig=$DATA_DIR/admin.kubeconfig

kubectl config use-context default --kubeconfig=$DATA_DIR/admin.kubeconfig

sudo mv -v $DATA_DIR/admin.kubeconfig \
			$MASTER_CONFIG_DIR
