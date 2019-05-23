
# Openshift

Test openshift with:

- [vagrant cluster](./vagrant/README.md) - Install a full cluster with official ansible scripts
- [examples](./examples/README.md) - deploy examples to openshift

## Resources

- Docs <https://docs.okd.io/3.11/welcome/index.html>

## CLI

- Install on mac os x with brew `brew install openshift-cli`
- run CLI from docker image openshift/origin-cli <https://hub.docker.com/r/openshift/origin-cli/> It is based on CentOS
- Enable shell completion `source <(oc completion bash)` or `source <(oc completion zsh)`
- Openshift CLI image openshift/origin-cli from <https://hub.docker.com/r/openshift/origin-cli/> It is based on CentOS



## TODO

- add example local-provisioner <https://docs.okd.io/3.11/install_config/configuring_local.html#local-volume-configure-local-provisioner>
- add example for nfs volumes