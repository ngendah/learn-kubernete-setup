sudo apt-get install -y vim jq

cat <<EOF | sudo tee /etc/sudoers.d/$USER
$USER ALL=(ALL:ALL) NOPASSWD:ALL
EOF