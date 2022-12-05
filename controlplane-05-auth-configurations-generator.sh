#!/usr/bin/env bash

source common.sh

# pre-condition
REQUIRED_CERTIFICATES="ca admin kube-controller-manager kube-scheduler"

missing_counter="0"

for certificate in $REQUIRED_CERTIFICATES
do
	key="$MASTER_CERT_DIR/$certificate.key"
	certificate="$MASTER_CERT_DIR/$certificate.crt"
	if [[ ! -f $key ]]; then
			echo "missing TLS key file: $key"
			((missing_counter+=1))
	fi
	if [[ ! -f $certificate ]]; then
			echo "missing TLS certificate file: $certificate"
			((missing_counter+=1))
	fi
done

if [[ "$missing_counter" -gt "0" ]]; then
	echo "missing files, cannot continue, try running certificates-generator.sh script first"
	exit 1
fi


# [2022-11-12]
# kubeadm tool refers to this files by the extension .conf

# Admin configuration
kubectl config set-cluster "$CLUSTER_NAME" \
    --certificate-authority=$MASTER_CERT_DIR/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
    --client-certificate=$MASTER_CERT_DIR/admin.crt \
    --client-key=$MASTER_CERT_DIR/admin.key \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

 kubectl config set-context default \
    --cluster="$CLUSTER_NAME" \
    --user=admin \
    --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

# kube-controller manager configuration
kubectl config set-cluster "$CLUSTER_NAME" \
    --certificate-authority=$MASTER_CERT_DIR/ca.crt \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig 

kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=$MASTER_CERT_DIR/kube-controller-manager.crt \
    --client-key=$MASTER_CERT_DIR/kube-controller-manager.key \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
    --cluster="$CLUSTER_NAME" \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

# kube-scheduler configuration
kubectl config set-cluster "$CLUSTER_NAME" \
    --certificate-authority=$MASTER_CERT_DIR/ca.crt \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
    --client-certificate=$MASTER_CERT_DIR/kube-scheduler.crt \
    --client-key=$MASTER_CERT_DIR/kube-scheduler.key \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
    --cluster="$CLUSTER_NAME" \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

# move configurations
sudo mv -v  kube-controller-manager.kubeconfig \
			kube-scheduler.kubeconfig \
			/etc/kubernetes/

# move admin configuration
sudo mv -v admin.kubeconfig \
			/etc/kubernetes/ 
