#!/bin/bash
echo $$
trap 'trap - TERM; umount /datavol; kill -s TERM -- -$$' TERM
while true; do
  mount.glusterfs $1:/gv0 /datavol
  if [ $? -eq 0 ]
  then
    break
  fi
  sleep 1
done
tail -f /dev/null & wait

exit 0
