Learn Kubernetes set-up, first principles
=========================================

If you are inclined.

After steps:

1. Build and install network plugins on the worker node

    - [Network plugins](https://github.com/containernetworking/plugins)
    
        Install `golang` or use `golang` docker image, build and install to `/opt/cni/bin`.

    - [Network plugins docs](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)

2. Deploy DNS and network add-on

  - [CoreDNS](https://github.com/coredns/coredns)

  - [Network add-ons](https://kubernetes.io/docs/concepts/cluster-administration/addons/#networking-and-network-policy)
