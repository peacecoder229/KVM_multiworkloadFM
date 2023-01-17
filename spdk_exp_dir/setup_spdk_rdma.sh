
yum install -y python3 net-tools

cd /root

git clone https://github.com/axboe/fio 
cd fio/
make
cd -

git clone https://github.com/spdk/spdk
cd spdk/
git submodule update --init
./scripts/pkgdep.sh -r # to install the dependencies

# need to install ninja 1.8.2 or latest, otherwise getting error while building spdk
yum install -y wget
wget https://github.com/ninja-build/ninja/releases/download/v1.8.2/ninja-linux.zip
unzip -o ninja-linux.zip -d /usr/local/bin/

# Build spdk with rdma
./configure --with-rdma
make
python3 dpdk/usertools/dpdk-hugepages.py -p 2M --setup 2048M
./scripts/setup.sh # Bind nvme drive with SPDK driver
cd -

ifconfig eth1 192.168.232.254 up
ip route add 192.168.232.0/24 dev eth1

# Generate ssh key for the VM
ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -P ""
