
# Openshift

Configure a centos cluster with vagrant and install full openshift cluster with ansible

- [minishift](./minishift/README.md) - start a 1 node openshift with minishift and vmbox
- [vagrant cluster](./vagrant/README.md) - Install a full cluster with official ansible scripts
- [apps](./apps/README.md) - deploy examples to openshift

Openshift Docs <https://docs.okd.io/3.11/welcome/index.html>

## CLI

- On mac os x install the cli with brew `brew install openshift-cli` then run `oc`
- OR run the cli with docker `docker pull openshift/origin-cli` from <https://hub.docker.com/r/openshift/origin-cli/>

## Notes

- Tip: enable shell completion `source <(oc completion bash)` or `source <(oc completion zsh)`
- Openshift docker images <https://hub.docker.com/r/openshift/>
