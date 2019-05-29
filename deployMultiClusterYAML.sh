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
    kubectl config set users.default.token "$KUBE_TOKEN_CANARY"
    kubectl config set clusters.cluster.server "$KUBE_SERVER_CANARY"

    if [ -n "$KUBE_CA_CANARY" ]; then
        kubectl config set clusters.cluster.certificate-authority-data "$KUBE_CA_CANARY"
    fi

    # manually set the current context; "kubectl config set-context cluster" doesn't work
    sed -i 's/current-context: ""/current-context: cluster/g' $KUBE_CONFIG
    sed -i 's/server: /server: https:\/\//g' $KUBE_CONFIG

    for KUBERNETES_YAML in `find ./k8s-canary/ -name '*.yaml'` ; 
    do
        sed -i 's/{{IMAGE_TAG}}/'"$TRAVIS_TAG"'/g' $KUBERNETES_YAML
        kubectl apply -n $KUBE_NAMESPACE -f $KUBERNETES_YAML
    
        DEPLOYMENT_NAME=$(echo "$KUBERNETES_YAML" | cut -f 1 -d '.')
        kubectl rollout status -n $KUBE_NAMESPACE $DEPLOYMENT_NAME

        IFS=',' read -r -a DEPLOYMENTS <<< "$KUBE_DEPLOYMENTS_CANARY"

        for deployment in "${DEPLOYMENTS[@]}"; do
            kubectl rollout status -n $KUBE_NAMESPACE $deployment
        done
    done

    if [[ $TRAVIS_TAG == *"canary"* ]]; then
        exit 0
    fi
fi

for KUBERNETES_YAML in `find ./k8s/ -name '*.yaml'` ; 
do
    KUBE_SERVER=$(echo $KUBERNETES_YAML | sed -e "s/.yaml//" -e "s/.\/k8s\///" | awk -F "-" '{print $1}')
    KUBE_NAMESPACE=$(grep 'namespace' $KUBERNETES_YAML | sed 's/namespace://')
    DOCKER_ORG=$(grep 'image:' $KUBERNETES_YAML | awk -F "/" '{ print $2 }')
    DOCKER_REPO=$(grep 'image:' $KUBERNETES_YAML | awk -F "/" '{ print $3 }' | awk -F ":" '{ print $1 }')

    # Wait for the tag to build in docker.cogolo.net
    for i in $(seq 1 60); do
        curl --output /dev/null --silent --head --fail "https://docker.cogolo.net/api/v1/repository/$DOCKER_ORG/$DOCKER_REPO/tag/$TRAVIS_TAG/images" -H "Authorization: Bearer $OAUTH_TOKEN" && {
            DONE="true"
            break
        } || {
            echo "Waiting for tag $TRAVIS_TAG to build in docker.cogolo.net..."
            echo "https://docker.cogolo.net/api/v1/repository/$DOCKER_ORG/$DOCKER_REPO/tag/$TRAVIS_TAG/images"
            sleep 5
        }
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

    if [ -n "$KUBE_CA" ]; then
        kubectl config set clusters.cluster.certificate-authority-data "$KUBE_CA"
    fi

    # manually set the current context; "kubectl config set-context cluster" doesn't work
    sed -i 's/current-context: ""/current-context: cluster/g' $KUBE_CONFIG
    sed -i 's/server: /server: https:\/\//g' $KUBE_CONFIG
    
    sed -i 's/{{IMAGE_TAG}}/'"$TRAVIS_TAG"'/g' $KUBERNETES_YAML
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
