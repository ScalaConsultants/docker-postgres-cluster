#!/bin/bash -e

if [ "$DEBUG" = "1" ]; then
  set -x
fi

echo -e "$(sed '/\(master\|standby\)/d' /etc/hosts; echo -e "$MASTER_IP\tmaster\n$STANDBY_IP\tstandby")" > /etc/hosts

rm -f /etc/service/sshd/down && /etc/my_init.d/00_regen_ssh_host_keys.sh > /dev/nul 2>&1
/etc/init.d/ssh start

if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
fi

POSTGRES_HOME=$(grep postgres /etc/passwd | awk -F ':' '{ print $6 }')

if [ ! -f $POSTGRES_HOME/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -N '' -f $POSTGRES_HOME/.ssh/id_rsa
  cat $POSTGRES_HOME/.ssh/id_rsa.pub > $POSTGRES_HOME/.ssh/authorized_keys
  chmod 0700 $POSTGRES_HOME/.ssh
  chown -R postgres:postgres $POSTGRES_HOME/.ssh
fi

if [ ! -f ~/.ssh/known_hosts ]; then

  ssh-keyscan -H $(hostname) > ~/.ssh/known_hosts
  cp ~/.ssh/known_hosts $POSTGRES_HOME/.ssh/
  chown postgres:postgres $POSTGRES_HOME/.ssh/known_hosts
  sleep 120
fi
