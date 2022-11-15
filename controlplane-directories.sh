# SETUP CONTROL-PLANE ON MASTER NODE

# create necessary directories

sudo mkdir -vp \
  /var/lib/kubernetes/pki \
  /var/run/kubernetes \
  /etc/etcd \
  /var/lib/etcd