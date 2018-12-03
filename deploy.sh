#!/usr/bin/env bash

if [ -z "$TRAVIS_TAG" ]; then
  echo "No travis tags were specified."
  echo "Doing nothing."
  exit 0
fi

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

KUBE_CONFIG="$HOME/.kube/config"

# Create the Kube config and set the token 
mkdir -p ${HOME}/.kube
curl --silent https://raw.git.cogolo.net/kubes/deploy/master/config >> $KUBE_CONFIG

# Ability to do canary OR multi deployments
if [[ $TRAVIS_TAG == *"canary"* || $TRAVIS_TAG == *"multi"* ]]; then
  kubectl config set users.default.token "$KUBE_TOKEN_CANARY"
  kubectl config set clusters.cluster.server "$KUBE_SERVER_CANARY"
  kubectl config set clusters.cluster.certificate-authority-data "$KUBE_CA_CANARY"

  if [ -n "$KUBE_CA_CANARY" ]; then
    kubectl config set clusters.cluster.certificate-authority-data "$KUBE_CA_CANARY"
  fi

  # manually set the current context; "kubectl config set-context cluster" doesn't work
  sed -i 's/current-context: ""/current-context: cluster/g' $KUBE_CONFIG

  IFS=',' read -r -a DEPLOYMENTS <<< "$KUBE_DEPLOYMENTS_CANARY"
  IFS=',' read -r -a CONTAINERS <<< "$KUBE_CONTAINERS_CANARY"

  # Deploy each container to each namespace
  for deployment in "${DEPLOYMENTS[@]}"; do
    for container in "${CONTAINERS[@]}"; do
      kubectl set image $deployment -n $KUBE_NAMESPACE $container=docker.cogolo.net/$DOCKER_ORG/$DOCKER_REPO:$TRAVIS_TAG
    done
  done

  # Ensure successful rollout
  for deployment in "${DEPLOYMENTS[@]}"; do
    kubectl rollout status -n $KUBE_NAMESPACE $deployment
  done

  if [[ $TRAVIS_TAG == *"canary"* ]]; then
    exit 0
  fi
fi

kubectl config set users.default.token "$KUBE_TOKEN" > /dev/null
kubectl config set clusters.cluster.server "$KUBE_SERVER" > /dev/null

if [ -n "$KUBE_CA" ]; then
  kubectl config set clusters.cluster.certificate-authority-data "$KUBE_CA"
fi

# manually set the current context; "kubectl config set-context cluster" doesn't work
sed -i 's/current-context: ""/current-context: cluster/g' $KUBE_CONFIG

# Here KUBE_DEPLOYMENTS can be one or many, e.g.
# deployment/senderd,deployment/ratesd or just cronjob/test
IFS=',' read -r -a DEPLOYMENTS <<< "$KUBE_DEPLOYMENTS"
IFS=',' read -r -a CONTAINERS <<< "$KUBE_CONTAINERS"

# Deploy each container to each namespace
for deployment in "${DEPLOYMENTS[@]}"; do
  for container in "${CONTAINERS[@]}"; do
    kubectl set image $deployment -n $KUBE_NAMESPACE $container=docker.cogolo.net/$DOCKER_ORG/$DOCKER_REPO:$TRAVIS_TAG
  done
done

# Ensure successful rollout
for deployment in "${DEPLOYMENTS[@]}"; do
  kubectl rollout status -n $KUBE_NAMESPACE $deployment
done