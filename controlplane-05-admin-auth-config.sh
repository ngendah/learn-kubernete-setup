#!/usr/bin/env bash

source common.sh

# Certificate
openssl genrsa -out admin.key 2048
openssl req -new -key admin.key -subj "/CN=admin/O=system:masters" -out admin.csr
openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out admin.crt -days 1000

sudo mv admin.crt admin.key \
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
    --kubeconfig=admin.kubeconfig

 kubectl config set-context default \
    --cluster="$CLUSTER_NAME" \
    --user=admin \
    --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

sudo mv -v admin.kubeconfig \
			$MASTER_CONFIG_DIR
