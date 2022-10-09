import sys, time
import json

sys.path.append("/opt/trex-core/scripts/automation/trex_control_plane/interactive/trex/examples/stl")

import stl_path
from trex_stl_lib.api import *

try:
    c = STLClient()
    c.connect()
    c.reset(ports = [0, 1])

    # With 64 bytes, ~10 Gbps aggregate rate (16 MPPS)
    # With 512 bytes, ~46 Gbps aggregate rate
    # Make sure that c arguments is set to desired number of cores in trex config
    pktSize = 512

    # Change accordingly - should be source address of port 1
    # Packets are constructed using scpay format
    base = Ether(dst='3c:fd:fe:d2:6c:29')
    pad = max(0, pktSize - len(base)) * 'x'

    s1 = STLStream(packet = STLPktBuilder(pkt = base/pad),
                   mode = STLTXCont(pps = 100))

    # Should be source address of port 0
    base = Ether(dst='3c:fd:fe:d2:6c:28')
    pad = max(0, pktSize - len(base)) * 'x'

    s2 = STLStream(packet = STLPktBuilder(pkt = base/pad),
                   mode = STLTXCont(pps = 100))

    c.add_streams(s1, ports = [0])
    c.add_streams(s2, ports = [1])
    c.clear_stats()

    rate = "100%"

    print("Running {:} on ports {:} for 30 seconds...".format(rate, 0))
    c.start(ports = [0, 1], mult = rate, duration = 30)

    c.wait_on_traffic(ports = [0, 1])

    stats = c.get_stats()
    print(json.dumps(stats[0], indent = 4, separators=(',', ': '), sort_keys = True))
    print(json.dumps(stats[1], indent = 4, separators=(',', ': '), sort_keys = True))

    c.disconnect()

except Exception as e:
    print(e)
