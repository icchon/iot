#!/bin/bash
SERVER_IP="192.168.56.110"

sudo apt update && sudo apt install -y net-tools bat tree

IFACE=$(ip -4 addr show | grep "$SERVER_IP" | awk '{print $NF}')
echo "Detected interface: $IFACE for IP $SERVER_IP"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=$SERVER_IP \
  --flannel-iface=$IFACE \
  --bind-address=$SERVER_IP \
  --advertise-address=$SERVER_IP" sh -

sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token
sudo chmod 644 /vagrant/node-token
