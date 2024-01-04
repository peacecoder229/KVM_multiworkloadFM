import pandas as pd
import matplotlib.pyplot as plt
import os
import sys

# Load the Excel file
excel_file = sys.argv[1] #'tmc_emon.xlsx'  # Replace with the path to your Excel file
#df = pd.read_excel(excel_file, sheet_name='thread view', index_col=0)  # Assuming the index is in the first column
#df = pd.read_excel(excel_file, sheet_name='thread view', engine='openpyxl', index_col=0)
df_thread = pd.read_excel(excel_file, sheet_name='thread view', engine='openpyxl', index_col=0)
df_socket = pd.read_excel(excel_file, sheet_name='socket view', engine='openpyxl', index_col=0)

# Define a list of row names/indexes you want to extract
row_names = [
    "metric_L1D MPI (includes data+rfo w/ prefetches)",
    "metric_L1D demand data read hits per instr",
    "metric_L1-I code read misses (w/ prefetches) per instr",
    "metric_L2 demand data read hits per instr",
    "metric_L2 MPI (includes code+data+rfo w/ prefetches)",
    "metric_L2 demand data read MPI",
    "metric_L2 demand code MPI",
    "metric_L2 Any local request that HITM in a sibling core (per instr)",
    "metric_L2 Any local request that HIT in a sibling core and forwarded(per instr)",
    "metric_L2 all L2 prefetches(per instr)",
    "metric_L2 % of all lines evicted that are unused prefetches",
    "metric_L2 % of L2 evictions that are allocated into L3",
    "metric_L2 % of L2 evictions that are NOT allocated into L3",
    "metric_core initiated local dram read bandwidth (MB/sec)",
    "metric_TMA_Info_Thread_IPC",
    "L2_LINES_IN.ALL",
    "L2_LINES_OUT.NON_SILENT",
    "L2_LINES_OUT.SILENT",
    "L2_LINES_OUT.USELESS_HWPF",
    "L2_RQSTS.ALL_CODE_RD",
    "L2_RQSTS.ALL_HWPF",
    "L2_RQSTS.ALL_RFO",
    "L2_RQSTS.CODE_RD_HIT",
    "L2_RQSTS.CODE_RD_MISS",
    "L2_RQSTS.RFO_HIT",
    "L2_RQSTS.RFO_MISS",
    "MEMORY_ACTIVITY.STALLS_L1D_MISS",
    "MEMORY_ACTIVITY.STALLS_L2_MISS",
    "MEMORY_ACTIVITY.STALLS_L3_MISS",
    #"metric_memory bandwidth read (MB/sec)",
    #"metric_memory bandwidth write (MB/sec)",
    #"metric_memory bandwidth total (MB/sec)"
]

row_names_l2_l1 = [
    "metric_L1D MPI (includes data+rfo w/ prefetches)",
    "metric_L1-I code read misses (w/ prefetches) per instr",
    "metric_L2 MPI (includes code+data+rfo w/ prefetches)",
    "L2_LINES_IN.ALL",
]

row_names_llc = [
    "metric_LLC MPI (includes code+data+rfo w/ prefetches)",
]

# Specify an absolute path for the plot directory
#plot_directory = sys.argv[2] # '/home/muktadir/l2_plots/gcc-gcc'

# Create the plot directory if it doesn't exist
#os.makedirs(plot_directory, exist_ok=True)

# Extract the data corresponding to the specified row names/indexes along with all columns
#data_l2_l1 = df_core.loc[row_names_l2_l1, 'socket 0 core 47'].to_frame().transpose()
#data_l2_l1['L1 MPI (data+code+rfo)'] = data_l2_l1['metric_L1-I code read misses (w/ prefetches) per instr'] + data_l2_l1['metric_L1D MPI (includes data+rfo w/ prefetches)']
#data_l2_l1['L2_Hit_Rate'] = 1 - (data_l2_l1['metric_L2 MPI (includes code+data+rfo w/ prefetches)'] / data_l2_l1['L1 MPI (data+code+rfo)'])

total_l2_mpi = 0
total_l1_mpi = 0
thread_no = 0
for cpu_range in ['0,48', '96,144']:
    start_cpu = int(cpu_range.split(',')[0])
    end_cpu = int(cpu_range.split(',')[1])
    core_no = 0
    for cpu_no in range(start_cpu, end_cpu):
        cpu_column = 'cpu ' + str(cpu_no) + ' (' + 'S0' + 'C'  + str(core_no) + 'T' + str(thread_no) + ')'
        #print(cpu_column)
        data_l2_l1 = df_thread.loc[row_names_l2_l1, cpu_column].to_frame().transpose()
        #print(data_l2_l1)
        total_l1_mpi += data_l2_l1['metric_L1-I code read misses (w/ prefetches) per instr'][0] + data_l2_l1['metric_L1D MPI (includes data+rfo w/ prefetches)'][0]
        total_l2_mpi += data_l2_l1['metric_L2 MPI (includes code+data+rfo w/ prefetches)'][0]
        #print(total_l2_mpi)
        #print(total_l1_mpi)
        core_no += 1
    
    l2_hit_rate = 1 - (total_l2_mpi/total_l1_mpi)

    data_llc = df_socket.loc[row_names_llc, 'socket 0'] #.to_frame() #.transpose()
    #data_llc['L3 Hit Rate'] = 1 - (data_llc['metric_LLC MPI (includes code+data+rfo w/ prefetches)']/data_l2_l1['metric_L2 MPI (includes code+data+rfo w/ prefetches)'])
    l3_hit_rate = 1 - (data_llc['metric_LLC MPI (includes code+data+rfo w/ prefetches)']/total_l2_mpi)

    #print(data_llc['metric_LLC MPI (includes code+data+rfo w/ prefetches)'])
    #print(data_l2_l1['metric_L2 MPI (includes code+data+rfo w/ prefetches)'])
    #print("L2 Hit Rate: ", data_l2_l1['L2_Hit_Rate'][0])
    #print("L3 Hit rate: ", data_llc['L3 Hit Rate'][0])
    #print(cpu_range , " L3 Hit rate: ", l3_hit_rate)
    print(cpu_range, "L2 Hit Rate: ", l2_hit_rate)
    #data = data_l2_l1[['L2_LINES_IN.ALL', 'L2_Hit_Rate']]
    #data.to_csv('l2_emon_data.csv', index=True)

    #data = pd.concat([data, data_llc], axis=1)
    #os.system("cat l2_emon_data.csv")
    thread_no += 1
