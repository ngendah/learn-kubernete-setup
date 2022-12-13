#!/usr/bin/env bash

# shellcheck disable=SC2086
source common.sh

# stop all services

cat<<EOF | ssh -T $NODE
sudo systemctl -q enable kube-proxy.service
sudo systemctl -q start kube-proxy.service

sudo systemctl -q disable kubelet.service
sudo systemctl -q stop kubelet.service

sudo systemctl daemon-reload
EOF

sudo systemctl -q disable kube-apiserver.service
sudo systemctl -q stop kube-apiserver.service

sudo systemctl -q disable kube-scheduler.service
sudo systemctl -q stop kube-scheduler.service

sudo systemctl -q disable kube-controller-manager.service
sudo systemctl -q stop kube-controller-manager.service

sudo systemctl -q disable etcd.service
sudo systemctl -q stop etcd.service

sudo systemctl daemon-reload

# Remove all files

sudo rm -vf $BIN_DIR/kubectl
sudo rm -vf $BIN_DIR/etcd*
sudo rm -vf $BIN_DIR/kube-controller-manager
sudo rm -vf $BIN_DIR/kube-scheduler
sudo rm -vf $BIN_DIR/kube-apiserver
sudo rm -vf $SERVICES_DIR/etcd.service
sudo rm -vf $SERVICES_DIR/kube-apiserver.service
sudo rm -vf $SERVICES_DIR/kube-controller-manager.service
sudo rm -vf $SERVICES_DIR/kube-scheduler.service

sudo rm -rvf $DATA_DIR
sudo rm -rvf $MASTER_CERT_DIR
sudo rm -rvf $MASTER_CONFIG_DIR
sudo rm -rvf $ETCD_DIR
sudo rm -rvf $ETCD_DATA_DIR


cat<<EOF | ssh -T $NODE
sudo rm -vf $BIN_DIR/kubectl
sudo rm -vf $BIN_DIR/kubelet
sudo rm -vf $BIN_DIR/kube-proxy
sudo rm -vf $SERVICES_DIR/kubelet.service
sudo rm -vf $SERVICES_DIR/kube-proxy.service

sudo rm -rvf $KUBELET_CERT_DIR
sudo rm -rvf $KUBELET_CONFIG_DIR
sudo rm -rvf $KUBE_PROXY_CERT_DIR
sudo rm -rvf $KUBE_PROXY_CONFIG_DIR
EOF

echo "Remove all complete"