#!/usr/bin/env bash

# SETUP WORKER NODE
# GENERATE TLS CERTIFICATES

# Run the script on the master node
# shellcheck disable=SC2155
export MASTER_1=$(jq -r '.master_node_ip' cluster-config.json)
export WORKER_1=$(jq -r '.worker_node_ip' cluster-config.json)
export SERVICE_CIDR=$(jq -r '.service_cidr' cluster-config.json)
export CLUSTER_NAME=$(jq '.cluster_name' cluster-config.json)
export POD_CIDR=$(jq -r '.pod_cidr' cluster-config.json)
export KUBERNETES_VERSION=$(jq -r '.kubernetes_version' cluster-config.json)
export API_SERVICE=$(echo "$SERVICE_CIDR" | sed 's/0\/24/1/g')
export CLUSTER_DNS=$(echo "$SERVICE_CIDR" | sed 's/0\/24/10/g')
export INTERNAL_IP=$MASTER_1


export NODE=$WORKER_1

# kube proxy certificate
openssl genrsa -out kube-proxy.key 2048
openssl req -new -key kube-proxy.key \
    -subj "/CN=system:kube-proxy/O=system:node-proxier" -out kube-proxy.csr
openssl x509 -req -in kube-proxy.csr \
    -CA /etc/kubernetes/pki/ca.crt -CAkey ca.key -CAcreateserial  -out kube-proxy.crt -days 1000


# kubelet certificate
cat<<EOF | tee openssl-worker.cnf
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

openssl genrsa -out worker.key 2048
openssl req -new -key worker.key \
        -subj "/CN=system:node:worker/O=system:nodes" \
        -out worker.csr -config openssl-worker.cnf
openssl x509 -req -in worker.csr \
              -CA /etc/kubernetes/pki/ca.crt \
              -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial \
              -out worker.crt -extensions v3_req \
              -extfile openssl-worker.cnf -days 1000

# copy files
scp kube-proxy.key kube-proxy.crt worker.key worker.crt certificates-cp.sh /etc/kubernetes/pki/ca.crt $NODE:~

# move files
cat<<EOF | ssh $NODE

sudo mv -v ~/ca.crt /etc/kubernetes/pki/
sudo mv -v ~/worker.key /etc/kubernetes/pki/kubelet.key
sudo mv -v ~/worker.crt /etc/kubernetes/pki/kubelet.crt
sudo mv -v ~/worker.crt /etc/kubernetes/pki/kube-proxy.key
sudo mv -v ~/worker.crt /etc/kubernetes/pki/kube-proxy.crt

sudo chown -Rv root:root /etc/kubernetes/pki/
sudo chmod -Rv 600 /etc/kubernetes/pki/
EOF