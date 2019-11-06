# Vagrant OpenShift cluster

Install ansible <https://docs.ansible.com/ansible/latest/index.html>

Install vagrant <https://www.vagrantup.com>

Install or upgrade required vagrant plugins:

- `vagrant-hostmanager`
- `vagrant-vbguest`

## Start cluster

- Edit [vagrant file](./Vagrantfile) to tune resources, memory and cpu
- (optional) Edit openshift [ansible inventory](./ansible/host-3-11-cluster.localhost)
- Run `vagrant up`
- Install OpenShift  with param `./os-vagrant.sh install-openshift`
- Open console `./os-vagrant.sh console`

See more task and commands in [os-vagrant.sh](./os-vagrant.sh)

## Notes

### Optimization

- Use NAT port forwarding because host-to-guest private network is slow

### Vagrant

- Vagrant supports ansible provisioner
- Vagrant generate an inventory files in `vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory`
- This inventory works from local terminal `export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory vagrant/ansible/ping.yml`

### Version tested

- OpenShift openshift-ansible-3.11.114-1 (k8s 1.11.0) + Rook v1.1.4 = flex volumes rbd and object store work

