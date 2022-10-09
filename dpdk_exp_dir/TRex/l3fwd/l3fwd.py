import sys, time
import json
import argparse
import collections

sys.path.append("/opt/trex-core/scripts/automation/trex_control_plane/interactive/trex/examples/stl")

import stl_path
from trex_stl_lib.api import *

def createPacket(ethSrc, ethDst, ipSrc, ipDst, pktSize):
    ip_max = ipDst.split(".")
    ip_max = "{}.{}.{}.255".format(ip_max[0], ip_max[1], ip_max[2])

    vm = STLScVmRaw( [   STLVmTupleGen ( ip_min = ipDst, ip_max = ip_max, name = "tuple"),
                         STLVmWrFlowVar (fv_name = "tuple.ip", pkt_offset = "IP.dst" ),
                         STLVmFixIpv4(offset = "IP"),
                     ],
                     cache_size = 256
                   )

    base = Ether(src = ethSrc, dst = ethDst)/IP(src = ipSrc, dst = ipDst)
    pad = max(0, pktSize - len(base)) * 'x'

    t = base/pad
    print(t.show())
    # sys.exit(0)

    return STLPktBuilder(pkt = base/pad, vm = vm)

def run(server, portList, printMAC, portDestDict, frameRate, runTime, frameSize, resultDir):
    c = STLClient(server=server)
    c.connect()
    if printMAC:
        for i in portList:
            print(c.get_port_attr(i)['src_mac'])
        sys.exit(0)

    c.reset(ports = portList)

    for i in portList:
        s = STLStream(packet = createPacket(c.get_port_attr(i)['src_mac'], portDestDict[i],
                                            "1{}.0.0.1".format(i),
                                            "198.18.{}.0".format(i),
                                            frameSize),
                      mode = STLTXCont(percentage = frameRate))
        c.add_streams(s, ports = portList[i])

    c.clear_stats()

    print("Running {:}% on ports {:} for {} seconds...".format(frameRate, portList, runTime))
    #c.start(ports = portList, mult = "{}%".format(frameRate), duration = runTime)
    c.start(ports = portList, duration = runTime)

    time.sleep(runTime)
    #c.wait_on_traffic(ports = portList, timeout = runTime + 5)
    
    c.stop()

    stats = c.get_stats()
    max_stats = stats

    '''
    while c.is_traffic_active():
        currentVal = 0
        maxStateVal = 0
        for p in portList:
            currentVal += stats[p]["rx_bps_L1"]
            maxStateVal += max_stats[p]["rx_bps_L1"]

        if currentVal > maxStateVal:
            max_stats = stats

        stats = c.get_stats()
        time.sleep(0.5)
    '''

    # Print the stats collected in the middle
    for i in portList:
        print(json.dumps(max_stats[i], indent = 4, separators=(',', ': '), sort_keys = True))

    header = "port,Tx line rate,Rx line rate,Tx Frames,Rx Frames,Frames Delta,Loss %,Tx (pps),Rx (pps),Tx L1 Rate (bps),Rx L1 Rate (bps)"

    csvFile = resultDir + "/trex-{}port-{}bytes-{}rate.csv".format(len(portList), frameSize, frameRate * .25)
    f = open(csvFile, 'w')
    print(header)
    f.write("{}\n".format(header))

    for i in range(len(portList)):
        opackets = max_stats[i]["opackets"]
        ipackets = max_stats[i]["ipackets"]
        if len(portList) == 1:
            framesDelta = opackets - ipackets
            if opackets != 0:
                frameLossPct = (float(framesDelta) / opackets) * 100.0
        else:
            if i % 2 == 0:
                framesDelta = opackets - max_stats[i + 1]["ipackets"]
            else:
                framesDelta = opackets - max_stats[i - 1]["ipackets"]
            if opackets != 0:
                frameLossPct = (float(framesDelta) / opackets) * 100.0

        values = "{}".format(i)
        values += ",{}".format(max_stats[0]["tx_util"] * 0.25)
        values += ",{}".format(max_stats[0]["rx_util"] * 0.25)
        values += ",{}".format(opackets)
        values += ",{}".format(ipackets)
        if frameLossPct is not None:
            values += ",{}".format(framesDelta)
            values += ",{}".format(frameLossPct)
        values += ",{}".format(max_stats[0]["tx_pps"])
        values += ",{}".format(max_stats[0]["rx_pps"])
        values += ",{}".format(max_stats[0]["tx_bps_L1"])
        values += ",{}".format(max_stats[0]["rx_bps_L1"])
        print(values)
        f.write("{}\n".format(values))

    f.close()

    c.disconnect()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Arguments for l3FWD experiment')
    parser.add_argument('--server', action='store', dest='server', default='localhost',
                         help='Server where TRex is running')
    parser.add_argument('--printMAC', action='store_true', dest='printMAC', default=False,
                         help='Print src MAC of ports and exit')
    parser.add_argument('--runTime', dest='runTime', type=int, default=30, choices=range(30, 181),
                         metavar='[30, 180]', help='Run time for the traffic')
    parser.add_argument('--frameRate', dest='frameRate', type=float, default=100,
                         metavar='[0, 100]', help='Frame rate in Gbps (taken from Ixia RFC tests results)')
    parser.add_argument('--frameSize', dest='frameSize', type=int, default=64, choices=range(64, 1501),
                         metavar='[64, 1500]', help='Frame size')
    parser.add_argument('--ports', action='store', dest='ports', default=None,
                         help='Comma separated list of ports')
    parser.add_argument('--portDest', action='append', dest='portDest', default=None,
                         help='Repeated arg dest MAC for each port, ex: 0,3C:FD:FE:D2:6C:5C')
    parser.add_argument('--resultDir', dest='resultDir', action='store', default='results',
                         help='Specify the path to the results directory')

    args = parser.parse_args()

    if args.frameRate <= 0 or args.frameRate > 100:
        print("Frame rate must be in (0, 100]")
        sys.exit(1)

    if args.ports is None:
        print("Please provide --ports option")
        sys.exit(1)

    scriptDir = os.path.dirname(os.path.realpath(__file__))
    resultDir = scriptDir + "/" + args.resultDir

    if not os.path.isdir(resultDir):
        os.mkdir(resultDir)

    portDestDict = {}
    try:
        portList = [int(i) for i in args.ports.split(",")]
        if not args.printMAC:
            for p in args.portDest:
                pd = p.split(",")
                portDestDict[int(pd[0])] = pd[1]
    except Exception as e:
        parser.print_help(sys.stderr)
        print(e)
        sys.exit(1)

    # To send traffic at frameRate - what percentage of 25G is needed
    # frameRate = (args.frameRate / 25) * 100
    frameRate = args.frameRate * 4

    try:
        run(args.server, portList, args.printMAC, portDestDict, frameRate, args.runTime, args.frameSize,
            resultDir)
    except Exception as e:
        print("Error: ", e)
