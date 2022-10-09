import sys, time
import json
import argparse

import ipaddress
import toml

#sys.path.append("/opt/2trex-core/scripts/automation/trex_control_plane/interactive/trex/examples/stl")

from trex_stl_lib.api import *
from scapy.contrib.gtp import *

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

    def get_bonded_streams(self, direction=0, **kwargs):
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
        # 140 (inst=0,port=0); 141 (inst=1,port1); 142 (inst=2,port=0); 143 (inst=3,por=t1)
        self.outer_ul_src = ipaddress.ip_address(u"192.178.120.140") + self.instance
        # 0,1->0; 2,3->1; 4,5->2
        self.outer_ul_dst = ipaddress.ip_address(u"192.178.120.170") + int(self.instance / 2)
        self.ul_dst       = ipaddress.ip_address(u"192.178.96.140")  + self.instance
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

        # UPF0,port0 = 1     - 12500 (port=0,inst=0)
        # UPF0,port1 = 12501 - 25000 (port=1,inst=1)
        # UPF1,port0 = 1     - 12500 (port=0,inst=2)
        # UPF1,port1 = 12501 - 25000 (port=1,inst=3)

        self.teid_min = 1 + ((self.instance % 2) * self.ue)
        self.teid_max = self.ue * ((self.instance % 2) + 1)

        print("Teid minimum value: {}".format(self.teid_min))
        print("Teid maximum value: {}".format(self.teid_max))

        return self.create_stream()

    def get_streams(self, direction=0, **kwargs):
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
        self.ethsrc = kwargs.get('eth_src', None)
        print("Using {} for eth src".format(self.ethsrc))
        self.ethdst = kwargs.get('eth_dst', None)
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

    def create_stream(self):

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

class Config:
    def __init__(self, line, start=False):
        self.stl = STLS1()

        self.bonded = False
        for pair in line.split(','):
            pair_split = pair.split('=')
            # print(pair_split)
            if pair_split[0] == 'bonded':
                self.bonded = True
            else:
                key, val = pair_split
                if key == 'n':
                    self.server_name = val
                elif key == 'inst':
                    self.inst = int(val)
                elif key == 'port':
                    self.port = int(val)
                elif key == 'ue':
                    self.ue = int(val)
                elif key == 'eth-dst':
                    self.eth_dst = val
                elif key == 'm':
                    self.m = val
        if start:
            if self.bonded:
                self.stream = self.stl.get_bonded_streams(inst=self.inst, ue=self.ue, eth_dst=self.eth_dst)
                print('Added bonded stream')
            else:
                self.stream = self.stl.get_streams(inst=self.inst, ue=self.ue, eth_dst=self.eth_dst)
                print('Added stream')

class PortConfigs:
    def __init__(self, port_config_list, start=False):
        self.port_configs = {}
        for conf_str in port_config_list:
            conf = Config(conf_str, start)
            if conf.server_name not in self.port_configs:
                self.port_configs[conf.server_name] = {}
            self.port_configs[conf.server_name][conf.port] = conf

    def __getitem__(self, server_name):
        if server_name in self.port_configs:
            return self.port_configs[server_name]
        return None

    def __iter__(self):
        return iter(self.port_configs)

    def keys(self):
        return self.port_configs.keys()

    def items(self):
        return self.port_configs.items()

    def values(self):
        return self.port_configs.values()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Arguments for 5G experiment')
    parser.add_argument('--start', action='store_true')
    parser.add_argument('--stop', action='store_true')
    parser.add_argument('--stats', action='store_true')
    parser.add_argument('-m', action='store', help='Multiplier, example: 70gbps')
    parser.add_argument('--dur', action='store', type=int, default=30, help='Duration of traffic (-1 = infinite)')
    parser.add_argument('--sdur', action='store', type=int, default=25, help='Duration of stat collection (ignores first 10 sec)')
    parser.add_argument('-c', action='append', help='n=218t,inst=0,port=0,ue=12500,eth-dst=40:a6:b7:63:8f:84,bonded,m=10gbps (repeated arg)')
    args = parser.parse_args()

    # [ 'n=218t,inst=0,port=0,ue=12500,eth-dst=40:a6:b7:63:8f:84,bonded,m=10gbps' ]
    port_configs = args.c
    port_configs = PortConfigs(port_configs, start=args.start)

    t = toml.load('trex_5g.conf')
    clients = {}
    for s in t['server']:
        if s not in port_configs:
            continue
        clients[s] = STLClient(server=t['server'][s]['ip'], sync_port=t['server'][s]['sync_port'])

    for server_name, c in clients.items():
        c.connect()
        c.acquire(force=True)
        # print(c.get_all_ports())
        # print(c.get_port_attr(0))

    if args.start:
        for server_name, port_confs in port_configs.items():
            if server_name in clients:
                clients[server_name].reset()
                clients[server_name].clear_stats()

        for server_name, c in clients.items():
            # resets on all ports by default
            c.reset()
            c.clear_stats()
            for s, port_conf in port_configs.items():
                if server_name == s:
                    for port, conf in port_conf.items():
                        c.add_streams(conf.stream, ports=conf.port)
                        c.start(ports=port, mult=conf.m if conf.m else args.m, duration=args.dur)
    if args.stats:
        active_ports = sum([ len(c.get_active_ports()) for name, c in clients.items() ])
        print('Active ports: {}'.format(active_ports))
        if active_ports == 0:
            print('No active ports')
            sys.exit(1)

        total_tx_rate = 0
        total_rx_rate = 0
        reading_iter  = 0
        stat_duration = args.sdur
        for i in range(1, stat_duration + 1):
            for client_name, c in clients.items():
                stats = c.get_stats()
                print('[{}]'.format(client_name), end='')
                for p in c.get_active_ports():
                    tx_rate = stats[p]["tx_bps"] / (10**9)
                    rx_rate = stats[p]["rx_bps"] / (10**9)
                    print('[P{}] TX: {:.2f}, RX: {:.2f} | '.format(p, tx_rate, rx_rate), end='')
                    total_tx_rate += tx_rate
                    total_rx_rate += rx_rate
                print()
            print('Avg TX rate: {:.2f}, Avg RX rate: {:.2f} '.format(total_tx_rate / i, total_rx_rate / i))
            time.sleep(1)

        print('Avg TX rate/port: {:.2f}, Avg RX rate/port: {:.2f}'.format(total_tx_rate / stat_duration, total_rx_rate / stat_duration))
        print('Avg TX rate: {:.2f}, Avg RX rate: {:.2f}'.format(total_tx_rate / stat_duration, total_rx_rate / stat_duration))

    if args.stop:
        for name, c in clients.items():
            c.stop()
