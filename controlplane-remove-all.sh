# remove all created files

#kubectl
sudo rm -vf /usr/local/bin/kubectl

# TLS certificates and keys
sudo rm -vf *.cnf *.csr *.crt *.key
sudo rm -vf /var/lib/kubernetes/pki/*

# kube-configs
sudo rm -vf *.kubeconfig
sudo rm -vf /var/lib/kubernetes/*.kubeconfig

# etcd
sudo rm -vf /etc/etcd/*
sudo rm -vf /etc/systemd/system/etcd.service

# api-server
sudo rm -vf /usr/local/bin/kube-apiserver
sudo rm -vf /etc/systemd/system/kube-apiserver.service \
                  /var/lib/kubernetes/encryption-config.yaml

# controller-manager
sudo rm -vf /usr/local/bin/kube-controller-manager
sudo rm -vf /etc/systemd/system/kube-controller-manager.service

# scheduler
sudo rm -vf /usr/local/bin/kube-scheduler
sudo rm -vf /etc/systemd/system/kube-scheduler.service
