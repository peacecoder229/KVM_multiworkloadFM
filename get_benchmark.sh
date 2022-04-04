#!/bin/bash

yum -y install fio

cd /root

wget http://cce-docker-cargo.sh.intel.com/docker_images/rn50.img.xz
scp -r root@10.165.100.51:/root/streeapp.tar .
cd -
