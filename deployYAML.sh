#!/usr/bin/env bash

if [ "$GITHUB_REF_TYPE" == "tag" ]; then
  echo "No tags were specified."
  echo "Doing nothing."
  exit 0
fi

# refs/heads/my-tag => my-tag
GITHUB_TAG=$(echo $GITHUB_REF | sed 's/refs\/heads//g')

# Use v1.21.2 unless --latest is specified
VERSION=v1.21.2
if [[ $1 == "--latest" ]]; then
	VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
fi

# Wait for the tag to build in docker.cogolo.net
for i in $(seq 1 300); do
  curl --output /dev/null --silent --head --fail "https://docker.cogolo.net/api/v1/repository/$DOCKER_ORG/$DOCKER_REPO/tag/$GITHUB_TAG/images" -H "Authorization: Bearer $OAUTH_TOKEN" && {
    DONE="true"
    break
  } || {
    echo "Waiting for tag $GITHUB_TAG to build in docker.cogolo.net..."
    sleep 5
  }
done

if [ -z "$DONE" ]; then
  echo "Timeout waiting on $GITHUB_TAG to build in docker.cogolo.net."
  echo "Exiting."
  exit 1
fi
 
# Download the stable version of Kubectl
curl -LO --silent https://storage.googleapis.com/kubernetes-release/release/$VERSION/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

KUBE_CONFIG="$HOME/.kube/config"

# Create the Kube config and set the token 
mkdir -p ${HOME}/.kube
curl --silent https://raw.git.cogolo.net/kubes/deploy/master/config >> $KUBE_CONFIG

# Ability to do canary OR multi deployments
if [[ $GITHUB_TAG == *"canary"* || $GITHUB_TAG == *"multi"* ]]; then
  kubectl config set users.default.token "$KUBE_TOKEN_CANARY"
  kubectl config set clusters.cluster.server "$KUBE_SERVER_CANARY"

  if [ -n "$KUBE_CA_CANARY" ]; then
    kubectl config set clusters.cluster.certificate-authority-data "$KUBE_CA_CANARY"
  fi

  # manually set the current context; "kubectl config set-context cluster" doesn't work
  sed -i 's/current-context: ""/current-context: cluster/g' $KUBE_CONFIG

  if [ -z "$KUBE_NAMESPACE_CANARY" ]; then
    KUBE_NAMESPACE_CANARY=$KUBE_NAMESPACE
  fi

  for KUBERNETES_YAML in `find ./k8s-canary/ -name '*.yaml'` ; 
  do
    sed -i 's/{{IMAGE_TAG}}/'"$GITHUB_TAG"'/g' $KUBERNETES_YAML
    kubectl apply -n $KUBE_NAMESPACE_CANARY -f $KUBERNETES_YAML
  done

  for KUBERNETES_YAML in `find ./k8s-canary/ -name '*.yaml'` ; 
  do
    DEPLOYMENT_NAME=$(echo "$KUBERNETES_YAML" | cut -f 1 -d '.')
    kubectl rollout status -n $KUBE_NAMESPACE_CANARY $DEPLOYMENT_NAME
  done

  IFS=',' read -r -a DEPLOYMENTS <<< "$KUBE_DEPLOYMENTS_CANARY"

  for deployment in "${DEPLOYMENTS[@]}"; do
    kubectl rollout status -n $KUBE_NAMESPACE_CANARY $deployment
  done

  if [[ $GITHUB_TAG == *"canary"* ]]; then
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

FIND_DIRECTORY="./k8s/"
if [ -n "$KUBE_DIRECTORY" ]; then
  FIND_DIRECTORY=$KUBE_DIRECTORY
fi

for KUBERNETES_YAML in `find $FIND_DIRECTORY -name '*.yaml'` ;
do
  sed -i 's/{{IMAGE_TAG}}/'"$GITHUB_TAG"'/g' $KUBERNETES_YAML
  kubectl apply -n $KUBE_NAMESPACE -f $KUBERNETES_YAML
done

# Here KUBE_DEPLOYMENTS can be one or many, e.g.
# deployment/senderd,deployment/ratesd or just cronjob/test.
# For deployYAML this is ONLY for monitoring purposes inside
# travisCI
IFS=',' read -r -a DEPLOYMENTS <<< "$KUBE_DEPLOYMENTS"

# Ensure successful rollout
for deployment in "${DEPLOYMENTS[@]}"; do
  kubectl rollout status -n $KUBE_NAMESPACE $deployment
done

#
# Deploy to AWS
#

# manually set AWS cli credentails
sed -i "s/_AWS_CLUSTER_NAME/$AWS_CLUSTER_NAME/g" $KUBE_CONFIG
aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY

export KUBECONFIG=$KUBE_CONFIG
kubectl config set clusters.eks.server $KUBE_SERVER_AWS

if [ -n "$KUBE_CA_AWS" ]; then
  kubectl config set clusters.eks.certificate-authority-data "$KUBE_CA_AWS"
fi

# manually set the current context; "kubectl config set-context cluster" doesn't work
sed -i 's/current-context: cluster/current-context: eks/g' $KUBE_CONFIG

if [ -z "$KUBE_NAMESPACE_AWS" ]; then
  KUBE_NAMESPACE_AWS=$KUBE_NAMESPACE_AWS
fi

for KUBERNETES_YAML in `find ./k8s-aws/ -name '*.yaml'` ; 
do
  sed -i 's/{{IMAGE_TAG}}/'"$GITHUB_TAG"'/g' $KUBERNETES_YAML
  kubectl apply -n $KUBE_NAMESPACE_AWS -f $KUBERNETES_YAML
done

IFS=',' read -r -a DEPLOYMENTS <<< "$KUBE_DEPLOYMENTS_AWS"

for deployment in "${DEPLOYMENTS[@]}"; do
  kubectl rollout status -n $KUBE_NAMESPACE_AWS $deployment
done
