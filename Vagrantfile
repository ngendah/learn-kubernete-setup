# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64" 
  config.vm.provider :virtualbox do |v|
    v.memory = 1024
    v.cpus = 2
  end

  config.vm.define "control", priviledged: false do |master|
    master.vm.synced_folder "./k8s-scripts", "/home/vagrant/k8s-scripts"
    master.vm.network "private_network", ip: "192.168.56.10"
    master.vm.hostname = "k8s-control"
    master.vm.provision "ansible" do |ansible|
      ansible.playbook = "cluster/main.yml"
      ansible.groups = {
        'control': ['control'],
      }
    end
  end

  config.vm.define "node01", priviledged: false do |node|
    node.vm.hostname = "k8s-node01"
    node.vm.network "private_network", ip: "192.168.56.11"
    node.vm.provision "ansible" do |ansible|
      ansible.playbook = "cluster/main.yml"
      ansible.groups = {
        'node': ['node01'],
      }
    end
  end

end
