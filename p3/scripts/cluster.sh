#!/bin/bash

CLUSTER_NAME="iot-cluster"

# 1. 既存の同名クラスターがあれば削除（クリーンな状態から開始）
sudo k3d cluster delete $CLUSTER_NAME || true

# 2. クラスター作成
# -p "80:80@loadbalancer": ホストの80番をK8sのIngressに繋ぐ
# --agents 2: ワーカーノードを2台用意
echo "--- Creating k3d cluster: $CLUSTER_NAME ---"
sudo k3d cluster create $CLUSTER_NAME \
    -p "80:80@loadbalancer" \
    --agents 2 \
    --wait

# 3. Argo CD のインストール
echo "--- Installing Argo CD ---"
sudo kubectl create namespace argocd
sudo kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Argo CD Pod が準備できるまで待機
echo "--- Waiting for Argo CD to be ready ---"
sudo kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

echo "--- Cluster is Ready! ---"
echo "Argo CD UI will be available via port-forward soon."

# --- 追加するおまじない ---
echo "--- Fixing Proxy Settings for Argo CD ---"
# argocd-repo-server が内部の 8081 ポートを使おうとするのを防ぐ
sudo kubectl set env deploy/argocd-repo-server -n argocd HTTP_PROXY- HTTPS_PROXY- NO_PROXY-
sudo kubectl set env deploy/argocd-server -n argocd HTTP_PROXY- HTTPS_PROXY- NO_PROXY-

# 再起動して反映させる
sudo kubectl rollout restart deployment/argocd-repo-server -n argocd
