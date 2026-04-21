#!/bin/bash
SERVER_IP="192.168.56.110"

sudo apt-get update && sudo apt-get install -y net-tools bat tree

IFACE=$(ip -4 addr show | grep "$SERVER_IP" | awk '{print $NF}')
echo "Detected interface: $IFACE for IP $SERVER_IP"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=$SERVER_IP \
  --flannel-iface=$IFACE \
  --bind-address=$SERVER_IP \
  --advertise-address=$SERVER_IP" sh -

sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token
sudo chmod 644 /vagrant/node-token

sudo kubectl apply --server-side -f /vagrant/conf/operator/cnpg-1.29.0.yaml
echo "Waiting for Operator and Traefik..."
sudo kubectl wait --for=condition=available --timeout=120s deployment/cnpg-controller-manager -n cnpg-system
sleep 30
sudo kubectl apply -f /vagrant/conf/db/namespace.yaml
sudo kubectl apply -f /vagrant/conf/db/secret.yaml
sudo kubectl apply --server-side -f /vagrant/conf/db/cluster.yaml

sudo kubectl apply -f /vagrant/conf/app/common/namespace.yaml
sudo kubectl apply -f /vagrant/conf/app/common/middleware.yaml
sudo kubectl apply -f /vagrant/conf/app/common/configmap.yaml
sudo kubectl apply -f /vagrant/conf/app/common/ingress.yaml
sudo kubectl apply -f /vagrant/conf/app/backend/backend.yaml
sudo kubectl apply -f /vagrant/conf/app/app1/app1.yaml
sudo kubectl apply -f /vagrant/conf/app/app2/app2.yaml
sudo kubectl apply -f /vagrant/conf/app/app3/app3.yaml
