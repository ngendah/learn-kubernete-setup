#!/usr/bin/env bash

source common.sh

export NODE_HOSTNAME=$(ssh $NODE sudo hostname -s)

# Binary
cat<<EOF | ssh -T $NODE
echo "Downloading kubelet-$KUBERNETES_VERSION"
wget -q --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/KUBERNETES_VERSION/bin/linux/amd64/kubelet
sudo mv -v ./kubectl $BIN_DIR
sudo chmod -v +x $BIN_DIR/kubelet
sudo chown -v root:root $BIN_DIR/kubelet
sudo chmod -v 600 $BIN_DIR/kubelet
EOF

# Certificate
cat<<EOF | tee $DATA_DIR/openssl-kubelet.cnf
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
        -config $DATA_DIR/openssl-kubelet.cnf
openssl x509 -req -in $DATA_DIR/kubelet.csr \
        -CA $MASTER_CERT_DIR/ca.crt \
        -CAkey $MASTER_CERT_DIR/ca.key \
        -CAcreateserial \
        -out $DATA_DIR/kubelet.crt \
        -extensions v3_req \
        -extfile $DATA_DIR/openssl-kubelet.cnf -days 1000

scp $DATA_DIR/kubelet.key $DATA_DIR/kubelet.crt $MASTER_CERT_DIR/ca.crt $NODE:~

cat<<EOF | ssh -T $NODE
sudo mv -v ~/ca.crt $WORKER_CERT_DIR/
sudo mv -v ~/kubelet.key $KUBELET_CERT_DIR/kubelet.key
sudo mv -v ~/kubelet.crt $KUBELET_CERT_DIR/kubelet.crt
EOF


# Configuration
cat<<EOF | ssh -T $NODE
kubectl config set-cluster $CLUSTER_NAME \\
    --certificate-authority=$WORKER_CERT_DIR/ca.crt \\
    --server=https://${MASTER_1}:6443 \\
    --kubeconfig=kubelet.kubeconfig

kubectl config set-credentials system:node:$NODE_HOSTNAME \\
    --client-certificate=$KUBELET_CERT_DIR/$NODE_HOSTNAME.crt \\
    --client-key=$KUBELET_CERT_DIR/$NODE_HOSTNAME.key \\
    --kubeconfig=kubelet.kubeconfig

kubectl config set-context default \\
    --cluster=$CLUSTER_NAME \\
    --user=system:node:$NODE_HOSTNAME \\
    --kubeconfig=kubelet.kubeconfig

kubectl config use-context default --kubeconfig=kubelet.kubeconfig
sudo mv -v ~/kubelet.kubeconfig $KUBELET_CONFIG_DIR
EOF


cat<<EOF | tee $DATA_DIR/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: $WORKER_CERT_DIR/ca.crt
authorization:
  mode: Webhook
clusterDomain: cluster.local
clusterDNS:
  - ${CLUSTER_DNS}
resolvConf: /run/systemd/resolve/resolv.conf
runtimeRequestTimeout: "15m"
tlsCertFile: $WORKER_CERT_DIR/kubelet.crt
tlsPrivateKeyFile: $WORKER_CERT_DIR/kubelet.key
registerNode: true
EOF

cat<<EOF | tee $DATA_DIR/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=$BIN_DIR/kubelet \\
  --config=$KUBELET_CONFIG_DIR/kubelet-config.yaml \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=KUBELET_CONFIG_DIR/kubelet.kubeconfig \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

scp $DATA_DIR/kubelet-config.yaml $DATA_DIR/kubelet.service $NODE:~

cat<<EOF | ssh -T $NODE
sudo mv -v ~/kubelet-config.yaml $KUBELET_CONFIG_DIR
sudo mv -v ~/kubelet.service /etc/systemd/system/kubelet.service
EOF
