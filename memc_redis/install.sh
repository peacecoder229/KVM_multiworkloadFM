#!/bin/bash
yum install -y memcached
yum install -y autoconf automake make gcc-c++
yum install -y pcre-devel zlib-devel libmemcached libevent-devel
yum install -y numactl numactl-devel
yum install -y python3-pip
yum install -y git
pip3 install pandas
yum install -y openssl openssl-devel
yum install -y wget
yum install -y bc
echo "Librarys installed"

sleep 5

git clone https://github.com/RedisLabs/memtier_benchmark.git
cd memtier_benchmark
autoreconf -ivf 
./configure
make
make install
cd ..
echo "Memcached and Memtier installed"
sleep 3

echo "Installing redis-server"

#./install-redis.sh
wget http://download.redis.io/redis-stable.tar.gz
tar xvzf redis-stable.tar.gz
cd redis-stable
make
make install

echo "RUN memcached and memtier benchmark with following CMD"
echo "./mc_rds_sweep.sh <phy_core_range> <result_director> <no_of_memcached_instance> <no_of_connection_per_each_core> <protocol>"
echo "Example ./mc_rds_sweep.sh 0-8 SPR_Memcache 1 16 memcache_text"
echo "Example ./mc_rds_sweep.sh 0-8 SPR_Memcache 1 16 redis"

