# Rook

Deploy a rook cluster

- 1 node on worker
- 3 nodes on workers

## Run

See apps example in [os-vagrant.sh](./../../os-vagrant.sh)

## Object sore in dashboard

Check if user exist:

- `radosgw-admin user list`
  
Enable object store in dashboard:

- `radosgw-admin user modify --uid=my-user --system`
- `ceph dashboard set-rgw-api-user-id my-user`
- `ceph dashboard set-rgw-api-access-key <ACCESS_KEY>`
- `ceph dashboard set-rgw-api-secret-key <SECRET_KEY>`
- `ceph dashboard set-rgw-api-host rook-ceph-rgw-my-store.rook-ceph`
- `ceph dashboard set-rgw-api-ssl-verify False`
- `ceph dashboard set-rgw-api-port 8080`

## Versions

- OpenShift openshift-ansible-3.11.114-1 (k8s 1.11.0) + Rook v1.1.4 = flex volumes rbd and object store work
- CSI volumes require k8s 1.13 (probably OpenShift 4)
  
## Issues
