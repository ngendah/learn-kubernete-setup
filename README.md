## Learn Kubernetes set-up, first principles

why?

1. provide a simple and clear way to separately install each of the kubernetes components from scratch on a bare local VM.
2. provide standalone scripts that can easily be read and adjusted.

There are alternatives;

1. [local-cluster by kubernetes](https://github.com/kubernetes/kubernetes/blob/master/hack/local-up-cluster.sh)
2. [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

## Pre-requisites
- Some knowledge of Kubernetes and its components.
  - Kubernetes concepts documentation is available [here.](https://kubernetes.io/docs/concepts/overview/components/)

- 2 VM servers installed with `Ubuntu 22.04 server` with the minimal installation.
  - one server shall be the master and the other a worker. You can name the master as `control` and the worker as `node01`.

- The same user configured on the master and worker node.
  - This requirement simplifies ssh logins and command execution. 

- The master node user can ssh into the worker node.
  - Generate ssh key pair on the master node, without a passphrase.
    
    `ssh-keygen`
  
  - Authorize the master on the worker using ssh.
    
    `ssh-copy-id <worker-node-ip>`

- Disable swap.
  - Run `swapoff -a`, to immediately disable swap.
  - Remove any swap entry from `/etc/fstab`, ensuring swap is not enabled on reboot.

- Bridge networking is enabled as documented [here](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#forwarding-ipv4-and-letting-iptables-see-bridged-traffic).
  Only what is documented under the heading: `Forwarding IPv4 and letting iptables see bridged traffic`

- Install docker and containerd as documented [here](https://docs.docker.com/engine/install/ubuntu/).

  - On `Ubuntu 22.04 server`, I had to regenerate containerd configuration as follows;
    
    `containerd config default > ~/config.toml`
  - Adjust `config.toml` as documented [here](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd-systemd). Under the heading `Configuring the systemd cgroup driver`
  
  - Replace the config on `/etc/containerd/config.toml` with the new config.
  
    `sudo mv ~/config.toml /etc/containerd/`
  
    `sudo chmod 600 /etc/containerd/config.toml`
  
    `sudo chown root:root /etc/containerd/config.toml`
  
  - Restart `containerd` daemon
    `sudo systemctl restart containerd`


## Steps

1. Obtain the IP addresses for the master and worker nodes, by running the following command on the master and worker nodes.
    
   `ip -br address`

2. Adjust the file [cluster-config.json](cluster-config.json) for;
     - Master node ip, the key `nodes.control_plane.ip`
     - Worker node ip, the key `nodes.worker.ip`

3. Set up user.

4. Set up the control plane node.

5. Set up the worker node.

6. Test our setup. 

## Credits

[Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way), as modified by [Mumshad Mannambeth](https://github.com/mmumshad/kubernetes-the-hard-way).