#!/usr/bin/env bash

# create necessary directories
sudo mkdir -vp $(jq -r ".nodes.control_plane.paths[]" cluster-config.json)