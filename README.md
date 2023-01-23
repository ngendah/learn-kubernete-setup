## Learn Kubernetes set-up, first principles

why?

1. provide a simple and clear method to separately install each of the kubernetes components from scratch on a bare local VM.
2. provide standalone scripts that can easily be read and adjusted; good to play with and setting up labs.
3. want to learn what [kubeadm tool](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) and other tools are 'doing' on the background.

There are alternatives;

1. [local-cluster by kubernetes](https://github.com/kubernetes/kubernetes/blob/master/hack/local-up-cluster.sh)
2. [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

## Pre-requisites

- Knowledge of Kubernetes and its components.
  
  - Kubernetes concepts documentation is available [here.](https://kubernetes.io/docs/concepts/overview/components/)

- Installed on the host:

  - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html)

  - [jq](https://stedolan.github.io/jq/download/)

  - [yq](https://github.com/mikefarah/yq)

  If you are using Windows, I would recommend using [WSL](https://ubuntu.com/wsl).

- 2 x86_64 VM servers with `Ubuntu 22.04 server`. Designate one server as the control plane node and the other as worker node.

  * By hand;

    - Download `Ubuntu 22 server` iso images.

    - Use `Virt Manager` or `Virtual Box` to create the 2 minimized servers.

      - Configure the 2 servers with the same user login.

      - On the host generate ssh key to login into the 2 server.

        ```
        ssh-keygen -f <path-to-private-key-file>
        ```

      - From the host upload the generated ssh key (public) to the 2 servers.

        ```
        ssh-copy-id -i <path-to-private-key-file> <login-name>@<ip>
        ```

  * [Vagrant](https://developer.hashicorp.com/vagrant/docs/installation) there is a vagrant script on the `vagrant` directory.


  * [LXD](https://linuxcontainers.org/lxd/getting-started-cli/)


  * [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).


  After the servers are up, create a file `inventory.yaml` from `inventory.sample.yaml` and update it with the its indicated params for both the control plane node and worker node.

- Finally run `setup.sh`

  ```
  ./setup.sh
  ```

  The setup script will automatically upload the [k8s-scripts](./k8s-scripts) to the control plane node.



## Play with the k8s setup scripts.

1. Set up the control plane node.

2. Set up the worker node.

3. Finally, to get a ready cluster to deploy pods;

    - Install [CoreDNS](https://github.com/coredns/deployment/tree/master/kubernetes).

    - Install Container Networking Interface(CNI) such as [WeaveNet](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/).

4. Troubleshooting
    
    - On the terminal you can source the file `common.sh` and `printenv` to see all the environment variables used
      
      ```commandline
       source ./common.sh
       printenv
      ```
      
    - print trace by adding to the top of the script the command `set -x`

    - `Journalctl` with the service unit name

## Credits

[Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way), as modified by [Mumshad Mannambeth](https://github.com/mmumshad/kubernetes-the-hard-way).


