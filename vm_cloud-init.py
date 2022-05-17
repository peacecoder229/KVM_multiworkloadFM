import collections
import os
import random
import sys
import subprocess
import re
import copy
from inspect import currentframe, getframeinfo
import inspect
import argparse
import requests
import pkg_check
from inspect import currentframe

def get_linenumber():
    cf = currentframe()
    return cf.f_back.f_lineno

#sriov nic devices
#P_PORT = {"ens11f0", "ens28f0", "ens11f1", "ens28f1"}  #local network
P_PORT = {"enp1s0"}  #local network
C_PORT = {"enp217s0f1", "enp37s0f1"}  #corporate ports 
DRY_RUN=0
def get_cpu_pool(socket):
    print("get_cpu_pool. socket: ", socket)
    cmd = f"numactl -H | grep 'node {socket} cpus'"
    res = subprocess.run(cmd,shell=True,check=False,stdout=subprocess.PIPE,universal_newlines=True)
    print("get_cpu_pool. ", res.stdout)
    pool1 = res.stdout.split(":")[1].split()
    if getsysinfo().ht:
        pool2 = []
        while len(pool1) > 0:
            pool2.append(pool1.pop())
            pool2.append(pool1.pop(int(len(pool1)/2)))
        return pool2
    return pool1

def get_ssh_key():
    if os.path.isfile(os.getenv("HOME")+"/.ssh/id_rsa.pub"):
        with open(os.getenv("HOME")+"/.ssh/id_rsa.pub") as f:
            rsa_key = f.read()
    else:
        try:
            print("ssh key not exist. trying to create ssh pair")
            cmd = f"ssh-keygen -t rsa -f {os.getenv('HOME')}/.ssh/id_rsa -q -N \"\""
            res = subprocess.run(cmd,shell=True,check=True,stdout=subprocess.PIPE)
        except:
            sys.exit("ssh key generation failed. please generate ssh key pair. Exiting...")
        else:
            return get_ssh_key()
    return rsa_key 
rsa_key = get_ssh_key()



QAT_VF_SOCKET = collections.OrderedDict()
vm_storage = r"vmimages2"
path_prefix = r"/home"

def download_qcow(image,path="%s/vmimages" % (path_prefix)):
    if not os.path.exists(path):
        os.makedirs(path)
        #os.makedirs("%s/vmimages2" % (path_prefix))
    print(f"trying to download the image {image} to {path}")
    # golden images are in JF5300-B11A235T , if ip is not working, just fix it 
    url = "http://10.165.84.177/images/" + image
    name = path+"/"+image
    try:
        res = requests.head(url)
        if not res.ok:
            sys.exit(f"{url} for {image} not found. Please try downloading the image manually. Exiting")
        with open(name, 'wb') as f:
            response = requests.get(url, stream=True)
            total = response.headers.get('content-length')
            if total is None:
                f.write(response.content)
            else:
                downloaded = 0
                total = int(total)
                print("Downloading image of size {} GB".format(total/(1024*1024)))
                for data in response.iter_content(chunk_size=max(int(total/1000), 1024*1024)):
                    downloaded += len(data)
                    f.write(data)
                    done = int(50*downloaded/total)
                    sys.stdout.write('\r[{}{}]'.format('█' * done, '.' * (50-done)))
                    sys.stdout.flush()
        sys.stdout.write('\n')


        # with open(name,'wb') as f:
        #     f.write(res.content)
    except:
        sys.exit(f"{image} download from {url} failed. Please try downloading the image manually. Exiting")
    else:
        print(f"{image} downloaded successfully in {path}")


#pass through devices (NIC, GPU, NVME),
PT_Device = {
    "GPU":  ["pci_0000_49_00_0"],
    "NIC":  ["pci_0000_38_00_0","pci_0000_38_00_1"],
    "NVME": [ "pci_0000_04_00_0"]
}

# what type of networking do you want for the vm ?
Networking={"SR-IOV":0,
            "Bridge":1,
            "PT":0,
            "None":0
            }

# to get system information , memory and cpu .
class getsysinfo():
    def unique(self, list1):
        # insert the list to the set
        list_set = set(list1)
        # convert the set to the list
        unique_list = (list(list_set))
        return unique_list

    def __init__(self):
        self.temp_dict = {}
        self.numa_node_memory = {}
        self.numa_node_cpus = {}

        with open("/sys/devices/system/node/online", "r") as n:
            nodes = n.read()
            nodes = nodes.split('-', 1)
            nodes =  int(nodes[1]) + 1 if len(nodes) > 1 else int(nodes[0]) + 1 
            self.num_numa_nodes = nodes
        for node in range(int(self.num_numa_nodes)):
            for meminfo in open(
                    "/sys/devices/system/node/node{}/meminfo".format(node),
                    "r"):
                #print(meminfo)
                memtotal = re.findall("MemTotal:\s+\d{0,9}", meminfo)
                if memtotal:
                    break
            #print (node,memtotal)
            memtotal = memtotal[0].split(':', 1)
            memtotal = int(memtotal[1])
            self.numa_node_memory[node] = memtotal
            with open("/sys/devices/system/node/node{}/cpulist".format(node),
                      "r") as f:
                cpu_list = f.read()
                self.numa_node_cpus[node] = cpu_list.strip("\n")

        with open("/sys/devices/system/cpu/present", "r") as f:
            cpus = f.read()
            cpus = cpus.split('-', 1)
            cpus = int(cpus[1]) + 1
            self.num_cores = cpus
        with open("/proc/cpuinfo", "r") as f:
            cpuinfo = f.read()
            socketid = re.findall("physical id\s+:\s+\d{0,9}", cpuinfo)
            cores_per_socket = re.findall("cpu cores\s+:\s+\d{0,9}", cpuinfo)
            #unique_numbers = list(set(socketid))
            cores_per_socket = list(set(cores_per_socket))
            cores_per_socket = cores_per_socket[0].split(':', 1)
            self.cores_per_socket = int(cores_per_socket[1])
            #print(unique_numbers, cores_per_socket)
            #print(socketid)
            sockets = self.unique(socketid)
            num_core_per_socket_dict = {i: socketid.count(i) for i in sockets}
            #print(num_core_per_socket_dict)
            for sid in socketid:
                self.temp_dict[sid] = 1
                self.num_core_per_socket = num_core_per_socket_dict[sid]
            self.num_sockets = len(self.temp_dict)
            #print("number of core per cpu = ", num_core_per_socket)
            #if (num_core_per_socket / cores_per_socket == 2.0):ht_on=True
            self.ht = True if (self.num_core_per_socket /
                               self.cores_per_socket == 2.0) else False
            self.num_threads_per_core = int(self.num_core_per_socket /
                                            self.cores_per_socket)


#how many vm's do you want on each socket ? if needed, add SOCKET2 and SOCKET3 for 4-socket system , the sriov devices will be assigned local to cpu


Tile_Map = {
    "SOCKET0": {
        "REDIS": 0,
        "MLC": 0,
        "FIO": 0,
        "IPERF": 0,
        "CPU_INFERENCE": 0,
        "GPU_INFERENCE": 0,
        "SPDK": 0,
        "QAT": 0,
        "SGX": 0,
        "SPEC":0,
        "5G" :0
    },
    
    "SOCKET1": {
        "REDIS": 0,
        "MLC": 0,
        "FIO": 0,
        "IPERF": 0,
        "CPU_INFERENCE": 0,
        "GPU_INFERENCE": 0,
        "SPDK": 0,
        "QAT": 0,
        "SGX": 0,
        "SPEC":0,
        "5G":0
    }
}

# each vm resources. NODE variable is not used anywhere for now

Tile_Resource = {
    "REDIS": {
        "VCPU": 2,
        "MEMORY": 4

    },
    "QAT": {
        "VCPU": 2,
        "MEMORY": 4,
        "IMG": "qat-golden-images.qcow2"

    },
    "SGX": {
        "VCPU": 56,
        "MEMORY": 250

    },
    "MLC": {
        "VCPU": 56,
        "MEMORY": 250

    },
    "FIO": {
        "VCPU": 4,
        "MEMORY": 8,
        "IMG": "cpu_inference_golden_vmimage.qcow2"

    },
    "IPERF": {
        "VCPU": 6,
        "MEMORY": 16

    },
    "CPU_INFERENCE": {
        "VCPU": 112,
        "MEMORY": 12

    },
    "GPU_INFERENCE": {
        "VCPU": 8,
        "MEMORY": 20

    },
    "SPDK": {
        "VCPU": 8,
        "MEMORY": 12

    },
    "SPEC": {
        "VCPU": 4,
        "MEMORY": 4,
        "IMG": "spec-golden-image.qcow2"

    },
    "5G": {
        "VCPU": 20,
        "MEMORY": 40,
        "IMG": "cpu_inference_golden_vmimage.qcow2"
    }
    
}

#vm tile count start
EXEC_TASKS = {
    "REDIS": 1,
    "MLC": 1,
    "FIO": 1,
    "IPERF": 1,
    "CPU_INFERENCE": 1,
    "GPU_INFERENCE": 1,
    "SPDK": 1,
    "QAT": 1,
    "SGX": 1,
    "SPEC": 1,
    "5G" :1
}



# CMD_FORMAT = "virt-install -n tile%02d-%s -r 24576 --vcpus=8 --os-type=linux --os-variant=rhel6 --accelerate " \
#             "--disk path=/opt/vmimages2/dbserver01.img,format=raw,bus=virtio,cache=writeback --import  " \
#             "--nonetworks  --host-device=%s --noautoconsole"

CMD_FORMAT = "virt-install -n tile%02d-%s -r 24576 --vcpus=8 --os-type=linux --os-variant=rhel6 --accelerate " \
             "--disk path=/opt/vmimages2/%sserver%02d.img,format=raw,bus=virtio,cache=writeback --disk CI_ISO.iso,device=cdrom --import  " \
             "--nonetworks  --host-device=%s --host-device=%s --noautoconsole --nographics"

ASSIGN_RANDOM_PORTS = False
MAX_VMS = getsysinfo().num_cores
print(f"max num of VMs is {MAX_VMS}")
seed = random.randrange(sys.maxsize)

V_PORT = collections.OrderedDict()
CORP_PORT = collections.OrderedDict()

ip_count = 0
ip_sub = 123

CPUS_PER_VM = []
WORKLOAD_PER_VM = []
CPU_AFFINITY = False

def get_qat_vf():

    print("------------------------get_qat_vf()-----------------------------")

    cmd = ['adf_ctl', 'status']
    try:
        popen = subprocess.Popen(cmd, stdout=subprocess.PIPE, universal_newlines=True)
    except:
        sys.exit("qat driver is not installed. try to install amnually.Exiting...")
    temp_dict = {}
    qat_vf_dict = {}

    for line in iter(popen.stdout.readline, ''):
        qat_dev = ""
        vf_name = ""

        if ("qat_dev" not in line):
            continue

        line = line.strip('\n')

        vf_name, rest_line = line.split('-', 1)

        rest_line = re.sub('#', "", rest_line)

        qat_dev = re.split(',|-', rest_line)

        for item in qat_dev:
            if (not item):
                continue

            key, value = item.split(':', 1)
            key = re.sub(' ', "", key)
            value = re.sub(' ', "", value)

            if (key == "type" or key == "inst_id" or key == 'node_id'
                    or key == 'bsf'):
                temp_dict[key] = value
        if temp_dict:
            qat_vf_dict[vf_name] = copy.deepcopy(temp_dict)
            temp_dict.clear()

    for k, v in qat_vf_dict.items():
        if (not v):
            continue
        vf_device = v["bsf"]
        vf_device = vf_device.replace(":", "_").replace(".", "_")
        vf_device = "pci_" + vf_device
        if (v["type"] != "4xxxvf"):
            continue
        Numa_Node = "SOCKET%s" % (v["node_id"])

        #QAT_VF_SOCKET0[Numa_Node]=(vf_device)
        if Numa_Node in QAT_VF_SOCKET:
            QAT_VF_SOCKET[Numa_Node].append(vf_device)
        else:
            QAT_VF_SOCKET[Numa_Node] = [vf_device]

    print("-------------------------END.. get_qat_vf().......................")


def get_vports():
    COUNT = 0
    #print("-------------------------started get_vports()............................")
    for P_Name in P_PORT:
        # key="PORT%d"%(COUNT)
        # V_PORT[key]=[]
        print("P_Name =", P_Name)
        # for sriov_numvfs in open(
        #         "/sys/class/net/%s/device/sriov_numvfs" % P_Name, "r"):
        #     sriov_numvfs = (int)(sriov_numvfs)
        #     print("sriov_numvfs=", sriov_numvfs)
        
        try:
           with open("/sys/class/net/{}/device/sriov_numvfs".format(P_Name),"r") as f:

                sriov_numvfs = f.read()
                sriov_numvfs = (int)(sriov_numvfs)
                print("sriov_numvfs=", sriov_numvfs)

                for vfs in range(0, sriov_numvfs, 1):
                    path = "/sys/class/net/%s/device/virtfn%d" % (P_Name, vfs)
                    link_path = (os.readlink(path).replace("../", ""))
                    link_path = "pci_" + \
                    link_path.replace(":", "_").replace(".", "_")
                    #print(link_path)
                    numa_path = "/sys/class/net/%s/device/numa_node" % (P_Name)
                    Numa_Node = open(numa_path, "r").readline().replace("\n", "")
                    #print("Numa_Node=====",Numa_Node)
                    Numa_Node = "SOCKET%s" % (Numa_Node)
                    # if V_PORT.has_key(Numa_Node):
                    if Numa_Node in V_PORT:
                        V_PORT[Numa_Node].append(link_path)
                    else:
                        V_PORT[Numa_Node] = [link_path]
        except:
            sys.exit("the ethernet device {} is not present ".format(P_Name))
        COUNT += 1
    #print("--------------------------finished get_vports funciton..............................")


def get_cports():

    C_COUNT = 0

    for C_Name in C_PORT:
        # print("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
        # key="PORT%d"%(COUNT)
        # V_PORT[key]=[]
        #print("C_Name =", C_Name)
        for sriov_numvfs in open(
                "/sys/class/net/%s/device/sriov_numvfs" % C_Name, "r"):
            sriov_numvfs = (int)(sriov_numvfs)
            #print("sriov_numvfs=", sriov_numvfs)

            for vfs in range(0, sriov_numvfs, 1):
                path = "/sys/class/net/%s/device/virtfn%d" % (C_Name, vfs)
                link_path = (os.readlink(path).replace("../", ""))
                link_path = "pci_" + \
                    link_path.replace(":", "_").replace(".", "_")
                #print(link_path)
                numa_path = "/sys/class/net/%s/device/numa_node" % (C_Name)
                Numa_Node = open(numa_path, "r").readline().replace("\n", "")
                #print(Numa_Node)
                Numa_Node = "PORT%s" % (Numa_Node)
                # if V_PORT.has_key(Numa_Node):
                if Numa_Node in CORP_PORT:
                    CORP_PORT[Numa_Node].append(link_path)
                else:
                    CORP_PORT[Numa_Node] = [link_path]
        C_COUNT += 1

def is_vm_available():
    total = 0
    for _port in sorted(Tile_Map.keys()):
        total += sum(Tile_Map.get(_port).values())
    if total > MAX_VMS:
        print("total > max")
        return False
    else:
        return True

def create_iso(iso_name, tile_no, tile):
    os.system("mkdir -p /{}/iso_test".format(vm_storage))
    print(f"create_iso(): mkdir -p /{vm_storage}/iso_test")

    global ip_count
    global ip_sub

    if ip_count > 254:
        ip_count = 0
        ip_sub = ip_sub + 1

    ip_count = ip_count + 1

    ip = "192.168.{}.{}".format(ip_sub, ip_count)

    print("tile = %s \t ip= %s" % (tile, ip))

    network_config_file = open("/{}/iso_test/network-config".format(vm_storage), "w")

    network_config_file.write('''
version: 2
ethernets:
    id0:
        match:
            name: enp*
        match:
            driver: iavf
        addresses: [%s/23,]
        gateway4: %s
        dhcp4: false
    
    id1:
        match:
            driver: virtio_net
        dhcp4: true
    
''' % (ip, ip))

    meta_data_file = open("/{}/iso_test/meta-data".format(vm_storage), "w")
    meta_data_file.write('''
instance-id: %s
local-hostname: %s
dsmode: local
''' % (iso_name, iso_name))
    user_data_file = open("/{}/iso_test/user-data".format(vm_storage), "w")
    user_data_file.write('''
#cloud-config
preserve_hostname: false
hostname: %s
lock-passwd: false
password: $6$rounds=4096$VI0AQ/nbS5fSWoC0$aVuV5VWp5xp0LPsM4l3pcom7FcrYCJQZaPzIBwm2bk84VE54flRusvcEOWv/Bh3YiUWCo8.TEQW5kl8MgYqxm/
chpasswd:
  expire: false
fqdn: %s.jf.intel.com


    

# Remove cloud-init when finished with it
runcmd:
  - [ apt, -y, remove, cloud-init ]
  - 'uuidgen > /etc/machine-id' 
  - 'reboot'
# Configure where output will go
output: 
  all: ">> /var/log/cloud-init.log"


# configure interaction with ssh server
ssh_svcname: ssh
ssh_deletekeys: True
ssh_genkeytypes: ['rsa', 'ecdsa']

# Install my public ssh key to the first user-defined user configured 
# in cloud.cfg in the template (which is centos for CentOS cloud images)

users: 
    - default
    - name: root
      lock-passwd: false
      password: $6$rounds=4096$VI0AQ/nbS5fSWoC0$aVuV5VWp5xp0LPsM4l3pcom7FcrYCJQZaPzIBwm2bk84VE54flRusvcEOWv/Bh3YiUWCo8.TEQW5kl8MgYqxm/
      ssh-authorized-keys: 
        - %s    
''' % (iso_name, iso_name, rsa_key))

    #cmd = "-output /vmimages/%s.iso  /vmimages/user-data /vmimages/meta-data /vmimages/network-config" % (
    #    iso_name)
    #cmd ="ls -lrt"
    user_data_file.flush()
    meta_data_file.flush()
    network_config_file.flush()
    os.system("sleep 1")
    os.system("ls /{}/iso_test".format(vm_storage))
    os.system("cat /{}/iso_test/user-data".format(vm_storage))
    os.system("cat /{}/iso_test/meta-data".format(vm_storage))
    os.system("cat /{}/iso_test/network-config".format(vm_storage))
    os.system(
        "mkisofs -input-charset=utf-8 -output /%s/%s.iso -volid cidata -joliet -rock  /%s/iso_test/ >>iso.log"
        % (vm_storage, iso_name, vm_storage))
    os.system("rm /{}/iso_test/user-data".format(vm_storage))
    os.system("rm /{}/iso_test/meta-data".format(vm_storage))
    os.system("rm /{}/iso_test/network-config".format(vm_storage))
    if ("qat" in iso_name):
        print("using qat golden image ")
        image_name = Tile_Resource.get('QAT').get('IMG')
        if not os.path.isfile(f"%s/vmimages/{image_name}" % (path_prefix)):
            download_qcow(image_name)
        os.system("cp %s/vmimages/qat-golden-images.qcow2 %s/%s/%s.qcow2" %
                  (path_prefix, path_prefix, vm_storage,iso_name))
    elif ("spec" in iso_name):
        print("using SPEC golden image ")
        
        image_name = Tile_Resource.get('SPEC').get('IMG')
        if not os.path.isfile(f"%s/vmimages/{image_name}" % (path_prefix)):
            download_qcow(image_name)
        os.system("cp %s/vmimages/spec-golden-image.qcow2 %s/%s/%s.qcow2" %
                  (path_prefix, path_prefix, vm_storage,iso_name))
    else:
        print("using  redis  golden image ")

        os.system("cp %s/vmimages/golden_vmimage.qcow2 %s/%s/%s.qcow2" %
                  (path_prefix, path_prefix, vm_storage,iso_name))

    #print("HelloXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
    #p = subprocess.run(["genisoimage",cmd], universal_newlines=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    #print("the commandline is {}".format(p.args))

def create_iso_centos(iso_name, tile_no, tile):
    os.system("mkdir -p {}/{}/iso_test".format(path_prefix, vm_storage))
    print(f"create_iso_centos(): mkdir -p {path_prefix}/{vm_storage}/iso_test")
    
    global ip_count
    global ip_sub

    if ip_count > 254:
        ip_count = 0
        ip_sub = ip_sub + 1

    ip_count = ip_count + 1

    ip = "192.168.{}.{}".format(ip_sub, ip_count)

    print("tile = %s \t ip= %s" % (tile, ip))

    network_config_file = open(
        "{}/{}/iso_test/network-config".format(path_prefix, vm_storage), "w")

    network_config_file.write('''
version: 2
ethernets:
    eth1:
        match:
            name: enp*
        match:
            driver: iavf
        addresses: [%s/23,]
        gateway4: %s
        dhcp4: false

    eth0:
        match:
            driver: virtio_net
        dhcp4: true
    
''' % (ip, ip))

    meta_data_file = open("{}/{}/iso_test/meta-data".format(path_prefix, vm_storage), "w")
    meta_data_file.write('''
instance-id: %s
local-hostname: %s
dsmode: local
''' % (iso_name, iso_name))
    user_data_file = open("{}/{}/iso_test/user-data".format(path_prefix, vm_storage), "w")
    user_data_file.write('''
#cloud-config
preserve_hostname: false
hostname: %s
lock-passwd: false
password: $6$rounds=4096$VI0AQ/nbS5fSWoC0$aVuV5VWp5xp0LPsM4l3pcom7FcrYCJQZaPzIBwm2bk84VE54flRusvcEOWv/Bh3YiUWCo8.TEQW5kl8MgYqxm/
chpasswd:
  expire: false
fqdn: %s.jf.intel.com

write_files:
- content: |
    SUBSYSTEM=="net", ACTION=="add", DRIVERS=="iavf", ATTR{type}=="1", KERNEL=="eth*", NAME="eth1"

  path: /lib/udev/rules.d/50-udev-default.rules
  append: true

    

# Remove cloud-init when finished with it
runcmd:
  - [ apt, -y, remove, cloud-init ]
  - 'uuidgen > /etc/machine-id'
  - 'reboot'



# Configure where output will go
output: 
  all: ">> /var/log/cloud-init.log"


# configure interaction with ssh server
ssh_svcname: ssh
ssh_deletekeys: True
ssh_genkeytypes: ['rsa', 'ecdsa']

# Install my public ssh key to the first user-defined user configured 
# in cloud.cfg in the template (which is centos for CentOS cloud images)

users: 
    - default
    - name: root
      lock-passwd: false
      password: $6$rounds=4096$VI0AQ/nbS5fSWoC0$aVuV5VWp5xp0LPsM4l3pcom7FcrYCJQZaPzIBwm2bk84VE54flRusvcEOWv/Bh3YiUWCo8.TEQW5kl8MgYqxm/
      ssh-authorized-keys: 
        - %s
    
''' % (iso_name, iso_name,rsa_key))

    #cmd = "-output /vmimages/%s.iso  /vmimages/user-data /vmimages/meta-data /vmimages/network-config" % (
    #    iso_name)
    #cmd ="ls -lrt"
    user_data_file.flush()
    meta_data_file.flush()
    network_config_file.flush()
    os.system("sleep 1")
    os.system("ls {}/{}/iso_test".format(path_prefix, vm_storage))
    os.system("cat {}/{}/iso_test/user-data".format(path_prefix, vm_storage))
    os.system("cat {}/{}/iso_test/meta-data".format(path_prefix, vm_storage))
    os.system("cat {}/{}/iso_test/network-config".format(path_prefix, vm_storage))
    os.system(
        "mkisofs -input-charset=utf-8 -output %s/%s/%s.iso -volid cidata -joliet -rock  %s/%s/iso_test/ >>iso.log"
        % (path_prefix, vm_storage, iso_name, path_prefix, vm_storage))
    os.system("rm {}/{}/iso_test/user-data".format(path_prefix, vm_storage))
    os.system("rm {}/{}/iso_test/meta-data".format(path_prefix, vm_storage))
    os.system("rm {}/{}/iso_test/network-config".format(path_prefix, vm_storage))
    if ("qat" in iso_name):
        print("using qat golden image ")
        image_name = Tile_Resource.get('QAT').get('IMG')
        if not os.path.isfile(f"%s/vmimages/{image_name}" % (path_prefix)):
            download_qcow(image_name)
        
        os.system("cp %s/vmimages/qat-golden-images.qcow2 /%s/%s.qcow2" %
                  (path_prefix, vm_storage, iso_name))

    elif ("cpu_inference" in iso_name):
        print("using GPU  golden image ")

        os.system("cp %s/vmimages/cpu_inference_golden_vmimage.qcow2 %s/%s/%s.qcow2" %
                  (path_prefix, path_prefix, vm_storage, iso_name))

    elif ("gpu_inference" in iso_name):
        print("using CPU   golden image ")

        os.system(
            "cp %s/vmimages/cpu_inference_golden_vmimage.qcow2 %s/%s/%s.qcow2" %
            (path_prefix, path_prefix, vm_storage, iso_name))
    
    elif ("spec" in iso_name):   
        print("using SPEC golden image ")
        
        image_name = Tile_Resource.get('SPEC').get('IMG')
        if not os.path.isfile(f"%s/vmimages/{image_name}" % (path_prefix)):
            download_qcow(image_name)
        os.system("cp %s/vmimages/spec-golden-image.qcow2 %s/%s/%s.qcow2" %
                  (path_prefix, path_prefix, vm_storage,iso_name))
    elif ("5g" in iso_name):   
        print("using CPU golden image ")
        image_name = Tile_Resource.get('SPEC').get('IMG')
        if not os.path.isfile(f"%s/vmimages/{image_name}" % (path_prefix)):
            download_qcow(image_name)
        
        print(f"Copying  {path_prefix}/vmimages/spec-golden-image.qcow2 {path_prefix}/{vm_storage}/{iso_name}.qcow2")
        os.system("cp %s/vmimages/spec-golden-image.qcow2 %s/%s/%s.qcow2" %
                  (path_prefix, path_prefix, vm_storage,iso_name))
    elif ("5g" in iso_name): 
        print("using CPU golden image ")
        image_name = Tile_Resource.get('FIO').get('IMG')
        if not os.path.isfile(f"%s/vmimages/{image_name}" %(path_prefix)):
            download_qcow(image_name)
        os.system("cp %s/vmimages/cpu_inference_golden_vmimage.qcow2 %s/%s/%s.qcow2" %
                  (path_prefix, path_prefix, vm_storage,iso_name))

    else:
        print("using generic redis  golden image ")

        os.system("cp %s/vmimages/golden_vmimage.qcow2 %s/%s/%s.qcow2" %
                  (path_prefix, path_prefix, vm_storage, iso_name))

    #print("HelloXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
    #p = subprocess.run(["genisoimage",cmd], universal_newlines=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    #print("the commandline is {}".format(p.args))


def generate_commands(assign_random=False):
    test_commands = []
    test_commands_remove_cd = []
    storage_pt=""
    nic_dev=""
    print("------------------------------generate_commands---started------------------")
    
    if assign_random:
        print("Using seed for Random ", seed)
        random.seed(seed)
    print(Tile_Map.keys())
    
    # Loop over the sockets
    for port_no in sorted(Tile_Map.keys()):
        r = re.compile("([a-zA-Z]+)([0-9]+)")
        m = r.match(port_no)
        sock_no = m.group(2)
        print(f"******************Socket#{sock_no}****************************")
        # res = subprocess.run('lscpu | grep "Socket(s):"',shell=True,stdout=subprocess.PIPE,universal_newlines=True)
        # num_sockets = int (res.stdout.split()[1])
        num_sockets = getsysinfo().num_sockets
        if int(sock_no) < num_sockets:
            cpupool=get_cpu_pool(sock_no)
        else:
            break
        
        # Get the tiles (which workloads and how many instances of the workloads) of the current socket 
        tiles = Tile_Map.get(port_no)

        print("Port Number = ",port_no," tiles =",tiles)

        if("QAT" in tiles):
            qat_virtual_devices = QAT_VF_SOCKET.get(port_no)
       

        if (Networking["SR-IOV"] ==1):
            virtual_ports = V_PORT.get(port_no)
            #corp_virtual_ports = CORP_PORT.get(port_no)
            #print("V_PORT", V_PORT, "QAT_DEVICE=", qat_virtual_devices)
            # print("C_PORT", CORP_PORT)
            #print("port_no", port_no, "tiles",tiles,"virtual_ports", virtual_ports)

            if virtual_ports == None:
                print("The Number of virtual ports is zero on {}, Is srivo  enabled on {}  device ?".format(port_no, port_no))
                continue
            #print("still here ")
            if assign_random:
                random.shuffle(virtual_ports)
                #random.shuffle(corp_virtual_ports)
            #print("size of virtual ports ", len(virtual_ports))

        network_cmd = "--nonetworks" #default no networks for any vm .
        
        # Loop over each tile (workload:no of copies) in the list of tiles
        for tile in sorted(tiles.keys()):
            # If a workload has atleast 1 copy, go inside the loop create that many VMs
            for count in range(0, tiles.get(tile)):
                print(f"********Creating {tile} vm#{count}*******")
                tile_no = EXEC_TASKS[tile]

                print("TILE NUMBER ", tile_no, "tile", tile)

                num_nics=len([v for k, v in PT_Device.items()if k.startswith('NIC')])
                #print("number of num_nics=",num_nics)
                
                ###################  Networking(start)  ####################
                for i in range (1,(num_nics+1)):
                    dev="NIC{}".format(i)

                if(Networking["PT"]==1):
                    # num_nic = len([v for k, v in PT_Device.items() if k.startswith('NIC')])
                    try:

                        nic_dev =" --host-device={}".format(PT_Device["NIC"].pop())
                        #print(nic_dev)
                    except IndexError:
                        print("No more Nics Available")

                if(Networking["SR-IOV"] == 1 and Networking["PT"] ==1):
                    print("Both SRIOV and PT are being passed to vm.. are you sure? if so edit the code and change the exit to pass ")
                    exit()

                if (Networking["SR-IOV"] == 1 and Networking["Bridge"]==0):
                    port_to_use = virtual_ports.pop()
                    network_cmd="--nonetworks --host-device={}".format(port_to_use)
                elif(Networking["SR-IOV"] ==1 and Networking["Bridge"]==1):
                    port_to_use = virtual_ports.pop()
                    network_cmd= "--network bridge=virbr0 --host-device={}".format(port_to_use)
                elif(Networking["SR-IOV"] ==0 and Networking["Bridge"]==1):
                    network_cmd = "--network bridge=virbr0"
                elif(Networking["PT"] ==1 and Networking["Bridge"]==1):
                    network_cmd = "--network bridge=virbr0 {}".format(nic_dev)
                elif(Networking["PT"] ==1 and Networking["Bridge"]==0):
                    network_cmd = "--nonetworks {}".format(nic_dev)
                elif (Networking["PT"] == 1 and Networking["Bridge"] == 0  and Networking["SR-IOV"] == 1):
                    #i added this
                    port_to_use = virtual_ports.pop()
                    network_cmd = "--nonetworks --host-device={} {}".format(port_to_use, nic_dev)
                elif (Networking["PT"] == 1 and Networking["Bridge"] == 1  and Networking["SR-IOV"] == 1):
                    #i added this
                    port_to_use = virtual_ports.pop()
                    network_cmd = "--network bridge=virbr0 --host-device={} {} ".format(port_to_use, nic_dev)

                ###################  Networking(end)  ####################

                # print("qat_device_to_use=",qat_device_to_use)
                # corp_port_to_use = corp_virtual_ports.pop()

                # Get the specified resource(vm memory, vcpus) for the current tile (workload)
                t_resource = Tile_Resource[tile]
                
                # print("cpus=", t_resource, "tile=", tile)
                # Purposefully added 'A' in front of DB to make sure that DB starts before Cassandra-tiles
                
                # create an iso for the current tile (workload)
                iso_name = "%s-%02d" % (tile.lower(), tile_no)
                print("iso-name= ", iso_name)
                if not DRY_RUN :
                    create_iso_centos(iso_name, tile_no, tile)

                #CMD_FORMAT = "virt-install --import -n tile%02d-%s -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=/vmimages/%s.qcow2,format=raw,bus=virtio,cache=writeback --disk path=/vmimages/%s.iso,device=cdrom   --host-device=%s --host-device=%s --noautoconsole"
                #test_cmd = CMD_FORMAT % (tile_no, tile.lower(),(int(t_resource["MEMORY"]) * 1024), t_resource["VCPU"],iso_name, iso_name, port_to_use, corp_port_to_use)
                if (tile == "QAT"):
                    if len(qat_virtual_devices) > 0:
                        qat_device_to_use ="--host-device={}".format(qat_virtual_devices.pop())
                    else:
                        sys.exit("There are no more unassigned VF qat devices. Exiting...")

                    cpu_set=str(cpupool.pop())
                    for _ in range(Tile_Resource["QAT"]['VCPU'] - 1):
                     cpu_set = cpu_set + "," + str(cpupool.pop())
                    cpuaffinity = f"--cpuset {cpu_set}"
                    CMD_FORMAT = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback --disk path=%s/%s/%s.iso,device=cdrom %s %s %s --noautoconsole --nographics"
                    test_cmd = CMD_FORMAT % (
                        tile.lower(), tile_no,
                        (int(t_resource["MEMORY"]) * 1024), t_resource["VCPU"],
                        path_prefix, vm_storage, iso_name, path_prefix,
                        vm_storage, iso_name,
                        network_cmd, qat_device_to_use, cpuaffinity)
                    CMD_FORMAT_REMOVE_CD = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback %s %s --noautoconsole"
                    test_cmd_remove_cd = CMD_FORMAT_REMOVE_CD % (
                        tile.lower(), tile_no,
                        (int(t_resource["MEMORY"]) * 1024), t_resource["VCPU"],
                        path_prefix, vm_storage, iso_name, network_cmd, qat_device_to_use )

                elif (tile == "CPU_INFERENCE"):
                    cpu_set=str(cpupool.pop())
                    for _ in range(Tile_Resource["QAT"]['VCPU'] - 1):
                     cpu_set = cpu_set + "," + str(cpupool.pop())
                    cpuaffinity = f"--cpuset {cpu_set}"


                    CMD_FORMAT = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback --disk path=/%s/%s.iso,device=cdrom %s %s --noautoconsole --cpu host-passthrough,cache.mode=passthrough --nographics"
                    test_cmd = CMD_FORMAT % (tile.lower(), tile_no,
                                             (int(t_resource["MEMORY"]) *
                                              1024), t_resource["VCPU"],
                                             path_prefix, vm_storage, iso_name, vm_storage,
                                             iso_name, network_cmd,cpuaffinity)
                    CMD_FORMAT_REMOVE_CD = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback %s --noautoconsole --cpu host-passthrough,cache.mode=passthrough"
                    test_cmd_remove_cd = CMD_FORMAT_REMOVE_CD % (
                        tile.lower(), tile_no,
                        (int(t_resource["MEMORY"]) * 1024), t_resource["VCPU"],
                        path_prefix, vm_storage, iso_name, network_cmd)

                elif (tile == "5G"):
                    print("Genrating command for 5G")
                    cpu_set=str(cpupool.pop())
                    print("No of cpus needed is : ", CPUS_PER_VM[count], cpu_set, cpupool)
                    #for _ in range(Tile_Resource["QAT"]['VCPU'] - 1):
                    for _ in range(1, CPUS_PER_VM[count]):
                        cpu_set = cpu_set + "," + str(cpupool.pop())
                    
                    # number of virtual cpus same as host's physical cpu
                    n_vcpus = CPUS_PER_VM[count] 
                    # name of the same as workload name
                    vm_name = WORKLOAD_PER_VM[count]
                    # floating or affitinized
                    cpuaffinity = f"--cpuset {cpu_set}" if CPU_AFFINITY else "" 

                    CMD_FORMAT = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback --disk path=%s/%s/%s.iso,device=cdrom %s %s --noautoconsole --cpu host-passthrough,cache.mode=passthrough --nographics"
                    
                    test_cmd = CMD_FORMAT % (vm_name.lower(), tile_no,
                                             (int(t_resource["MEMORY"]) *
                                              1024), n_vcpus,  # t_resource["VCPU"],
                                             path_prefix, vm_storage, iso_name, 
                                             path_prefix, vm_storage,
                                             iso_name, network_cmd,cpuaffinity)
                    print(test_cmd)
                    CMD_FORMAT_REMOVE_CD = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback %s --noautoconsole --cpu host-passthrough,cache.mode=passthrough"
                    test_cmd_remove_cd = CMD_FORMAT_REMOVE_CD % (
                        tile.lower(), tile_no,
                        (int(t_resource["MEMORY"]) * 1024), n_vcpus, # t_resource["VCPU"],
                        path_prefix, vm_storage, iso_name, network_cmd)

                elif(tile == "GPU_INFERENCE"):

                    try:

                        gpu_pt = " --host-device={}".format(PT_Device["GPU"].pop())
                        print(gpu_pt)
                    except IndexError:
                        print("No more gpu's Available")

                    cpu_set=str(cpupool.pop())
                    for _ in range(Tile_Resource["QAT"]['VCPU'] - 1):
                     cpu_set = cpu_set + "," + str(cpupool.pop())
                    cpuaffinity = f"--cpuset {cpu_set}"


                    CMD_FORMAT = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback --disk path=%s/%s/%s.iso,device=cdrom %s %s %s --noautoconsole --cpu host-passthrough,cache.mode=passthrough --nographics"

                    test_cmd = CMD_FORMAT % (tile.lower(), tile_no,
                                             (int(t_resource["MEMORY"]) *
                                              1024), t_resource["VCPU"],
                                             path_prefix, vm_storage, iso_name, 
                                             path_prefix, vm_storage,
                                             iso_name, network_cmd,gpu_pt, cpuaffinity)
                    CMD_FORMAT_REMOVE_CD = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback %s %s --noautoconsole --cpu host-passthrough,cache.mode=passthrough"
                    test_cmd_remove_cd = CMD_FORMAT_REMOVE_CD % (
                        tile.lower(), tile_no,
                        (int(t_resource["MEMORY"]) * 1024), t_resource["VCPU"],
                        path_prefix, vm_storage, iso_name, network_cmd, gpu_pt)

                elif(tile == "FIO"):
                    num_nvme =len( PT_Device["NVME"])
                    print("number of nvme=",num_nvme)
                    for i in range (1,(num_nvme+1)):
                        try:
                            storage_pt=storage_pt + " --host-device={}".format(PT_Device["NVME"].pop())
                        except IndexError:
                            print("No more NVME's Available")

                    cpu_set=str(cpupool.pop())
                    for _ in range(Tile_Resource["QAT"]['VCPU'] - 1):
                     cpu_set = cpu_set + "," + str(cpupool.pop())
                    cpuaffinity = f"--cpuset {cpu_set}"

                    CMD_FORMAT = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback --disk path=%s/%s/%s.iso,device=cdrom %s %s %s --noautoconsole --cpu host-passthrough,cache.mode=passthrough --nographics"

                    test_cmd = CMD_FORMAT % (tile.lower(), tile_no,
                                             (int(t_resource["MEMORY"]) *
                                              1024), t_resource["VCPU"],
                                             path_prefix, vm_storage, iso_name, 
                                             path_prefix, vm_storage,
                                             iso_name, network_cmd, storage_pt, cpuaffinity)
                    CMD_FORMAT_REMOVE_CD = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback %s %s --noautoconsole --cpu host-passthrough,cache.mode=passthrough"
                    test_cmd_remove_cd = CMD_FORMAT_REMOVE_CD % (
                        tile.lower(), tile_no,
                        (int(t_resource["MEMORY"]) * 1024), t_resource["VCPU"], path_prefix,
                        vm_storage, iso_name, network_cmd, storage_pt)

                else:

                    CMD_FORMAT = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback --disk path=%s/%s/%s.iso,device=cdrom %s --noautoconsole --nographics"
                    test_cmd = CMD_FORMAT % (tile.lower(), tile_no,
                                             (int(t_resource["MEMORY"]) *
                                              1024), t_resource["VCPU"],
                                             path_prefix, vm_storage, iso_name, 
                                             path_prefix, vm_storage,
                                             iso_name, network_cmd)
                    
                    cpu_set=str(cpupool.pop())
                    for _ in range(Tile_Resource["QAT"]['VCPU'] - 1):
                     cpu_set = cpu_set + "," + str(cpupool.pop())
                    cpuaffinity = f"--cpuset {cpu_set}"

                    CMD_FORMAT_REMOVE_CD = "virt-install --import -n %s-%02d -r %s --vcpus=%s --os-type=linux --os-variant=centos7.0 --accelerate --disk path=%s/%s/%s.qcow2,format=raw,bus=virtio,cache=writeback %s %s --noautoconsole"
                    test_cmd_remove_cd = CMD_FORMAT_REMOVE_CD % (
                        tile.lower(), tile_no,
                        (int(t_resource["MEMORY"]) * 1024), t_resource["VCPU"],
                        path_prefix, vm_storage, iso_name, network_cmd, cpuaffinity)

                EXEC_TASKS[tile] = tile_no + 1
                test_commands.append(test_cmd)
                test_commands_remove_cd.append(test_cmd_remove_cd)

    return (test_commands, test_commands_remove_cd)


def run_test(test_commands, test_commands_remove_cd):
    print("***** run_test: writing commands to virt-install-cmds.sh.")
    # file1 = open("/{}/virt-install-cmds.sh".format(vm_storage), "w")
    # file2 = open("/{}/remove-cd-virt-install-cmds.sh".format(vm_storage), "w")
    file1 = open("virt-install-cmds.sh".format(vm_storage), "w")
    file2 = open("remove-cd-virt-install-cmds.sh".format(vm_storage), "w")
    
    #file1.write("for x in `virsh list --all|tr -s \" \" |cut -f 3 -d \" \" | tail -n +3`; do virsh destroy $x;virsh undefine $x;done;sleep 5 \n")
    file1.write("virsh list --all --name|xargs -i virsh destroy {} --graceful;  virsh list --all --name|xargs -i virsh undefine {} ; sleep 5 \n ")
    for command in test_commands:
        print(command)
        file1.write(command + "\n")
        pass
    file1.close()
    
    for command in test_commands_remove_cd:
        print(command)
        file2.write(command + "\n")
        pass
    file2.close()
    print("END here ..... -> {}".format(get_linenumber()))

def find(key, dictionary):
    for k, v in dictionary.items():
        if k == key:
            yield v
        elif isinstance(v, dict):
            for result in find(key, v):
                yield result
        elif isinstance(v, list):
            for d in v:
                for result in find(key, d):
                    yield result




if __name__ == '__main__':
    print("sriov vm images")
    qat_enabled=0

    if(Networking["SR-IOV"]==1):
        get_vports()
    #print("Line Number ..... -> {}".format(get_linenumber()))
    num_sockets_qat_vm_requested=list(find("QAT", Tile_Map))
    is_qat_enabled = [item for item in num_sockets_qat_vm_requested if item > 0]

    if (len(is_qat_enabled)):
        get_qat_vf()
        
        if(len(QAT_VF_SOCKET.values()) < 1 ):
            sys.exit("QAT VM is requested but QAT VF devices are not present, check QAT driver installed ")
    
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('-c', '--CPUS_PER_VM', type=str, help = 'Comma seperated list of physical cpus each vm is pinned to.')
    parser.add_argument('-w', '--WORKLOAD_PER_VM', type=str, help = 'Comma seperated list of the name of the workloads each VM will run.')
    parser.add_argument('--cpu_affinity', action = 'store_true', help = 'Do not set cpu affinity to VMs.', default = False)

    args = parser.parse_args()
    
    CPUS_PER_VM = [int(cpu) for cpu in args.CPUS_PER_VM.split(',')]
    WORKLOAD_PER_VM = [str(wl) for wl in args.WORKLOAD_PER_VM.split(',')]
    CPU_AFFINITY = args.cpu_affinity
    Tile_Map["SOCKET0"]["5G"] = len(CPUS_PER_VM)
    
    print ("List Workload Name per vm: ", WORKLOAD_PER_VM, "List of physcial and virtual cpus for each vm: ", CPUS_PER_VM, "Number of VMs: ", Tile_Map["SOCKET0"]["5G"])

    #WORKLOAD_NAME = args.workload_name
    #print ("Workload Name: ", WORKLOAD_NAME , "List of physcial and virtual cpus for each vm: ", CPUS_PER_VM)

    #get_cports()
    if is_vm_available():
        test_commands, test_commands_remove_cd = generate_commands(
            ASSIGN_RANDOM_PORTS)
        print("is_vm_available: Total test commands : ", len(test_commands))
        run_test(test_commands, test_commands_remove_cd)
    

