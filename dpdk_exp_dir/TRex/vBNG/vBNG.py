import sys, time
import json
import argparse
import traceback

sys.path.append("/opt/trex-core/scripts/automation/trex_control_plane/interactive/trex/examples/stl")

import stl_path
from trex_stl_lib.api import *
from scapy.layers.ppp import PPP, PPPoE

def createDLPacket(ethSrc, ethDst, ipSrc, ipDst, pktSize):

    vm = STLScVmRaw( [ STLVmTupleGen (ip_min = ipDst, ip_max = ipDst,
                                      port_min = 10000, port_max = 14095, name = "tuple"),
                       STLVmWrFlowVar (fv_name = "tuple.port", pkt_offset = "UDP.dport" ),
                     ]
                     #, cache_size =
                   )

    base = Ether(src = ethSrc, dst = ethDst)/IP(src = ipSrc, dst = ipDst)/UDP(dport=10000, sport=210)
    pad = max(0, pktSize - len(base)) * 'x'

    # t = base/pad
    # print(t.show())

    return STLPktBuilder(pkt = base/pad, vm = vm)

def createULPacket(ethSrc, ethDst, ipSrc, ipDst, pktSize, proto):
    ip_max = ipSrc.split(".")
    # 16 * 256 = 4096
    ip_max = "{}.{}.15.255".format(ip_max[0], ip_max[1])

    vm = STLScVmRaw( [
                       # size is number of bytes of the variable
                       STLVmFlowVar( name="vlan", min_value=0, max_value=4095, size=2, op="inc"),
                       STLVmFlowVar ( "ip_src", min_value = ipSrc, max_value = ip_max, step=1, op="inc"),

                       # 18 such that it is the second vlan (could not make two FlowVar for vlan work)
                       STLVmWrFlowVar (fv_name = "vlan", pkt_offset = 18),
                       STLVmWrFlowVar (fv_name = "ip_src", pkt_offset= "IP.src"),
                       #, cache_size =
                     ]
                   )

    base = Ether(src = ethSrc, dst = ethDst)/Dot1Q(vlan=0)/Dot1Q(vlan=0)
    if proto == 'pppoe':
        base = base/PPPoE()/PPP()

    base = base/IP(src = ipSrc, dst = ipDst)/UDP(dport=210, sport=110)

    pad = max(0, pktSize - len(base)) * 'x'

    t = base/pad
    print(t.show())

    # Works w/o VM too!
    #return STLPktBuilder(pkt = base/pad)
    return STLPktBuilder(pkt = base/pad, vm = vm)

def run(server, portList, runTime, dlFrameRate, ulFrameRate, dlFrameSize, ulFrameSize, resultDir, proto):
    c = STLClient(server=server, verbose_level='info')
    c.connect()
    c.reset(ports = portList)

    # A TRex port receives a packet only if the packet's destination MAC matches the HW Src MAC
    # defined for that port in the (/etc/)trex_cfg.yaml configuration file.
    # Alternatively, a port can be put into promiscuous mode,
    # allowing the port to receive all packets on the line.
    # Ref: https://trex-tgn.cisco.com/trex/doc/trex_stateless.pdf
    c.set_service_mode(ports = [0], enabled = True) # (also need to use force=True in start)
    c.set_service_mode(ports = [1], enabled = True) # (also need to use force=True in start)
    #capture = c.start_capture(rx_ports = 0, limit = 1000)

    # Need to add DL and UL on separate ports due to source MAC address
    # DL
    streams = []
    numInstances = 1
    for i in range(numInstances):
        # ip source for vBNG DL instance can be anything since firewall says for src ip the mask is zero?
        # --> Not sure about NAT
        s1 = STLStream(packet = createDLPacket(ethSrc="00:0{0}:01:01:0{0}:01".format(i),
                                               ethDst="00:00:00:01:0{}:01".format(i),
                                               ipSrc="210.0.0.0", ipDst="201.0.0.0", pktSize=dlFrameSize))
        s2 = STLStream(packet = createULPacket(ethSrc="00:0{0}:01:01:0{0}:00".format(i),
                                               ethDst="00:00:00:01:0{}:00".format(i),
                                               ipSrc="110.0.0.0", ipDst="210.0.0.0", pktSize=ulFrameSize, proto=proto))
    streams.append(s1)
    streams.append(s2)

    for i in portList:
        c.add_streams(streams[i], ports = [i])

    c.clear_stats()

    c.start(ports = portList[:len(portList)/2], mult = "{}%".format(dlFrameRate), duration = runTime, force=True)
    c.start(ports = portList[len(portList)/2:], mult = "{}%".format(ulFrameRate), duration = runTime, force=True)

    c.wait_on_traffic(ports = portList)

    stats = c.get_stats()
    print(json.dumps(stats[0], indent = 4, separators=(',', ': '), sort_keys = True))
    print(json.dumps(stats[1], indent = 4, separators=(',', ': '), sort_keys = True))

    # print(capture)
    # c.stop_capture(capture['id'], "/tmp/rx-capture")

    while True:
        time.sleep(1)

    c.disconnect()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Arguments for vBNG experiment')
    parser.add_argument('--server', action='store', dest='server', default='localhost',
                         help='Server where TRex is running')
    parser.add_argument('--runTime', dest='runTime', type=int, default=30, choices=range(30, 181),
                         metavar='[30, 180]', help='Run time for the traffic')
    parser.add_argument('--ports', action='store', dest='ports', default="0,1",
                         help='Comma separated list of ports (must be even)')
    parser.add_argument('--dlFrameSize', dest='dlFrameSize', type=int, default=700, choices=range(64, 1501),
                         metavar='[64, 1500]', help='Frame size of DL instances')
    parser.add_argument('--ulFrameSize', dest='ulFrameSize', type=int, default=128, choices=range(64, 1501),
                         metavar='[64, 1500]', help='Frame size of UL instances')
    parser.add_argument('--dlFrameRate', dest='dlFrameRate', type=float, default=89,
                         metavar='[0, 100]', help='Frame rate of DL instances')
    parser.add_argument('--ulFrameRate', dest='ulFrameRate', type=float, default=11,
                         metavar='[0, 100]', help='Frame rate of UL instances')
    parser.add_argument('--resultDir', dest='resultDir', action='store', default='results',
                         help='Specify the path to the results directory')
    parser.add_argument('--proto', dest='proto', default='pppoe', choices=['ipoe', 'pppoe'],
                         help='Protocol to use in UL traffic generation')

    args = parser.parse_args()

    print("Do not forget to set switchport mode dot1q-tunnel on the switch for UL port!!")

    scriptDir = os.path.dirname(os.path.realpath(__file__))
    resultDir = scriptDir + "/" + args.resultDir

    if not os.path.isdir(resultDir):
        os.mkdir(resultDir)

    if (args.dlFrameRate < 0 or args.dlFrameRate > 100) or \
       (args.ulFrameRate < 0 or args.ulFrameRate > 100):
        parser.print_help(sys.stderr)
        sys.exit(1)

    if args.ports is None:
        print("Please provide --ports option")
        sys.exit(1)

    try:
        portList = [int(i) for i in args.ports.split(",")]
    except Exception as e:
        print("Error", e)
        sys.exit(1)

    if len(portList) % 2 != 0:
        print("Number of ports not even")
        sys.exit(1)

    dlFrameRate = (args.dlFrameRate / 25) * 100
    ulFrameRate = (args.ulFrameRate / 25) * 100

    try:
        run(args.server, portList, args.runTime, args.dlFrameRate, args.ulFrameRate,
            args.dlFrameSize, args.ulFrameSize, resultDir, args.proto)
    except Exception as e:
        print("Error: ", e)
        print(traceback.format_exc())
