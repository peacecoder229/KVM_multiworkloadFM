yum groupinstall -y 'Development Tools'
cd /root

git clone https://github.com/axboe/fio 
cd fio/
make
cd -

git clone https://github.com/spdk/spdk
cd spdk/
git submodule update --init
./scripts/pkgdep.sh # to install the dependencies
./configure --with-fio=/root/fio
make
python3 dpdk/usertools/dpdk-hugepages.py -p 2M --setup 2048M
./scripts/setup.sh
cd -
