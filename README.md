# Multi-Cluster Deploy

Deployment automation for Kubernetes in TravisCI

To get automated deployments:

1. Setup the docker.cogolo.net repository to trigger on `tags/.+` builds
2. Follow the Travis Configuration guide, then
3. follow the steps to trigger a deployment.

### Formatting Kubernetes YAMLs

Kubernetes YAMLs should be placed in the `k8s` directory with file names formatted as follows:

`<cluster-FQDN>-<file-type>.yaml`

Example: kubes2.cogolo.net-deployment.yaml

Append `-canary` for canary deploys:

`<cluster-FQDN>-<file-type>-canary.yaml`

Example: kubes2.cogolo.net-deployment-canary.yaml

### Travis YAML

Add the following to your `travis.yml` file:

```yml
after_success:
  - bash <(curl -s https://raw.git.cogolo.net/kubes/deploy/master/deployMultiClusterYAML.sh)
```

## Triggering a deployment

Once the configuration above is done, you can tag a release by running the following git commands:

```bash
git checkout master && git pull origin master
git tag v0.01
git push origin --tags
```

To start a canary deploy, the tag must include the word `canary`.

# Deploy.sh/DeployYAML.sh

## Travis Configuration

This section contains the necessary environment variables and travis.yml changes to
automated tagged deployments to work.

### Environment Variables

| Environment Variable  | Purpose | Encrypted |
| ------------- | ------------- | -------------- |
| DOCKER_ORG  | Organization associated with this repositories docker repo | No |
| DOCKER_REPO  | Name of this repositories docker repo  | No |
| TRAVIS_TAG | Name of the tag building in travis (e.g. v0.10) | No |
| DOCKER_ACCESS_TOKEN | docker.cogolo.net robot account token | Yes |
| KUBE_TOKEN | Kubernetes token with write access to this namespace | Yes |
| KUBE_SERVER | Server IP for Kubernetes, e.g. https://sink.cogolo.net | No |
| KUBE_CA | Optional, if the server IP requires a CA | No |
| KUBE_DEPLOYMENTS | Comma seperated list of deployments, e.g. deployment/senderd | No |
| KUBE_CONTAINERS | Comma seperated list of containers to deploy | No |
| KUBE_TOKEN_CANARY | Optional, Kubernetes token with write access to this namespace | Yes |
| KUBE_SERVER_CANARY | Optional, server IP for Kubernetes, e.g. https://sink.cogolo.net | No |
| KUBE_CA_CANARY | Optional, if the server IP requires a CA | No |
| KUBE_DEPLOYMENTS_CANARY | Optional, comma seperated list of deployments, e.g. deployment/senderd | No |
| KUBE_CONTAINERS_CANARY | Optional, comma seperated list of containers to deploy | No |
| KUBE_NAMESPACE | Namespace where the deployments are currently running | No |
| KUBE_SECRET | Optional, only required if Quay repo is private. The name of the kubes secret that willa llow the deployment to pull the docker image. | No |
| OAUTH_TOKEN | Optional, only required if Quay repo is private. Access token allows us to use the Quay API (see instructions below) | Yes |

If the `Encrypted` is `Yes`, store these environment variables in Travis using `travis encrypt` ([instructions here](https://git.cogolo.net/platform/wiki/wiki/Travis#usage)).

### Canary/Multi deployments

Canary and multi deployments allow you to target a second point of deployment. To do this tag the branch with the prefixes
`canary-` or `multi-`.

A canary deployment will only deploy to the canary specified server/deployment/containers and a multi will taget
both environments.

### Travis YAML

Add the following to your `travis.yml` file:

```yml
after_success:
  - bash <(curl -s https://raw.git.cogolo.net/kubes/deploy/master/deploy.sh)
```

If your Quay repo is private, generate an OAuth token for that repository. To do so:

- Create a new `Application` for that repo
  - This is different than creating a repo, go to https://docker.cogolo.net/organization/<your_org>?tab=applications and create a new one with the same name as your repository
- Click the `Generate Token` button from the vertical list on the left
- Generate a new oauth token with the `View all visible repositories` permission
- Encrypt the token and add it to your `travis.yml`

## Triggering a deployment

Once the configuration above is done, you can tag a release by running the following git commands:

```bash
git checkout master && git pull origin master
git tag v0.01
git push origin --tags
```

Github also has a releases view if you want to go through the GUI

# DeployStagingYAML.sh

## Staging Travis Configuration

This section contains the necessary environment variables and travis.yml changes to get
automated merge-to-master deployments to work.

### Staging Environment Variables

| Environment Variable  | Purpose | Encrypted |
| ------------- | ------------- | -------------- |
| DOCKER_ORG  | Organization associated with this repository's docker repo | No |
| DOCKER_REPO  | Name of this repository's docker repo  | No |
| STAGING_TAG | Name of the tag of the staging image | No |
| KUBE_TOKEN | Kubernetes token with write access to this namespace | Yes |
| KUBE_SERVER | Server IP for Kubernetes, e.g. https://sink.cogolo.net | No |
| KUBE_CA | Optional, if the server IP requires a CA | No |
| KUBE_DEPLOYMENTS | Comma seperated list of deployments, e.g. deployment/senderd | No |
| KUBE_NAMESPACE | Namespace where the deployments are currently running | No |
| OAUTH_TOKEN | Optional, only required if Quay repo is private. Access token allows us to use the Quay API (see instructions below) | Yes |

If the `Encrypted` is `Yes`, store these environment variables in Travis using `travis encrypt` ([instructions here](https://git.cogolo.net/platform/wiki/wiki/Travis#usage)).

### Formatting staging Kubernetes YAMLs

Staging Kubernetes YAMLs should be placed in the `k8s-staging` directory

### Staging Travis YAML

Add the following to your `travis.yml` file:

```yml
after_success:
  - bash <(curl -s https://raw.git.cogolo.net/kubes/deploy/master/deployStagingYAML.sh)
```

## Triggering a staging deployment

Once the configuration above is done, staging deployments will be rolled out on merges to master.