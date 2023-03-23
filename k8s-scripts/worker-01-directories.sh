#!/usr/bin/env bash

source common.sh

ssh -T $NODE sudo mkdir -vp $(jq -r ".nodes.worker.kubernetes.paths[]" cluster-config.json)
ssh -T $NODE sudo mkdir -vp $(jq -r ".nodes.worker.kubelet.paths[]" cluster-config.json)
ssh -T $NODE sudo mkdir -vp $(jq -r ".nodes.worker.kube_proxy.paths[]" cluster-config.json)