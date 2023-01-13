#!/usr/bin/env bash

# shellcheck disable=SC2086

setup_control() {
  ansible-playbook -vv -l control -Ki inventory.ini ./setup/master.yaml
}

setup_nodes() {
  ansible-playbook -vv -l nodes -Ki inventory.ini ./setup/node.yaml
}

ping() {
  echo "Testing if servers are reachable"
  group="all"
  if [ "$1" != "" ]; then
    group=$1
  fi
  ansible $group -m ping -i inventory.ini
}

case $1 in
"ping_all")
  ping
  ;;
"control")
  ping control
  if [ $? -ne 0 ]; then
    echo "Control server not reachable, edit inventory.ini with correct params"
    exit 1
  fi
  setup_control
  ;;
"nodes")
  ping nodes
  if [ $? -ne 0 ]; then
    echo "Node server not reachable, edit inventory.ini with correct params"
    exit 1
  fi
  setup_nodes
  ;;
*)
  echo "Available options are [ping_all, control, nodes]"
  echo "Ping all to check all servers are reachable"
  echo "For example: ./setup control"
  ;;
esac


