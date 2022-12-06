#!/usr/bin/env bash

source common.sh

wget --show-progress --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kube-apiserver

sudo mv -v  kube-apiserver $BIN_DIR/

# Encryption configuration
# it will store the key to encrypt secrets
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat<<EOF | sudo tee /etc/kubernetes/encryption-config.yaml
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

# setup kube-apiserver systemd unit file
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
  --encryption-provider-config=/etc/kubernetes/encryption-config.yaml \\
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
