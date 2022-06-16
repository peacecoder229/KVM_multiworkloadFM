#!/usr/bin/env python3

import socket 
import sys
import subprocess
import re
import libvirt

HOST = "192.168.122.1"  # Standard loopback interface address (localhost) 
PORT = 65432  # Port to listen on (non-privileged ports are > 1023) 

def kill_all_workloads():
    #conn = libvirt.openReadOnly(None)
    conn = libvirt.open(None) # The connection needs to be opened in write mode to access VM interfaces
    if conn == None:
        raise Exception('Failed to open connection to the hypervisor')
    
    try:  # getting a list of all domains (by ID) on the host
            domains = conn.listDomainsID()
    except:
            raise Exception('Failed to find any domains')
    
    procs = []
    for domain_id in domains:
        # Open that vm
        vm = conn.lookupByID(domain_id)

        vm_name = vm.name()
        
        vm_ifaces = vm.interfaceAddresses(libvirt.VIR_DOMAIN_INTERFACE_ADDRESSES_SRC_AGENT, 0)
        vm_ip = vm_ifaces['eth0']['addrs'][0]['addr'] # Get the IPV4 address of eth0 interface
        
        if ("mlc" in vm_name):
            wl = "mlc" # killing outputs result
        elif ("redis" in vm_name):  
            wl = "redis" # killing does not outputs result 
        elif ("memcache" in vm_name):  
            wl = "memcache" # not testted
        elif ("rnnt" in vm_name):
            wl = "rnnt" # not tested
        elif ("rn50" in vm_name):
            wl = "rn50" # not tested
        elif ("fio" in vm_name):
            wl = "fio" # not tested
        elif ("stressapp" in vm_name):
            wl = "stressapp" # not tested
        elif ("speccpu" in vm_name):
            wl = "gcc" # killing outputs result
        elif ("ffmpegbm" in vm_name):
            wl = "ffmpeg"# not tested
        else:
            wl = "None"

        cmd_for_vm = f"ssh -oStrictHostKeyChecking=no root@{vm_ip} \"sudo pkill -9 {wl}\""
        p = subprocess.Popen(cmd_for_vm, shell=True, universal_newlines = True)
        print(f"Killing {wl}: {cmd_for_vm}")
        procs.append(p)
    
    for p in procs:
        p.wait()

    conn.close()

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s: 
    s.bind((HOST, PORT)) 
    s.listen() 
    conn, addr = s.accept() 
    
    with conn: 
        print(f"Connected by {addr}")
        while True: 
            data = conn.recv(1024) 
            if not data: 
                break 
            result_file = data.decode()
            print("Got data: ", result_file) 
            # loop over all the vm's and kill corresponding workloads
            kill_all_workloads() 

            '''
            virsh_cmd = "virsh list"
            vm_name_list = subprocess.check_output([virsh_cmd], stderr=subprocess.STDOUT)
            print(vm_name_list)
            '''
