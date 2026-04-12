#!/bin/bash

USER=icchondocker
APP1=$USER/vote-app1:latest
APP2=$USER/vote-app2:latest
APP3=$USER/vote-app3:latest
BACKEND=$USER/vote-backend:latest

docker build -t $APP1 ./app1 && docker push $APP1
docker build -t $APP2 ./app2 && docker push $APP2
docker build -t $APP3 ./app3 && docker push $APP3
docker build -t $BACKEND ./backend && docker push $BACKEND
