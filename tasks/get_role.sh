#!/bin/sh
# Gets the current role from classes.txt
if [ -f /opt/puppetlabs/puppet/cache/state/classes.txt ] ; then
  sudo cat /opt/puppetlabs/puppet/cache/state/classes.txt | grep role::
fi

