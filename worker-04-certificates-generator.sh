#!/usr/bin/env bash

source common.sh

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
scp kube-proxy.key kube-proxy.crt worker.key worker.crt /etc/kubernetes/pki/ca.crt $NODE:~

# move files
cat<<EOF | ssh -T $NODE

sudo mv -v ~/ca.crt /etc/kubernetes/pki/
sudo mv -v ~/worker.key /etc/kubernetes/pki/kubelet.key
sudo mv -v ~/worker.crt /etc/kubernetes/pki/kubelet.crt
sudo mv -v ~/kube-proxy.key /etc/kubernetes/pki/kube-proxy.key
sudo mv -v ~/kube-proxy.crt /etc/kubernetes/pki/kube-proxy.crt

sudo chown -Rv root:root /etc/kubernetes/pki/
sudo chmod -Rv 600 /etc/kubernetes/pki/
EOF
