#!/usr/bin/env bash

source common.sh

cat<<EOF | ssh -T $NODE
sudo mkdir -vp $(jq -r ".nodes.worker.paths[]" cluster-config.json)
EOF