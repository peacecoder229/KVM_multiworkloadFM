from trex_stl_lib.api import *
from scapy.contrib.gtp import *

import ipaddress

OLD_VERSION = True
try:
   from scapy.contrib.gtp import GTP_PDUSessCon_ExtensionHeader
except Exception as e:
   OLD_VERSION = False

   # Missing from scapy 2.4.3 which is in current TRex (v2.89) so adding here
   class GTP_PDUSessCon_ExtensionHeader(Packet):
       name = "GTP-U PDU Session Container"
       fields_desc = [ ByteField("length", 0x01),
                       BitField("pdu_type", 1, 4),
                       BitField("spare", 0, 4),
                       BitField("QFI", 1, 8),
                       ByteField("next_ex", 0),
                     ]

class STLS1(object):

    def get_streams (self, direction = 0, **kwargs):
        self.instance = kwargs.get('inst', 0)
        print("Instance: {}".format(self.instance))
        self.ue = kwargs.get('ue', 10000)
        print("Using {} user equipments".format(self.ue))
        self.apps = kwargs.get('apps', 10)

        self.ps = kwargs.get('ps', 650)
        if self.ps != 650 and self.ps != 950:
            return -1
        print("Using {} packet size".format(self.ps))
        if self.ps == 650:
           self.ul_size = 564
           self.dl_size = 608
        else:
           self.ul_size = 864
           self.dl_size = 908

        print("Using {} apps per user equipment".format(self.apps))
        self.ethsrc = kwargs.get('eth-src', None)
        print("Using {} for eth src".format(self.ethsrc))
        self.ethdst = kwargs.get('eth-dst', None)
        print("Using {} for eth dst".format(self.ethdst))
        self.ether = Ether()
        if self.ethdst and not self.ethsrc:
            self.ether = Ether(dst=self.ethdst)
        if self.ethsrc and not self.ethdst:
            self.ether = Ether(dst=self.ethdst)
        if self.ethsrc and self.ethdst:
            self.ether = Ether(src=self.ethsrc, dst=self.ethdst)
        self.ether.show2()

        # Increment 2nd Octect by 2
        self.outer_ul_src = ipaddress.ip_address(u"192.178.120.140") + (self.instance) # * 2 * 256)
        self.outer_ul_dst = ipaddress.ip_address(u"192.178.120.170") + (self.instance)
        self.ul_dst       = ipaddress.ip_address(u"192.178.96.140")  + (self.instance)
        self.dl_src       = self.ul_dst

        print("outer_ul_src: {}".format(self.outer_ul_src))
        print("outer_ul_dst: {}".format(self.outer_ul_dst))
        print("ul_dst: {}".format(self.ul_dst))
        print("dl_src: {}".format(self.dl_src))

        # Base IP depends on instance and UE
        self.ul_src_min   = ipaddress.ip_address(u"172.20.0.1")      + (self.instance * self.ue)
        self.dl_dst_min   = self.ul_src_min
        print("ul_src_min: {}".format(self.ul_src_min))
        print("dl_dst_min: {}".format(self.dl_dst_min))

        # Mas IP is base + UE
        self.ul_src_max = self.ul_src_min + self.ue - 1
        self.dl_dst_max = self.dl_dst_min + self.ue - 1
        print("ul_src_max: {}".format(self.ul_src_max))
        print("dl_dst_max: {}".format(self.dl_dst_max))

        self.udp_src_min = 10001
        self.udp_src_max = self.udp_src_min + self.ue - 1
        print("UDP src port minimum value: {}".format(self.udp_src_min))
        print("UDP src port maximum value: {}".format(self.udp_src_max))

        self.teid_min = 1
        self.teid_max = self.ue

        print("Teid minimum value: {}".format(self.teid_min))
        print("Teid maximum value: {}".format(self.teid_max))

        return self.create_stream()

    def create_stream (self):

        vm1 = STLVM()
        vm1.var(name = "ip_src_outer", min_value = str(self.outer_ul_src), max_value = str(self.outer_ul_src), size = 4, op = "inc")
        vm1.var(name = "ip_src", min_value = str(self.ul_src_min), max_value = str(self.ul_src_max), size = 4, op = "inc")
        vm1.var(name = "udp_src_port_outer", min_value = self.udp_src_min, max_value = self.udp_src_max, size = 2, op = "inc")
        vm1.var(name = "teid", min_value = self.teid_min, max_value = self.teid_max, size = 4, op = "inc")
        vm1.write(fv_name = "ip_src_outer", pkt_offset = "IP.src")
        vm1.write(fv_name = "ip_src", pkt_offset = "IP:1.src")
        vm1.write(fv_name = "udp_src_port_outer", pkt_offset = "UDP.sport")
        if OLD_VERSION:
            vm1.write(fv_name = "teid", pkt_offset = "GTP_U_Header.TEID")
        else:
            vm1.write(fv_name = "teid", pkt_offset = "GTP_U_Header.teid")
        vm1.fix_chksum(offset = "IP:1")
        vm1.fix_chksum_hw(l3_offset = "IP", l4_offset = "UDP", l4_type  = CTRexVmInsFixHwCs.L4_TYPE_UDP )

        vms = []
        for i in range(3):
            vm2 = STLVM()
            vm2.var(name = "ip_dst", min_value = str(self.dl_dst_min), max_value = str(self.dl_dst_max), size = 4, op = "inc")
            vm2.write(fv_name = "ip_dst", pkt_offset = "IP.dst")
            vm2.fix_chksum_hw(l3_offset = "IP", l4_offset = "UDP", l4_type  = CTRexVmInsFixHwCs.L4_TYPE_UDP )
            vms.append(vm2)

        QFI = [9, 6, 6, 6, 6, 6, 6, 6, 6, 4]
        UL_UDP_SRC_PORTS = [20001, 2011, 2112, 2213, 2314, 2415, 2516, 2617, 2718, 2819]
        UL_UDP_DST_PORTS = [20001, 2000, 2100, 2200, 2300, 2400, 2500, 2600, 2700, 2800]

        streams = []
        for i in range(self.apps):
            if OLD_VERSION:
                gtpu_header = GTP_U_Header(E=1, TEID=self.teid_min, gtp_type=255, next_ex=133)
            else:
                gtpu_header = GTP_U_Header(E=1, teid=self.teid_min, gtp_type=255, next_ex=133)
            streams.append(
                STLStream(
                    name = 'UL-{}-1'.format(i + 1),
                    #isg = 20,
                    packet = STLPktBuilder(pkt = self.ether/IP(src=str(self.outer_ul_src), dst=str(self.outer_ul_dst),tos=192)/
                                                 UDP(dport=2152, sport=2152)/
                                                   gtpu_header/
                                                   GTP_PDUSessCon_ExtensionHeader(QFI=QFI[i])/
                                                     IP(src=str(self.ul_src_min), dst=str(self.ul_dst), tos=192)/
                                                     UDP(dport=UL_UDP_DST_PORTS[i],sport=UL_UDP_SRC_PORTS[i],chksum=0)/(self.ul_size*'x'),
                                                 vm = vm1),
                                           mode = STLTXCont(pps = 1000))
                )

            for j in range(3):
                streams.append(STLStream(
                           name = 'DL-{}-{}'.format(i + 1, j + 1),
                           #isg = 120,
                           packet = STLPktBuilder(
                              pkt = self.ether/IP(src=str(self.dl_src), dst=str(self.dl_dst_min), tos=192)/
                                 UDP(dport=UL_UDP_SRC_PORTS[i],sport=UL_UDP_DST_PORTS[i])/
                                 (self.dl_size*'x'),
                                  vm = vms[j]
                           ),
                           mode = STLTXCont(pps = 1000)))

        return STLProfile(streams).get_streams()

# dynamic load - used for trex console or simulator
def register():
    return STLS1()
