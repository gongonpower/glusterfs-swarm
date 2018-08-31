#!/bin/bash
docker run --restart=always --name gfsc1 -v /bricks:/bricks -v /etc/glusterfs:/etc/glusterfs:z -v /var/lib/glusterd:/var/lib/glusterd:z -v /var/log/glusterfs:/var/log/glusterfs:z -v /sys/fs/cgroup:/sys/fs/cgroup:ro --mount type=bind,source=/datavol,target=/datavol,bind-propagation=rshared -d --privileged=true --net=netgfs -v /dev/:/dev gluster/gluster-centos
