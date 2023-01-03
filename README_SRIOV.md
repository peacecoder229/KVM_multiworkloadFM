# Enabling SR-IOV:
  1. First make sure vt-x and vt-d is enabled:
  (1) Add "intel_iommu=on" in GRUB_CMDLINE_LINUX of /etc/default/grub file;
  (2) Execute “grub2-mkconfig -o /boot/grub2/grub.cfg”.
  (3) It did not work, because system was booting from another grub conf which is in: /boot/efi/EFI/fedora/grub.cfg. So written the iommu changes there as well:
  grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg or /boot/efi/EFI/centos/grub.cfg
  The changes we made in /etc/defualt/grub will reflect in the new grub.cfg file.
  (4) reboot.
  (5) After machine is booted check “dmesg | grep -i IOMMU” if iommu is enabled.
  (6) If VT-d is enabled, Linux will configure DMA Remapping at boot time. The easiest way to find this is to look in dmesg for DMAR entries. If you don't see errors, then VT-d is enabled.
  (7) Check if the network card supports sriov: (i) lshw -c network -businfo (ii) lspci -vs <bus address>
  (8 ) To see the boot option: cat /proc/cmdline
 2. echo 2 > /sys/class/net/enp1s0f0/device/sriov_numvfs
