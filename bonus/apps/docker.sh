#!/bin/bash

# PREFIX=registry.k8s.icchon.jp/root/iot
# VERSION=v0.1.0
# APP1=$PREFIX/vote-app1:$VERSION
# APP2=$PREFIX/vote-app2:$VERSION
# APP3=$PREFIX/vote-app3:$VERSION
# BACKEND=$PREFIX/vote-backend:$VERSION

# docker build -t $APP1 ./app1 && docker push $APP1
# docker build -t $APP2 ./app2 && docker push $APP2
# docker build -t $APP3 ./app3 && docker push $APP3
# docker build -t $BACKEND ./backend && docker push $BACKEND


#!/bin/bash

# 本来のドメインを使用
PREFIX=registry.k8s.icchon.jp/root/iot
VERSION=v0.1.0
APPS=("vote-app1" "vote-app2" "vote-app3" "vote-backend")

for APP in "${APPS[@]}"; do
    TAG=$PREFIX/$APP:$VERSION
    echo "Building $TAG..."
    
    DIR=${APP/vote-/}
    docker build -t $TAG ./$DIR

    echo "Pushing $TAG with Skopeo (ignoring TLS)..."
    # --dest-tls-verify=false で SSL エラーを無視
    # --dest-creds で root:トークン を直接渡す
    skopeo copy --dest-tls-verify=false \
        --dest-creds root:$GITLAB_TOKEN \
        docker-daemon:$TAG \
        docker://$TAG
done
