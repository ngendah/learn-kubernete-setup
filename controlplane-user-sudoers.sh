sudo apt-get install -y vim jq

cat <<EOF | sudo tee /etc/sudoers.d/$USER
$USER ALL=(ALL:ALL) NOPASSWD:ALL
EOF

# set up vim
cat<<EOF | tee $HOME/.vimrc
set number relativenumber
set autoindent smarttab expandtab
set shiftround softtabstop=2 tabstop=2 shiftwidth=2
set paste
EOF

if [[ `grep -e "EDITOR" $HOME/.bashrc` == "" ]]; then
  echo "export EDITOR=vim" >> $HOME/.bashrc
fi

sed -Ei "s/^(#\\s*)?force_color_prompt=.*$/force_color_prompt=yes/g" $HOME/.bashrc

source $HOME/.bashrc