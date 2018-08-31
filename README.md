# Using glusterfs docker container with docker swarm
Since docker swarm does not allow container with privilege to run, this cause problem when the container needs to mount a glusterfs volume to use inside the container. To overcome this limitation, below approach is developed.

The approach principle is that run glusterfs container as a file repository. then run a middle man container which is used to initiate to connect to glusterfs repo container and expose the content to a linux shared directory. Finally docker swarm run a user application container with a volume connect to the shared directory. 


## Prerequisite
1. os : centos7
2. docker swarm with 3 nodes: at least 17.x (i am using 18.06.1-ce, build e68fc7a for this setup)

## Step 1: create directories
i am using docker container "gluster/gluster-centos" image.(https://github.com/gluster/gluster-containers). refer the step guide of the readme of the container, the below three directory are needed to create manually first.

- /etc/glusterfs
- /var/lib/glusterd
- /var/log/glusterfs

furthermore, the below two directories are also needed to create manually first for this setup:
- /bricks/brick1/gv0  (the actual location where glusterfs store files. It is used only by glusterfs container.)
- /datavol  (the access point to expose repoistory content, It is used by user application or container to access.)

or issue below script to do together
```
create-dir.sh
```

## Step 2: create docker network
In any one manager node of the docker swarm, issue command:
```
docker network create -d overlay --attachable netgfs
```
"-d overlay" option means container can communication across different nodes.
"--attachable" option means that overlay network is restricted to be used by swarm managed container by default. "attachable" option allow individaul container to use the overlay network also.

## Step 3: mount directory at host level first
at all the 3 nodes, issue my-temp-mount.sh to mount the /datavol as the share folder
```
my-temp-mount.sh
```


Reference:
- [Improving the Linux mount utility](http://dirkgerrits.com/publications/mount.pdf)
- (https://stackoverflow.com/questions/46359255/how-to-mount-gluster-volume-to-host-folder-in-docker)


## Step 4: run glusterfs container in each node
Since docker swarm does not allow to run any container with priviledge, we cannot use docker swarm to deploy the glusterfs container. we need to "docker run" to run each container one by one in each host

The glusterfs container image used is the official glusterfs image (https://hub.docker.com/r/gluster/gluster-centos/)

At docker node 1 :
```
run-gfs-srv1.sh
```
At docker node 2 :
```
run-gfs-srv2.sh
```
At docker node 3 :
```
run-gfs-srv3.sh
```
### Tips : Why not use docker-compose yml format?
When using yml format to run a container, the container name will be the format "xxx_yyy". The name has an undersore inside. glusterfs treats this name as invalid and refuse to perform any action e.g.(gluster peer probe gfsc1). The only way is used docker run to create a container with the name we wanted.


## Step 5: join the 3 nodes to cluster and create  glusterfs volume
enter any one glusterfs container to join nodes to the gfs cluster and then create glusterfs volume.
the main commands we used is as below:
```
gluster peer probe gfsc2
gluster peer probe gfsc3
gluster volume create gv0 replica 3 gfsc1:/bricks/brick1/gv0 gfsc2:/bricks/brick1/gv0 gfsc3:/bricks/brick1/gv0
gluster volume start gv0
```
e.g.
at node1

```
docker exec -it gfsc1 bash

[root@fa5a2c64a2d1 /]# ping gfsc2
PING gfsc2 (10.0.5.6) 56(84) bytes of data.
64 bytes from 27ff822548dd.netgfs (10.0.5.6): icmp_seq=1 ttl=64 time=0.411 ms
64 bytes from 27ff822548dd.netgfs (10.0.5.6): icmp_seq=2 ttl=64 time=0.269 ms
64 bytes from 27ff822548dd.netgfs (10.0.5.6): icmp_seq=3 ttl=64 time=0.370 ms^C
--- gfsc2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2000ms
rtt min/avg/max/mdev = 0.269/0.350/0.411/0.059 ms
[root@fa5a2c64a2d1 /]# ping gfsc3
PING gfsc3 (10.0.5.7) 56(84) bytes of data.
64 bytes from gfsc3.netgfs (10.0.5.7): icmp_seq=1 ttl=64 time=0.421 ms
64 bytes from gfsc3.netgfs (10.0.5.7): icmp_seq=2 ttl=64 time=0.279 ms
^C
--- gfsc3 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1000ms
rtt min/avg/max/mdev = 0.279/0.350/0.421/0.071 ms
[root@fa5a2c64a2d1 /]# gluster peer probe gfsc2
peer probe: success.
[root@fa5a2c64a2d1 /]# gluster peer probe gfsc3
peer probe: success.
[root@fa5a2c64a2d1 /]# gluster pool list
UUID                                    Hostname        State
247cdbae-5891-4b8d-8456-61ffef136bd2    gfsc2           Connected
8dfc5fbd-9259-4810-a8f6-47ddf6376760    gfsc3           Connected772e7545-51f4-4680-87f2-b337a6a6853d    localhost       Connected
[root@fa5a2c64a2d1 /]# gluster peer status
Number of Peers: 2

Hostname: gfsc2
Uuid: 247cdbae-5891-4b8d-8456-61ffef136bd2
State: Peer in Cluster (Connected)

Hostname: gfsc3
Uuid: 8dfc5fbd-9259-4810-a8f6-47ddf6376760
State: Peer in Cluster (Connected)
[root@fa5a2c64a2d1 /]# gluster volume create gv0 replica 3 gfsc1:/bricks/brick1/gv0 gfsc2:/bricks/brick1/gv0 gfsc3:/bricks/brick1/gv0
volume create: gv0: success: please start the volume to access data
[root@fa5a2c64a2d1 /]# gluster volume start gv0
volume start: gv0: success
[root@fa5a2c64a2d1 /]# gluster volume info

Volume Name: gv0
Type: Replicate
Volume ID: 75dc7b42-a16d-419f-9721-8b8fa92389d3
Status: Started
Snapshot Count: 0
Number of Bricks: 1 x 3 = 3
Transport-type: tcp
Bricks:Brick1: gfsc1:/bricks/brick1/gv0
Brick2: gfsc2:/bricks/brick1/gv0
Brick3: gfsc3:/bricks/brick1/gv0
Options Reconfigured:
transport.address-family: inet
nfs.disable: on
[root@fa5a2c64a2d1 /]# gluster volume status
Status of volume: gv0
Gluster process                             TCP Port  RDMA Port  Online  Pid
------------------------------------------------------------------------------
Brick gfsc1:/bricks/brick1/gv0              49152     0          Y       186
Brick gfsc2:/bricks/brick1/gv0              49152     0          Y       134
Brick gfsc3:/bricks/brick1/gv0              49152     0          Y       134
Self-heal Daemon on localhost               N/A       N/A        Y       209
Self-heal Daemon on gfsc3                   N/A       N/A        Y       157
Self-heal Daemon on gfsc2                   N/A       N/A        Y       157

Task Status of Volume gv0
------------------------------------------------------------------------------
There are no active volume tasks
```

## Step 6: mount volume and add some file:
Still remain in the gfsc1 container, issue the below command:
```
[root@fa5a2c64a2d1 /]# mount.glusterfs gfsc1:/gv0 /datavol
WARNING: getfattr not found, certain checks will be skipped..
[root@fa5a2c64a2d1 /]# ls /datavol
[root@fa5a2c64a2d1 /]# cd /datavol
[root@fa5a2c64a2d1 datavol]# echo apple > test1.txt
[root@fa5a2c64a2d1 datavol]# ls
test1.txt
[root@fa5a2c64a2d1 datavol]# exit
exit
```
At node level, issue the below command to verify the content of the shared volume (datavol) is seen at node level and container level:
```
[root@qry-01-dev glusterfs]# ls /datavol
test1.txt
```

## Step 7: Automatic mount volume
at Step3 and Step6, we need to mount the volume at node level and container level manually. The action will be lost after system reboot. We need to make these step automatically start after reboot.

for step 3, we can use /etc/fstab. For step 6, we use another container to do.

### For step 3:
at each node, att "/datavol                /datavol                none    bind,make-shared        0 0" to fstab. it looks below:
```
[root@qry-01-dev etc]# cat fstab

/dev/mapper/cl-root     /                       xfs     defaults        0 0
UUID=4f5bd15f-91f0-4484-b73d-f7a76aa1c5a9 /boot                   xfs     defaults        0 0
/dev/mapper/cl-swap     swap                    swap    defaults        0 0
/datavol                /datavol                none    bind,make-shared        0 0
```
after modify the fstab, it is suggested to reboot the system to apply the setting and prepare for the next step:

Reference:
- [Improving the Linux mount utility](http://dirkgerrits.com/publications/mount.pdf)

### For step 6:
we use another container as a middle man container to mount the mount the volume when the this container start
at each node, run corresponding run-mount-client.sh script. e.g. node 1 run run-mount-client1.sh, node 2 run run-mount-client2.sh ...
```
[root@qry-01-dev glusterfs]# cd client/
[root@qry-01-dev client]# ls
run-mount-client1.sh  run-mount-client2.sh  run-mount-client3.sh  scripts
[root@qry-01-dev client]# ./run-mount-client1.sh
ad08683f568b461ca1563a3e3baa4572e8461689ff75af025f027804f07afc57
[root@qry-01-dev client]# ls /datavol
test1.txt
[root@qry-01-dev client]#
```
When the container startup, it will run a script which will try to connect to glusterfs conatiner (here is gfsc1, gfsc2 or gfsc3) to mount volume. if failed, it will sleep one second and then try again until success.

## Step 8: run docker swarm app to use the share volume:
go to the folder "test-app" and deploy a docker swarm app to test:

```
[root@qry-01-dev glusterfs]# cd test-app/
[root@qry-01-dev test-app]# ./deploy.sh
Creating network testgfs_default
Creating service testgfs_busybox
[root@qry-01-dev test-app]# docker exec -it testgfs_busybox.t8iqz390vin6yuaw7imw3pk4y.pnmwdjqqwz1yso5q7mpbcg7ws sh
/ # ls /data
test1.txt
```

## How to unmount the share directory (e.g. /datavol)
At the desired node, stop the middle man container and then issue umount command.

e.g. at node1 
```
docker stop gfsm1
umount /datavol
```
