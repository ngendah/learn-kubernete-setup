#!/usr/bin/env bash

# SETUP ETCD ON MASTER NODE
source common.sh

# download binary
wget -q --show-progress --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/$ETCD_VERSION/$ETCD_DOWNLOAD_FILE.tar.gz"

# extract and move to bin directory
tar -xvf "$ETCD_DOWNLOAD_FILE.tar.gz" 
sudo mv -v $ETCD_DOWNLOAD_FILE/etcd* \
        $BIN_DIR/

# copy etcd TLS key and certificate
sudo cp $MASTER_CERT_DIR/etcd-server.key\
        $MASTER_CERT_DIR/etcd-server.crt \
        $ETCD_DIR/
sudo ln -vs $MASTER_CERT_DIR/ca.crt \
            $ETCD_DIR/ca.crt

# create systemd unit file
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=$BIN_DIR/etcd \\
  --name=${ETCD_NAME} \\
  --data-dir=$ETCD_DATA_DIR \\
  --cert-file=$ETCD_DIR/etcd-server.crt \\
  --key-file=$ETCD_DIR/etcd-server.key \\
  --peer-cert-file=$ETCD_DIR/etcd-server.crt \\
  --peer-key-file=$ETCD_DIR/etcd-server.key \\
  --trusted-ca-file=$ETCD_DIR/ca.crt \\
  --peer-trusted-ca-file=$ETCD_DIR/ca.crt \\
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