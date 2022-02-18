from subprocess import run, PIPE

print("====Checking KVM Packages installation====")

# dis = distro.id().lower()
# print(dis)
dis = ""
try:
    with open ("/etc/os-release","r") as f:
        for line in f:
            if "PRETTY_NAME=" in line:
                dis = line.lower().split("=",1)[1].strip('"').split()[0]
                break
        if not dis:
            raise ValueError("Cannot determine the linux distro type. Please check and rerun")
except FileNotFoundError:
    print("'/etc/os-release' not found. Please check and rerun")
    exit()
except ValueError as e:
    print(e)
    exit()

def kvm_pkg_check():
 cmd = "egrep -c '(vmx|svm)' /proc/cpuinfo"
 res = run(cmd, shell=True, stdout=PIPE, stderr=PIPE, check=False)
 if res.stdout == 0:
     print("vmx|svm is not enabled. please check the bios setting. exiting..")
     exit()
 packages=[]

 if dis and dis in "centosfedoraredhat":
      packages=["qemu", "qemu-kvm", "virt-manager", "libvirt-daemon-kvm", "libguestfs-tools", "virt-install","libvirt-daemon-config-network","numactl","python3-pip"]
      pkgmgr="dnf"
 elif dis and dis in "ubuntudebian":
      packages=["qemu", "qemu-kvm", "bridge-utils", "virt-manager", "libvirt-daemon-system", "libvirt-clients", "virtinst","libvirt-daemon-config-network","numactl","ppython3-pip"]
      pkgmgr="apt-get"
 else:
      print("OS not supported. Exiting")
      exit()


 for p in packages:
  if dis in "centosfedoraredhat":
      cmd = f"{pkgmgr} list --installed {p}"
  elif dis in "ubuntudebian":
      cmd = f"apt-cache policy {p} | grep Installed"
  res = run(cmd, shell=True, stdout=PIPE, stderr=PIPE, check=False)
  if res.returncode != 0 or "none" in str(res.stdout):
      print(f"installing pkg {p}")
      cmd = f"{pkgmgr} -y install {p}"
      res = run(cmd, shell=True, check=False, stdout=PIPE, stderr=PIPE)
      if res.returncode == 0:
          print(f"pkg {p} installed sucessfully")
      else:
          print(f"pkg {p} installation failed. please install manually and run again")
  else:
      print(f"pkg {p} is already installed")

 print("====Checking the libvirtd service====")
 cmd = "systemctl is-active --quiet libvirtd"
 res = run(cmd,shell=True,stdout=PIPE,stderr=PIPE,check=False)
 if res.returncode != 0:
     print("Libvirtd services is not running. Trying to start Libvirtd..")
     cmd = "systemctl start libvirtd"
     res = run(cmd,shell=True,stdout=PIPE,stderr=PIPE,check=False)
     if res.returncode != 0:
         print("Failed to start the service. please start manually and run again. Exiting...")
         exit()
     else:
         print("Libvirtd started successfully")
 else:
     print("Libvirtd is running")

 print("====Checking the default network====")
 cmd = "virsh net-list | grep default"
 res = run(cmd,shell=True,stdout=PIPE,stderr=PIPE,check=False)
 if res.returncode != 0:
     if dis in "centosfedoraredhat":
         print("default network is not active. Trying to disable firewalld, reset libvirtd and activate default network...")
         cmd = "systemctl stop firewalld; systemctl restart libvirtd;virsh net-start default"
         res = run(cmd,shell=True,stdout=PIPE,stderr=PIPE,check=False)
         if res.returncode != 0:
             print("Failed to start default network. please start manually and run again. Exiting...")
             exit()
         else:
             print("default network started successfully")
 else:
     print("default network is running")

 print("====Checking the needed python modules====")
 needed_modules = ["distro","requests"]
 cmd = "python3 -m pip list|awk '{print $1}'"
 res = run(cmd, shell=True, check=False, stdout=PIPE, stderr=PIPE,universal_newlines=True)
 installed_modules = res.stdout.split()
 mods = [m for m in needed_modules if m not in installed_modules]
 for mod in mods:
    print(f"Trying to install the package for {mod} module")
    cmd = f"python3 -m pip install {mod}"
    res = run(cmd,shell=True,stdout=PIPE,stderr=PIPE,check=False)
    if res.returncode == 0:
        print(f"{mod} installed successfully.")
    else:
        print(f"Failed to install module {mod}. Please install it and try again")
        exit()
        


kvm_pkg_check()
