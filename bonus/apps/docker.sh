#!/bin/bash

PREFIX=registry.k8s.icchon.jp/root/iot
VERSION=v0.2.0
APP1=$PREFIX/vote-app1:$VERSION
APP2=$PREFIX/vote-app2:$VERSION
APP3=$PREFIX/vote-app3:$VERSION
BACKEND=$PREFIX/vote-backend:$VERSION

docker build -t $APP1 ./app1 && docker push $APP1
docker build -t $APP2 ./app2 && docker push $APP2
docker build -t $APP3 ./app3 && docker push $APP3
docker build -t $BACKEND ./backend && docker push $BACKEND
