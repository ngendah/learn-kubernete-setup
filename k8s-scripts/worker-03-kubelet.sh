#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

# shellcheck disable=SC2155
export NODE_HOSTNAME=$(ssh $NODE hostname -s)

kubelet_generate() {
  master_ca_exists

  cat <<EOF | tee $DATA_DIR/openssl-worker-kubelet.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = worker
IP.1 = ${NODE}
EOF

  openssl genrsa -out $DATA_DIR/kubelet.key 2048
  openssl req -new -key $DATA_DIR/kubelet.key \
    -subj "/CN=system:node:${NODE_HOSTNAME}/O=system:nodes" \
    -out $DATA_DIR/kubelet.csr \
    -config $DATA_DIR/openssl-worker-kubelet.cnf
  openssl x509 -req -in $DATA_DIR/kubelet.csr \
    -CA $MASTER_CERT_DIR/$CA_FILE_NAME.crt \
    -CAkey $MASTER_CERT_DIR/$CA_FILE_NAME.key \
    -CAcreateserial \
    -out $DATA_DIR/kubelet.crt \
    -extensions v3_req \
    -extfile $DATA_DIR/openssl-worker-kubelet.cnf -days 1000

  cat <<EOF | tee $DATA_DIR/kubelet-config.yaml
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

  cat <<EOF | tee $DATA_DIR/kubelet.service
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
  cat <<EOF | ssh -T $NODE
echo "Downloading kubelet-$KUBERNETES_VERSION"
wget -q --https-only --timestamping \
    https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kubelet

sudo mv -v ./kubelet $BIN_DIR

sudo chown -v root:root $BIN_DIR/kubelet
sudo chmod -v 500 $BIN_DIR/kubelet
EOF

  scp $DATA_DIR/kubelet.key $DATA_DIR/kubelet.crt $MASTER_CERT_DIR/$CA_FILE_NAME.crt $NODE:~

  cat <<EOF | ssh -T $NODE
sudo mv -v ~/$CA_FILE_NAME.crt $WORKER_CERT_DIR/
sudo mv -v ~/kubelet.key $KUBELET_CERT_DIR/kubelet.key
sudo mv -v ~/kubelet.crt $KUBELET_CERT_DIR/kubelet.crt

sudo chown -v root:root $KUBELET_CERT_DIR/kubelet.key
sudo chmod -v 600 $KUBELET_CERT_DIR/kubelet.key
EOF

  cat <<EOF | ssh -T $NODE
sudo kubectl config set-cluster $CLUSTER_NAME \\
    --certificate-authority=$WORKER_CERT_DIR/$CA_FILE_NAME.crt \\
    --server=https://${MASTER_1}:6443 \\
    --kubeconfig=kubelet.kubeconfig

sudo kubectl config set-credentials system:node:$NODE_HOSTNAME \\
    --client-certificate=$KUBELET_CERT_DIR/kubelet.crt \\
    --client-key=$KUBELET_CERT_DIR/kubelet.key \\
    --kubeconfig=kubelet.kubeconfig

sudo kubectl config set-context default \\
    --cluster=$CLUSTER_NAME \\
    --user=system:node:$NODE_HOSTNAME \\
    --kubeconfig=kubelet.kubeconfig

sudo kubectl config use-context default --kubeconfig=kubelet.kubeconfig

sudo mv -v ~/kubelet.kubeconfig $KUBELET_CONFIG_DIR
sudo chmod -v 600 $KUBELET_CONFIG_DIR/kubelet.kubeconfig
EOF

  scp $DATA_DIR/kubelet-config.yaml $DATA_DIR/kubelet.service $NODE:~

  cat <<EOF | ssh -T $NODE
sudo mv -v ~/kubelet-config.yaml $KUBELET_CONFIG_DIR
sudo mv -v ~/kubelet.service $SERVICES_DIR/kubelet.service

sudo chown -v root:root $KUBELET_CONFIG_DIR/kubelet-config.yaml
sudo chmod -v 600 $KUBELET_CONFIG_DIR/kubelet-config.yaml

sudo chown -v root:root $SERVICES_DIR/kubelet.service
sudo chmod -v 600 $SERVICES_DIR/kubelet.service
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
  $DATA_DIR/openssl-worker-kubelet.cnf $DATA_DIR/kubelet*
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
  kubelet_remove_all
  kubelet_generate
  kubelet_install
}

case $1 in
"remove")
  ;;
"generate")
  ;;
"install")
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