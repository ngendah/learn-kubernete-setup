# SETUP WORKER NODE
# GENERATE TLS CERTIFICATES

# Run the script on the master node

export MASTER_1=192.168.122.204
export WORKER_1=192.168.122.4
export SERVICE_CIDR=10.96.0.0/24
export API_SERVICE=10.96.0.1
export CLUSTER_DNS=10.96.0.10
export CLUSTER_NAME="kubernetes"
export POD_CIDR=10.244.0.0/16

export INTERNAL_IP=$MASTER_1


export NODE=$WORKER_1

# kube proxy certificate
openssl genrsa -out kube-proxy.key 2048
openssl req -new -key kube-proxy.key \
    -subj "/CN=system:kube-proxy/O=system:node-proxier" -out kube-proxy.csr
openssl x509 -req -in kube-proxy.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial  -out kube-proxy.crt -days 1000


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
              -CA /var/lib/kubernetes/pki/ca.crt \
              -CAkey /var/lib/kubernetes/pki/ca.key -CAcreateserial \
              -out worker.crt -extensions v3_req \
              -extfile openssl-worker.cnf -days 1000

# copy files
scp kube-proxy.key kube-proxy.crt worker.key worker.crt certificates-cp.sh /var/lib/kubernetes/pki/ca.crt $NODE:~

# get node host name
chmod +x worker-hostname.sh
scp worker-hostname.sh $NODE:~
export NODE_HOSTNAME=`ssh $NODE "bash -c ~/worker-hostname.sh"`

# move files
cat<<EOF | ssh $NODE

sudo mv -v ~/ca.crt /var/lib/kubernetes/pki/
sudo mv -v ~/worker.key /var/lib/kubernetes/pki/kubelet.key
sudo mv -v ~/worker.crt /var/lib/kubernetes/pki/kubelet.crt
sudo mv -v ~/worker.crt /var/lib/kubernetes/pki/kube-proxy.key
sudo mv -v ~/worker.crt /var/lib/kubernetes/pki/kube-proxy.crt

sudo chown -Rv root:root /var/lib/kubernetes/pki/
sudo chmod -Rv 600 /var/lib/kubernetes/pki/
EOF
