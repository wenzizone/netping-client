#! /bin/sh

CURRENT_DIR=$(pwd)
BASE_DIR=$(dirname $0)

MAIN_PROGRAM='net-test.pl'
LOGROTATE_PROGRAM='net-test-logrotate.sh'
LOG_DIR="net-test-log"
CURRENT_CRON_CONTENT=$(crontab -l)

# 判断当前目录是否是程序所在目录
if [ -f ${CURRENT_DIR}/${MAIN_PROGRAM} ] && [ -f ${BASE_DIR}/${MAIN_PROGRAM} ]
then
    confirm_dir=${CURRENT_DIR}
else 
    if [[ ${BASE_DIR} =~ ^/ ]] && [[ ${BASE_DIR} =~ \. ]]
    then
        confirm_dir=${BASE_DIR}
    else
        confirm_dir=${CURRENT_DIR}/${BASE_DIR}
    fi
fi

# 导出当前用户的crontab内容

$(crontab -l > ${confirm_dir}/crontabfile)

if test $?
then
    $(grep -i \"${MAIN_PROGRAM}\" ${confirm_dir}/crontabfile)
    if test $? 
    then
        sed -i '/'${MAIN_PROGRAM}'/d' ${confirm_dir}/crontabfile
    fi
    $(grep -i \"${LOGROTATE_PROGRAM}\" ${confirm_dir}/crontabfile)
    if test $?
    then
        sed -i '/'${LOGROTATE_PROGRAM}'/d' ${confirm_dir}/crontabfile
    fi
    echo "0 0 * * * sh ${confirm_dir}/${LOGROTATE_PROGRAM}" >>${confirm_dir}/crontabfile
    echo "*/10 * * * * perl ${confirm_dir}/${MAIN_PROGRAM} >/tmp/nettest.log 2>&1 &" >> ${confirm_dir}/crontabfile
    if [ ! -d ${confirm_dir}/net-test-log ] 
    then
        mkdir -p ${confirm_dir}/net-test-log
    fi
fi

# 导入新的crontab内容到当前用户
$(crontab ${confirm_dir}/crontabfile)
if test $?
then
    rm -f ${confirm_dir}/crontabfile
    echo "install done ~~~~~"
fi
