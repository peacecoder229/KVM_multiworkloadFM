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
from matplotlib import cm
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.mlab as mlab
from scipy.interpolate import griddata as gd
import json
import optparse
'''
'-' solid line style
'--'    dashed line style
'-.'    dash-dot line style
':' dotted line style
'''


def multi_plot_prim_sec(title, row=1, col=1, prim=None, sec=None, figsize=None):  

    baseline = {'type' : 'plot' , 'ls' : '-', 'lw' : '5', 'lm' : 'H', 'msz' : 18, 'font' : 30, 'bbox' : '{"x" : 0.95, "y" : 0.85}', 'loc' : 'upper right', 'color' : 'g', 'setleg' : 'no', 'setaxis' : 'no', 'addtext' : None , 'addtextbox' : None, 'ylim' : None, 'yscale' : None, 'tag' : None, 'barlabel' : None, 'tag' : None} 
    basebar = {'type' : 'bar', 'width' : 0.3 , 'bbox' : '{"x" : 0.95, "y" : 0.35}', 'loc' : 'upper right', 'font' : 24, 'bbox' : '{"x" : 0.95, "y" : 0.85}', 'color' : 'g', 'setleg' : 'no', 'setaxis' : 'no', 'updatebottom' : None, 'addtext' : None, 'addtextbox' : None, 'addoffset' : None , 'ylim' : None, 'yscale' : None, 'barlabel' : None, 'tag' : None}
    basemetric = { 'sortby' : None, 'xlabel' : 'Index', 'xvar' : 'index', 'rowrange' : None }
    sizex = int(figsize.split(",")[0])
    sizey = int(figsize.split(",")[1])
    if row == 1 and col == 1:
        fig, ax0 = plt.subplots(nrows=row, ncols=col, figsize=(sizex,sizey))
        plot = 1
        ax0sec = ax0.twinx() if sec else None
    elif (row == 1 and col == 2) or (row == 2 and col == 1):
        fig, [ax0, ax1] =  plt.subplots(nrows=row, ncols=col, figsize=(sizex,sizey))
        plot = 2
        ax0sec = ax0.twinx() if sec else None
        ax1sec = ax1.twinx() if sec else None
    elif (row == 2 and col == 2):
        fig, [[ax1, ax2], [ax3, ax4]] =  plt.subplots(nrows=row, ncols=col, figsize=(sizex,sizey))
        plot = 4

        ax0sec = ax0.twinx() if sec else None
        ax1sec = ax1.twinx() if sec else None
        ax2sec = ax2.twinx() if sec else None
        ax3sec = ax3.twinx() if sec else None
    else:
        print("Error in axis config\n")
        exit(1)



    finalmetlist = list()
    for n in range(plot):
        color = ['b', 'g', 'r', 'c', 'm', 'y', 'k']
        pri_list = prim[n]
        for p in pri_list:
            print(type(p))
            plotaxis = eval("ax%s" %(n))
            print("metric is %s\n" %(p))
            metlist = p['met'].split(",")
            metlistlen = len(metlist)
            off = 0
            offsetlist = offsetlist = [round((off + i*0.1),1) for i in range(0, metlistlen )]
            plottype = p['type'] if p['type'] else line
            updatelist = json.loads(p['updatelist']) if p['updatelist'] else None
            csv = p['csv']
            if csv:
                print("prepare metric property collection for primary\n")
            else:
                print("No file given \n")
                exit(1)
            i=0
            #color = ['b', 'g', 'r', 'c', 'm', 'y', 'k']
            legendbox = p['bbox'] if  p['bbox'] else None 
            for metric in metlist:
                coloridx = i%7
                met = "%s" %(metric)
                m = dict()
                m.update(basemetric)
                m.update(axis = plotaxis)
                m.update(met = met)
                m.update(csv =  csv)
                if plottype == 'bar':
                    m.update(basebar)
                else:
                    m.update(baseline)
                if p['tag']:
                    m.update(tag =  p['tag'])
                else:
                    m.update(tag = met.upper())
                m.update(met = met)
                if updatelist:
                    m.update(updatelist)
                else:
                    pass
                print(m)
                #below values suppplied outside updatelist.. they have to be expicitly updated here.
                if p['bbox']:
                    m.update(bbox = legendbox)
                else:
                    pass
                if p['addtextbox']:
                    m.update(addtextbox = p['addtextbox'])
                else:
                    pass
                if metric == metlist[-1]:
                    m.update(setaxis = "yes")
                else:
                    pass
                print(updatelist.keys())
                if "color" in updatelist:
                    print("Color assigned is %s\n" %(updatelist["color"]))
                else:
                    m.update(color = color[coloridx])

                    print("Color assigned is %s\n" %(color[coloridx]))
                #below for bartype plots width is fixed to 0.1
                #and if addoffset is passed from main then only a single offet is passed to all metricss
                #else each metric extra offset is added  for example 0.1 , then 0.2 , then 0.3 so that each metric plotted next to each prev ones. width is also changed to 0.1 .
                #TBD make width and offset as values that can be updated .. offsetset list should be crated from passed value and  if 'addoffset' in updatelist: line need to be changed. 
                if metlistlen > 1 and plottype == 'bar':
                    if 'addoffset' in updatelist:
                        print(updatelist['addoffset'])
                        pass
                    else:
                        print("Updating bar offset to %s\n" %(offsetlist[i]))
                        m.update(addoffset = offsetlist[i])
                        m.update(width = 0.1)
                finalmetlist.append(m)
                i += 1
                print("I = %s and color index is %s\n" %(i, coloridx))
            #print(finalmetlist)

            
        if(sec):
            sec_list = sec[n]
            for p in sec_list:
                secaxis = eval("ax%ssec" %(n))
                metlist = p['met'].split(",")
                plottype = p['type'] if p['type'] else line
                updatelist = json.loads(p['updatelist']) if p['updatelist'] else None
                csv = p['csv']
                if csv:
                    print("prepare metric property collection for secondary\n")
                else:
                    print("No file given \n")
                    exit(1)
                k = 3
                legendbox = p['bbox'] if  p['bbox'] else None 
                for metric in metlist:
                    seccoloridx = k%7
                    print("sec color idx is %s and color is %s\n" %(k, color[seccoloridx]))
                    met = "%s" %(metric)
                    ms = dict()
                    ms.update(basemetric)
                    ms.update(axis = secaxis)
                    ms.update(met = met)
                    ms.update(csv =  csv)
                    if p['bbox']:
                        m.update(bbox = legendbox)
                    else:
                        pass
                    if plottype == 'bar':
                        ms.update(basebar)
                    else:
                        ms.update(baseline)
                    if p['tag']:
                        m.update(tag =  p['tag'])
                    else:
                        m.update(tag = met.upper())
                    if updatelist:
                        ms.update(updatelist)
                    else:
                        pass
                    if metric == metlist[-1]:
                        ms.update(setaxis = "yes")
                    else:
                        pass
                    ms.update(color = color[seccoloridx])
                    if p['bbox']:
                        print("Updating bbox to %s\n" %(p['bbox']))
                        ms.update(bbox = p['bbox'])
                    else:
                        pass
                    #print(ms)
                    finalmetlist.append(ms)
                    k += 1
        n += 1


    #print(finalmetlist)

    for metric in finalmetlist:
        for k,v in metric.items():
            pass
            #print("key is %s and value=%s\n" %(k, v))

    flex_plot(finalmetlist)
    titlefont =  baseline['font'] + 6
    fig.suptitle(title, horizontalalignment='center', verticalalignment='top',  fontsize=titlefont)
    plt.tight_layout()
    title = title.replace("\n", "")
    plt.savefig("%s.pdf" %(title), dpi=300, transparent=True,pad_inches=0)




def flex_plot(kwargs, bottom = None):
    for info in kwargs:
        print(info['met'])
        #print(info)
        if info['met']:
            metric =  info['met']
        else:
            print("Metric to plot not given\n")
            exit(1)
 
        if info['csv']:
            csv =  info['csv']
        else:
            print("CSVfile not given\n")
            exit(1)
        
        plottype = info['type'] if info['type'] else 'plot'
        sortby = info['sortby'] if info['sortby'] else None
        BBOX = json.loads(info['bbox'])
        if info['addtextbox']:
            addtextbox = json.loads(info['addtextbox'])
        else:
            addtextbox = { 'x' : 0.5 , 'y' : 0.75}
        xvar = info['xvar'] if info['xvar'] else 'index'
        color = info['color'] if info['color'] else 'g'
        tag = info['tag'] if info['tag'] else None
        legend = info['tag'] if info['tag'] else None
        xlabel = info['xlabel'] if info['xlabel'] else None
        ylabel = info['ylabel'] if info['ylabel'] else None
        yscale = info['ylim'] if  info['ylim'] else None
        yscaletype = info['yscale'] if  info['yscale'] else None
        barlabel = info['barlabel'] if info['barlabel'] else None 
        if info['rowrange']:
            rangelo, rangehi = info['rowrange'].split(",")
            rangelo = int(rangelo)
            rangehi = int(rangehi)
        else:
            pass

        ax = info['axis']
        if plottype == 'bar' or  plottype == 'barh':
            offset =  info['addoffset'] if info['addoffset'] else 0	
            width = float(info['width'])
            if width is None:
                print("Width not defined for bar chart\n")
                exit(1)

            df = pd.read_csv(csv, sep=",", header=0)

            if info['rowrange']:
                df = df.iloc[rangelo:rangehi]
            else:
                pass

            if sortby:
                df.sort_values([sortby], inplace=True)

            if xvar == 'index':
                xvar = df.index
            else:
                xvar = df[xvar]

            if offset is None:
                 print("Offset  not defined for bar chart\n")
                 exit(1)
            else:
                offset_var = np.array(len(df.index) * [float(offset)] )
                print("Offset is %s\n" %(offset))
                print(offset_var)

        #print(df) update bottom for first bar
            if plottype == 'bar':
                if bottom is None:
                    bottom = np.zeros(len(df.index))
            #plot = eval("ax.%s" %(plottype))
                print(df.index)
                x_var = np.arange(len( df.index))
                df.index = np.add(x_var, offset_var)
                print(x_var)
                print(df[metric])
                ax.bar(df.index, df[metric], bottom=bottom, label = tag, color = color, width=width)

                if barlabel:
                    print(df[metric])
                    for i in df.index:
                        hieght =  round(float(df.at[i, metric]), 2)
                        print("Hieght is %s\n" %(hieght))
                        ax.text(i, hieght, '%s' %(hieght), fontsize=30,  ha='center', va='bottom')
                else:
                    pass

                if info['updatebottom']:
                    bottom = df[metric] + bottom
                else:
                    pass
            elif  plottype == 'barh':
                ax.barh(df.index, df[metric], label = tag, color = color, width=width)
            #In case of plot type provide font,ls,lw,lm, loc, bbox.x and bbox.y
            if info['setleg'] == "yes":
                loc = info['loc'] if info['loc'] else 'upper right'
                font = info['font'] if info['font'] else 20
                bbox = (BBOX['x'], BBOX['y']) if info['bbox'] else (.75, 0.75)  
                ax.legend(bbox_to_anchor=bbox, loc=loc, fontsize=font)
            else:
                pass
            if info['setaxis'] == 'yes':
                ax.set_ylabel(ylabel, fontsize=font)
                ax.set_xlabel(xlabel, fontsize=font)
                if yscale:
                    ylo, yhi = yscale.split(",")
                    yhi = round(float(yhi), 1)
                    ylo = round(float(ylo), 1)
                    print("Top is %s and Bot is %s\n" %(yhi, ylo))

                    ax.set_ylim(bottom=ylo, top=yhi)
                else:
                    pass
                if yscaletype:
                    ax.set_yscale(yscaletype)
                else:
                    pass
                #ax.xticks(ticks = df.index, labels = xvar)
                #ticks_loc = ax.get_xticks().tolist()
                #ax.set_xticklabels(xvar)
                ax.set_xticks(df.index)
                ax.set_xticklabels(xvar)
                #plt.xticks(ticks = df.index, labels = xvar)
                plt.setp(ax.get_xticklabels(), rotation=90, fontsize=font)
                plt.setp(ax.get_yticklabels(), fontsize=font)
            else:
                pass
            
            if info['addtext']:
                #ax.annotate(info['addtext'], xy=(150,120000), xycoords='data', va='center', ha='center', fontsize=28, bbox=dict(boxstyle="round", fc="w"))
                print("textbox x= %s\t and textbox y= %s\n" %(addtextbox['x'], addtextbox['y']))
                ax.annotate(info['addtext'], xy=(addtextbox['x'], addtextbox['y']), xycoords='axes fraction', va='center', ha='center', fontsize=font, color='b', bbox=dict(boxstyle="round", fc="w"))
            else:
                pass
        #for k,v in info.items():
        #    print("Info key : %s has a value %s\n" %(k, v))      
        #print("metric is %s and CSV file is %s xaxis is %s and chartype if %s and sort by is %s\n" %(info['met'], info['csv'], info['xvar'], info['type'], info['sortby'] ))
                

        if plottype == 'plot':
            df = pd.read_csv(csv, sep=",", header=0)

            if info['rowrange']:
                df = df.iloc[rangelo:rangehi]
            else:
                pass

            if sortby:
                df.sort_values([sortby], inplace=True)

            if xvar == 'index':
                xvar = df.index
            else:
                xvar = df[xvar]

            #plot = eval("ax.%s" %(plottype))
            lm = info['lm'] if info['lm'] else 'o'
            ls = info['ls'] if  info['ls'] else '-'
            lw = info['lw'] if  info['lw'] else 3
            ms = info['msz'] if info['msz'] else 3
            ax.plot(df.index, df[metric], label = tag, color = color,  marker = lm, markersize=ms, ls=ls, lw=lw)
            if info['setleg'] == "yes":
                loc = info['loc'] if info['loc'] else 'upper right'
                font = info['font'] if info['font'] else 20
                bbox = (BBOX['x'], BBOX['y']) if info['bbox'] else (.75, 0.75)  
                ax.legend(bbox_to_anchor=bbox, loc=loc, fontsize=font)
            else:
                pass
            if info['setaxis'] == 'yes':
                ax.set_ylabel(ylabel, fontsize=font)
                ax.set_xlabel(xlabel, fontsize=font)
                if yscale:
                    ylo, yhi = yscale.split(",")
                    yhi = round(float(yhi), 1)
                    ylo = round(float(ylo), 1)

                    ax.set_ylim(bottom=ylo, top=yhi)
                else:
                    pass
                if yscaletype:
                    ax.set_yscale(yscaletype)
                else:
                    pass
                print("setting xlabel =%s\n" %(xlabel))
                ax.set_xticks(df.index)
                ax.set_xticklabels(xvar)
                #plt.xticks(ticks = df.index, labels = xvar)
                plt.setp(ax.get_xticklabels(), rotation=90, fontsize=font)
                plt.setp(ax.get_yticklabels(), fontsize=font)
            else:
                pass
            
            if info['addtext']:
                #ax.annotate(info['addtext'], xy=(0.5,0.75), xycoords='data', va='center', ha='center', bbox=dict(boxstyle="round", fc="w"))
                ax.annotate(info['addtext'], xy=(addtextbox['x'], addtextbox['y']), xycoords='axes fraction', va='center', ha='center', fontsize=font, color='b', bbox=dict(boxstyle="round", fc="w"))
            else:
                pass
             

            



def get_opts():
    """
    read user params
    :return: option object
    """
    parser = optparse.OptionParser('usage: ./pqos_plot.py --filelist="mbw_mix_dbg/mbw_iter4_ngx_800000_16_1920_25_15_mixpr_stressmem_16.csv,mbw_mix_dbg/mbw_iter4_ngx_800000_16_1920_25_15_nopr_stressmem_16.csv,mbw_mix_dbg/mbw_iter4_ngx_800000_16_1920_stressmem_16_nodrc.csv,mbw_mix_dbg/mbw_iter2_ngx_800000_16_1920_stressmem_16_nodrc.csv" --variablepos=\'{"3" : "Iter", "10" : "mb"}\' --variablesep="_" --metriclist="ipc_0-15,ipc_16-31" --mettag="iter-cnfig:" --outputfile="plt2-IPC of NGINX 0-15  and StressApp 16-31 cores with DRC nopr and mixpr and noDRC"')
    parser.add_option("--filelist", dest="files", help="provide Input file name", default=None)
    parser.add_option("--onefilemanymet", dest="metsinfile", help="provide Input file name", default=None)
    parser.add_option("--outputfile", dest="outfile", help="provide Output file name", default=None)
    parser.add_option("--variablepos", dest="varpos", help="provide positions of variables when column name is split with varpattern like a dict {0:delay, 2:cores} etc", default=None)
    parser.add_option("--variablesep", dest="varsep", help="provide separator charecter that can be used to extract variable names sucg as - or , ", default=None)
    parser.add_option("--mettag", dest="mettag", help="provide metric name or base name to be shown as legend such as memBW ", default=None)
    parser.add_option("--metriclist", dest="metlist", help="provide list of metrics that need to be plotted each metric is plotted on a separate plot.. total 4 plots", default=None)
    parser.add_option("--multifile", dest="mfileopt", help="provide each filename followed by operation needed  --multfile=\"file1,file2:hpbw;100*(df1.hpbw - df2.hpbw)/df1.hpbw, lpbw;100*(df1.lpbw - df2.lpbw)/df1.lpbw\"", default=None)
    (options, args) = parser.parse_args()
    return options

    

if __name__ == "__main__":

    color = ['b', 'g', 'r', 'c', 'm', 'y', 'k']
    mettmp = '{"addtextbox" : None,  "bbox" : \'{"x" : 0.65, "y" : 0.85}\', "csv" : "%s", "met" : "%s" , "tag" : "%s",  "type" : "line", "updatelist" : \'{"xlabel" : "PQOS Samples", "ylabel" : "%s", "setleg" : "yes", "lw" : "7", "color" : "%s"}\' }'
    mettmp_manymetrics = '{"addtextbox" : \'{"x" : 0.85, "y" : 0.85}\',  "bbox" : \'{"x" : 0.65, "y" : 0.85}\', "csv" : "%s", "met" : "%s" , "tag" : None, "type" : "line", "updatelist" : \'{"xlabel" : "PQOS Samples", "ylabel" : "%s", "setleg" : "yes", "lw" : "7" , "addtext" : "%s"}\' }'
    lstyle = ['-', '--', '-.', ':', '']
    options = get_opts()
    outfile = options.outfile
    tag = options.mettag
    vardict = json.loads(options.varpos)
    varsep = options.varsep
    filelist = options.files.split(",")
    metrics = options.metlist.split(",")
    metsinfile = options.metsinfile
    prim = list()
    mlist = dict()
    flist = dict()


# below Many metrics in the file are overlayed if metsinfile is "yes"
#Multiple files metrics are plotted on multiple quadrant
    if metsinfile:
        for f in filelist:
            flist[f] = list()
        for f in filelist:
            val = re.split(r"_", f)
            tmp = ""
            for k,v in vardict.items():
                k = int(k)
                tmp = "%s-%s" %(tmp, val[k])
            #ftag = "%s%s" %(tag, tmp)
            primary = eval(mettmp_manymetrics %(f, options.metlist, tag, f.upper()))
            flist[f].append(primary)
                
        for f in filelist:
            prim.append(flist[f])
# Plots the same metric from multiple files in one plot. for example memory_bw from many files are overlayed on a single plot.
# Multiple metrics are plotted on diferent plot quadrant.

    else:

        for m in metrics:
            mlist[m] = list()
        for m in metrics:
            i=0
            for f in filelist:
                val = re.split(r"_", f)
                tmp = ""
                for k,v in vardict.items():
                    k = int(k)
                    tmp = "%s-%s" %(tmp, val[k])
                ftag = "%s%s" %(tag, tmp)
                primary = eval(mettmp %(f, m, ftag, m, color[i]))
               # print("primary type is \n")
               # print(type(primary))
                mlist[m].append(primary)
                i += 1


        for m in metrics:
            prim.append(mlist[m])

    '''
    for p in prim:
        for m in p:
            print(m)
    '''
    if len(prim) == 1:
        multi_plot_prim_sec("%s \n" %(outfile), row=1, col=1, prim=prim, sec=None, figsize="60,45")
    elif len(prim) == 2:
        multi_plot_prim_sec("%s \n" %(outfile), row=2, col=1, prim=prim, sec=None, figsize="60,45")
    elif len(prim) == 4:
        multi_plot_prim_sec("%s \n" %(outfile), row=2, col=2, prim=prim, sec=None, figsize="60,45")
    else:
        print("Wrong no of  metrics\n")
        exit(1)




    wrkld_combo_ff = { "addtextbox" : '{"x" : 0.5, "y" : 0.75}', "bbox" : '{"x" : 0.65, "y" : 0.85}', "csv" : "mix_run/combned_normalized_t_ff_t.csv", "met" : "specjbb,nginx,mcache" , "type" : "bar", "updatelist" : '{"xlabel" : "HWDRC_setting_and_IterationNo", "ylabel" : "latency variation normalized to minimum latency without DRC", "setleg" : "yes", "xvar" : "case", "lw" : "10", "font" : "36", "yscale" : "log", "barlabel" : "yes" , "addtext" : "Agressor FFMPG on group1 with 16 cpu ; Workloads on group2 with 16 cpus\\n Both groups are thottled with same priority \\n normalized p99 latency of workloads plotted on yaxis "}' }
    mix_np_pr_combo_stress = { "addtextbox" : '{"x" : 0.75, "y" : 0.5}', "bbox" : '{"x" : 0.65, "y" : 0.85}', "csv" : "hwdrc_final_plot/stressmem_ngx_jbb_iter_res_mod.csv", "met" : "itr1,itr2,itr3,itr4,itr5" , "type" : "bar", "updatelist" : '{"xlabel" : "Workload_HWDRC-Configuration", "ylabel" : "latency variation normalized to minimum latency without DRC", "setleg" : "yes", "xvar" : "case", "lw" : "10", "font" : "36", "yscale" : "log", "barlabel" : "yes" , "addtext" : "Agressor stressapp on group1 with 16 cpu ; Workloads on group2 with 16 cpus\\n mixpr:workloads high priority agressor low priority  \\n nopr: workloads and agressor both same priority \\n normalized p99 latency of workloads plotted on yaxis "}' }
    mix_np_pr_combo_stress_avg = { "addtextbox" : '{"x" : 0.75, "y" : 0.75}', "bbox" : '{"x" : 0.65, "y" : 0.85}', "csv" : "hwdrc_final_plot/stressmem_avg_sum.csv", "met" : "AVG-normalized-p99lat" , "type" : "bar", "updatelist" : '{"xlabel" : "Workload_HWDRC-Configuration", "ylabel" : "Average of latency variations normalized to minimum latency without DRC", "setleg" : "yes", "xvar" : "case", "lw" : "10", "font" : "36", "barlabel" : "yes" , "addtext" : "Agressor stressapp on group1 with 16 cpu ; Workloads on group2 with 16 cpus\\n mixpr:workloads high priority agressor low priority  \\n nopr: workloads and agressor both same priority \\n Average normalized p99 latency of workloads plotted on yaxis "}' }
    mix_np_pr_combo_ff_avg = { "addtextbox" : '{"x" : 0.75, "y" : 0.75}', "bbox" : '{"x" : 0.65, "y" : 0.85}', "csv" : "hwdrc_final_plot/ff_avg_sum.csv", "met" : "AVG-normalized-p99lat" , "type" : "bar", "updatelist" : '{"xlabel" : "Workload_HWDRC-Configuration", "ylabel" : "Average of latency variations normalized to minimum latency without DRC", "setleg" : "yes", "xvar" : "case", "lw" : "10", "font" : "36", "barlabel" : "yes" , "addtext" : "Agressor FFMPEG on group1 with 16 cpu ; Workloads on group2 with 16 cpus\\n mixpr:workloads high priority agressor low priority  \\n nopr: workloads and agressor both same priority \\n Average normalized p99 latency of workloads plotted on yaxis "}' }
    mix_np_pr_combo_ff = { "addtextbox" : '{"x" : 0.75, "y" : 0.6}', "bbox" : '{"x" : 0.65, "y" : 0.85}', "csv" : "hwdrc_final_plot/ff_ngx_jbb_iter_res_mod.csv", "met" : "itr1,itr2,itr3,itr4,itr5" , "type" : "bar", "updatelist" : '{"xlabel" : "Workload_HWDRC-Configuration", "ylabel" : "latency variation normalized to minimum latency without DRC", "setleg" : "yes", "xvar" : "case", "lw" : "10", "font" : "36", "yscale" : "log", "barlabel" : "yes" , "addtext" : "Agressor FFMPG on group1 with 16 cpu ; Workloads on group2 with 16 cpus\\n mixpr:workloads high priority agressor low priority  \\n nopr: workloads and agressor both same priority \\n normalized p99 latency of workloads plotted on yaxis "}' }
    #mix_np_pr_combo_ff_rdt = { "addtextbox" : '{"x" : 0.75, "y" : 0.6}', "bbox" : '{"x" : 0.65, "y" : 0.85}', "csv" : "hwdrc_final_plot/nginx_ff_ecs_cases.csv", "met" : "itr1,itr2,itr3,itr4,itr5" , "type" : "bar", "updatelist" : '{"xlabel" : "DRC_or_RDT_Configuration", "ylabel" : "latency variation normalized to minimum latency with 100%MBA", "setleg" : "yes", "xvar" : "case", "lw" : "10", "font" : "36", "yscale" : "log", "barlabel" : "yes" , "addtext" : "Agressor FFMPG on group1 with 16 cpu ; NGINX on group2 with 16 cpus\\n mixpr:workloads high priority agressor low priority  \\n nopr: workloads and agressor both same priority \\n RDT_mb.. % same MBA set for both group1 and group2 \\n normalized p99 latency of workloads plotted on yaxis ", "width" : "0.15", "addoffset" : "0.15"}' }
    mix_np_pr_combo_ff_rdt = { "addtextbox" : '{"x" : 0.75, "y" : 0.6}', "bbox" : '{"x" : 0.65, "y" : 0.85}', "csv" : "hwdrc_final_plot/nginx_ff_ecs_cases.csv", "met" : "itr1,itr2,itr3,itr4,itr5" , "type" : "bar", "updatelist" : '{"xlabel" : "DRC_or_RDT_Configuration", "ylabel" : "latency variation normalized to minimum latency with 100%MBA", "setleg" : "yes", "xvar" : "case", "lw" : "10", "font" : "36", "yscale" : "log", "barlabel" : "yes" , "addtext" : "Agressor FFMPG on group1 with 16 cpu ; NGINX on group2 with 16 cpus\\n mixpr:workloads high priority agressor low priority  \\n nopr: workloads and agressor both same priority \\n RDT_mb.. % same MBA set for both group1 and group2 \\n normalized p99 latency of workloads plotted on yaxis "}' }
    tmpngxutil = '{ "csv" : "nginx_ffmpeg_mc/nginx_lat_setp_sum_iter%s.csv", "met" : "nginxutil,memcachutil,ffmpegutil" , "type" : "line", "updatelist" : \'{"xlabel" : "HWDRC_SetPoint", "ylabel" : "CoreGroup %% CPU Util", "setleg" : "yes", "xvar" : "setp",  "addoffset" : "0.0", "lw" : "7", "ls" : "%s", "rowrange" : "0,7"}\' }'
    
    #secdict1 = { "csv" : "nginx_ffmpeg/nginx_lat_setp_sum_mod.csv", "met" : "QPS,RPS" , "type" : "line", "updatelist" : '{"xlabel" : "SETP_FF%", "ylabel" : "Total timeouts in 2 minutes", "setleg" : "yes", "xvar" : "case", "ls" : "--", "bbox" : \'{"x" : "0.95", "y" : "0.85"}\'}' }
    #secdict1 = {"bbox" : '{"x" : 0.65, "y" : 0.85}',  "csv" : "nginx_ffmpeg/nginx_lat_setp_sum_iter1.csv", "met" : "QPS,RPS" , "type" : "line", "updatelist" : '{"xlabel" : "SETP", "ylabel" : "Requested and Executed QPS", "setleg" : "yes", "xvar" : "case", "ls" : "--"}' }

    #primdict_tmp = '{ "csv" : "nginx_ffmpeg/nginx_lat_setp_sum_iter%s.csv", "met" : "p99" , "type" : "line", "updatelist" : \'{"xlabel" : "SETP_LPshare_CON", "ylabel" : "latency in (mS)", "setleg" : "yes", "xvar" : "case", "lw" : "7" , "ls" : "%s"}\' }'
    #primdict2tmp = '{ "csv" : "nginx_ffmpeg/nginx_lat_setp_sum_iter%s.csv", "met" : "hputil,lputil" , "type" : "line", "updatelist" : \'{"xlabel" : "SETP_LPShare_CON", "ylabel" : "CPU Util in Percentage ", "setleg" : "yes", "xvar" : "case", "lw" : "7", "ls" : "%s"}\' }'
    #primdict2tmp = '{ "csv" : "nginx_ffmpeg/nginx_lat_setp_sum_iter%s.csv", "met" : "hputil" , "type" : "line", "updatelist" : \'{"xlabel" : "SETP_LPShare_CON", "ylabel" : "CPU Util in Percentage ", "setleg" : "yes", "xvar" : "case", "lw" : "7", "ls" : "%s"}\' }'
    ''' 
    listofprimarymetrics = list()
    listofprim2metrics = list()
    for i in range(5):
        it = i + 1
        primary = eval(tmpngxp99 %(it, lstyle[i]))
        primary2 = eval(tmpngxutil %(it, lstyle[i]))
        print(type(primary))
        listofprimarymetrics.append(primary)
        listofprim2metrics.append(primary2)
        #print(listofprimarymetrics)
    '''

    

    #multi_plot_prim_sec("NGINX Latency and RPS vs HWDRC SETP LP CPU 75%-25%  Over 5 Iterations", row=2, col=1, prim= [ listofprimarymetrics, [primdict2]], sec=[[secdict1], [secdict1]])  
    #multi_plot_prim_sec("4 core NGINX Latency and QPS variation  vs CON and RPS", row=2, col=1, prim= [ listofprimarymetrics, listofprim2metrics], sec=[[secdict1], [secdict1]], figsize="50,25")  
    #single_plot_prim_sec("NGINX Latency and RPS vs HWDRC SETP Only High LP CPU Util", prim=[primdict1], sec=[secdict1])
    #multi_plot_prim_sec("NGINX Perf Variation in AWS C5.9xlarge vs C5.x4large\n", row=1, col=1, prim=[[c54xp90,c59xp90]], sec=None, figsize="50,35")
    #multi_plot_prim_sec("8 core NGINX Perf Variation vs RPS and CON\n", row=1, col=1, prim=[[ngxp99only]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("NGINX Noisy neighbour Impact with and without DRC\n", row=1, col=1, prim=[[ngxp99comp]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("NGINX, memcahe, SpecJBBB DRC and no DRC impacts \n", row=1, col=1, prim=[[wrkld_combo]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("Agressor FFMPG: NGINX, memcahe, SpecJBB  with ECS equal priority for all VMs vs no DRC \n", row=1, col=1, prim=[[wrkld_combo_ff]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("Agressor StressApp: NGINX, memcahe, SpecJBB  with ECS equal priority for all VMs vs no DRC \n", row=1, col=1, prim=[[wrkld_combo_stress]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("NGINX perf impact under different agressor combinations\n", row=1, col=1, prim=[[ngxp99_combo]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("Agressor StressApp: wrklds NGINX and SpecJBB;  ECS no-priority vs mixpriority vs no DRC \n", row=1, col=1, prim=[[mix_np_pr_combo_stress]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("Agressor FFMPEG: wrklds NGINX and SpecJBB;  ECS no-priority vs mixpriority vs no DRC \n", row=1, col=1, prim=[[mix_np_pr_combo_ff]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("NGINX perf SLA variation with DRC(mixpr &nopr) vs noDRC vs static MBA(nopr)\n", row=1, col=1, prim=[[mix_np_pr_combo_ff_rdt]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("Agressor StressApp: Avg p99 lat reduction with  ECS no-priority vs mixpriority vs no DRC \n", row=1, col=1, prim=[[mix_np_pr_combo_stress_avg]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("Agressor FFMPEG: Avg p99 lat reduction with  ECS no-priority vs mixpriority vs no DRC \n", row=1, col=1, prim=[[mix_np_pr_combo_ff_avg]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("NGINX Debug \n", row=1, col=1, prim=[[ngxdbg]], sec=None, figsize="60,45")
    #multi_plot_prim_sec("NGINX Perf Varitaion and CPU Util in C5.9xlarge vs C5.x4large\n", row=2, col=1, prim=[[c54xp90var,c59xp90var], [c54xutil,c59xutil]], sec=None, figsize="50,25")
    #multi_plot_prim_sec("NGINX Perf Variation in AWS C5.9xlarge 18core:36threads\n", row=2, col=1, prim=[[primdict1], [primdict2]], sec=[[secdict1], [secdict2]], figsize="50,25")
    #multi_plot_prim_sec("NGINX Perf Variation in AWS C5.9xlarge vs C5.x4large rev2\n", row=2, col=1, prim=[[primdict1], [primdict2]], sec=[[secdict1], [secdict2]], figsize="50,25")
    #multi_plot_prim_sec("NGINX, Memcache, FFMPEG perf with HWDRC\n", row=2, col=1, prim=[[ngxp99], [ngxutil]], sec=None, figsize="50,25")
    #multi_plot_prim_sec("NGINX, Memcache, FFMPEG perf with HWDRC 5 Iterations\n", row=2, col=1, prim=[ listofprimarymetrics , listofprim2metrics ], sec=None, figsize="50,25")
    #single_plot_prim_sec("NGINX Latency and RPS", prim=[primdict1])


    #bbox is for legend.. for text bx still a fixed offset is being used. ax.annotate(info['addtext'], xy=(0.6,0.75), xycoords='axes fraction', va='center', ha='center', fontsize=28, color='b', bbox=dict(boxstyle="round", fc="w"))
