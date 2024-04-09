username=$1
password=$2
dir=$3
cd $dir
# work on spr image
curl -u $username:$password -O https://ubit-artifactory-or.intel.com/artifactory/drc-repo-or-local/spec-golden-image.qcow2

