#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

# shellcheck disable=SC2086
source common.sh

# shellcheck disable=SC2155
export NODE_HOSTNAME=$(ssh $NODE hostname -s)

KUBELET_FILE_NAME=kubelet
KUBELET_SETUP_DIR_NAME=kubelet
KUBELET_SETUP_DIR="${DATA_DIR}/$KUBELET_SETUP_DIR_NAME"

kubelet_download() {
  KUBELET_DOWNLOAD_FILE_NAME=$KUBELET_SETUP_DIR/$KUBELET_FILE_NAME
  if [ ! -f $KUBELET_DOWNLOAD_FILE_NAME ]; then
    wget -P $KUBELET_SETUP_DIR -q --show-progress --https-only --timestamping \
      "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/$KUBELET_FILE_NAME"
  else
    echo "$KUBELET_DOWNLOAD_FILE_NAME already exists, skipping download"
  fi
}

kubelet_setup_dirs() {
  master_check_dirs_and_create
  mkdir -p $KUBELET_SETUP_DIR
  ssh -T $NODE sudo mkdir -vp $(jq -r ".nodes.worker.kubernetes.paths[]" cluster-config.json)
  ssh -T $NODE sudo mkdir -vp $(jq -r ".nodes.worker.kubelet.paths[]" cluster-config.json)
}

kubelet_copy_ca_certs() {
  cp $MASTER_CERT_DIR/$CA_FILE_NAME.crt $MASTER_CERT_DIR/$CA_FILE_NAME.key $KUBELET_SETUP_DIR
}

kubelet_generate() {
  kubelet_setup_dirs
  master_ca_exists
  kubelet_copy_ca_certs
  kubelet_download

  cat <<EOF | tee $KUBELET_SETUP_DIR/openssl-worker-kubelet.cnf
[req]
req_extensions = v3_req
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = worker
IP.1 = ${NODE}
EOF

  openssl genrsa -out $KUBELET_SETUP_DIR/kubelet.key 2048
  openssl req -new -key $KUBELET_SETUP_DIR/kubelet.key \
    -subj "/CN=system:node:${NODE_HOSTNAME}/O=system:nodes" \
    -out $KUBELET_SETUP_DIR/kubelet.csr \
    -config $KUBELET_SETUP_DIR/openssl-worker-kubelet.cnf
  openssl x509 -req -in $KUBELET_SETUP_DIR/kubelet.csr \
    -CA $KUBELET_SETUP_DIR/$CA_FILE_NAME.crt \
    -CAkey $KUBELET_SETUP_DIR/$CA_FILE_NAME.key \
    -CAcreateserial \
    -out $KUBELET_SETUP_DIR/kubelet.crt \
    -extensions v3_req \
    -extfile $KUBELET_SETUP_DIR/openssl-worker-kubelet.cnf -days 1000

  sudo kubectl config set-cluster $CLUSTER_NAME \
    --certificate-authority=$KUBELET_SETUP_DIR/$CA_FILE_NAME.crt \
    --server=https://${MASTER_1}:6443 \
    --embed-certs=true \
    --kubeconfig=$KUBELET_SETUP_DIR/kubelet.kubeconfig

  sudo kubectl config set-credentials system:node:$NODE_HOSTNAME \
    --client-certificate=$KUBELET_SETUP_DIR/kubelet.crt \
    --client-key=$KUBELET_SETUP_DIR/kubelet.key \
    --embed-certs=true \
    --kubeconfig=$KUBELET_SETUP_DIR/kubelet.kubeconfig

  sudo kubectl config set-context default \
    --cluster=$CLUSTER_NAME \
    --user=system:node:$NODE_HOSTNAME \
    --kubeconfig=$KUBELET_SETUP_DIR/kubelet.kubeconfig

  sudo kubectl config use-context default --kubeconfig=$KUBELET_SETUP_DIR/kubelet.kubeconfig

  cat <<EOF | tee $KUBELET_SETUP_DIR/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: $WORKER_CERT_DIR/$CA_FILE_NAME.crt
authorization:
  mode: Webhook
clusterDomain: $CLUSTER_DOMAIN_NAME
clusterDNS:
  - ${CLUSTER_DNS}
resolvConf: /run/systemd/resolve/resolv.conf
runtimeRequestTimeout: "15m"
tlsCertFile: $KUBELET_CERT_DIR/kubelet.crt
tlsPrivateKeyFile: $KUBELET_CERT_DIR/kubelet.key
registerNode: true
EOF

  cat <<EOF | tee $KUBELET_SETUP_DIR/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=$BIN_DIR/kubelet \\
  --config=$KUBELET_CONFIG_DIR/kubelet-config.yaml \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=$KUBELET_CONFIG_DIR/kubelet.kubeconfig \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

kubelet_install() {
  scp -r $KUBELET_SETUP_DIR $NODE:~

  cat <<EOF | ssh -T $NODE
sudo cp -v ~/$KUBELET_SETUP_DIR_NAME/kubelet $BIN_DIR

sudo chown -v root:root $BIN_DIR/kubelet
sudo chmod -v 500 $BIN_DIR/kubelet
EOF

  cat <<EOF | ssh -T $NODE
sudo cp -v ~/$KUBELET_SETUP_DIR_NAME/$CA_FILE_NAME.crt $WORKER_CERT_DIR/
sudo cp -v ~/$KUBELET_SETUP_DIR_NAME/kubelet.key ~/$KUBELET_SETUP_DIR_NAME/kubelet.crt $KUBELET_CERT_DIR

sudo chown -v root:root $KUBELET_CERT_DIR/kubelet.key
sudo chmod -v 600 $KUBELET_CERT_DIR/kubelet.key

sudo chown -v root:root $KUBELET_CERT_DIR/kubelet.crt
sudo chmod -v 600 $KUBELET_CERT_DIR/kubelet.crt
EOF

  cat <<EOF | ssh -T $NODE
sudo cp -v ~/$KUBELET_SETUP_DIR_NAME/kubelet-config.yaml $KUBELET_CONFIG_DIR
sudo cp -v ~/$KUBELET_SETUP_DIR_NAME/kubelet.service $SERVICES_DIR/kubelet.service

sudo chown -v root:root $KUBELET_CONFIG_DIR/kubelet-config.yaml
sudo chmod -v 600 $KUBELET_CONFIG_DIR/kubelet-config.yaml

sudo chown -v root:root $SERVICES_DIR/kubelet.service
sudo chmod -v 600 $SERVICES_DIR/kubelet.service
EOF

  cat <<EOF | ssh -T $NODE
sudo cp -v ~/$KUBELET_SETUP_DIR_NAME/kubelet.kubeconfig $KUBELET_CONFIG_DIR
sudo chmod -v 600 $KUBELET_CONFIG_DIR/kubelet.kubeconfig
EOF
}

kubelet_remove() {
  cat <<EOF | ssh -T $NODE
# sudo rm -fv $WORKER_CERT_DIR/$CA_FILE_NAME.crt
sudo rm -fv $BIN_DIR/kubelet
sudo rm -fv $KUBELET_CERT_DIR/kubelet.key
sudo rm -fv $KUBELET_CERT_DIR/kubelet.crt
sudo rm -fv $KUBELET_CONFIG_DIR/kubelet.kubeconfig
sudo rm -fv $KUBELET_CONFIG_DIR/kubelet-config.yaml
sudo rm -fv $SERVICES_DIR/kubelet.service/kubelet.service
EOF
}

kubelet_remove_all() {
  kubelet_remove
  rm -fr $KUBELET_SETUP_DIR/*
}

kubelet_start() {
  cat <<EOF | ssh -T $NODE
  sudo systemctl enable kubelet.service
sudo systemctl start kubelet.service
EOF
}

kubelet_stop() {
  cat <<EOF | ssh -T $NODE
  sudo systemctl stop kubelet.service
sudo systemctl disable kubelet.service
EOF
}

kubelet_restart() {
  kubelet_stop
  kubelet_start
}

kubelet_reinstall() {
  kubelet_remove
  kubelet_generate
  kubelet_install
}

case $1 in
"setup-dirs")
  kubelet_setup_dirs
  ;;
"download")
  kubelet_setup_dirs
  kubelet_download
  ;;
"remove")
  kubelet_stop
  kubelet_remove
  ;;
"generate")
  kubelet_generate
  ;;
"install")
  kubelet_stop
  kubelet_setup_dirs
  kubelet_install
  kubelet_start
  ;;
"reinstall")
  kubelet_stop
  kubelet_reinstall
  kubelet_start
  ;;
"remove-all") ;;

"stop")
  kubelet_stop
  ;;

"start")
  kubelet_start
  ;;

"restart")
  kubelet_restart
  ;;

*)
  kubelet_stop
  kubelet_reinstall
  kubelet_start
  ;;
esac
