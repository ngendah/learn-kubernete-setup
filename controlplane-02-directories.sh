#!/usr/bin/env bash

# create necessary directories
sudo mkdir -vp $(jq -r ".nodes.control_plane.kubernetes.paths[]" cluster-config.json)
sudo mkdir -vp $(jq -r ".nodes.control_plane.etcd.paths[]" cluster-config.json)