#!/usr/bin/env bash

source common.sh
wget --show-progress --https-only --timestamping \
        "https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kubectl"

sudo chmod +x kubectl
sudo mv -v kubectl /usr/local/bin/
