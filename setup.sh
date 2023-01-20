#!/usr/bin/env bash

# shellcheck disable=SC2086

setup_control() {
  # add option -K to request for sudo password
  ansible-playbook -vv -l control -i inventory.yaml ./setup/master.yaml
}

setup_nodes() {
  ansible-playbook -vv -l nodes -i inventory.yaml ./setup/node.yaml
}

setup_cluster_config() {
  control_plane_ip=$(yq '.all.hosts.control.ansible_host' inventory.yaml)
  node_ip=$(yq '.all.hosts.nodes.ansible_host' inventory.yaml)
  control_plane_ip="$control_plane_ip" jq '.nodes.control_plane.ip=env.control_plane_ip' k8s-scripts/cluster-config.json \
    | node_ip="$node_ip" jq '.nodes.worker.ip=env.node_ip' - > k8s-scripts/cluster-config.tmp.json
  mv k8s-scripts/cluster-config.tmp.json k8s-scripts/cluster-config.json
}

setup_generate_sshkey() {
  # generate key for ssh login from the k8s-control
  if [ ! -f ./setup/ssh/id_rsa ]; then
    mkdir ./setup/ssh
    ssh-keygen -t rsa -b 4096 -f ./setup/ssh/id_rsa -q -N ""
  fi
}

ping() {
  echo "Testing if servers are reachable"
  group="all"
  if [ "$1" != "" ]; then
    group=$1
  fi
  ansible $group -m ping -i inventory.yaml
}

case $1 in
"ping")
  ping
  ;;
*)
  ping
  if [ $? -ne 0 ]; then
    echo "One or more servers  are not reachable, edit inventory.yaml with correct params"
    exit 1
  fi
  setup_generate_sshkey
  setup_cluster_config
  setup_nodes
  setup_control
  ;;
esac

