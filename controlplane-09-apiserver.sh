#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

# Binary
wget --show-progress --https-only --timestamping \
    https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kube-apiserver

sudo mv -v  kube-apiserver $BIN_DIR/

# Certificates
cat > $DATA_DIR/openssl.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
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
openssl genrsa -out $DATA_DIR/kube-apiserver.key 2048
openssl req -new -key $DATA_DIR/kube-apiserver.key \
    -subj "/CN=kube-apiserver/O=Kubernetes" \
    -config $DATA_DIR/openssl.cnf \
    -out $DATA_DIR/kube-apiserver.csr
openssl x509 -req -in $DATA_DIR/kube-apiserver.csr \
  -CA $MASTER_CERT_DIR/ca.crt \
  -CAkey $MASTER_CERT_DIR/ca.key \
  -CAcreateserial  \
  -out $DATA_DIR/kube-apiserver.crt \
  -extensions v3_req \
  -extfile $DATA_DIR/openssl.cnf -days 1000

openssl genrsa -out $DATA_DIR/service-account.key 2048
openssl req -new -key $DATA_DIR/service-account.key \
    -subj "/CN=service-accounts/O=Kubernetes" \
    -out $DATA_DIR/service-account.csr
 openssl x509 -req -in $DATA_DIR/service-account.csr \
    -CA $MASTER_CERT_DIR/ca.crt \
    -CAkey $MASTER_CERT_DIR/ca.key \
    -CAcreateserial \
    -out $DATA_DIR/service-account.crt \
    -days 1000

cat > $DATA_DIR/openssl-kubelet.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = critical, CA:FALSE
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF
openssl genrsa -out $DATA_DIR/apiserver-kubelet-client.key 2048
openssl req -new -key $DATA_DIR/apiserver-kubelet-client.key \
    -subj "/CN=kube-apiserver-kubelet-client/O=system:masters" \
    -out $DATA_DIR/apiserver-kubelet-client.csr \
    -config $DATA_DIR/openssl-kubelet.cnf
openssl x509 -req -in $DATA_DIR/apiserver-kubelet-client.csr \
    -CA $MASTER_CERT_DIR/ca.crt \
    -CAkey $MASTER_CERT_DIR/ca.key \
    -CAcreateserial  \
    -out $DATA_DIR/apiserver-kubelet-client.crt \
    -extensions v3_req \
    -extfile $DATA_DIR/openssl-kubelet.cnf \
    -days 1000


sudo mv -v $DATA_DIR/kube-apiserver.key \
          $DATA_DIR/kube-apiserver.crt \
          $DATA_DIR/service-account.key \
          $DATA_DIR/service-account.crt \
          $DATA_DIR/apiserver-kubelet-client.key \
          $DATA_DIR/apiserver-kubelet-client.crt \
          $MASTER_CERT_DIR

# Data encryption configuration
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat<<EOF | sudo tee $MASTER_CONFIG_DIR/encryption-config.yaml
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

# Service
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
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
  --client-ca-file=$MASTER_CERT_DIR/ca.crt \\
  --enable-admission-plugins=NodeRestriction,ServiceAccount \\
  --enable-bootstrap-token-auth=true \\
  --etcd-cafile=$MASTER_CERT_DIR/ca.crt \\
  --etcd-certfile=$MASTER_CERT_DIR/etcd-server.crt \\
  --etcd-keyfile=$MASTER_CERT_DIR/etcd-server.key \\
  --etcd-servers=https://${MASTER_1}:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=$MASTER_CONFIG_DIR/encryption-config.yaml \\
  --kubelet-certificate-authority=$MASTER_CERT_DIR/ca.crt \\
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


for DIR in $MASTER_CONFIG_DIR $MASTER_CERT_DIR $BIN_DIR $SERVICES_DIR;
do
  sudo chown -Rv --quiet root:root $DIR/*apiserver*
  if [ $DIR == $BIN_DIR ]; then
    sudo chmod -Rv --quiet 500 $DIR/*apiserver*
  else
    sudo chmod -Rv --quiet 600 $DIR/*apiserver* $DIR/service-*
  fi
done

sudo systemctl enable kube-apiserver.service
sudo systemctl start kube-apiserver.service
