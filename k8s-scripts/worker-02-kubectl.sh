#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

source common.sh

scp $DATA_DIR/kubectl $NODE:~

cat<<EOF | ssh -T $NODE
sudo mv -v ./kubectl $BIN_DIR

sudo chmod -v 500 $BIN_DIR/kubectl
sudo chown -v root:root $BIN_DIR/kubectl
EOF
