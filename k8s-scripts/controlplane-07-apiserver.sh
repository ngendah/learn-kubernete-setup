#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

# shellcheck disable=SC2086
source common.sh

APISERVER_FILE_NAME=kube-apiserver
APISERVER_SETUP_DIR="${DATA_DIR}/apiserver"

apiserver_download() {
  APISERVER_DOWNLOAD_FILE_NAME=$APISERVER_SETUP_DIR/$APISERVER_FILE_NAME
  if [ ! -f $APISERVER_DOWNLOAD_FILE_NAME ]; then
    wget -P $APISERVER_SETUP_DIR -q --show-progress --https-only --timestamping \
      "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/$APISERVER_FILE_NAME"
  else
    echo "$APISERVER_DOWNLOAD_FILE_NAME already exists, skipping download"
  fi
}

apiserver_setup_dirs() {
  master_check_dirs_and_create
  mkdir -p $APISERVER_SETUP_DIR
}

apiserver_generate() {
  apiserver_setup_dirs
  master_ca_exists
  apiserver_download

  cat >$APISERVER_SETUP_DIR/openssl-apiserver.cnf <<EOF
[req]
req_extensions = v3_req
[v3_req]
basicConstraints = critical, CA:FALSE
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster
DNS.5 = kubernetes.default.svc.cluster.local
IP.1 = ${API_SERVICE}
IP.2 = ${MASTER_1}
IP.3 = 127.0.0.1
EOF

  openssl genrsa -out $APISERVER_SETUP_DIR/kube-apiserver.key 2048
  openssl req -new -key $APISERVER_SETUP_DIR/kube-apiserver.key \
    -subj "/CN=kube-apiserver/O=Kubernetes" \
    -config $APISERVER_SETUP_DIR/openssl-apiserver.cnf \
    -out $APISERVER_SETUP_DIR/kube-apiserver.csr
  openssl x509 -req -in $APISERVER_SETUP_DIR/kube-apiserver.csr \
    -CA $DATA_DIR/$CA_FILE_NAME.crt \
    -CAkey $DATA_DIR/$CA_FILE_NAME.key \
    -CAcreateserial \
    -out $APISERVER_SETUP_DIR/kube-apiserver.crt \
    -extensions v3_req \
    -extfile $APISERVER_SETUP_DIR/openssl-apiserver.cnf -days 1000

  openssl genrsa -out $APISERVER_SETUP_DIR/service-account.key 2048
  openssl req -new -key $APISERVER_SETUP_DIR/service-account.key \
    -subj "/CN=service-accounts/O=Kubernetes" \
    -out $APISERVER_SETUP_DIR/service-account.csr
  openssl x509 -req -in $APISERVER_SETUP_DIR/service-account.csr \
    -CA $DATA_DIR/$CA_FILE_NAME.crt \
    -CAkey $DATA_DIR/$CA_FILE_NAME.key \
    -CAcreateserial \
    -out $APISERVER_SETUP_DIR/service-account.crt \
    -days 1000

  cat >$APISERVER_SETUP_DIR/openssl-kubelet.cnf <<EOF
[req]
req_extensions = v3_req
[v3_req]
basicConstraints = critical, CA:FALSE
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

  openssl genrsa -out $APISERVER_SETUP_DIR/apiserver-kubelet-client.key 2048
  openssl req -new -key $APISERVER_SETUP_DIR/apiserver-kubelet-client.key \
    -subj "/CN=kube-apiserver-kubelet-client/O=system:masters" \
    -out $APISERVER_SETUP_DIR/apiserver-kubelet-client.csr \
    -config $APISERVER_SETUP_DIR/openssl-kubelet.cnf
  openssl x509 -req -in $APISERVER_SETUP_DIR/apiserver-kubelet-client.csr \
    -CA $DATA_DIR/$CA_FILE_NAME.crt \
    -CAkey $DATA_DIR/$CA_FILE_NAME.key \
    -CAcreateserial \
    -out $APISERVER_SETUP_DIR/apiserver-kubelet-client.crt \
    -extensions v3_req \
    -extfile $APISERVER_SETUP_DIR/openssl-kubelet.cnf \
    -days 1000

  ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
  cat <<EOF | tee $APISERVER_SETUP_DIR/encryption-config.yaml
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

  cat <<EOF | tee $APISERVER_SETUP_DIR/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=$BIN_DIR/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=1 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=$MASTER_AUDIT_LOG_DIR/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=$MASTER_CERT_DIR/$CA_FILE_NAME.crt \\
  --enable-admission-plugins=NodeRestriction,ServiceAccount \\
  --enable-bootstrap-token-auth=true \\
  --etcd-cafile=$MASTER_CERT_DIR/$CA_FILE_NAME.crt \\
  --etcd-certfile=$MASTER_CERT_DIR/etcd-server.crt \\
  --etcd-keyfile=$MASTER_CERT_DIR/etcd-server.key \\
  --etcd-servers=https://${MASTER_1}:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=$MASTER_CONFIG_DIR/encryption-config.yaml \\
  --kubelet-certificate-authority=$MASTER_CERT_DIR/$CA_FILE_NAME.crt \\
  --kubelet-client-certificate=$MASTER_CERT_DIR/apiserver-kubelet-client.crt \\
  --kubelet-client-key=$MASTER_CERT_DIR/apiserver-kubelet-client.key \\
  --runtime-config=api/all=true \\
  --service-account-key-file=$MASTER_CERT_DIR/service-account.crt \\
  --service-account-signing-key-file=$MASTER_CERT_DIR/service-account.key \\
  --service-account-issuer=https://${MASTER_1}:6443 \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=$MASTER_CERT_DIR/kube-apiserver.crt \\
  --tls-private-key-file=$MASTER_CERT_DIR/kube-apiserver.key \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

apiserver_install() {
  sudo cp -v $APISERVER_SETUP_DIR/kube-apiserver $BIN_DIR/
  sudo cp -v $APISERVER_SETUP_DIR/*.key $APISERVER_SETUP_DIR/*.crt $MASTER_CERT_DIR
  sudo cp -v $APISERVER_SETUP_DIR/encryption-config.yaml $MASTER_CONFIG_DIR
  sudo cp -v $APISERVER_SETUP_DIR/kube-apiserver.service $SERVICES_DIR

  sudo chmod -v 500 $BIN_DIR/kube-apiserver
  sudo chmod -Rv 600 $MASTER_CERT_DIR/*apiserver* $MASTER_CERT_DIR/service-account* \
    $MASTER_CONFIG_DIR/encryption* $SERVICES_DIR/kube-apiserver*
  sudo chown -Rv root:root $BIN_DIR/kube-apiserver $MASTER_CERT_DIR/*apiserver* $MASTER_CERT_DIR/service-account* \
    $MASTER_CONFIG_DIR/encryption* $SERVICES_DIR/kube-apiserver*
}

apiserver_remove() {
  sudo rm -fr $BIN_DIR/kube-apiserver $MASTER_CERT_DIR/*apiserver* $MASTER_CERT_DIR/service-account* \
    $MASTER_CONFIG_DIR/encryption* $SERVICES_DIR/kube-apiserver*
}

apiserver_remove_all() {
  apiserver_remove
  sudo rm -fr $APISERVER_SETUP_DIR/*
}

apiserver_start() {
  sudo systemctl enable kube-apiserver.service
  sudo systemctl start kube-apiserver.service
}

apiserver_stop() {
  sudo systemctl stop kube-apiserver.service
  sudo systemctl disable kube-apiserver.service
}

apiserver_restart() {
  apiserver_stop
  apiserver_start
}

apiserver_reinstall() {
  if [ -f $APISERVER_SETUP_DIR/kube-apiserver ] && [ -f $APISERVER_SETUP_DIR/kube-apiserver.key ] && \
    [ -f $APISERVER_SETUP_DIR/kube-apiserver.crt ] && [ -f $APISERVER_SETUP_DIR/service-account.key ] && \
    [ -f $APISERVER_SETUP_DIR/service-account.crt ] && [ -f $APISERVER_SETUP_DIR/apiserver-kubelet-client.key ] && \
    [ -f $APISERVER_SETUP_DIR/apiserver-kubelet-client.crt ] && [ -f $APISERVER_SETUP_DIR/kube-apiserver.service ] ; then
    apiserver_remove
    apiserver_install
  else
    apiserver_remove_all
    apiserver_generate
    apiserver_install
  fi
}

case $1 in
"setup-dirs")
  apiserver_setup_dirs
  ;;
"download")
  apiserver_setup_dirs
  apiserver_download
  ;;
"remove")
  apiserver_stop
  apiserver_remove
  ;;
"generate")
  apiserver_generate
  ;;
"install")
  apiserver_install
  apiserver_start
  ;;
"reinstall")
  apiserver_stop
  apiserver_reinstall
  apiserver_start
  ;;
"remove-all") ;;

"stop")
  apiserver_stop
  ;;

"start")
  apiserver_start
  ;;

"restart")
  apiserver_restart
  ;;

*)
  apiserver_stop
  apiserver_reinstall
  apiserver_start
  ;;
esac
