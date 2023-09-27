import pandas as pd
import matplotlib.pyplot as plt
import os
import sys

# Load the Excel file
excel_file = sys.argv[1] #'tmc_emon.xlsx'  # Replace with the path to your Excel file
#df = pd.read_excel(excel_file, sheet_name='thread view', index_col=0)  # Assuming the index is in the first column
df = pd.read_excel(excel_file, sheet_name='thread view', engine='openpyxl', index_col=0)

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

# Specify an absolute path for the plot directory
plot_directory = sys.argv[2] # '/home/muktadir/l2_plots/gcc-gcc'

# Create the plot directory if it doesn't exist
os.makedirs(plot_directory, exist_ok=True)

# Extract the data corresponding to the specified row names/indexes along with all columns
data = df.loc[row_names, :]

# Plot each value in a row against the increasing order of x
for metric_name, metric_data in data.iterrows():
    plt.figure(figsize=(10, 6))
    x_values = range(len(metric_data))  # Create x-values from 0 to the length of the row
    plt.plot(x_values, metric_data, marker='o', linestyle='-')
    plt.title(f"Metric: {metric_name}")
    plt.xlabel("X")
    plt.ylabel("Value")
    plt.grid(True)
    
    # Save the plot with just the metric name as the filename
    plot_filename = os.path.join(plot_directory, f"{metric_name}.png")
    
    # Ensure that the directory exists before saving
    os.makedirs(os.path.dirname(plot_filename), exist_ok=True)
    
    plt.savefig(plot_filename)
    plt.close()  # Close the current plot to free memory

