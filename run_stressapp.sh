ip="10.219.66.160"


result_file=$1_$(getconf _NPROCESSORS_ONLN)

docker load < streeapp.tar

docker run --rm --cpuset-cpus=0-$[$(getconf _NPROCESSORS_ONLN)-1] --cpuset-mems=0 -e RUNTIME=300 -e MSIZEMB=16384 -e MTHREAD=$[$(getconf _NPROCESSORS_ONLN)-2] -e CTHREAD=2 stressapp:latest 


