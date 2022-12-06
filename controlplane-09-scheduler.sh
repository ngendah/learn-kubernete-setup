#!/usr/bin/env bash

source common.sh

# Binary
wget --show-progress --https-only --timestamping \
        "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kube-scheduler"

sudo mv -v kube-scheduler $BIN_DIR/

# Certificate
openssl genrsa -out $DATA_DIR/kube-scheduler.key 2048
openssl req -new -key $DATA_DIR/kube-scheduler.key \
    -subj "/CN=system:kube-scheduler/O=system:kube-scheduler" \
    -out $DATA_DIR/kube-scheduler.csr
openssl x509 -req -in $DATA_DIR/kube-scheduler.csr \
    -CA $MASTER_CERT_DIR/ca.crt \
    -CAkey $MASTER_CERT_DIR/ca.key \
    -CAcreateserial  \
    -out $DATA_DIR/kube-scheduler.crt -days 1000

sudo mv -v $DATA_DIR/kube-scheduler.key $DATA_DIR/kube-scheduler.crt $MASTER_CERT_DIR

# Kube-config
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

sudo mv -v $DATA_DIR/kube-scheduler.kubeconfig $MASTER_CONFIG_DIR

# Service
cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
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
