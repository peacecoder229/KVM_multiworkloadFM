from trex_stl_lib.api import *
from scapy.contrib.gtp import *

import ipaddress

class STLS1(object):

    def get_streams (self, direction = 0, **kwargs):
        self.instance = kwargs.get('inst', 0)
        print("Instance: {}".format(self.instance))
        self.ue = kwargs.get('ue', 10000)
        print("Using {} user equipments".format(self.ue))
        self.apps = kwargs.get('apps', 10)
        print("Using {} apps per user equipment".format(self.apps))

        # Increment 2nd Octect by 2
        self.outer_ul_src = ipaddress.ip_address(u"192.179.120.1")   + (self.instance) # * 2 * 256)
        self.outer_ul_dst = ipaddress.ip_address(u"192.179.120.180") + (self.instance)
        self.ul_dst       = ipaddress.ip_address(u"192.179.96.100")  + (self.instance)
        self.dl_src       = self.ul_dst

        print("outer_ul_src: {}".format(self.outer_ul_src))
        print("outer_ul_dst: {}".format(self.outer_ul_dst))
        print("ul_dst: {}".format(self.ul_dst))
        print("dl_src: {}".format(self.dl_src))

        # Base IP depends on instance and UE
        self.ul_src_min   = ipaddress.ip_address(u"172.20.0.1")       + (self.instance * self.ue)
        self.dl_dst_min   = self.ul_src_min
        print("ul_src_min: {}".format(self.ul_src_min))
        print("dl_dst_min: {}".format(self.dl_dst_min))

        # Mas IP is base + UE
        self.ul_src_max = self.ul_src_min + self.ue - 1
        self.dl_dst_max = self.dl_dst_min + self.ue - 1
        print("ul_src_max: {}".format(self.ul_src_max))
        print("dl_dst_max: {}".format(self.dl_dst_max))

        self.udp_src_min = self.ue + 1
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
        vm1.write(fv_name = "teid", pkt_offset = "GTP_U_Header.TEID")
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
        UL_UDP_SRC_PORTS = [20010, 2020, 2130, 2240, 2350, 2460, 2570, 2680, 2790, 2810]
        UL_UDP_DST_PORTS = [20001, 2000, 2100, 2200, 2300, 2400, 2500, 2600, 2700, 2800]

        streams = []
        for i in range(self.apps):
            streams.append(
                STLStream(
                    name = 'UL-{}-1'.format(i + 1),
                    #isg = 20,
                    packet = STLPktBuilder(pkt = Ether()/IP(src=str(self.outer_ul_src), dst=str(self.outer_ul_dst),tos=192)/
                                                 UDP(dport=2152, sport=2152)/
                                                   GTP_U_Header(E=1, TEID=self.teid_min, gtp_type=255, next_ex=133)/
                                                   GTP_PDUSessCon_ExtensionHeader(QFI=QFI[i])/
                                                     IP(src=str(self.ul_src_min), dst=str(self.ul_dst), tos=192)/
                                                     UDP(dport=UL_UDP_DST_PORTS[i],sport=UL_UDP_SRC_PORTS[i],chksum=0)/(564*'x'),
                                                 vm = vm1),
                                           mode = STLTXCont(pps = 1000))
                )

            for j in range(3):
                streams.append(STLStream(
                           name = 'DL-{}-{}'.format(i + 1, j + 1),
                           #isg = 120,
                           packet = STLPktBuilder(
                              pkt = Ether()/IP(src=str(self.dl_src), dst=str(self.dl_dst_min), tos=192)/
                                 UDP(dport=UL_UDP_SRC_PORTS[i],sport=UL_UDP_DST_PORTS[i])/
                                 (608*'x'),
                                  vm = vms[j]
                           ),
                           mode = STLTXCont(pps = 1000)))

        return STLProfile(streams).get_streams()

# dynamic load - used for trex console or simulator
def register():
    return STLS1()
