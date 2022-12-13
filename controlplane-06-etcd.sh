#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

# Binary
wget -q --show-progress --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/$ETCD_VERSION/$ETCD_DOWNLOAD_FILE.tar.gz"

tar -xvf "$ETCD_DOWNLOAD_FILE.tar.gz"
sudo mv -v $ETCD_DOWNLOAD_FILE/etcd* \
        $BIN_DIR/

# Certificate
cat > $DATA_DIR/openssl-etcd.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = ${MASTER_1}
IP.2 = 127.0.0.1
EOF

openssl genrsa -out $DATA_DIR/etcd-server.key 2048
openssl req -new -key $DATA_DIR/etcd-server.key \
    -subj "/CN=etcd-server/O=Kubernetes" \
    -out $DATA_DIR/etcd-server.csr \
    -config $DATA_DIR/openssl-etcd.cnf
openssl x509 -req -in $DATA_DIR/etcd-server.csr \
    -CA $MASTER_CERT_DIR/ca.crt \
    -CAkey $MASTER_CERT_DIR/ca.key \
    -CAcreateserial  \
    -out $DATA_DIR/etcd-server.crt \
    -extensions v3_req \
    -extfile $DATA_DIR/openssl-etcd.cnf -days 1000

sudo mv -v $DATA_DIR/etcd-server.key \
        $DATA_DIR/etcd-server.crt \
        $MASTER_CERT_DIR/
sudo ln -vs $MASTER_CERT_DIR/ca.crt $ETCD_DIR/ca.crt
sudo ln -vs $MASTER_CERT_DIR/etcd-server.key $ETCD_DIR/etcd-server.key
sudo ln -vs $MASTER_CERT_DIR/etcd-server.crt $ETCD_DIR/etcd-server.crt

# service
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

rm -vf "$ETCD_DOWNLOAD_FILE.tar.gz"
rm -vrf $ETCD_DOWNLOAD_FILE

for DIR in $MASTER_CONFIG_DIR $MASTER_CERT_DIR $BIN_DIR $SERVICES_DIR $ETCD_DIR;
do
  sudo chown -Rv root:root $DIR/etcd*
  if [ $DIR == $BIN_DIR ]; then
    sudo chmod -Rv 500 $DIR/etcd*
  else
    sudo chmod -Rv 600 $DIR/etcd*
  fi
done

sudo systemctl enable etcd.service
sudo systemctl start etcd.service
