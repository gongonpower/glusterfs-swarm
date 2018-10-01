#!/bin/bash
trap "umount /datavol;exit 0" SIGKILL SIGTERM SIGHUP SIGINT EXIT
while true; do
  mount.glusterfs $1:/gv0 /datavol
  if [ $? -eq 0 ]
  then
    break
  fi
  sleep 1
done
while true; do :; done
