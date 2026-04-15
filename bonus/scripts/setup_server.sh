#!/bin/bash
SERVER_IP="192.168.56.110"

# 1. 必要なツールのインストール
# git と helm は GitLab や Argo CD の操作に必須なので追加しました
sudo apt update && sudo apt install -y net-tools bat tree git curl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 2. インターフェースの自動検出
IFACE=$(ip -4 addr show | grep "$SERVER_IP" | awk '{print $NF}')
echo "Detected interface: $IFACE for IP $SERVER_IP"

# 3. K3s のインストール
# --write-kubeconfig-mode 644 を追加（vagrant ユーザーが直接 kubectl を使えるようにするため）
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=$SERVER_IP \
  --flannel-iface=$IFACE \
  --bind-address=$SERVER_IP \
  --advertise-address=$SERVER_IP \
  --disable traefik \
  --write-kubeconfig-mode 644" sh -

# 4. トークンの共有
while [ ! -d /vagrant ]; do sleep 1; done
sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token

# 5. [重要] スワップファイルの作成 (GitLab用)
# メモリ不足によるクラッシュを防ぐため、4GBのスワップを追加します
if [ ! -f /swapfile ]; then
    echo "Creating 4GB swap file..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# 6. Kubeconfig を vagrant ユーザーのデフォルトに設定
mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config

# GitLab 公式リポジトリを追加
helm repo add gitlab https://charts.gitlab.io/
# リポジトリの情報を最新にする
helm repo update
