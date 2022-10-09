# Example usage

Copy and edit conf file:

    cp trex_5g.conf.sample trex_5g.conf

    python3 trex_exp_5g.py -c n=218t,inst=0,port=0,ue=12500,eth-dst=40:a6:b7:63:8f:84,m=10gbps -c n=292t,inst=1,port=0,ue=12500,eth-dst=40:a6:b7:63:8c:d0,m=10gbps --stats --sdur 10
