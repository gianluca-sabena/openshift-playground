# Istio / Maistra

Install Istio / Maistra to OpenShift cluster with an operator <https://maistra.io/>

## Prepare

Patch openshift master `export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory examples/maistra/ansible-masters.yaml`