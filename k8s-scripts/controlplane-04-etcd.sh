#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

# shellcheck disable=SC2086
source common.sh

ETCD_FILE_NAME="etcd-$ETCD_VERSION-linux-amd64"
ETCD_SETUP_DIR="${DATA_DIR}/etcd"
ETCD_DOWNLOAD_DIR=$ETCD_SETUP_DIR/$ETCD_FILE_NAME

etcd_download() {
  ETCD_DOWNLOAD_FILE_NAME="${ETCD_DOWNLOAD_DIR}.tar.gz"
  if [[ ! -f $ETCD_DOWNLOAD_FILE_NAME ]]; then
    wget -P $ETCD_SETUP_DIR -q --show-progress --https-only --timestamping \
      "https://github.com/coreos/etcd/releases/download/$ETCD_VERSION/$ETCD_FILE_NAME.tar.gz"
  else
    echo "$ETCD_DOWNLOAD_FILE_NAME already exists, skipping download"
  fi
  tar -C $ETCD_SETUP_DIR -xvf "$ETCD_DOWNLOAD_FILE_NAME"
}

etcd_setup_dirs() {
  master_check_dirs_and_create
  mkdir -p $ETCD_SETUP_DIR
}

etcd_generate() {
  etcd_setup_dirs
  master_ca_exists
  etcd_download

  cat >$ETCD_SETUP_DIR/openssl-etcd.cnf <<EOF
[req]
req_extensions = v3_req
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = ${MASTER_1}
IP.2 = 127.0.0.1
EOF

  openssl genrsa -out $ETCD_SETUP_DIR/etcd-server.key 2048
  openssl req -new -key $ETCD_SETUP_DIR/etcd-server.key \
    -subj "/CN=etcd-server/O=Kubernetes" \
    -out $ETCD_SETUP_DIR/etcd-server.csr \
    -config $ETCD_SETUP_DIR/openssl-etcd.cnf
  openssl x509 -req -in $ETCD_SETUP_DIR/etcd-server.csr \
    -CA $DATA_DIR/$CA_FILE_NAME.crt \
    -CAkey $DATA_DIR/$CA_FILE_NAME.key \
    -CAcreateserial \
    -out $ETCD_SETUP_DIR/etcd-server.crt \
    -extensions v3_req \
    -extfile $ETCD_SETUP_DIR/openssl-etcd.cnf -days 1000

  #TODO: change ETCD_NAME to HOST_NAME
  cat <<EOF | tee $ETCD_SETUP_DIR/etcd.service
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
  --trusted-ca-file=$ETCD_DIR/$CA_FILE_NAME.crt \\
  --peer-trusted-ca-file=$ETCD_DIR/$CA_FILE_NAME.crt \\
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
  sudo cp -v $ETCD_DOWNLOAD_DIR/etcd* $BIN_DIR/
  sudo cp -v $ETCD_SETUP_DIR/etcd-server.key $ETCD_SETUP_DIR/etcd-server.crt $MASTER_CERT_DIR/
  sudo cp -v $ETCD_SETUP_DIR/etcd.service $SERVICES_DIR/etcd.service

  sudo ln -vs $MASTER_CERT_DIR/$CA_FILE_NAME.crt $ETCD_DIR/$CA_FILE_NAME.crt
  sudo ln -vs $MASTER_CERT_DIR/etcd-server.key $ETCD_DIR/etcd-server.key
  sudo ln -vs $MASTER_CERT_DIR/etcd-server.crt $ETCD_DIR/etcd-server.crt

  sudo chmod -Rv 500 $BIN_DIR/etcd*
  sudo chmod -Rv 600 $MASTER_CERT_DIR/etcd* $SERVICES_DIR/etcd* $ETCD_DIR/
  sudo chown -Rv root:root $BIN_DIR/etcd* $MASTER_CERT_DIR/etcd* $ETCD_DIR/
}

etcd_remove() {
  sudo rm -vfr $ETCD_DIR/* $BIN_DIR/etcd* $MASTER_CERT_DIR/etcd*
}

etcd_remove_all() {
  etcd_remove
  rm -fr $ETCD_SETUP_DIR
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
  if [ -f $ETCD_SETUP_DIR/etcd-server.key ] && [ -f $ETCD_SETUP_DIR/etcd-server.crt ] && [ -f $ETCD_SETUP_DIR/etcd.service ]; then
    etcd_remove
    etcd_install
  else
    etcd_remove_all
    etcd_generate
    etcd_install
  fi
}

case $1 in
"setup-dirs")
  etcd_setup_dirs
  ;;
"download")
  etcd_setup_dirs
  etcd_download
  ;;
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
"remove-all")
  etcd_stop
  etcd_remove_all
  ;;
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
