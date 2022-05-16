# Author: Rohan Tabish
# Organization: Intel Corporation
# Description: This script runs ffmpeg. Always launch as multiple of 8 cores


rm -rf *.log
rm -rf *.csv
rm -rf uhd*.mp4


taskset -c 0-7 ffmpeg -i uhd1.webm -preset ultrafast -c:v libx264 -b:v 100M -bufsize 200M -maxrate 200M -threads 32 -g 120 -tune psnr -report uhd1.mp4 2> cores_8_ffmpeg.csv &
