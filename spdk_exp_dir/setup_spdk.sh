cd /root


git clone https://github.com/axboe/fio 
cd fio/
make
cd -

git clone https://github.com/spdk/spdk
cd spdk/
git submodule update --init
./scripts/pkgdep.sh # to install the dependencies

# need to install ninja 1.8.2 or latest, otherwise getting error while building spdk
yum install -y wget
wget https://github.com/ninja-build/ninja/releases/download/v1.8.2/ninja-linux.zip
unzip -o ninja-linux.zip -d /usr/local/bin/

./configure --with-fio=/root/fio
make
python3 dpdk/usertools/dpdk-hugepages.py -p 2M --setup 2048M
./scripts/setup.sh
cd -
