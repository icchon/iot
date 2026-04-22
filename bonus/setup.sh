#!/bin/bash

CLUSTER_NAME="iot-cluster"

# 1. 既存のクラスターを削除（存在する場合）
k3d cluster delete $CLUSTER_NAME || true

# 2. クラスターの作成
echo "Creating k3d cluster: $CLUSTER_NAME..."
k3d cluster create --config k3d-config.yaml

# 3. cert-manager のインストール
echo "Installing cert-manager..."

# 既存の競合を避けるため、まず Namespace を確実に作成
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

# 【重要】CRDだけを先に、独立して適用する（公式のリモートURLを使うのが最も確実です）
echo "Applying cert-manager CRDs directly..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml

# 確実に API サーバーに登録されるまで待機
sleep 10

# 定義が作られたか確認（ここでダメなら YAML 取得に失敗しています）
if ! kubectl get crd certificates.cert-manager.io > /dev/null 2>&1; then
    echo "CRDs failed to install. Checking connectivity..."
    exit 1
fi

# 本体（コントローラー等）をインストール
echo "Installing cert-manager controllers..."
kubectl apply --server-side --force-conflicts -f conf/cert/cert-manager.yaml

echo "Waiting for cert-manager Webhook to be ready..."
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=300s

echo "Giving Webhook a few seconds to stabilize..."
sleep 20

# 4. 自己署名 Issuer の適用
echo "Applying self-signed issuer..."
# 失敗しても3回までリトライする
for i in {1..3}; do
    kubectl apply -f conf/cert/selfsigned-issuer.yaml && break
    echo "Retry applying issuer in 10s... ($i/3)"
    sleep 10
done


# 5. ArgoCD のインストール
echo "Installing Argo CD..."
kubectl create namespace argocd || true
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD to be ready..."
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=600s

# 6. ArgoCD Ingress の適用
echo "Applying Argo CD Ingress..."
kubectl apply -f conf/argocd/ingress.yaml


# 既存のCRDにHelmの所有権ラベルを付与する
CRDS=(
  "certificates.cert-manager.io"
  "certificaterequests.cert-manager.io"
  "challenges.acme.cert-manager.io"
  "clusterissuers.cert-manager.io"
  "issuers.cert-manager.io"
  "orders.acme.cert-manager.io"
)

for crd in "${CRDS[@]}"; do
  kubectl label crd $crd app.kubernetes.io/managed-by=Helm --overwrite
  kubectl annotate crd $crd meta.helm.sh/release-name=gitlab --overwrite
  kubectl annotate crd $crd meta.helm.sh/release-namespace=gitlab --overwrite
done

# 7. GitLab のインストール
echo "Installing GitLab..."
kubectl create namespace gitlab || true

echo "Patching existing CRDs for Helm ownership..."
CRDS=("certificates.cert-manager.io" "certificaterequests.cert-manager.io" "challenges.acme.cert-manager.io" "clusterissuers.cert-manager.io" "issuers.cert-manager.io" "orders.acme.cert-manager.io")
for crd in "${CRDS[@]}"; do
  kubectl label crd $crd app.kubernetes.io/managed-by=Helm --overwrite > /dev/null 2>&1
  kubectl annotate crd $crd meta.helm.sh/release-name=gitlab --overwrite > /dev/null 2>&1
  kubectl annotate crd $crd meta.helm.sh/release-namespace=gitlab --overwrite > /dev/null 2>&1
done

kubectl delete crd certificates.cert-manager.io certificaterequests.cert-manager.io challenges.acme.cert-manager.io clusterissuers.cert-manager.io issuers.cert-manager.io orders.acme.cert-manager.io --ignore-not-found

helm repo add gitlab https://charts.gitlab.io
helm repo update
helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f conf/gitlab/values.yaml \
  --set global.certmanager.install=false \
  --timeout 600s

# 8. CoreDNS の設定適用 (GitLab のサービスを解決するため)
echo "Applying CoreDNS custom configuration..."
kubectl apply -f conf/coredns-hosts.yaml
echo "Restarting CoreDNS to apply changes..."
kubectl rollout restart deployment coredns -n kube-system

# 9. ArgoCD に GitLab の CA を信頼させる
echo "Trusting GitLab CA in Argo CD..."

# cert-manager が管理する root-ca-secret を待つ
while ! kubectl get secret root-ca-secret -n cert-manager > /dev/null 2>&1; do
  echo "Waiting for root-ca-secret in cert-manager namespace..."
  sleep 10
done

# CA 証明書を取得
CA_CRT=$(kubectl get secret root-ca-secret -n cert-manager -o jsonpath='{.data.ca\.crt}' | base64 -d)

# Argo CD の ConfigMap に登録
kubectl create configmap argocd-tls-certs-cm -n argocd \
  --from-literal=gitlab.k8s.icchon.jp="$CA_CRT" \
  --dry-run=client -o yaml | kubectl apply -f -

# リポジトリサーバーを再起動して反映
kubectl rollout restart deployment argocd-repo-server -n argocd

# 10. ArgoCD Application の適用 (Root App)
echo "Applying ArgoCD Root Application..."
kubectl apply -f conf/app/argocd-vote-app.yaml
kubectl apply -f conf/db/argocd-vote-app-db.yaml
kubectl apply -f conf/operator/argocd-db-operator.yaml

echo "Setup complete! Everything is being deployed."
kubectl cluster-info
