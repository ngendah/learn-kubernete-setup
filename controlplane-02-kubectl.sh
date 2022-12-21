#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh
wget --show-progress --https-only --timestamping \
        "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kubectl"

sudo chmod +x kubectl
sudo mv -v kubectl $BIN_DIR

sudo chown -v root:root $BIN_DIR
sudo chmod -v 500 $BIN_DIR/kubectl
