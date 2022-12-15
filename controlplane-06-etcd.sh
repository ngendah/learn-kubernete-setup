#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

etcd_download() {
  if [ ! -f "$DATA_DIR/$ETCD_DOWNLOAD_FILE" ]; then
    wget -q --show-progress --https-only --timestamping \
      "https://github.com/coreos/etcd/releases/download/$ETCD_VERSION/$ETCD_DOWNLOAD_FILE.tar.gz"
    tar -C $DATA_DIR -xvf "$ETCD_DOWNLOAD_FILE.tar.gz"
    rm -f "$ETCD_DOWNLOAD_FILE.tar.gz"
  fi
}

etcd_generate() {
  etcd_download

  cat >$DATA_DIR/openssl-etcd.cnf <<EOF
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
    -CAcreateserial \
    -out $DATA_DIR/etcd-server.crt \
    -extensions v3_req \
    -extfile $DATA_DIR/openssl-etcd.cnf -days 1000

  cat <<EOF | tee $DATA_DIR/etcd.service
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
  --listen-client-urls=https://$MASTER_1:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls=https://$MASTER_1:2379,https://127.0.0.1:2379
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

etcd_install() {
  sudo cp -v $DATA_DIR/$ETCD_DOWNLOAD_FILE/etcd* $BIN_DIR/
  sudo cp -v $DATA_DIR/etcd-server.key $DATA_DIR/etcd-server.crt $MASTER_CERT_DIR/
  sudo cp -v $DATA_DIR/etcd.service $SERVICES_DIR/etcd.service

  sudo ln -vs $MASTER_CERT_DIR/ca.crt $ETCD_DIR/ca.crt
  sudo ln -vs $MASTER_CERT_DIR/etcd-server.key $ETCD_DIR/etcd-server.key
  sudo ln -vs $MASTER_CERT_DIR/etcd-server.crt $ETCD_DIR/etcd-server.crt

  sudo chmod -Rv 500 $BIN_DIR/etcd*
  sudo chmod -Rv 600 $MASTER_CERT_DIR/etcd* $SERVICES_DIR/etcd* $ETCD_DIR/
  sudo chown -Rv root:root $BIN_DIR/etcd* $MASTER_CERT_DIR/etcd* $ETCD_DIR/
}

etcd_remove() {
  sudo rm -fr $ETCD_DIR/ $BIN_DIR/etcd* $MASTER_CERT_DIR/etcd*
}

etcd_remove_all() {
  etcd_remove
  rm -fr $DATA_DIR/etcd-server.key $DATA_DIR/etcd-server.crt $DATA_DIR/etcd-server.csr \
    $DATA_DIR/etcd.service $DATA_DIR/*etcd.cnf $DATA_DIR/${ETCD_DOWNLOAD_FILE:?}
}

etcd_start() {
  sudo systemctl enable etcd.service
  sudo systemctl start etcd.service
}

etcd_stop() {
  sudo systemctl stop etcd.service
  sudo systemctl disable etcd.service
}

etcd_restart() {
  etcd_stop
  etcd_start
}

etcd_reinstall() {
  if [ -f $DATA_DIR/etcd-server.key ] && [ -f $DATA_DIR/etcd-server.crt ] && [ -f $DATA_DIR/etcd.service ]; then
    etcd_remove
    etcd_install
  else
    etcd_remove_all
    etcd_generate
    etcd_install
  fi
}

case $1 in
"remove")
  etcd_stop
  etcd_remove
  ;;
"generate")
  etcd_generate
  ;;
"install")
  etcd_install
  etcd_start
  ;;
"reinstall")
  etcd_stop
  etcd_reinstall
  etcd_start
  ;;
"remove-all") ;;

"stop")
  etcd_stop
  ;;

"start")
  etcd_start
  ;;

"restart")
  etcd_restart
  ;;

*)
  etcd_stop
  etcd_reinstall
  etcd_start
  ;;
esac
