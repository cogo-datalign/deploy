#!/usr/bin/env bash

if [ -z "$TRAVIS_TAG" ]; then
  echo "No travis tags were specified."
  echo "Doing nothing."
  exit 0
fi

# Use v1.13.2 unless --latest is specified
VERSION=v1.13.2
if [[ $1 == "--latest" ]]; then
	VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
fi


# Download the stable version of Kubectl
curl -LO --silent https://storage.googleapis.com/kubernetes-release/release/$VERSION/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

KUBE_CONFIG="$HOME/.kube/config"

# Create the Kube config and set the token 
mkdir -p ${HOME}/.kube
curl --silent https://raw.git.cogolo.net/kubes/deploy/master/config >> $KUBE_CONFIG

# Ability to do canary
if [[ $TRAVIS_TAG == *"canary"* ]]; then
    FIND_ARGS="-name *canary*.yaml"
else
    FIND_ARGS="-name *.yaml ! -name *canary*"
fi

for KUBERNETES_YAML in `find ./k8s $FIND_ARGS`; 
do
    KUBE_SERVER=$(basename $KUBERNETES_YAML | awk -F "-" '{print $1}')
    KUBE_NAMESPACE=$(grep -oP "namespace:\s*\K((\w+-?)+)" $KUBERNETES_YAML)
    DOCKER_ORG=$(grep -oP "image: [a-zA-Z0-9\-\.]+\/\K([a-zA-Z0-9\-\.]+)" $KUBERNETES_YAML)
    DOCKER_REPO=$(grep -oP "image: [a-zA-Z0-9\-\.]+\/[a-zA-Z0-9\-\.]+\/\K([a-zA-Z0-9\-\.]+)" $KUBERNETES_YAML)

    # Wait for the tag to build in docker.cogolo.net
    for i in $(seq 1 60); do
        curl --output /dev/null --silent --head --fail "https://docker.cogolo.net/api/v1/repository/$DOCKER_ORG/$DOCKER_REPO/tag/$TRAVIS_TAG/images" -H "Authorization: Bearer $OAUTH_TOKEN"
        if [[ $? == "0" ]]; then
            DONE="true"
            break
        else
            echo "Waiting for tag $TRAVIS_TAG to build in docker.cogolo.net..."
            echo "https://docker.cogolo.net/api/v1/repository/$DOCKER_ORG/$DOCKER_REPO/tag/$TRAVIS_TAG/images"
            sleep 5
        fi
    done

    if [ -z "$DONE" ]; then
        echo "Timeout waiting on $TRAVIS_TAG to build in docker.cogolo.net."
        echo "Exiting."
        exit 1
    fi
    
    KUBE_TOKEN_VAR=$(echo $KUBE_SERVER$'_KUBE_TOKEN' | sed -e "s/\./_/g")
    KUBE_TOKEN=${!KUBE_TOKEN_VAR}

    kubectl config set users.default.token "$KUBE_TOKEN" > /dev/null
    kubectl config set clusters.cluster.server "$KUBE_SERVER" > /dev/null

    # manually set the current context; "kubectl config set-context cluster" doesn't work
    sed -i 's/current-context: ""/current-context: cluster/g' $KUBE_CONFIG
    sed -i 's/server: /server: https:\/\//g' $KUBE_CONFIG
    
    sed -i "s/{{IMAGE_TAG}}/$TRAVIS_TAG/g" $KUBERNETES_YAML
    kubectl apply -n $KUBE_NAMESPACE -f $KUBERNETES_YAML

    # Here KUBE_DEPLOYMENTS can be one or many, e.g.
    # deployment/senderd,deployment/ratesd or just cronjob/test.
    # For deployYAML this is ONLY for monitoring purposes inside
    # travisCI
    IFS=',' read -r -a DEPLOYMENTS <<< "$KUBE_DEPLOYMENTS"

    # Ensure successful rollout
    for deployment in "${DEPLOYMENTS[@]}"; do
        kubectl rollout status -n $KUBE_NAMESPACE $deployment
    done


done
