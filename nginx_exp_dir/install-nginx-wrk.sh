yum install -y nginx
yum install -y numactl

git clone https://github.com/wg/wrk
cd wrk
make
cd ..
