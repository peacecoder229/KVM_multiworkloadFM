from trex_stl_lib.api import *

from l3fwd import *

class STLS1(object):
    def __init__ (self):
        pass

    def create_stream (self):
        return STLStream(packet = createPacket("3c:fd:fe:d2:6c:08", "10.0.0.1", "192.18.0.0", 1024))

    def get_streams (self, direction = 0, **kwargs):
        # create 1 stream
        return [ self.create_stream() ]

def register():
    return STLS1()
