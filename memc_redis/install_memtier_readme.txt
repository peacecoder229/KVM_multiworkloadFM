#!/bin/bash
yum install memcached
yum install -y autoconf automake make gcc-c++
yum install -y pcre-devel zlib-devel libmemcached libevent-devel

git clone https://github.com/RedisLabs/memtier_benchmark.git
cd memtier_benchmark
autoreconf -ivf 
./configure
make
make install

echo "RUN memcached and memtier benchmark with following CMD"
echo "./mc_rds_sweep.sh <phy_core_range> <result_director> <no_of_memcached_instance> <no_of_connection_per_each_core>"
echo "Example ./mc_rds_sweep.sh 0-8 SPR_Memcache 1 16"

