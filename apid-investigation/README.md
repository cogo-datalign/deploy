#  Notes on creating helm charts auotmagically

I stared with [helmify](https://github.com/arttor/helmify) which takes manifest files and generates helms and some of elgoog, to generate the manifest, landing on [some rando scripts](https://github.com/kubernetes/kubernetes/issues/24873).


This results in [k8-backup.sh](k8-backup.sh) and [create help](create-helm.sh).

## Things to figure out

* Remove all secrets from the config maps
* There seems like a bunch of duplication, where the pods, replicasets and targetgroupbindings have each instance in them, and not the number (e.g. this pod has 5 nodes), but that may be because of the tool or my ignorance about k8.


### Steps

#### August worklog

* ran the script, copied over *just* lead align to apid-investigation.
* deleted the pods, replicasets targetgroupbindings, events, persistentvolumeclaims
* deleted every resource that didn't begin with api **except** for the config map ones (including the secrets directory).  Also deleted kube_root_cert in configmaps directory.
* Ran [create-helm.sh](./create-helm.sh).
* Gave "" value to anything in ./apid/apid/values.yaml that looked secret.
* Copied result to ../terraform
* Looking at [this](https://developer.hashicorp.com/terraform/tutorials/kubernetes/helm-provider) to wire helm into tf.
* Copied over jaeger-helm tf data
* Needed to add "variable "region" {default = "us-east-1"} to 

## Todo

* The leadalign.yaml file has the entirity of the configuration.toml file, including secrets included - this needs to be snipped (the values.yml in the outer directory has the same info).
* Wire chart into terraform & test.




