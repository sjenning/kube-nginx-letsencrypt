#/bin/bash

docker build --tag sjenning/kube-nginx-letsencrypt:0.8.1-1 .
echo "docker login before continuing"
read
docker push sjenning/kube-nginx-letsencrypt:0.8.1-1

