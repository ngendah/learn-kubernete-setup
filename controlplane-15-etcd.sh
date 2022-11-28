# SETUP ETCD ON MASTER NODE

export MASTER_1=$(jq '.master_node_ip' cluster-config.json)
export WORKER_1=$(jq '.worker_node_ip' cluster-config.json)
export SERVICE_CIDR=$(jq '.service_cidr' cluster-config.json)
export CLUSTER_NAME=$(jq '.cluster_name' cluster-config.json)
export POD_CIDR=$(jq '.pod_cidr' cluster-config.json)
export KUBERNETES_VERSION=$(jq '.kubernetes_version' cluster-config.json | sed 's/"//g')
export API_SERVICE=$(echo $SERVICE_CIDR | sed 's/0\/24/1/g')
export ETCD_NAME=$(hostname -s)
export ETCD_VERSION=$(jq '.etcd_version' cluster-config.json | sed 's/"//g')
export ETCD_DOWNLOAD_FILE="etcd-$ETCD_VERSION-linux-amd64"
export INTERNAL_IP=$MASTER_1

# download binary
wget -q --show-progress --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/$ETCD_VERSION/$ETCD_DOWNLOAD_FILE.tar.gz"

# extract and move to bin directory
tar -xvf "$ETCD_DOWNLOAD_FILE.tar.gz" 
sudo mv -v $ETCD_DOWNLOAD_FILE/etcd* \
        /usr/local/bin/

# copy etcd TLS key and certificate
sudo cp /etc/kubernetes/pki/etcd-server.key\
        /etc/kubernetes/pki/etcd-server.crt \
        /etc/etcd/
sudo ln -vs /etc/kubernetes/pki/ca.crt \
            /etc/etcd/ca.crt

# create systemd unit file
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --data-dir=/var/lib/etcd \\
  --cert-file=/etc/etcd/etcd-server.crt \\
  --key-file=/etc/etcd/etcd-server.key \\
  --peer-cert-file=/etc/etcd/etcd-server.crt \\
  --peer-key-file=/etc/etcd/etcd-server.key \\
  --trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls=https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls=https://${INTERNAL_IP}:2380 \\
  --listen-client-urls=https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls=https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token=etcd-cluster-0 \\
  --initial-cluster=master-1=https://${MASTER_1}:2380,\\
  --initial-cluster-state new
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


# cleanup
rm -vf "$ETCD_DOWNLOAD_FILE.tar.gz"
rm -vrf $ETCD_DOWNLOAD_FILE