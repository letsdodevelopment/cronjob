#!/bin/bash
NODES=$(oc get nodes -o name)
for NODE in $NODES; do
 oc debug $NODE -- chroot /host /bin/bash -c 'crictl images; crictl rmi --prune'
 echo $?
done;
