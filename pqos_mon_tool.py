#!/usr/bin/env python3
import subprocess
import sys
import os
import time
import re
import signal
import pandas as pd
import matplotlib
import numpy as np
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import json
from pathlib import Path


def perflineout(buf):
    for l in iter(buf.readline, ""):
        if not re.findall(r'time', l):
            yield l

def run_and_capture_pqos(cmd, outfile):
    pqos = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True, universal_newlines=True)
    getpqos = perflineout(pqos.stdout)
    patterns = ['CORE',  'IPC',   'MISSES' ,    'LLC[KB]' ,  'MBL[MB/s]' ,  'MBR[MB/s]', 'TIME']
    infopat = '|'.join(patterns)
    data = dict()
    cores = list()
    metlist = list()
    if getpqos:
        count=0
        try:
            while(count < 2):
                line = next(getpqos)
                line = line.rstrip().lstrip()
                if re.search(r"TIME", line):
                    count += 1
                    continue
                elif count >= 1 :
                    if re.search(infopat, line):
                        metname = re.split("\s+", line)
                        #print("Info is " + info[0])
                    else:
                        coreline = re.split("\s+", line)
                        cores.append(coreline[0])
                        #print(cores[0])
                else:
                    continue

        except StopIteration:
            pass

    for c in cores:
        for i in range(1, len(metname)):
            #print(info[i] + "-----" + c + "\n")
            metric = "%s_%s" %(metname[i].lower(), c)
            data[metric] = list()
            metlist.append(metric)

    while pqos.poll() is None:
        if getpqos:
            try:
                line = next(getpqos)
                line = line.rstrip().lstrip()
                if re.search(infopat, line):
                    continue
                else:
                    #print(line)
                    metinfo = re.split("\s+", line)
                    for i in range(1, len(metinfo)):
                        colname = "%s_%s" %(metname[i].lower(), metinfo[0])
                        data[colname].append(metinfo[i])

            except KeyboardInterrupt:
                #print(data)
                df = pd.DataFrame.from_dict(data, orient='index').transpose()
                df.to_csv(outfile, index=False)
                pqos.send_signal(signal.SIGINT)
            except StopIteration:
                pass


if __name__ == "__main__":
    cmd = sys.argv[1]
    outfile =  sys.argv[2]
    print (cmd)
    print (outfile)
    run_and_capture_pqos(cmd, outfile)
