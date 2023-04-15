#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

source common.sh

KUBECTL_FILE_NAME=kubectl
KUBECTL_SETUP_DIR_NAME=kubectl
KUBECTL_SETUP_DIR=$DATA_DIR/$KUBECTL_SETUP_DIR_NAME

scp -r $KUBECTL_SETUP_DIR $NODE:~

cat<<EOF | ssh -T $NODE
sudo mv -v ~/$KUBECTL_SETUP_DIR_NAME/kubectl $BIN_DIR

sudo chmod -v 500 $BIN_DIR/kubectl
sudo chown -v root:root $BIN_DIR/kubectl
EOF
