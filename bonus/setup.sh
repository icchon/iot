#!/bin/bash

CLUSTER_NAME="iot-cluster"

# 1. 既存のクラスターを削除（存在する場合）
k3d cluster delete $CLUSTER_NAME || true

# 2. クラスターの作成
echo "Creating k3d cluster: $CLUSTER_NAME..."
k3d cluster create --config k3d-config.yaml

# 3. cert-manager のインストール
echo "Installing cert-manager..."
kubectl apply -f conf/cert/cert-manager.yaml

echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=300s

# 4. 自己署名 Issuer の適用
echo "Applying self-signed issuer..."
kubectl apply -f conf/cert/selfsigned-issuer.yaml

# 5. ArgoCD のインストール
echo "Installing Argo CD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD to be ready..."
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=600s

# 6. ArgoCD Ingress の適用
echo "Applying Argo CD Ingress..."
kubectl apply -f conf/argocd/ingress.yaml

# 7. GitLab のインストール
echo "Installing GitLab..."
kubectl create namespace gitlab || true
helm repo add gitlab https://charts.gitlab.io
helm repo update
helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f conf/gitlab/values.yaml \
  --timeout 600s

# 8. CoreDNS の設定適用 (GitLab のサービスを解決するため)
echo "Applying CoreDNS custom configuration..."
kubectl apply -f conf/coredns-hosts.yaml
echo "Restarting CoreDNS to apply changes..."
kubectl rollout restart deployment coredns -n kube-system

# 9. ArgoCD Application の適用 (Root App)
echo "Applying ArgoCD Root Application..."
kubectl apply -f conf/app/argocd-vote-app.yaml
kubectl apply -f conf/db/argocd-vote-app-db.yaml
kubectl apply -f conf/operator/argocd-db-operator.yaml

echo "Setup complete! Everything is being deployed."
kubectl cluster-info
