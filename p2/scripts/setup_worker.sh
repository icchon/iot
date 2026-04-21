#!/bin/bash

SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"

sudo apt-get update && sudo apt-get install -y net-tools

IFACE=$(ip -4 addr show | grep "$WORKER_IP" | awk '{print $NF}')

if [ -f /vagrant/node-token ]; then
    NODE_TOKEN=$(cat /vagrant/node-token)
else
    echo "Error: /vagrant/node-token not found. Run Server script first."
    exit 1
fi

echo "Detected interface: $IFACE for IP $WORKER_IP"

curl -sfL https://get.k3s.io | K3S_URL=https://${SERVER_IP}:6443 \
  K3S_TOKEN=${NODE_TOKEN} \
  INSTALL_K3S_EXEC="agent \
  --node-ip=$WORKER_IP \
  --flannel-iface=$IFACE" sh -
