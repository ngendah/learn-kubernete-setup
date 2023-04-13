#!/usr/bin/env bash

##
## Copyright (c) 2022 Ngenda Henry
##
## For the license information refer to LICENSE.
##

# shellcheck disable=SC2086
source common.sh

KUBECTL_FILE_NAME=kubectl
KUBECTL_SETUP_DIR=$DATA_DIR/$KUBECTL_FILE_NAME

kubectl_create_setup_dirs() {
  mkdir -p $KUBECTL_SETUP_DIR
}

kubectl_download() { 
  if [ ! -f "$KUBECTL_SETUP_DIR/$KUBECTL_FILE_NAME" ]; then
    wget --show-progress --https-only --timestamping \
      "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/$KUBECTL_FILE_NAME"
    mv $KUBECTL_FILE_NAME $KUBECTL_SETUP_DIR/
  fi
}

kubectl_generate() {
  master_check_dirs_and_create
  kubectl_create_setup_dirs
  kubectl_download
}

kubectl_install() {
  sudo cp -v $KUBECTL_SETUP_DIR/$KUBECTL_FILE_NAME $BIN_DIR

  sudo chown -v $USER:root $BIN_DIR/$KUBECTL_FILE_NAME
  sudo chmod -v 500 $BIN_DIR/$KUBECTL_FILE_NAME
}

kubectl_remove(){
  sudo rm -f $BIN_DIR/$KUBECTL_FILE_NAME
}

kubectl_remove_all(){
  kubectl_remove
  rm -fr $KUBECTL_SETUP_DIR/*
}

kubectl_reinstall(){
  if [ -f $KUBECTL_SETUP_DIR/$KUBECTL_FILE_NAME ]; then
    kubectl_remove
    kubectl_install
  else
    kubectl_remove_all
    kubectl_generate
    kubectl_install
  fi
}

case $1 in
"remove")
  kubectl_remove
  ;;
"generate")
  kubectl_generate
  ;;
"install")
  kubectl_install
  ;;
"reinstall")
  kubectl_reinstall
  ;;
"remove-all") ;;

"stop")
  ;;

"start")
  ;;

"restart")
  ;;

*)
  kubectl_reinstall
  ;;
esac
