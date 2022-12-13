#!/usr/bin/env bash

source common.sh

scp /usr/local/bin/kubectl $NODE:~

cat<<EOF | ssh -T $NODE
sudo mv -v ./kubectl $BIN_DIR

sudo chmod -v 500 $BIN_DIR/kubectl
sudo chown -v root:root $BIN_DIR/kubectl
EOF
