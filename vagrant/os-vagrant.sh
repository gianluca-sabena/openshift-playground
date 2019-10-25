#!/bin/bash
#
#   Openshift cluster helper script
#
#   REMEMBER TO check syntax with https://github.com/koalaman/shellcheck
#

#set -x          # debug enabled
set -e          # exit on first error
set -o pipefail # exit on any errors in piped commands

#ENVIRONMENT VARIABLES

declare OS_MASTER_HOST="okd-master-01.vm.local"
declare OS_MASTER_URL="https://127.0.0.1:8443"
declare OS_NAMESPACE="apps-example"
declare OS_CMD="oc -n ${OS_NAMESPACE} "

declare SCRIPT_PATH; SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
declare CURRENT_PATH; CURRENT_PATH=$( pwd )

# Check platform
declare PLATFORM; PLATFORM=$(uname)
if [[ "$PLATFORM" != 'Darwin' ]]; then
  echo " Only Mac Os X is supported"
  exit 1
fi


declare PARAM_OPENSHIFT=''
function parseCli(){
  if [[ "$#" -eq 0 ]]; then
    usage
  fi
  while [[ "$#" -gt 0 ]]; do
    key="$1"
    #val="$2"
    case $key in
      #openshift | os) PARAM_OPENSHIFT=$val; openshift; exit 0;;
      -h | --help ) usage; exit 0 ;;
      *) PARAM_OPENSHIFT=$key; openshift; exit 0;;
    esac
    shift
  done

}

# @info:	Prints out usage
function usage {
  echo
  echo "  ${0}: "
  echo "-------------------------------"
  echo
  echo "  -h or --help          Opens this help menu"
  echo
  echo "  tasks:" 
  echo "   ! vagrant-install-openshift  -> run all ansible and install openshift cluster on vagrant"
  echo "     vagrant-create-user-admin"
  echo "     vagrant-open-web-ui"
  echo "     vagrant-login-admin"
  echo "     create-user-developer"
  echo "     get-auth"
  echo "     get-all"
  echo "     diagnostic"
  echo "  examples:" 
  echo "     example-create-namespace"
  echo "     example-import-docker-image-busy-box"
  echo "     example-s2i-python-web-server-deploy"
  echo "     example-s2i-python-web-server-delete"
  echo "     example-s2i-python-web-server-info"
  echo "     example-s2i-python-web-server-console"
  echo "  rook: "
  echo "     example-rook-v13-r3-create | example-rook-v13-r3-delete"
  echo "     example-rook-v14-r1-create | example-rook-v14-r1-delete"
  echo "     example-rook-test-pod-deploy | example-rook-test-pod-delete"
  echo "  maistra/istio:"
  echo "     maistra-patch-master | maistra-operator-deploy | maistra-control-plane-deploy | maistra-check | maistra-uninstall "
  echo "     maistra-example-book-info-deploy | maistra-example-book-info-delete"
  echo
}


#
# ---------- Openshift ----------------------------------------------------------
#


function openshift() {

  case $PARAM_OPENSHIFT in

    #
    # ---------- Vagrant ----------
    #     
    vagrant-install-openshift)
      confirm "Install openshift cluster on vagrant vms "
      TMP=$( pwd )
      cd "${SCRIPT_PATH}/vagrant" || echo "ERROR: Folder ${SCRIPT_PATH}/vagrant not found..."
      vagrant ssh ${OS_MASTER_HOST} -c "sudo ansible-playbook -i /opt/host-3-11-cluster.localhost /opt/ping.yml"
      confirm "Are all sdb disks bound to a 10G drive "
      vagrant ssh ${OS_MASTER_HOST} -c "sudo ansible-playbook -i /opt/host-3-11-cluster.localhost /opt/openshift-ansible/playbooks/prerequisites.yml"
      confirm "Are prerequisites installed "
      vagrant ssh ${OS_MASTER_HOST} -c "sudo ansible-playbook -i /opt/host-3-11-cluster.localhost /opt/openshift-ansible/playbooks/deploy_cluster.yml"
      cd "${TMP}" || echo "ERROR: Folder ${TMP} not found..."
    ;;
    vagrant-open-web-ui)
      open ${OS_MASTER_URL}
    ;;
    vagrant-create-user-admin)
      TMP=$( pwd )
      cd "${SCRIPT_PATH}/vagrant" || echo "ERROR: Folder ${SCRIPT_PATH}/vagrant not found..."
      vagrant ssh ${OS_MASTER_HOST} -c "sudo oc create user admin && sudo ${OS_CMD} adm policy add-cluster-role-to-user cluster-admin admin"
      cd "${TMP}" || echo "ERROR: Folder ${TMP} not found..."
    ;;
    # User admin password admin created at install time
    vagrant-login-admin)
      ${OS_CMD} login -u admin -p admin --server=${OS_MASTER_URL} --insecure-skip-tls-verify --loglevel 5
      ${OS_CMD} project default
      echo "Export this context: export OS_CONTEXT=$( ${OS_CMD} whoami -c)"
    ;;

    #
    # ---------- Common tasks ----------
    # 


    create-user-developer)
      ${OS_CMD} create user developer
      ${OS_CMD} login --username=developer --password=developer
    ;;

    get-auth)
      setEnvContext
      echo " * Get cluster user, roles and scc info"
      ${OS_CMD} get scc
      ${OS_CMD} get roleBindings
      ${OS_CMD} get policyBindings
      ${OS_CMD} get clusterPolicyBindings
      ${OS_CMD} get user
      echo " To have more details run same commands with ${OS_CMD} describe [scc | ...]"
    ;;

    get-all)
      setEnvContext
      echo "Get templates"
      ${OS_CMD} get templates --show-labels=true --all-namespaces=true
      echo "Get persistent volumes"
      ${OS_CMD} get pv  --show-labels=true --all-namespaces=true
      echo "Get persistent volume claims"
      ${OS_CMD} get pvc --show-labels=true --all-namespaces=true
      echo "Get service accounts"
      ${OS_CMD} get serviceaccounts --show-labels=true --all-namespaces=true
      echo "Get all objects"
      ${OS_CMD} get all --show-labels=true --all-namespaces=true
    ;;

    diagnostic)
      setEnvContext
      ${OS_CMD} adm  diagnostics  all
    ;;

    docker-registry-login)
      local DOCKER_REGISTRY_ROUTE; DOCKER_REGISTRY_ROUTE=$(oc get route docker-registry  -n default -o jsonpath='{.spec.host}')
      local OS_USER; OS_USER=$(${OS_CMD} whoami)
      local OS_TOKEN; OS_TOKEN=$(${OS_CMD} whoami -t)
      docker info &> /dev/null || (echo "ERROR: Check if docker engine on your LAPTOP is up and running!" && exit 1)
      echo "${OS_TOKEN}" | docker login --password-stdin  -u "${OS_USER}"  "${DOCKER_REGISTRY_ROUTE}"
    ;;

    #
    # ---------- rook ----------
    # 

    # See readme.md
    example-rook-v13-r3-create)
      # use a old ceph image, this works with replica 3, hostnetwork false and dashboard disabled
      ${OS_CMD} label node okd-worker-01.vm.local role=storage-node
      ${OS_CMD} label node okd-worker-02.vm.local role=storage-node
      ${OS_CMD} label node okd-worker-03.vm.local role=storage-node
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/v13-r3/common.yaml"
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/v13-r3/operator-openshift.yaml"
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/v13-r3/cluster.yaml"
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/v13-r3/storageclass.yaml"
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/toolbox.yaml"
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/dashboard-external-https.yaml"
      ;;
    example-rook-v13-r3-delete)
      # official delete guide
      ${OS_CMD} -n rook-ceph  deletecephblockpool replicapool
      ${OS_CMD} delete storageclass rook-ceph-block
      ${OS_CMD} -n rook-ceph delete cephcluster rook-ceph
      echo "sleep 60 seconds"
      sleep 60
      kubectl -n rook-ceph get cephcluster
      echo "If there is no ceph cluster running, go to example-rook-delete-2..."
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/dashboard-external-https.yaml"
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/toolbox.yaml"
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/v13-r3/storageclass.yaml"
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/v13-r3/cluster-test.yaml"
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/v13-r3/operator-openshift.yaml"
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/v13-r3/common.yaml"
      ${OS_CMD} label node okd-worker-01.vm.local role-
      ${OS_CMD} label node okd-worker-02.vm.local role-
      ${OS_CMD} label node okd-worker-03.vm.local role-
      # delete data on vm
      export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i "${SCRIPT_PATH}/vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory" "${SCRIPT_PATH}/vagrant/ansible/rook-clean-data.yml"
      ;;
    example-rook-v14-r1-create)
      # Only work with 1 node, mon and operator on same node, networkhost = false and dashboard enabled
      ${OS_CMD} label node okd-worker-01.vm.local role=storage-node
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/v14-r1/common.yaml"
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/v14-r1/operator-openshift.yaml"
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/v14-r1/cluster.yaml"
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/v14-r1/storageclass.yaml"
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/toolbox.yaml"
      ${OS_CMD} create -f "${SCRIPT_PATH}/examples/rook/dashboard-external-https.yaml"
      ;;
    # DOES NOT WORK!!! Many issues.... TEST ONLY
    example-rook-v14-r1-delete)
      # official delete guide
      ${OS_CMD} -n rook-ceph  deletecephblockpool replicapool
      ${OS_CMD} delete storageclass rook-ceph-block
      ${OS_CMD} -n rook-ceph delete cephcluster rook-ceph
      echo "sleep 60 seconds"
      sleep 60
      kubectl -n rook-ceph get cephcluster
      echo "If there is no ceph cluster running, go to example-rook-delete-2..."
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/dashboard-external-https.yaml"
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/toolbox.yaml"
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/v14-r1/storageclass.yaml"
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/v14-r1/cluster-test.yaml"
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/v14-r1/operator-openshift.yaml"
      ${OS_CMD} delete -f "${SCRIPT_PATH}/examples/rook/v14-r1/common.yaml"
      ${OS_CMD} label node okd-worker-01.vm.local role-
      ${OS_CMD} label node okd-worker-02.vm.local role-
      ${OS_CMD} label node okd-worker-03.vm.local role-
      # delete data on vm
      export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory ansible/rook-clean-data.yml
      ;;
    example-rook-dashboard-open)
      # see https://rook.github.io/docs/rook/v1.0/ceph-dashboard.html
      PSW=$(${OS_CMD} -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode && echo)
      echo "Login with user 'admin' and password '${PSW}'"
      ROUTE=$(${OS_CMD} -n rook-ceph get route rook-ceph-mgr-dashboard-external-https -o jsonpath='{.spec.host}' -n "rook-ceph")
      open "https://${ROUTE}"
      ;;
    example-rook-test-pod-deploy)
      ${OS_CMD} -n rook-ceph create -f "${SCRIPT_PATH}/examples/rook/test-pod.yaml"
      ;;
    example-rook-test-pod-delete)
      ${OS_CMD} -n rook-ceph delete -f "${SCRIPT_PATH}/examples/rook/test-pod.yaml"
      ;;
    example-rook-info)
      ${OS_CMD} -n rook-ceph get pod
      ;;
    

    *) usage; exit 0 ;;
  esac

}

function setEnvContext(){
  if [[ -n "${OS_CONTEXT}" ]]; then
    echo "!!! Found OS_CONTEXT env: ${OS_CONTEXT} !!!"
    USER=$(${OS_CMD} whoami)
    USER_FROM_CONTEXT=$( echo "${OS_CONTEXT}"  | cut -d/ -f3 )
    if [[ "${USER}" != "${USER_FROM_CONTEXT}" ]]; then
      echo "ERROR: User from OS_CONTEXT env is: ${USER_FROM_CONTEXT} but it is not authenticated! Try to login..."
      exit 11
    fi
    echo "!!! Logged in user is: ${USER}"
    OS_CMD="${OS_CMD} --context=$OS_CONTEXT "
  fi
}

function confirm {
  echo
  read -p " - ${1} [yes/no]? " -n 5 -r
  echo # (optional) move to a new line
  if [[ ! "$REPLY" == "yes" ]]
  then
      echo "aborted..."
      exit 11
  fi
}


parseCli "$@"

cd "${CURRENT_PATH}" || .



