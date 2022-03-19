HP=28 core LP = 20 cores

## Baseline
HP=rn50, LP=stressapp -> 120.332778 images/second 

HP=redis, LP=stressapp -> Throughput: 2.94028e+06 op/s, P99: 14.9, P75: 1.27, avg: 2.36

HP=redis, LP=rn50 -> Throughput: 3.5e+06 op/s, P99: 12.1, P75: 1.18, avg: 2.18; 188.244868 images/second

HP=redis, LP=mlc -> Throughput: 3.91902e+06 op/s, P99: 13.91, P75: 8.18, avg: 3.54; 

## Static MBA
HP=rn50, LP=stressapp -> 165.61 images/second 

HP=redis, LP=stressapp -> Throughput: 3.43e+06 op/s, P99: 13.31, P75: 1.52, avg: 2.43

HP=redis, LP=rn50 -> Throughput: 3.7e+06 op/s, P99: 11.73, P75: 1.57, avg: 2.55; 38.3 images/second

HP=redis, LP=mlc -> Throughput: 2.67e+06 op/s, P99: 7.54, P75: .63, avg: .67


The experiments were run in the following SPR system in GDC.

IP: 10.219.84.89
Pass:gdcpnp123

Add data in the foils below:

https://intel.sharepoint.com/:p:/r/sites/nginxperformanceevaluation-baremetalvsdocker/Shared%20Documents/Nginx%20SPR%20Vs%20ICX%20Performance/MSFT_Nutanix/HWDRC_intro.pptx?d=wa601a233a40847159e2e5745bb68e22c&csf=1&web=1&e=mnSSZF 
