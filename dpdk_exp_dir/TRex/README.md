# TRex

The GUI can be started and monitored during the debugging of these scripts.
See the docs repo for more details.

## Folder Structure

- bidirectional-loopback-test.py: Loopback test - assumes that daemon server is running locally
  - Will need to change MAC address according to platform
- trex-manager/trex-manager.py: Start/stop TRex locally or remotely
  - Called after running TRex daemon server with the IP where the daemon server is run (can be localhost)
  - Connects to the daemon server and starts TRex with the Yaml provided
- l3fwd:
  - *-port.yaml: Yaml file w/ which TRex is started via trex-manager. 
    - Update according to the machine where TRex will be run
  - l3fwd.py: Connect to TRex and send L3fwd traffic (see below and -h for help)
  - sim_l3fwd.py: Simulate traffic with the packet manipulation done in l3fwd.py (see SIMULATOR.md in docs)
- run-l3fwd.sh: Combine script to start workload, start trex, and send traffic via TRex to workload
  - Update NIC addresses accordingly
- vBNG:
  - 2-port.yaml: Yaml to start TRex w/ (vBNG requires MAC addresses updated according to vBNG destinations)
  - vBNG.py: Work in progress (almost done - need some more cleaning and testing) for sending traffic via TRex to workload
  - sim_vbng.py: Simulate traffic to see how the packets are manipulated (see SIMULATOR.md in docs)

### L3FWD

Example command to run l3fwd on the same machine (see docs repo for more details):

    ./build/l3fwd -w 86:00.1 -w 86:00.0 -l 40,41 -n 6 --file-prefix trex-test -- \
    -p 0x3 --config="(0,0,40),(1,0,41)" --eth-dest="0,3c: fd:fe:d2:6c:29" --eth-dest="1,3c:fd:fe:d2:6c:28"

Example to run the l3fwd script:

    python l3fwd.py --ports 0,1 --portDest 0,3C:FD:FE:D2:6C:5C --portDest 1,3C:FD:FE:D2:6C:5D

### vBNG

The traffic sent back to Rx does not show up in the stats.
It is in the hardware counter. If service mode is enabled
then the traffic is shown in the stats. More on service mode
[here](https://trex-tgn.cisco.com/trex/doc/trex_stateless.html#_port_service_mode).
Service mode will affect packet performance speed.
