#!/usr/bin/env bash

source common.sh

cat<<EOF | ssh -T $NODE
sudo apt-get update
sudo apt-get install -y vim jq
sudo echo "\$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/\$USER
EOF
