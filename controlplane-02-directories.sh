#!/usr/bin/env bash

# Directories
sudo mkdir -vp $(jq -r ".script_data_dir" cluster-config.json)
sudo mkdir -vp $(jq -r ".nodes.control_plane.kubernetes.paths[]" cluster-config.json)
sudo mkdir -vp $(jq -r ".nodes.control_plane.etcd.paths[]" cluster-config.json)