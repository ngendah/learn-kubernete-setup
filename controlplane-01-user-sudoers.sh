#!/usr/bin/env bash

sudo apt-get update
sudo apt-get install -y vim jq

cat <<EOF | sudo tee /etc/sudoers.d/$USER
$USER ALL=(ALL) NOPASSWD:ALL
EOF

# set up vim
cat > $HOME/.vimrc << EOF
set number relativenumber
set autoindent smarttab expandtab
set softtabstop=2 tabstop=2 shiftwidth=2
EOF

# enable terminal color
sed -Ei "s/^(#\\s*)?force_color_prompt=.*$/force_color_prompt=yes/g" $HOME/.bashrc

source $HOME/.bashrc
