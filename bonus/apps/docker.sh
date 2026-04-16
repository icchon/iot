#!/bin/bash

PREFIX=registry.k8s.icchon.jp/root/iot
APP1=$PREFIX/vote-app1:latest
APP2=$PREFIX/vote-app2:latest
APP3=$PREFIX/vote-app3:latest
BACKEND=$PREFIX/vote-backend:latest

docker build -t $APP1 ./app1 && docker push $APP1
docker build -t $APP2 ./app2 && docker push $APP2
docker build -t $APP3 ./app3 && docker push $APP3
docker build -t $BACKEND ./backend && docker push $BACKEND
