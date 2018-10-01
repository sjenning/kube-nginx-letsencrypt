#!/bin/bash

set -e

if [[ -z $EMAIL || -z $DOMAINS || -z $SECRET || -z $DEPLOYMENT ]]; then
	echo "EMAIL, DOMAINS, SECERT, and DEPLOYMENT env vars required"
	env
	exit 1
fi

CONFIGURATION="--webroot -w $HOME -n --agree-tos --email ${EMAIL} --no-self-upgrade -d ${DOMAINS}"
if [[ -n $STAGING ]]; then
  CONFIGURATION="--staging $CONFIGURATION"
fi

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

cd $HOME
python -m SimpleHTTPServer 80 &
PID=$!
certbot certonly $CONFIGURATION
kill $PID

CERTPATH=/etc/letsencrypt/live/$(echo $DOMAINS | cut -f1 -d',')

ls $CERTPATH || exit 1


echo "Update secret..."
cat /secret-patch-template.json | \
	sed "s/NAMESPACE/${NAMESPACE}/" | \
	sed "s/NAME/${SECRET}/" | \
	sed "s/TLSCERT/$(cat ${CERTPATH}/fullchain.pem | base64 | tr -d '\n')/" | \
	sed "s/TLSKEY/$(cat ${CERTPATH}/privkey.pem |  base64 | tr -d '\n')/" \
	> /secret-patch.json
ls /secret-patch.json || exit 1

curl -v --fail \
  -k --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  -H "Accept: application/json, */*" \
  -H "Content-Type: application/strategic-merge-patch+json" \
  -X PATCH \
  -d @/secret-patch.json \
  https://kubernetes/api/v1/namespaces/${NAMESPACE}/secrets/${SECRET}


echo "Update the pod spec on ingress deployment to trigger redeploy..."
cat /deployment-patch-template.json | \
	sed "s/TLSUPDATED/$(date)/" | \
	sed "s/NAMESPACE/${NAMESPACE}/" | \
	sed "s/NAME/${DEPLOYMENT}/" \
	> /deployment-patch.json
ls /deployment-patch.json || exit 1

curl --fail \
  -k --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  -H "Accept: application/json, */*" \
  -H "Content-Type: application/strategic-merge-patch+json" \
  -X PATCH  \
  -d @/deployment-patch.json \
  https://kubernetes/apis/extensions/v1beta1/namespaces/${NAMESPACE}/deployments/${DEPLOYMENT}
