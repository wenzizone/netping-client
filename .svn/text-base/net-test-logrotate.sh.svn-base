#!/bin/sh

log_path=$(dirname $0)
log_src_file="net-test.log"
year=$(date -d '-1days' +%Y)
month=$(date -d '-1days' +%m)
day=$(date -d '-1days' +%d)
localip=$(/sbin/ifconfig eth0|grep "inet addr"|awk -F':' '{print $2}'|awk '{print $1}')
log_dst_file="${localip}_${year}_${month}_${day}.log"

mkdir -p ${log_path}/net-test-log/${year}/${month}/

mv ${log_path}/${log_src_file} ${log_path}/net-test-log/${year}/${month}/${log_dst_file}
#gzip ${log_path}/net-test-log/${year}/${month}/${log_dst_file}

