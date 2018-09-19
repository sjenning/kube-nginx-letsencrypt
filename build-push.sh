#/usr/bin/env bash

set -e

BASE=${1:-sjenning}
VERSION=${2:-0.8.1-1}

docker build --tag $BASE/kube-nginx-letsencrypt:$VERSION .
echo "docker login before continuing"
read
docker push $BASE/kube-nginx-letsencrypt:$VERSION

