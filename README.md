## Learn Kubernetes set-up, first principles

## Pre-requisites
- Knowledge of Kubernetes and its components.
  - Kubernetes concepts documentation is available [here.](https://kubernetes.io/docs/concepts/overview/components/)

- 2 servers installed with `Ubuntu 22.04 server` with the minimal installation.
  - one server shall be the master and the other a worker. You can name the master as `control` and the worker as `node01`.

- The same user is configured on the master and worker node.
  - This requirement simplifies ssh logins and command execution. 
  - By default, ssh uses the current login user as its default username.
    Example:
    server-1 ip is `192.167.10.1` and server-2 ip is `192.167.10.2` and both have the same logged-in user `foo` 
    from server-1 you can ssh into server-2 simply `ssh 192.167.10.2` instead of the long form `ssh foo@192.167.10.2`.
  - This also applies for other `ssh` related commands such as `ssh-copy-id` e.tc.

- The master node user can ssh into the worker node.
  - Generate ssh key pair on the master node, without a passphrase. Defaults settings are recommended.
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
  - Because we are using `systemd` adjust the configuration as documented [here](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd-systemd).
  
  - Replaced the default config on `/etc/containerd/config.toml`
  
    `sudo mv ~/config.toml /etc/containerd/`
  
    `sudo chmod 600 /etc/containerd/config.toml`
  
    `sudo chown root:root /etc/containerd/config.toml`
  
  - Restart `containerd` daemon
    `sudo systemctl restart containerd`


## Steps

1. Set up user on sudoers
2. Set up the control plane node
3. Set up the worker node

## Credits

[Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way), as modified by [Mumshad Mannambeth](https://github.com/mmumshad/kubernetes-the-hard-way).