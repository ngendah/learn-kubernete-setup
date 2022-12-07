#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

# Binary
wget --show-progress --https-only --timestamping \
        "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kube-controller-manager"

sudo mv -v kube-controller-manager $BIN_DIR/

# Certificate
openssl genrsa -out $DATA_DIR/kube-controller-manager.key 2048
openssl req -new -key $DATA_DIR/kube-controller-manager.key \
    -subj "/CN=system:kube-controller-manager/O=system:kube-controller-manager" \
    -out $DATA_DIR/kube-controller-manager.csr
openssl x509 -req -in $DATA_DIR/kube-controller-manager.csr \
    -CA $MASTER_CERT_DIR/ca.crt \
    -CAkey $MASTER_CERT_DIR/ca.key \
    -CAcreateserial \
    -out $DATA_DIR/kube-controller-manager.crt -days 1000

sudo mv -v $DATA_DIR/kube-controller-manager.key \
          $DATA_DIR/kube-controller-manager.crt \
          $MASTER_CERT_DIR

# Kube-config
kubectl config set-cluster "$CLUSTER_NAME" \
    --certificate-authority=$MASTER_CERT_DIR/ca.crt \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=$DATA_DIR/kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=$MASTER_CERT_DIR/kube-controller-manager.crt \
    --client-key=$MASTER_CERT_DIR/kube-controller-manager.key \
    --kubeconfig=$DATA_DIR/kube-controller-manager.kubeconfig

kubectl config set-context default \
    --cluster="$CLUSTER_NAME" \
    --user=system:kube-controller-manager \
    --kubeconfig=$DATA_DIR/kube-controller-manager.kubeconfig

kubectl config use-context default \
    --kubeconfig=$DATA_DIR/kube-controller-manager.kubeconfig

sudo mv -v $DATA_DIR/kube-controller-manager.kubeconfig $MASTER_CONFIG_DIR

# Service
cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=$BIN_DIR/kube-controller-manager \\
  --allocate-node-cidrs=true \\
  --authentication-kubeconfig=$MASTER_CONFIG_DIR/kube-controller-manager.kubeconfig \\
  --authorization-kubeconfig=$MASTER_CONFIG_DIR/kube-controller-manager.kubeconfig \\
  --bind-address=127.0.0.1 \\
  --client-ca-file=$MASTER_CERT_DIR/ca.crt \\
  --cluster-cidr=${POD_CIDR} \\
  --cluster-name=${CLUSTER_NAME} \\
  --cluster-signing-cert-file=$MASTER_CERT_DIR/ca.crt \\
  --cluster-signing-key-file=$MASTER_CERT_DIR/ca.key \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --kubeconfig=$MASTER_CONFIG_DIR/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --node-cidr-mask-size=24 \\
  --requestheader-client-ca-file=$MASTER_CERT_DIR/ca.crt \\
  --root-ca-file=$MASTER_CERT_DIR/ca.crt \\
  --service-account-private-key-file=$MASTER_CERT_DIR/service-account.key \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Change permissions and start service
for DIR in $MASTER_CONFIG_DIR $MASTER_CERT_DIR $BIN_DIR $SERVICES_DIR;
do
  sudo chown -Rv root:root $DIR/kube-controller*
  if [ $DIR == $BIN_DIR ]; then
    sudo chmod -Rv 500 $DIR/kube-controller*
  else
    sudo chmod -Rv 600 $DIR/kube-controller*
  fi
  if [ $DIR == $SERVICES_DIR ]; then
    sudo systemctl enable kube-controller*
    sudo systemctl start kube-controller*
  fi
done
