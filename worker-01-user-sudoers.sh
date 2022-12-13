#!/usr/bin/env bash

sudo apt-get install -y vim jq

cat <<EOF | sudo tee /etc/sudoers.d/$USER
$USER ALL=(ALL) NOPASSWD:ALL
EOF