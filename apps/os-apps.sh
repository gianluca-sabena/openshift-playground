#!/bin/bash
#
#   OpenShift and k8s example applications
#   check syntax with https://github.com/koalaman/shellcheck
#

#set -x          # debug enabled
set -e          # exit on first error
set -o pipefail # exit on any errors in piped commands

#ENVIRONMENT VARIABLES

declare OS_CONFIG="/tmp/openshift-config/openshift.conf"
declare OS_NAMESPACE="apps-example"
declare OS_CMD="oc --config=${OS_CONFIG} "
declare SCRIPT_PATH; SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
declare TMP_PATH="/tmp/openshift/"
#declare CURRENT_PATH; CURRENT_PATH=$( pwd )

# @info:  Parses and validates the CLI arguments
# @args:	Global Arguments $@

function parseCli() {
  if [[ "$#" -eq 0 ]]; then
    echo "  ${0}: "
    echo ""
    echo "               -action value               first param "
    exit 0
  fi
  while [[ "$#" -gt 0 ]]; do
    declare KEY="$1"
    #declare VALUE="$2"
    case "${KEY}" in
    #
    # ---------- Custom examples ----------
    #
    # set-env)
    #   echo "# Run eval \$(${0} set-env) "
    #   echo "export OS_CMD=\"${OS_CMD}\""
    # ;;
    create-apps-namespace)
      ${OS_CMD} new-project "${OS_NAMESPACE}"
      ${OS_CMD} project "${OS_NAMESPACE}"
      ;;
    import-docker-image-busy-box)
      ${OS_CMD} -n "${OS_NAMESPACE}" import-image default/busysbox:latest --from=docker.io/library/busybox:latest --confirm
      ;;
    #
    #
    # ---------- kubedb ----------
    #
    app-kubedb-install)
      mkdir -p "${SCRIPT_PATH}/${TMP_PATH}"
      cd "${SCRIPT_PATH}/${TMP_PATH}"
      ${OS_CMD} create namespace kubedb || echo ""
      #Use this config for kubedb bash script
      export KUBECONFIG="${OS_CONFIG}"
      curl -fsSL https://raw.githubusercontent.com/kubedb/cli/0.12.0/hack/deploy/kubedb.sh | bash -s --  --rbac --enable-validating-webhook=false --enable-mutating-webhook=false
    ;;
    app-kubedb-uninstall)
      mkdir -p "${SCRIPT_PATH}/${TMP_PATH}"
      cd "${SCRIPT_PATH}/${TMP_PATH}"
      #Use this config for kubedb bash script
      export KUBECONFIG="${OS_CONFIG}"      
      curl -fsSL https://raw.githubusercontent.com/kubedb/cli/0.12.0/hack/deploy/kubedb.sh | bash -s -- --uninstall 
    ;;
    app-kubedb-pgadmin-create)
      ${OS_CMD} create namespace demo || echo ""
      ${OS_CMD} adm policy add-scc-to-user anyuid system:serviceaccount:demo:default
      ${OS_CMD} -n ${OS_NAMESPACE} create -f "${SCRIPT_PATH}/kubedb-postgresql/0.12/pgadmin.yaml"
    ;;
    app-kubedb-pgadmin-delete)
      ${OS_CMD} -n ${OS_NAMESPACE} delete -f "${SCRIPT_PATH}/kubedb-postgresql/0.12/pgadmin.yaml"
    ;;
    app-kubedb-pgadmin-port-forward)
      ${OS_CMD} port-forward -n ${OS_NAMESPACE} svc/pgadmin 8080:80
    ;;
    app-kubedb-postgresql-scc-create)
      ${OS_CMD} create -f "${SCRIPT_PATH}/kubedb-postgresql/0.12/scc.yaml" || echo "."
      # Allow operator to start postgres with a specific service account
      # Add a custom scc (anyuid + 2 Capabilities)
      ${OS_CMD} adm policy add-scc-to-user kubedb-postgresql system:serviceaccount:${OS_NAMESPACE}:quick-postgres
      ${OS_CMD} adm policy add-scc-to-user kubedb-postgresql system:serviceaccount:${OS_NAMESPACE}:quick-postgres-snapshot
      # Allow unprivileged user to use kubedb crd/api/operator
      oc --config=/tmp/openshift-config/openshift.conf -n ${OS_NAMESPACE} adm policy add-role-to-user kubedb:core:edit developer
      oc --config=/tmp/openshift-config/openshift.conf -n ${OS_NAMESPACE} adm policy add-role-to-user kubedb:core:view developer
    ;;
    app-kubedb-postgresql-scc-delete)
      ${OS_CMD} adm policy remove-scc-from-user kubedb-postgresql system:serviceaccount:${OS_NAMESPACE}:quick-postgres
      ${OS_CMD} adm policy remove-scc-from-user kubedb-postgresql system:serviceaccount:${OS_NAMESPACE}:quick-postgres-snapshot
      ${OS_CMD} delete -f "${SCRIPT_PATH}/kubedb-postgresql/0.12/scc.yaml" || echo "."
    ;;
    app-kubedb-postgresql-create)
      ${OS_CMD} -n ${OS_NAMESPACE} create -f "${SCRIPT_PATH}/kubedb-postgresql/0.12/postgresql.yaml"
    ;;
    app-kubedb-postgresql-delete)
      ${OS_CMD} -n ${OS_NAMESPACE} delete -f "${SCRIPT_PATH}/kubedb-postgresql/0.12/postgresql.yaml"
    ;;
    app-kubedb-postgresql-dump-config)
      echo "--- pgadmin config ---"
      echo "pgAdmin user: admin"
      echo "pgAdmin password: admin"
      echo "postgresql user: $(${OS_CMD} get secrets -n ${OS_NAMESPACE} quick-postgres-auth -o jsonpath='{.data.\POSTGRES_USER}' | base64 -D)"
      echo "postgresql password: $(${OS_CMD} get secrets -n ${OS_NAMESPACE} quick-postgres-auth -o jsonpath='{.data.\POSTGRES_PASSWORD}' | base64 -D)"
      echo "host: quick-postgres.${OS_NAMESPACE}"
      echo "port: 5432"
      echo "maintenance database: postgres"
    ;;

    #
    # ---------- Istio / maistra ----------
    #
    maistra-patch-master)
      confirm "Run ansible script to patch master config?"
      export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i "${SCRIPT_PATH}/vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory" "${SCRIPT_PATH}/maistra/ansible-masters.yaml"
      confirm "Run ansible script to patch all nodes?"
      export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i "${SCRIPT_PATH}/vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory" "${SCRIPT_PATH}/maistra/ansible-nodes.yaml"
      ;;
    maistra-operator-deploy)
      ${OS_CMD} new-project istio-operator
      ${OS_CMD} new-project istio-system
      ${OS_CMD} -n istio-operator apply-f https://raw.githubusercontent.com/Maistra/istio-operator/maistra-0.10/deploy/maistra-operator.yaml
      ${OS_CMD} -n istio-system create -f "${SCRIPT_PATH}/maistra/control-plane.yaml"
      ;;
    maistra-uninstall)
      confirm "Delete maistra/istio oeprator and applications "
      ${OS_CMD}  -n istio-system delete -f "${SCRIPT_PATH}/maistra/control-plane.yaml"
      ${OS_CMD}  -n istio-operator delete -f https://raw.githubusercontent.com/Maistra/istio-operator/maistra-0.10/deploy/maistra-operator.yaml
      ${OS_CMD}  -n istio-system delete project istio-system
      ${OS_CMD}  -n istio-system delete project istio-operator
      ;;
    maistra-check)
      echo
      echo " --- Check operator ..."
      echo
      ${OS_CMD} -n istio-operator get pods-l name=istio-operator
      echo
      echo " --- Check control plane ..."
      echo
      ${OS_CMD} -n istio-system get controlplane/basic-install --template='{{range .status.conditions}}{{printf "%s=%s, reason=%s, message=%s\n\n" .type .status .reason .message}}{{end}}'
      echo
      echo " --- Open kiali ..."
      echo
      ROUTE=$(${OS_CMD} -n istio-system get routekiali -o jsonpath='{.spec.host}')
      echo "Kiali dashboard https://${ROUTE}"
      open "https://${ROUTE}"
      ;;
    maistra-example-book-info-deploy)
      # From https://maistra.io/docs/examples/bookinfo/
      ${OS_CMD} new-project bookinfo
      ${OS_CMD} -n bookinfo adm policy add-scc-to-user anyuid -z default
      ${OS_CMD} -n bookinfo adm policy add-scc-to-user privileged -z default
      ${OS_CMD} -n bookinfo apply -f https://raw.githubusercontent.com/Maistra/bookinfo/master/bookinfo.yaml
      ${OS_CMD} -n bookinfo apply -f https://raw.githubusercontent.com/Maistra/bookinfo/master/bookinfo-gateway.yaml
      ${OS_CMD} -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/release-1.1/samples/bookinfo/networking/destination-rule-all.yaml

      ;;
    maistra-example-book-info-check)
      GATEWAY_URL=$(${OS_CMD} -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
      open "http://${GATEWAY_URL}/productpage"
      ROUTE=$(${OS_CMD} -n istio-system get routekiali -o jsonpath='{.spec.host}')
      echo "Kiali dashboard https://${ROUTE}"
      open "https://${ROUTE}"
      ;;
    maistra-example-book-info-delete)
      ${OS_CMD} delete project bookinfo
      ;;

    # --- s2i python-web-server ---
    s2i-python-web-server-create)
      ${OS_CMD} -n "${OS_NAMESPACE}" create -f "${SCRIPT_PATH}/s2i-python-web-server/openshift.yaml"
      ;;
    s2i-python-web-server-delete)
      ${OS_CMD} -n "${OS_NAMESPACE}" delete -f "${SCRIPT_PATH}/s2i-python-web-server/openshift.yaml"
      ;;
    s2i-python-web-server-info)
      ${OS_CMD} -n "${OS_NAMESPACE}" describe -f "${SCRIPT_PATH}/s2i-python-web-server/openshift.yaml"
      ;;
    s2i-python-web-server-console)
      open "${OPENSHIFT_VAGRANT_CLUSTER_URL}/console/project/overview"
      ROUTE=$(${OS_CMD} -n ${OS_NAMESPACE} get route s2i-python-web-server -o jsonpath='{.spec.host}' )
      open "http://${ROUTE}"
      ;;


    # ---------- Openshift examples ----------
    #
    # --- django-deploy ---
    # https://github.com/openshift/origin/tree/v3.11.0/examples

    django-deploy)
      echo " * Start node example from git repo (use s2i)"
      ${OS_CMD} -n "${OS_NAMESPACE}" new-app -f "https://raw.githubusercontent.com/openshift/origin/release-${OPENSHIFT_VERSION}/examples/quickstarts/django-postgresql-persistent.json" -l name=django-example
      echo " * Follow build logs"
      ${OS_CMD} -n "${OS_NAMESPACE}" logs -f bc/nodejs-ex
      echo " * Expose route to outside"
      ${OS_CMD} -n "${OS_NAMESPACE}" expose svc/nodejs-ex
      ;;
    django-delete)
      # use label selector to delete
      echo " * Delete all objects"
      ${OS_CMD} -n "${OS_NAMESPACE}" delete all -l name=django-example
      ;;

    # From https://github.com/openshift/origin/blob/release-${OPENSHIFT_VERSION}/examples/quickstarts/nginx.json
    nginx-deploy)
      echo " * Start node example from git repo (use s2i)"
      ${OS_CMD} -n "${OS_NAMESPACE}" new-app -f "https://raw.githubusercontent.com/openshift/origin/release-${OPENSHIFT_VERSION}/examples/quickstarts/nginx.json" -l name=nginx-example
      echo " * Follow build logs"
      ${OS_CMD} -n "${OS_NAMESPACE}" logs -f bc/nginx-example
      echo " * Expose route to outside"
      ${OS_CMD} -n "${OS_NAMESPACE}" expose svc/nodejs-ex
      ;;
    nginx-delete)
      # use label selector to delete
      echo " * Delete all objects"
      ${OS_CMD} -n "${OS_NAMESPACE}" delete all -l name=nginx-example
      ;;

    deploy-local-storage)
      echo " * Build and deploy local storage template -> https://github.com/openshift/origin/tree/release-${OPENSHIFT_VERSION}/examples/storage-examples/host-path-examples"
      echo "TO DO ...."
      ;;

    -h | *)
      ${0}
      ;;
    esac
    shift
  done
}

parseCli "$@"
