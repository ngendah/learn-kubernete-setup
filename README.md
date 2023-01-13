## Learn Kubernetes set-up, first principles

why?

1. provide a simple and clear method to separately install each of the kubernetes components from scratch on a bare local VM.
2. provide standalone scripts that can easily be read and adjusted; good to play with and setting up labs.
3. want to learn what [kubeadm tool](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) and other tools are 'doing' on the background.

There are alternatives;

1. [local-cluster by kubernetes](https://github.com/kubernetes/kubernetes/blob/master/hack/local-up-cluster.sh)
2. [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

## Pre-requisites
- Some knowledge of Kubernetes and its components.
  - Kubernetes concepts documentation is available [here.](https://kubernetes.io/docs/concepts/overview/components/)

- 2 x86_64 VM servers installed with minimized `Ubuntu 22.04 server`.
  - one server will be the control plane(master) and the other a worker.

- Ansible installed on the host.

- The same login user configured on the master and worker node.
  - This requirement simplifies ssh logins and command execution.

  - You can ssh into the VM's from the host.

  - Copy and edit the `inventory.ini.sample` with the ssh logins to the hosts.

- To complete the setup run ansible;

  ```
    ansible-playbook -i inventory.ini playbooks/master.yaml -K
  ```


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

7. Troubleshooting
    
    - On the terminal you can source the file `common.sh` and `printenv` to see all the environment variables used
      
      ```commandline
       source ./common.sh
       printenv
      ```
      
    - print trace by adding to the top of the script the command `set -x`

    - `Journalctl` with the service unit name


    ansible-playbook -i inventory.ini playbooks/master.yaml

    Vagrant:

      - https://github.com/hashicorp/vagrant/issues/12664

      - https://github.com/vagrant-libvirt/vagrant-libvirt/issues/921

      - https://developer.hashicorp.com/vagrant/docs/provisioning/ansible_intro#the-inventory-file


## Credits

[Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way), as modified by [Mumshad Mannambeth](https://github.com/mmumshad/kubernetes-the-hard-way).
