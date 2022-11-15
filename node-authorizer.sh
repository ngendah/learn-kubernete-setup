sudo mv -v ~/worker-1.key ~/worker-1.crt /var/lib/kubernetes/pki/
sudo mv -v ~/worker-1.kubeconfig /var/lib/kubernetes/
sudo chown -Rv root:root /var/lib/kubernetes/pki
sudo chmod -Rv 600 /var/lib/kubernetes/pki
sudo chmod -v 600 /var/lib/kubernetes/worker-1.kubeconfig
