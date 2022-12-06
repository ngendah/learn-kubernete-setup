#!/usr/bin/env bash

source common.sh

cat<<EOF | ssh -T $NODE
sudo mkdir -vp $(jq -r ".nodes.worker.kubernetes.paths[]" cluster-config.json)
sudo mkdir -vp $(jq -r ".nodes.worker.kubelet.paths[]" cluster-config.json)
sudo mkdir -vp $(jq -r ".nodes.worker.kube_proxy.paths[]" cluster-config.json)
EOF