#!/bin/bash -ex

#
# Prepare a Deis-optimized AMI from a vanilla Ubuntu 12.04
#
# Instructions:
#
#   1. Create a server using the Ubuntu 12.04 LTS image,
#      performance1-2, 2GB performance server
#   2. SSH in as root with the password shown, then install the 3.8 kernel with:
#      apt-get update && apt-get install -yq linux-image-generic-lts-raring linux-headers-generic-lts-raring && reboot
#   3. After reboot is complete, SSH in and `uname -r` to confirm kernel is 3.8
#   4. Run this script (as root) to optimize the image for fast boot times
#   5. Create a new image from the server named "deis-base-image".
#   6. Distribute the image to other regions
#   7. Create/update your Deis flavors to use your new images
#

# Remove old kernel(s)
dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | xargs sudo apt-get -y purge

apt-get install fail2ban python-software-properties -y

# Add the Nginx repository key to our local keychain
# using apt-key finger you can check the fingerprint matches 573B FD6B 3D8F BC64 1079  A6AB ABF5 BD82 7BD9 BF62
curl http://nginx.org/keys/nginx_signing.key | apt-key add -

# Add the Nginx repository to our apt sources list
echo deb http://nginx.org/packages/ubuntu precise nginx > /etc/apt/sources.list.d/nginx-ppa.list

# Add the Docker repository key to your local keychain
# using apt-key finger you can check the fingerprint matches 36A1 D786 9245 C895 0F96 6E92 D857 6A8B A88D 21E9
curl https://get.docker.io/gpg | apt-key add -

# Add the Docker repository to your apt sources list.
echo deb https://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list

# upgrade to latest packages
apt-get update
apt-get dist-upgrade -yq

# install required packages
apt-get install lxc-docker-0.8.0 curl git inotify-tools make python-setuptools python-pip -yq

# wait for docker to start
while [ ! -e /var/run/docker.sock ] ; do
  inotifywait -t 2 -e create $(dirname /var/run/docker.sock)
done

# pull progrium/cedarish docker image
docker pull progrium/cedarish

# install chef 11.x deps
apt-get install -yq ruby1.9.1 ruby1.9.1-dev make
update-alternatives --set ruby /usr/bin/ruby1.9.1
update-alternatives --set gem /usr/bin/gem1.9.1

# clean and remove old packages
apt-get clean
apt-get autoremove -yq

# reset cloud-init
rm -rf /var/lib/cloud

# purge SSH authorized keys
rm -f /home/ubuntu/.ssh/authorized_keys
rm -f /root/.ssh/authorized_keys

# remove /etc/chef so contents can't intefere with
# node being converged (i.e. old keys)
rm -f /etc/chef/*

# purge /var/log
find /var/log -type f | xargs rm

# flush writes to block storage
sync
