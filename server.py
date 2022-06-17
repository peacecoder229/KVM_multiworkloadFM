#!/usr/bin/env python3

import socket 
import os
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

def kill_turbostat(turbostat_pids, result_file):
    #speccpu_0-35_co_na_sst-0_rep_1
    result_file_split = result_file.split("_")
    turbostat_file = result_file_split[0] + "_" + result_file_split[1] + "_" + result_file_split[2] + "_" + result_file_split[3] + "_" + result_file_split[4] + "_turbostat.txt"
    
    subprocess.run(f"kill -9 {turbostat_pids[turbostat_file]}", shell=True)
    print(f"Killed turbostat process: {turbostat_pids[turbostat_file]}")


def start_server(turbostat_pids):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s: 
        s.bind((HOST, PORT)) 
        s.listen() 
        
        while True:
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
                    #kill_all_workloads() 
                    kill_turbostat(turbostat_pids, result_file)
   
                    '''
                    virsh_cmd = "virsh list"
                    vm_name_list = subprocess.check_output([virsh_cmd], stderr=subprocess.STDOUT)
                    print(vm_name_list)
                    '''

def main():
    turbostat_pids = {}
    with open('turbostat_pids.txt') as f:
        lines = f.readlines()
    for line in lines:
        print(line)
        ts_file = line.strip().split(',')[0]
        ts_pid = line.strip().split(',')[1]
        turbostat_pids[ts_file] = ts_pid

    start_server(turbostat_pids)

if __name__ == "__main__":
    main()
