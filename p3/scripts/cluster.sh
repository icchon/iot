#!/bin/bash

CLUSTER_NAME="iot-cluster"

# 1. 既存の同名クラスターがあれば削除
k3d cluster delete $CLUSTER_NAME || true

# 2. クラスター作成
# -p "8888:443@loadbalancer": アプリ用 (HTTPS)
# -p "8080:443@loadbalancer": Argo CD用 (HTTPS)
echo "--- Creating k3d cluster: $CLUSTER_NAME ---"
k3d cluster create $CLUSTER_NAME \
    -p "8888:443@loadbalancer" \
    -p "8080:443@loadbalancer" \
    --agents 2 \
    --wait

# 3. Argo CD のインストール
echo "--- Installing Argo CD ---"
kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Argo CD Pod が準備できるまで待機
echo "--- Exposing Argo CD via Ingress (HTTPS) ---"
kubectl apply -f conf/argocd/setup.yaml

echo "--- Waiting for Argo CD to be ready ---"
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

echo "--- Cluster is Ready! ---"
echo "Access Argo CD at: https://argocd.localhost:8080/"
echo "Access Apps at: https://localhost:8888/"
echo "Initial Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

echo "--- Fixing Proxy Settings for Argo CD ---"
kubectl set env deploy/argocd-repo-server -n argocd HTTP_PROXY- HTTPS_PROXY- NO_PROXY-
kubectl set env deploy/argocd-server -n argocd HTTP_PROXY- HTTPS_PROXY- NO_PROXY-

kubectl rollout restart deployment/argocd-repo-server -n argocd

kubectl apply -f conf/operator/argocd-db-operator.yaml
kubectl apply -f conf/db/argocd-vote-app-db.yaml
kubectl apply -f conf/app/argocd-vote-app.yaml
