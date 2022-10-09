yum groupinstall -y 'Development Tools'
pip3 install meson ninja pyelftools
yum install -y numactl-devel

cd /root

git clone https://github.com/DPDK/dpdk
cd /root/dpdk
meson build -Dexamples=l2fwd,l3fwd
ninja -C build
cd -
