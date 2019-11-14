#!/bin/bash
#
#   Openshift cluster helper script
#
#   check syntax with https://github.com/koalaman/shellcheck
#

#set -x         # debug enabled
set -e          # exit on first error
set -o pipefail # exit on any errors in piped commands

#ENVIRONMENT VARIABLES
declare ROOK_VERSION="v1.1.4"
declare OS_NAMESPACE="apps-example"
declare OS_MASTER_HOST="okd-master-01.vm.local"
declare OS_MASTER_URL="https://${OS_MASTER_HOST}:8443"
declare OS_USER_ADMIN_NAME="admin"
declare OS_USER_ADMIN_PASSWORD="admin"
declare OS_USER_DEVELOPER_NAME="developer"
declare OS_USER_DEVELOPER_PASSWORD="developer"
declare TMP_PATH="/tmp/openshift"
declare OS_CONFIG="${TMP_PATH}/openshift.conf"
declare OS_CMD="oc --config=${OS_CONFIG} "
declare SCRIPT_PATH
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare CURRENT_PATH
CURRENT_PATH=$(pwd)

# Check platform
declare PLATFORM
PLATFORM=$(uname)
if [[ "$PLATFORM" != 'Darwin' ]]; then
  echo " Only Mac Os X is supported"
  exit 1
fi

declare PARAM_OPENSHIFT=''
function parseCli() {
  if [[ "$#" -eq 0 ]]; then
    usage
  fi
  while [[ "$#" -gt 0 ]]; do
    key="$1"
    #val="$2"
    case $key in
    #openshift | os) PARAM_OPENSHIFT=$val; openshift; exit 0;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      PARAM_OPENSHIFT=$key
      openshift
      exit 0
      ;;
    esac
    shift
  done

}

# @info:	Prints out usage
function usage() {
  echo
  echo "  ${0}: "
  echo "-------------------------------"
  echo
  echo "  -h or --help          Opens this help menu"
  echo
  echo "  system:"
  echo "     check-ansible-connection"
  echo "     install-openshift  -> run all ansible and install openshift cluster on vagrant"
  echo "     create-user-admin"
  echo "     create-apps-namespace"
  echo "     console"
  echo "     login-admin"
  echo "     login-developer"
  echo "     get-auth"
  echo "     get-all"
  echo "     diagnostic"
  echo "  apps:"
  echo "     app-rook-rbd-create"
  echo "     app-rook-rbd-delete"
  echo "     app-rook-object-create"
  echo "     app-rook-object-delete"
  echo "     apps-rook-dashboard-open"
  echo "     app-rook-info"
  echo "     app-rook-test-pod-create"
  echo "     app-rook-test-pod-delete"
  echo
}

#
# ---------- Openshift ----------------------------------------------------------
#

function openshift() {

  case $PARAM_OPENSHIFT in

  #
  # ---------- system ----------
  #
  check-ansible-connection)
    export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i "${SCRIPT_PATH}/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory" "${SCRIPT_PATH}/ansible/ping.yml"
    ;;
  install-openshift)
    confirm "Install openshift cluster on vagrant vms "
    TMP=$(pwd)
    cd "${SCRIPT_PATH}" || echo "ERROR: Folder ${SCRIPT_PATH}/vagrant not found..."
    vagrant ssh ${OS_MASTER_HOST} -c "sudo ansible-playbook -i /opt/host-3-11-cluster.localhost /opt/ansible/ping.yml"
    confirm "Are all sdb disks bound to a 10G drive "
    vagrant ssh ${OS_MASTER_HOST} -c "sudo ansible-playbook -i /opt/host-3-11-cluster.localhost /opt/openshift-ansible/playbooks/prerequisites.yml"
    confirm "Are prerequisites installed "
    vagrant ssh ${OS_MASTER_HOST} -c "sudo ansible-playbook -i /opt/host-3-11-cluster.localhost /opt/openshift-ansible/playbooks/deploy_cluster.yml"
    cd "${TMP}" || echo "ERROR: Folder ${TMP} not found..."
    ;;

  console)
    open ${OS_MASTER_URL}
    ;;

  create-user-admin)
    TMP=$(pwd)
    cd "${SCRIPT_PATH}" || echo "ERROR: Folder ${SCRIPT_PATH}/vagrant not found..."
    vagrant ssh ${OS_MASTER_HOST} -c "sudo oc create user ${OS_USER_ADMIN_NAME} && sudo ${OS_CMD} adm policy add-cluster-role-to-user cluster-admin ${OS_USER_ADMIN_NAME}"
    cd "${TMP}" || echo "ERROR: Folder ${TMP} not found..."
    ;;

  #
  # ---------- Common tasks ----------
  #

  # User admin password admin created at install time
  login-admin)
    ${OS_CMD} login -u ${OS_USER_ADMIN_NAME} -p ${OS_USER_ADMIN_PASSWORD} --server=${OS_MASTER_URL} --insecure-skip-tls-verify --loglevel 5
    ${OS_CMD} project default
    ;;

  login-developer)
    [[ "$(${OS_CMD} whoami)" == "${OS_USER_ADMIN_NAME}" ]] || (echo "Must be run as oc admin user... please login as admin!" && exit 1)
    ${OS_CMD} create user ${OS_USER_DEVELOPER_NAME} || echo ""
    ${OS_CMD} login --username=${OS_USER_DEVELOPER_NAME} --password=${OS_USER_DEVELOPER_PASSWORD}
    ;;

  get-auth)
    echo " * Get cluster user, roles and scc info"
    ${OS_CMD} get scc
    ${OS_CMD} get roleBindings
    ${OS_CMD} get policyBindings
    ${OS_CMD} get clusterPolicyBindings
    ${OS_CMD} get user
    echo " To have more details run same commands with ${OS_CMD} describe [scc | ...]"
    ;;

  get-all)
    echo "Get templates"
    ${OS_CMD} get templates --show-labels=true --all-namespaces=true
    echo "Get persistent volumes"
    ${OS_CMD} get pv --show-labels=true --all-namespaces=true
    echo "Get persistent volume claims"
    ${OS_CMD} get pvc --show-labels=true --all-namespaces=true
    echo "Get service accounts"
    ${OS_CMD} get serviceaccounts --show-labels=true --all-namespaces=true
    echo "Get all objects"
    ${OS_CMD} get all --show-labels=true --all-namespaces=true
    ;;

  diagnostic)
    ${OS_CMD} adm diagnostics all
    ;;

  docker-registry-login)
    local DOCKER_REGISTRY_ROUTE
    DOCKER_REGISTRY_ROUTE=$(oc get route docker-registry -n default -o jsonpath='{.spec.host}')
    local OS_USER
    OS_USER=$(${OS_CMD} whoami)
    local OS_TOKEN
    OS_TOKEN=$(${OS_CMD} whoami -t)
    docker info &>/dev/null || (echo "ERROR: Check if docker engine on your LAPTOP is up and running!" && exit 1)
    echo "${OS_TOKEN}" | docker login --password-stdin -u "${OS_USER}" "${DOCKER_REGISTRY_ROUTE}"
    ;;
  #
  # ---------- apps ----------
  #
  create-apps-namespace)
    [[ "$(${OS_CMD} whoami)" == "${OS_USER_ADMIN_NAME}" ]] || (echo "Must be run as oc admin user... please login as admin!" && exit 1)
    # Add rbac roles to developer user
    ${OS_CMD} new-project "${OS_NAMESPACE}" || echo "."
    ${OS_CMD} project "${OS_NAMESPACE}"
    ${OS_CMD} -n ${OS_NAMESPACE} adm policy add-role-to-user edit developer
    ${OS_CMD} -n ${OS_NAMESPACE} adm policy add-role-to-user view developer

    ;;
  #
  # ---------- rook ----------
  #
  app-rook-rbd-create)
    ${OS_CMD} label node okd-worker-01.vm.local role=storage-node
    ${OS_CMD} label node okd-worker-02.vm.local role=storage-node
    ${OS_CMD} label node okd-worker-03.vm.local role=storage-node
    ${OS_CMD} -n rook-ceph create -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/common.yaml" || echo ""
    ${OS_CMD} -n rook-ceph create -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/operator-openshift.yaml" || echo ""
    ${OS_CMD} -n rook-ceph create -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/cluster.yaml" || echo ""
    ${OS_CMD} -n rook-ceph create -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/storageclass.yaml" || echo ""
    ${OS_CMD} -n rook-ceph create -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/toolbox.yaml" || echo ""
    ${OS_CMD} -n rook-ceph create -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/dashboard-route.yaml" || echo ""
    ;;
  app-rook-rbd-delete)
    ${OS_CMD} -n rook-ceph delete -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/common.yaml" || echo ""
    ${OS_CMD} -n rook-ceph delete -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/operator-openshift.yaml" || echo ""
    ${OS_CMD} -n rook-ceph delete -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/cluster.yaml" || echo ""
    ${OS_CMD} -n rook-ceph delete -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/storageclass.yaml" || echo ""
    ${OS_CMD} -n rook-ceph delete -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/toolbox.yaml" || echo ""
    ${OS_CMD} -n rook-ceph delete -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/dashboard-route.yaml" || echo ""
    ${OS_CMD} label node okd-worker-01.vm.local role- || echo ""
    ${OS_CMD} label node okd-worker-02.vm.local role- || echo ""
    ${OS_CMD} label node okd-worker-03.vm.local role- || echo ""
    # delete data on vm
    export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory ansible/rook-clean-data.yml
    ;;
  app-rook-object-create)
    ${OS_CMD} -n rook-ceph create -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/object-store.yaml"
    echo "Wait 60 seconds to allow operator creates object store pool..."
    sleep 60
    ${OS_CMD} -n rook-ceph create -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/object-user.yaml"
    confirm "Modify ceph dshboard to show object store?"
    ${OS_CMD} -n rook-ceph rsh deployment/rook-ceph-tools radosgw-admin user list
    confirm "Is user present?"
    ACCESS_KEY=$(${OS_CMD} -n rook-ceph get secret rook-ceph-object-user-my-store-my-user -o yaml | grep AccessKey | awk '{print $2}' | base64 --decode)
    SECRET_KEY=$(${OS_CMD} -n rook-ceph get secret rook-ceph-object-user-my-store-my-user -o yaml | grep SecretKey | awk '{print $2}' | base64 --decode)
    ${OS_CMD} radosgw-admin user modify --uid=my-user --system
    ${OS_CMD} ceph dashboard set-rgw-api-user-id my-user
    ${OS_CMD} ceph dashboard set-rgw-api-access-key "${ACCESS_KEY}"
    ${OS_CMD} ceph dashboard set-rgw-api-secret-key "${SECRET_KEY}"
    ${OS_CMD} ceph dashboard set-rgw-api-host rook-ceph-rgw-my-store.rook-ceph
    ${OS_CMD} ceph dashboard set-rgw-api-ssl-verify False
    ${OS_CMD} ceph dashboard set-rgw-api-port 8080
    ;;
  app-rook-object-delete)
    ${OS_CMD} -n rook-ceph delete -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/object-store.yaml"
    ${OS_CMD} -n rook-ceph delete -f "${SCRIPT_PATH}/apps/rook/${ROOK_VERSION}/object-user.yaml"
    ;;
  app-rook-info)
    ${OS_CMD} -n rook-ceph get all
    ${OS_CMD} -n rook-ceph rsh deployment/rook-ceph-tools ceph status
    ;;
  app-rook-dashboard-open)
    PSW=$(${OS_CMD} -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode && echo)
    echo "Login with user 'admin' and password '${PSW}'"
    ROUTE=$(${OS_CMD} -n rook-ceph get route rook-ceph-mgr-dashboard-external-https -o jsonpath='{.spec.host}' -n "rook-ceph")
    open "https://${ROUTE}"
    ;;
  app-rook-test-pod-create)
    ${OS_CMD} -n ${OS_NAMESPACE} create -f "${SCRIPT_PATH}/examples/rook/pod-bash-test.yaml"
    ;;
  app-rook-test-pod-delete)
    ${OS_CMD} -n ${OS_NAMESPACE} delete -f "${SCRIPT_PATH}/examples/rook/pod-bash-test.yaml"
    ;;

  *)
    usage
    exit 0
    ;;
  esac

}

function confirm() {
  echo
  read -p " - ${1} [yes/no]? " -n 5 -r
  echo # (optional) move to a new line
  if [[ ! "$REPLY" == "yes" ]]; then
    echo "aborted..."
    exit 11
  fi
}

parseCli "$@"

cd "${CURRENT_PATH}" || .
