# kubectl
sudo chmod -v +x /usr/local/bin/kubectl
sudo chown -v root:root /usr/local/bin/kubectl
sudo chmod -v 600 /usr/local/bin/kubectl

# TLS keys and certificates
sudo chown -v $USER:root /var/lib/kubernetes/pki/*
sudo chmod -v 600 /var/lib/kubernetes/pki/*

# kube-config
sudo chown -v root:root /var/lib/kubernetes/*.kubeconfig
sudo chmod -v 600 /var/lib/kubernetes/*.kubeconfig

# etcd
sudo chown -v root:root /etc/etcd/*
sudo chmod -v 600 /etc/etcd/*
sudo chown -v root:root /etc/systemd/system/etcd.service
sudo chmod -v 600 /etc/systemd/system/etcd.service

# api-server
sudo chmod -v +x /usr/local/bin/kube-apiserver
sudo chown -v root:root /usr/local/bin/kube-apiserver
sudo chmod -v 600 /usr/local/bin/kube-apiserver
sudo chown -v root:root /etc/systemd/system/kube-apiserver.service \
                        /var/lib/kubernetes/encryption-config.yaml
sudo chmod -v 600 /etc/systemd/system/kube-apiserver.service \
                  /var/lib/kubernetes/encryption-config.yaml

# controller-manager
sudo chmod -v +x /usr/local/bin/kube-controller-manager
sudo chown -v root:root /usr/local/bin/kube-controller-manager
sudo chmod -v 600 /usr/local/bin/kube-controller-manager
sudo chown -v root:root /etc/systemd/system/kube-controller-manager.service
sudo chmod -v 600 /etc/systemd/system/kube-controller-manager.service

# scheduler
sudo chmod -v +x /usr/local/bin/kube-scheduler
sudo chown -v root:root /usr/local/bin/kube-scheduler
sudo chmod -v 600 /usr/local/bin/kube-scheduler
sudo chown -v root:root /etc/systemd/system/kube-scheduler.service
sudo chmod -v 600 /etc/systemd/system/kube-scheduler.service

# reload control plane systemd
sudo systemctl daemon-reload
sudo systemctl enable etcd kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start etcd kube-apiserver kube-controller-manager kube-scheduler


