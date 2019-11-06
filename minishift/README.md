# Minishift

Note: works only with openshift 3.x, version 4 is not supported, use code ready <https://github.com/code-ready/crc>

## Run

- Run `./os-minishift.sh` for a complete list of commands
- See script code [os-minishift.sh](./os-minishift.sh)
- Docker registry login `docker login -u $(oc whoami -t) -p $(oc whoami -t) $(minishift openshift registry)`
