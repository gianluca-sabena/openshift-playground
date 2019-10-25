# Minishift and docker cluster

Note: works only with openshift 3.x, version 4 is not supported, use code ready <https://github.com/code-ready/crc>

Openshift can run with:

- `oc cluster up`
- minishift

## Minishift

Docker registry login `docker login -u developer -p $(oc whoami -t) $(minishift openshift registry)`