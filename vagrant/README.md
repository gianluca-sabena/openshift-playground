# Vagrant

Install ansible <https://docs.ansible.com/ansible/latest/index.html>

Install vagrant <https://www.vagrantup.com>

Install or upgrade required vagrant plugins:

- `vagrant-hostmanager`
- `vagrant-vbguest`

## Vagrant cluster

- Edit [vagrant file](./Vagrantfile) to tune resources: memory and cpu
- (optional) Edit openshift [ansible inventory](./ansible/host-3-11-cluster.localhost)

Run `vagrant up`

## Prepare bastion node

Bastion node is the server where ansible installation scripts run

- Vagrant supports ansible provisioner
- Vagrant generate an inventory files in `vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory`
- This inventory works from local terminal `export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory vagrant/ansible/ping.yml`

## Install cluster

Use [openshift.sh](../openshift.sh) with param `./openshift.sh vagrant-install-openshift`

First **ssh login to bastion (master)** server `vagrant ssh okd-master-01.vm.local`

Run This steps from bastion (master) server

- **IMPORTANT!** sudo `sudo su`
- `cd /opt/openshift-ansible`
- `git status` check if git tag is `openshift-ansible-3.11.114-1`
- test inventory `ansible-playbook -i /opt/host-3-11-cluster.localhost /opt/ansible/ping.yml`
- install openshift prerequisites `ansible-playbook -i /opt/host-3-11-cluster.localhost /opt/openshift-ansible/playbooks/prerequisites.yml`
- install openshift cluster `ansible-playbook -i /opt/host-3-11-cluster.localhost /opt/openshift-ansible/playbooks/deploy_cluster.yml`
- create user admin `oc create user admin && oc adm policy add-cluster-role-to-user cluster-admin admin`
- uninstall `ansible-playbook -i /opt/host-3-11-cluster.localhost /opt/openshift-ansible/playbooks/adhoc/uninstall.yml`

Open web console at <https://okd-master-01.vm.local:8443>

Use helper script [openshift.sh](../openshift.sh) for common tasks: login, run example, ...

## Notes

- Tested with `openshift-ansible-3.11.114-1`
- Add/fix nfs example <https://docs.okd.io/3.11/install/configuring_inventory_file.html#configuring-oab-storage>