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

# 9. ArgoCD に GitLab の CA を信頼させる
echo "Trusting GitLab CA in Argo CD..."
# ルート証明書が作成されるのを待つ
while ! kubectl get secret root-ca-secret -n cert-manager > /dev/null 2>&1; do
  echo "Waiting for root-ca-secret in cert-manager namespace..."
  sleep 5
done

# CA 証明書を取得し、Argo CD の ConfigMap に登録
CA_CRT=$(kubectl get secret root-ca-secret -n cert-manager -o jsonpath='{.data.ca\.crt}' | base64 -d)
kubectl create configmap argocd-tls-certs-cm -n argocd \
  --from-literal=gitlab.k8s.icchon.jp="$CA_CRT" \
  --dry-run=client -o yaml | kubectl apply -f -

# 設定を反映させるためにリポジトリサーバーを再起動
kubectl rollout restart deployment argocd-repo-server -n argocd

# 10. ArgoCD Application の適用 (Root App)
echo "Applying ArgoCD Root Application..."
kubectl apply -f conf/app/argocd-vote-app.yaml
kubectl apply -f conf/db/argocd-vote-app-db.yaml
kubectl apply -f conf/operator/argocd-db-operator.yaml

echo "Setup complete! Everything is being deployed."
kubectl cluster-info
