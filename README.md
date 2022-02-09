# Amazon EKS Deploy

Deployment automation for EKS via Github Actions

To get automated deployments:

1. Setup the docker.cogolo.net repository to trigger on `tags/.+` builds
2. Follow the Github Actions configuration guide
3. Follow the steps to trigger a deployment

## Github Actions Configuration

This section contains the necessary environment variables for automated tagged deployments to work.

### Environment Variables

| Environment Variable  | Purpose |
| ------------- | ------------- |
| AWS_CLUSTER_NAME | The EKS cluster name |
| AWS_ACCESS_KEY_ID | The AWS access key (do not store in plaintext) |
| AWS_SECRET_ACCESS_KEY | The AWS secret key (do not store in plaintext) |
| DOCKER_ORG  | Organization associated with this repositories Docker repo |
| DOCKER_REPO  | Name of this repository's Docker repo |
| KUBE_SERVER_AWS | Server IP for Kubernetes, e.g. https://7B50BCD2D74AACBE31D13435FF390BB1.gr7.us-east-1.eks.amazonaws.com |
| KUBE_CA_AWS | The base64 encoded certificate                               |
| KUBE_DEPLOYMENTS_AWS | Comma separated list of deployments, e.g. `deployment/apid,deployment/portald` |
| KUBE_YAML_FOLDER | The folder where the YAMLs are located, ie. `k8s-aws` |
| KUBE_NAMESPACE_AWS | Namespace where the deployments are currently running |
| OAUTH_TOKEN | Optional, only required if Quay repo is private. Access token allows us to use the Quay API (see instructions below) |

If your Quay repo is private, generate an OAuth token for that repository. To do so:

- Create a new `Robot Account` for that repo
  - This is different than creating a repo, go to `https://docker.cogolo.net/organization/<your_org>?tab=robots` and create a new one 
- Click on the robot account name and get the `Robot Token` from the modal
- Add the token as a secret to the repo and import it to your Github Actions workflow YAML

### Github Actions YAML

Add the following to your Github Actions workflow YAML:

```yml
- name: Deploy
  run: bash <(curl -s --cipher 'DEFAULT:!DH' https://raw.git.cogolo.net/clickx/deploy/master/deployYAML.sh)
```

## Triggering a deployment

Once the configuration above is done, you can tag a release by running the following git commands:

```bash
git checkout master && git pull origin master
git tag v0.01
git push origin --tags
```

Github also has a releases view if you want to go through the GUI.
