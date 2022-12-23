#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

kubectl_download() {
  FILE_NAME=kubectl
  if [ ! -f "$DATA_DIR/$FILE_NAME" ]; then
    wget --show-progress --https-only --timestamping \
      "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/$FILE_NAME"
    mv $FILE_NAME $DATA_DIR/
  fi
}

kubectl_generate() {
  master_check_dirs_and_create

  kubectl_download
}

kubectl_install() {
  sudo cp -v $DATA_DIR/kubectl $BIN_DIR

  sudo chown -v $USER:root $BIN_DIR/kubectl
  sudo chmod -v 500 $BIN_DIR/kubectl
}

kubectl_remove(){
  sudo rm -f $BIN_DIR/kubectl
}

kubectl_remove_all(){
  kubectl_remove
  rm -f $DATA_DIR/kubectl
}

kubectl_reinstall(){
  if [ -f $DATA_DIR/kubectl ]; then
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
