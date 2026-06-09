#!/bin/sh
# Stop puppet services, uninstall package and remove directories

puppet_config_dir=/etc/puppetlabs/puppet

# Stop puppet services
sudo systemctl stop puppet 2>&1 | logger -t remove_puppet
sudo systemctl stop pxp-agent 2>&1 | logger -t remove_puppet
sudo systemctl stop mcollective 2>&1 | logger -t remove_puppet

# Uninstall package
centos_package=`rpm -qa | grep puppet-agent`
echo "centos_package = ${centos_package}" | logger -t remove_puppet
if [ -n "${centos_package}" ]
then 
  sudo yum erase -y puppet-agent 2>&1 | logger -t remove_puppet
fi

ubuntu_package=`dpkg --list | grep '^ii  puppet-agent'`
echo "ubuntu_package = ${ubuntu_package}" | logger -t remove_puppet
if [ -n "${ubuntu_package}" ]
then
  sudo apt-get remove -y puppet-agent 2>&1 | logger -t remove_puppet
fi

# Remove config directory
sudo rm -rf ${puppet_config_dir} 2>&1 | logger -t remove_puppet

