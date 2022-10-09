#import sys

#sys.path.append("/opt/trex-core/scripts/automation/trex_control_plane/interactive/trex/examples/stl")

#import stl_path
from trex_stl_lib.api import *

from vBNG import *

class STLS1(object):
    def __init__ (self):
        pass

    def create_stream (self):
        #return STLStream(packet = createDLPacket(ethSrc="00:00:01:01:00:01", ethDst="00:00:00:01:00:01",
        #                                         ipSrc="210.0.0.0", ipDst="201.0.0.0", pktSize=700))

        return STLStream(packet = createULPacket(ethSrc="00:00:01:01:00:00", ethDst="00:00:00:01:00:00",
                                                 ipSrc="110.0.0.0", ipDst="210.0.0.0", pktSize=128, proto='pppoe'))

    def get_streams (self, direction = 0, **kwargs):
        # create 1 stream
        return [ self.create_stream() ]

def register():
    return STLS1()
