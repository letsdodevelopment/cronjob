#!/bin/bash
NODES=$(oc get nodes -o name)
for node in $NODES;
do
	echo $node
	oc debug $node -- chroot /host /bin/bash -xc 'crictl images ; crictl rmi --prune'
	echo $?
done;

