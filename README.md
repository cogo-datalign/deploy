# Deploy

Deployment automation for Kubernetes in TravisCI

To get automated deployments:

1. Setup the docker.cogolo.net repository to trigger on `tags/.+` builds
1. Follow the Travis Configuration guide, then
1. follow the steps to trigger a deployment.

## Travis Configuration

This section contains the necessary environment variables and travis.yml changes to
automated tagged deployments to work.

### Environment Variables

| Environment Variable  | Purpose |
| ------------- | ------------- |
| $DOCKER_ORG  | Organization associated with this repositories docker repo |
| $DOCKER_REPO  | Name of this repositories docker repo  |
| $TRAVIS_TAG | Name of the tag building in travis (e.g. v0.10) |
| $DOCKER_ACCESS_TOKEN | docker.cogolo.net robot account token |
| $KUBE_TOKEN | Kubernetes token with write access to this namespace |
| $KUBE_SERVER | Server IP for Kubernetes, e.g. https://sink.cogolo.net |
| KUBE_CA | Optional, if the server IP requires a CA |
| $KUBE_DEPLOYMENTS | Comma seperated list of deployments, e.g. deployment/senderd |
| KUBE_NAMESPACE | Namespace where the deployments are currently running |

### Travis YAML

Just add:

```yml
after_success:
  - >
    if [ -n "$TRAVIS_TAG" ]; then
      bash <(curl -s https://raw.git.cogolo.net/kubes/deploy/not_sh/deploy.sh)
    fi
```

To your `travis.yml` file.

## Triggering a deployment

Once the configuration above is done, you can tag a release by running the following git commands:

```bash
git checkout master && git pull origin master
git tag v0.01
git push origin --tags
```

Github also has a releases view if you want to go through the GUI
