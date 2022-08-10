# Setup: Two guest VMs in the same host communicating over OVS Bridge.
1. Download and install OpenVSwitch on the host.
   - yum -y install libcap-ng 
   - git clone https://github.com/openvswitch/ovs.git
   - cd ovs
   - Build the configure script: ./boot.sh
   - Configure, by default all files are installed in /usr/local: ./configure
   - make && make install

2. Start OVS
   - Create directory: mkdir -p /usr/local/etc/openvswitch
   - Create the OVS configuration database: ovsdb-tool create /usr/local/etc/openvswitch/conf.db vswitchd/vswitch.ovsschema 
   - Create directory: mkdir -p /usr/local/var/run/openvswitch   
   - Configure the created database: ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach --log-file
   - Initialize the database: ovs-vsctl --no-wait init
   - Start OVS daemon: ovs-vswitchd --pidfile --detach --log-file

3. Create OVS Bridge
   - Add a OVS bridge named ovs-br0: ovs-vsctl add-br ovs-br0 
   - Associate the bridge with an interface: ovs-vsctl add-port ovs-br0 <interface-name>
     Note: The interface should be up.
   - Check the setting: ovs-vsctl show 

4. Create two VMs with two interfaces each, one using Linux Bridge, another using OVS Bridge: 
   - Turn on Bridge and OVS-Bridge flag on vm_cloud-init.py:
     Networking={"SR-IOV":0,
            "Bridge":1,
            "OVS-Bridge:1"
            "PT":0,
            "None":0
            }
   - Spawn two VM: ./run.sh -A -T vm -S setup -C 16,16 -W redis,redis 
   - The VMs should have two interfaces, eth0 is connected to the Linux bridge and eth1 is connected to OVS-Bridge. Launch redis server in one VM using the ip address of eth1: redis-server --bind <IP-Address> --port <Port-No> --protected-mode no
   - Launch memtier benchmark from the other VM: memtier_benchmark -s <IP-Address> -p <Port-No>

# Setup: Two guest VMs in two hosts communicating over OVS Bridge. (TODO)

# Setup: Two guest VMs in two hosts communicating over OVS Bridge+DPDK. (TODO)
1. Download and install DPDK on machine A and machine B.
2. Install prerequisites and OVS on machine A.
   - yum -y install libcap-ng 
   - git clone https://github.com/openvswitch/ovs.git
   - cd ovs
   - Build the configure script: ./boot.sh
   - Configure, by default all files are installed in /usr/local: ./configure
   2.6.
3. Start OVS on machine A.
  3.1. Prepare directories.
  3.2. Start database server.
  3.3. Enable hugepages in kernel parameter.
  3.4. Mounting hugepages.
  3.5. Start OVS.
  3.6. Bind NIC to DPDK driver.
  3.7 Configure OVS bridge.
  3.8. Add flow configuration to OVS.
4. Start VM on machine A using the OVS bridge as networking.
5. Build and install DPDK inside the machine A VM and start L2 forwarder.
6. Start packet generator on Machine B.
