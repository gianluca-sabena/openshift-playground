# Rook

Deploy a rook cluster

- 1 node on worker
- 3 nodes on workers

## Run

See [openshift.sh](../../openshift.sh)

## Virtual box

Use `hostNetwork: true` in cluster.yaml, this REQUIRE to add scc

## Issues

- Replica 3 only works with old ceph v13 instead v14 see <https://github.com/rook/rook/issues/3140>
- operator timeout to mgr service, no osd service running: operator and mgr need to run on the same node, use label and placement (to be confirmed, no issue open)
- timeout mount volume for pod: flex volume folder must be set in [operator-openshift.yaml](./operator-openshift.yaml), see openshift docs <- Flex volume folder <https://docs.okd.io/3.11/install_config/persistent_storage/persistent_storage_flex_volume.html#flex-volume-installation>
- use at least 10 GB disc
