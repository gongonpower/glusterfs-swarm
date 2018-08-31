#!/bin/bash
while true; do
  mount.glusterfs $1:/gv0 /datavol
  if [ $? -eq 0 ]
  then
    break
  fi
  sleep 1
done
tail -f /etc/passwd > /dev/null
