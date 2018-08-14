#!/usr/bin/env bash

# Wait for the tag to build in docker.cogolo.net
for i in $(seq 1 60); do
  curl --output /dev/null --silent --head --fail "https://docker.cogolo.net/api/v1/repository/$DOCKER_ORG/$DOCKER_REPO/tag/$TRAVIS_TAG/images" -H "Authorization: Bearer $OAUTH_TOKEN" && {
    DONE="true"
    break
  } || {
    echo "Waiting for tag $TRAVIS_TAG to build in docker.cogolo.net..."
    sleep 5
  }
done

if [ -z "$DONE" ]; then
  echo "Timeout waiting on $TRAVIS_TAG to build in docker.cogolo.net."
  echo "Exiting."
  exit 1
fi
 
# Download the stable version of Kubectl
curl -LO --silent https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Create the Kube config and set the token 
mkdir ${HOME}/.kube
curl --silent https://raw.git.cogolo.net/kubes/deploy/master/config >> ${HOME}/.kube/config
kubectl config set users.default.token "$KUBE_TOKEN"
kubectl config set clusters.cluster.server "$KUBE_SERVER"

if [ -n "$KUBE_CA" ]; then
  kubectl config set clusters.cluster.certificate-authority-data "$KUBE_CA"
fi

echo
kubectl config get-contexts
echo
kubectl config set-context cluster --namespace=$KUBE_NAMESPACE

# Here KUBE_DEPLOYMENTS can be one or many, e.g.
# deployment/senderd,deployment/ratesd or just cronjob/test
IFS=',' read -r -a array <<< "$KUBE_DEPLOYMENTS"

echo
cat ~/.kube/config
echo

# Deploy to each namespace
for element in "${array[@]}"
do
  kubectl set image $element -n $KUBE_NAMESPACE deployment=docker.cogolo.net/$DOCKER_ORG/$DOCKER_REPO:$TRAVIS_TAG
done

# Ensure successful rollout
for element in "${array[@]}"
do
  kubectl rollout status -n $KUBE_NAMESPACE $element
done
