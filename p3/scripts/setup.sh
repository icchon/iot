#!/bin/bash

# 1. Docker のインストール (Ubuntu用)
echo "--- Installing Docker ---"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg net-tools bat tree
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 2. 現在のユーザーを docker グループに追加
echo "--- Configuring Docker permissions ---"
sudo usermod -aG docker $USER

# 3. k3d のインストール
echo "--- Installing k3d ---"
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.6.3 bash

# 4. kubectl のインストール (もしまだ無ければ)
if ! command -v kubectl &> /dev/null; then
    echo "--- Installing kubectl ---"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

echo "--- Setup Complete! ---"
echo "Please log out and log back in, or run 'newgrp docker' to use Docker without sudo."
