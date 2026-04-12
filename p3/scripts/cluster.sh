#!/bin/bash

CLUSTER_NAME="iot-cluster"

# 1. 既存の同名クラスターがあれば削除
k3d cluster delete $CLUSTER_NAME || true

# 2. クラスター作成
# -p "8888:80@loadbalancer": ローカルの8888番をK8sのIngressに繋ぐ
echo "--- Creating k3d cluster: $CLUSTER_NAME ---"
k3d cluster create $CLUSTER_NAME \
    -p "8888:80@loadbalancer" \
    --agents 2 \
    --wait

# 3. Argo CD のインストール
echo "--- Installing Argo CD ---"
kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Argo CD Pod が準備できるまで待機
echo "--- Waiting for Argo CD to be ready ---"
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

echo "--- Cluster is Ready! ---"
echo "Access Apps at: http://localhost:8888/"

echo "--- Fixing Proxy Settings for Argo CD ---"
kubectl set env deploy/argocd-repo-server -n argocd HTTP_PROXY- HTTPS_PROXY- NO_PROXY-
kubectl set env deploy/argocd-server -n argocd HTTP_PROXY- HTTPS_PROXY- NO_PROXY-

kubectl rollout restart deployment/argocd-repo-server -n argocd

