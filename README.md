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

| Environment Variable  | Purpose | Encrypted |
| ------------- | ------------- | -------------- |
| $DOCKER_ORG  | Organization associated with this repositories docker repo | No |
| $DOCKER_REPO  | Name of this repositories docker repo  | No |
| $TRAVIS_TAG | Name of the tag building in travis (e.g. v0.10) | No |
| $DOCKER_ACCESS_TOKEN | docker.cogolo.net robot account token | Yes |
| $KUBE_TOKEN | Kubernetes token with write access to this namespace | Yes |
| $KUBE_SERVER | Server IP for Kubernetes, e.g. https://sink.cogolo.net | No |
| KUBE_CA | Optional, if the server IP requires a CA | No |
| $KUBE_DEPLOYMENTS | Comma seperated list of deployments, e.g. deployment/senderd | No |
| KUBE_NAMESPACE | Namespace where the deployments are currently running | No |
| OAUTH_TOKEN | (Only required if Quay repo is private) Access token allows us to use the Quay API (see instructions below) | Yes |

If the `Encrypted` is `Yes`, store these environment variables in Travis using `travis encrypt` ([instructions here](https://git.cogolo.net/platform/wiki/wiki/Travis#usage)).

### Travis YAML

Add the following to your `travis.yml` file:

```yml
after_success:
  - >
    if [ -n "$TRAVIS_TAG" ]; then
      bash <(curl -s https://raw.git.cogolo.net/kubes/deploy/not_sh/deploy.sh)
    fi
```

If your Quay repo is private, generate an OAuth token for that repository. To do so:

- Create a new `Application` for that repo
  - This is different than creating a repo, go to https://docker.cogolo.net/organization/<your_org>?tab=applications and create a new one with the same name as your repository
- Click the `Generate Token` button from the vertical list on the left
- Generate a new oauth token
- Encrypt the token and add it to your `travis.yml`

## Triggering a deployment

Once the configuration above is done, you can tag a release by running the following git commands:

```bash
git checkout master && git pull origin master
git tag v0.01
git push origin --tags
```

Github also has a releases view if you want to go through the GUI
