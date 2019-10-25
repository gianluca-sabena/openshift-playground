#!/bin/bash
#
#   Minishift
#
#   Check syntax with https://github.com/koalaman/shellcheck
#

#set -x          # debug enabled
set -e          # exit on first error
set -o pipefail # exit on any errors in piped commands

#ENVIRONMENT VARIABLES

#declare OS_MASTER_HOST="okd-master-01.vm.local"
#declare OS_MASTER_URL="https://127.0.0.1:8443"
declare OS_CONFIG="/tmp/openshift-config/openshift.conf"
declare OS_CMD="oc --config=${OS_CONFIG} "

#declare SCRIPT_PATH; SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#declare CURRENT_PATH; CURRENT_PATH=$( pwd )

# @info:  Parses and validates the CLI arguments
# @args:	Global Arguments $@

function parseCli() {
  if [[ "$#" -eq 0 ]]; then
      echo "  ${0}: "
      echo ""
      echo "    help       print help"
      echo "    upgrade    upgrade minishift and cli..."
      echo "    up"
      echo "    down"
      echo "    console"
      echo "    login-admin"
      echo "    login-developer"
      echo "    docker-login-admin"
      echo "    info"
      echo "    set-clock"
      exit 0
  fi
  while [[ "$#" -gt 0 ]]; do
    declare KEY="$1"
    #declare VALUE="$2"
    case "${KEY}" in

    #
    # --- Minishift ---
    #
    upgrade)
      brew update
      brew cask install minishift || (brew cask upgrade minishift && brew cask cleanup minishift)
      brew install openshift-cli || (brew upgrade openshift-cli && brew cleanup openshift-cli)
      brew install kubernetes-cli || (brew upgrade kubernetes-cli && brew cleanup kubernetes-cli)
    ;;
    up)
      minishift addon enable admin-user
      minishift addon enable registry-route
      minishift start --vm-driver virtualbox --memory 8GB ## --routing-suffix TODO
    ;;
    down)
      minishift stop
    ;;
    console)
      minishift console
    ;;
    login-developer)
      ${OS_CMD} create user developer || echo ""
      ${OS_CMD} login --username=developer --password=developer
    ;;
    login-admin)
      SERVER="https://$( minishift ip ):8443"
      echo " * Login to ${SERVER} with user:admin password:admin "
      #--insecure-skip-tls-verify
      minishift ssh "cat /mnt/sda1/var/lib/minishift/base/kube-apiserver/ca.crt" > /tmp/openshift-crt-ca.crt
      echo 
      ${OS_CMD} -n default login -u admin -p admin --server="${SERVER}"  --certificate-authority=/tmp/openshift-crt-ca.crt --loglevel 5
    ;;
    docker-login-admin)
      local DOCKER_REGISTRY_ROUTE; DOCKER_REGISTRY_ROUTE=$(minishift openshift registry)
      local OS_USER; OS_USER="admin"
      local OS_TOKEN; OS_TOKEN=$(${OS_CMD} whoami -t)
      docker info &> /dev/null || (echo "ERROR: Check if docker engine on your LAPTOP is up and running!" && exit 1)
      echo "${OS_TOKEN}" | docker login --password-stdin  -u "${OS_USER}"  "${DOCKER_REGISTRY_ROUTE}"
    ;;
    info)
      DOCKER_REGISTRY_ROUTE=$(${OS_CMD} get route docker-registry  -n default -o jsonpath='{.spec.host}')
      DOCKER_REGISTRY_IP=$(${OS_CMD} get svc docker-registry  -n default -o jsonpath='{.spec.clusterIP}')
      echo " * Minishift current context: $(${OS_CMD} config current-context)"
      echo " * Minishift ip: $( minishift ip) "
      echo " * Docker registry route: ${DOCKER_REGISTRY_ROUTE}"
      echo " * Docker registry internal pod ip: ${DOCKER_REGISTRY_IP}"
    ;;
    set-clock)
      echo "Current date in minishift: $(minishift ssh date)"
      DATE_SEC=$(  date +%s )
      minishift ssh "sudo timedatectl set-timezone Europe/Rome"
      minishift ssh "sudo date -s '@${DATE_SEC}'"
      echo "New date in minishift: $(minishift ssh date)"
    ;;
    help | *)
      ${0}
      ;;
    esac
    shift
  done
}

parseCli "$@"
