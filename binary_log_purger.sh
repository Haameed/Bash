#!/bin/bash
####################################
#  Author : Hamed Maleki
#  This script checks disk usage
#     and purge pinary logs 
####################################

SLAVE_MYSQL="mysql -uslave -p'somepasswd' -h slvae1.domain.com"
SLAVE2_MYSQL="mysql -uslave -p'somepasswd' -h 192.168.1.100"
MYSQL="mysql -uroot -psomepasswd"
ERROR_FILE="/var/log/binary_log_purger.log"

function disk_usage() {
USED=$(df -h  /var/lib/mysql/|tail -1|awk '{print $5}' | sed 's/%//g')
}

function error() {
echo -e "\033[1;33m$@\033[m" >> $ERROR_FILE 
}

function message(){
echo -e "\033[1;32m$@\033[m" >> $ERROR_FILE 
}

disk_usage
if [ $USED -gt 70 ]
then
        error "#############################################"
        error  `date +"%F %T"` 
        error "Attention: Disk is getting full"
        error "Purging useless binary logs"
        SLAVE1_BIN=$($SLAVE_MYSQL -e "show slave status \G" |grep -w "Master_Log_File" | awk -F ':' '{print $2}' | sed 's/^ //g')
        SLAVE2_BIN=$($SLAVE2_MYSQL -e "show slave status \G" |grep -w "Master_Log_File" | awk -F ':' '{print $2}' | sed 's/^ //g')
        SLAVE_BIN=$(echo -e "$SLAVE1_BIN\n$SLAVE2_BIN"| sort -n | head -n1)
        error "$SLAVE_BIN is the latest bin log removing old ones"
        #$MYSQL -e "purge binary logs to '$SLAVE_BIN'" 
        STATUS=$?
        if [ $STATUS -eq 0 ] 
                then 
                        message "Old binary logs are removed"
                        disk_usage
                        message "Used_space=$USED%"
                else 
                        error "Somthing went wrong"
                        error "please Check the purging steps"
                fi
else
        message "#############################################"
        message `date +"%F %T"`
        message "Disk usage is ok"
        message "Used_space=$USED%"

fi
