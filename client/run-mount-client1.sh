#!/bin/bash
docker run --restart=always --name gfsm1 -v $(pwd)/scripts:/scripts --mount type=bind,source=/datavol,target=/datavol,bind-propagation=rshared -d --privileged=true --net=netgfs gluster/glusterfs-client /scripts/run.sh gfsc1
