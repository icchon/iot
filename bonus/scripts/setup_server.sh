#!/bin/bash
SERVER_IP="192.168.56.110"

sudo ip addr add $SERVER_IP/24 dev eth0 || true
# 1. 必要なツールのインストール
# bat -> batcat (Ubuntuパッケージ名) に修正
sudo apt-get update && sudo apt-get install -y net-tools bat git curl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 2. インターフェースの自動検出
IFACE=$(ip -4 addr show | grep "$SERVER_IP" | awk '{print $NF}')
echo "Detected interface: $IFACE for IP $SERVER_IP"

# 3. K3s のインストール
# OrbStackでは root 実行が基本のため kubeconfig-mode は 644 でOK
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=$SERVER_IP \
  --flannel-iface=$IFACE \
  --bind-address=$SERVER_IP \
  --advertise-address=$SERVER_IP \
  --disable traefik \
  --write-kubeconfig-mode 644" sh -

# 4. トークンの共有
# OrbStack では Mac のカレントディレクトリが /mnt/mac にマウントされます
sudo cat /var/lib/rancher/k3s/server/node-token > node-token

# 5. スワップファイルの作成 (GitLab用)
if [ ! -f /swapfile ]; then
    echo "Creating 4GB swap file..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# 6. Kubeconfig の設定 (OrbStack のデフォルトユーザー root 用)
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config

helm repo add gitlab https://charts.gitlab.io/
helm repo update

echo "--- Installing Argo CD ---"
kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "--- Waiting for Argo CD to be ready ---"
# タイムアウトを少し長めに設定
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=600s

echo "--- Fixing Proxy Settings for Argo CD ---"
kubectl set env deploy/argocd-repo-server -n argocd HTTP_PROXY- HTTPS_PROXY- NO_PROXY-
kubectl set env deploy/argocd-server -n argocd HTTP_PROXY- HTTPS_PROXY- NO_PROXY-

kubectl rollout restart deployment/argocd-repo-server -n argocd