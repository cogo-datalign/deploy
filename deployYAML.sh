#!/usr/bin/env bash

# Github Actions default environment variables
# https://docs.github.com/en/enterprise-server@3.2/actions/learn-github-actions/environment-variables#default-environment-variables

if [[ "$GITHUB_REF" != *"tags"* && "$GITHUB_REF" != "refs/heads/master" ]]; then
  echo "No tags were specified."
  echo "Doing nothing."
  exit 0
fi

GITHUB_TAG=$(echo "$GITHUB_REF" | sed 's/refs\/tags\///g' | sed 's/refs\/heads\///g')

# Wait for the tag to build in docker.cogolo.net
for i in $(seq 1 300); do
  curl --output /dev/null --cipher 'DEFAULT:!DH' --silent --head --fail "https://docker.cogolo.net/api/v1/repository/$DOCKER_ORG/$DOCKER_REPO/tag/$GITHUB_TAG/images" -H "Authorization: Bearer $OAUTH_TOKEN" && {
    DONE="true"
    break
  } || {
    echo "Waiting for tag '$GITHUB_TAG' to build in docker.cogolo.net..."
    sleep 5
  }
done

if [ -z "$DONE" ]; then
  echo "Timeout waiting on '$GITHUB_TAG' to build in docker.cogolo.net."
  echo "Exiting."
  exit 1
fi
 
# Ensure that we use a local kubeconfig file
export KUBECONFIG="./kube_config"

# Create the Kube config and set the token 
curl --silent https://raw.git.cogolo.net/clickx/deploy/master/config >> $KUBECONFIG

#
# Deploy to AWS
#

# manually set AWS cli credentials
sed -i "s/_AWS_CLUSTER_NAME/$AWS_CLUSTER_NAME/g" $KUBECONFIG
sed -i "s/_AWS_ACCESS_KEY_ID/$AWS_ACCESS_KEY_ID/g" $KUBECONFIG
sed -i "s/_KUBE_NAMESPACE_AWS/$KUBE_NAMESPACE_AWS/g" $KUBECONFIG
sed -i "s/_AWS_SECRET_ACCESS_KEY/$(echo "$AWS_SECRET_ACCESS_KEY" | sed 's/\//\\\//g')/g" $KUBECONFIG

# set kubes server and CA data
sed -i "s/_AWS_SERVER/$(echo "$KUBE_SERVER_AWS" | sed 's/\//\\\//g')/g" $KUBECONFIG
sed -i "s/_AWS_CA_DATA/$KUBE_CA_AWS/g" $KUBECONFIG

for KUBERNETES_YAML in `find "./$KUBE_YAML_FOLDER/" -name '*.yaml'` ;
do
  sed -i 's/{{IMAGE_TAG}}/'"$GITHUB_TAG"'/g' "$KUBERNETES_YAML"
  kubectl --insecure-skip-tls-verify apply -n "$KUBE_NAMESPACE_AWS" -f "$KUBERNETES_YAML"
done

IFS=',' read -r -a DEPLOYMENTS <<< "$KUBE_DEPLOYMENTS_AWS"

for deployment in "${DEPLOYMENTS[@]}"; do
  kubectl --insecure-skip-tls-verify rollout status -n "$KUBE_NAMESPACE_AWS" $deployment
done
