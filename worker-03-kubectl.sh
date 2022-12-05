#!/usr/bin/env bash

source common.sh
scp /usr/local/bin/kubectl $NODE:~

cat<<EOF | ssh -T $NODE
sudo mv -v ./kubectl /usr/local/bin/
sudo chmod -v +x /usr/local/bin/kubectl
EOF
