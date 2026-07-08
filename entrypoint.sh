#!/bin/bash

# START TEMPORARY SCRIPT

set -e

sed -i 's/TARGET_IP/'"$TARGET_IP"'/g' /root/.ssh/config

for i in $(ls /app | grep -oE 'level[0-9]')
  do
    ln -s /app/$i/Ressources/pass /app/l$(echo $i | tr -d 'level');
  done

for i in $(ls /app | grep -oE 'bonus[0-3]')
  do
    ln -s /app/$i/Ressources/pass /app/b$(echo $i | tr -d 'bonus');
  done

# END TEMPORARY SCRIPT

exec "$@"
