#!/bin/bash
#########
#  Author : Hamed Maleki
#########
CONTACT_POINTS='091xxxxxxx,0912qqqqqqq'
DB='192.168.200.20'
LOG="/var/log/auto_apply.log"
TABLES="tbl_host,tbl_hostgroup,tbl_hosttemplate,tbl_hostdependency,tbl_service,tbl_servicegroup,tbl_servicetemplate,tbl_servicedependency,tbl_contact,tbl_contacttemplate,tbl_contactgroup,tbl_timeperiod,tbl_command"
COUNTER=0
RETRY=3
RETRY_TIMES=0

function query() {
local table=$1
mysql -udbuser -h$DB -pnagiosxi -BN nagiosql -e "select unix_timestamp(max(last_modified)) from  $table"
}

function compare () {
local mtime=$1
if [ $LAST_APPLY -lt $mtime ]
then 
COUNTER=$(($COUNTER + 1))
fi
}
function nagios_export_script() {
/usr/local/nagiosxi/scripts/restart_nagios_with_export.sh 2>&1 >> $LOG
if [ $? -ne 0 ]
then 
RETRY_TIMES=$(($RETRY_TIMES + 1 ))
notify
sleep 60
nagios_export_script
fi
}

function notify() {
if [ $RETRY -eq $RETRY_TIMES ]
then 
/usr/bin/sendsms "$CONTACT_POINTS" "nagiosxi apply config has failed after $RETRY times. for more information read $LOG" 2>&1 >>$LOG ; echo -e "$(date +'%F %T')\t auto_apply: Apply config failed. RESULT=1" >> $LOG 
exit 1
fi
}


LAST_APPLY=$(date +%s -d "$(cat /var/log/auto_apply.log | grep "auto_apply"| tail -n1 | awk '{print $1" "$2}')")
LAST_APPLY_RESULT=$(cat /var/log/auto_apply.log | grep "auto_apply"| grep -oP "RESULT=.*" | tail -n1 |awk  -F '=' '{print $2}')
if [ -z $LAST_APPLY ] ; then 
LAST_APPLY=$(date +%s -d "$(zcat /var/log/auto_apply.log-$(date +"%Y%m%d").gz | grep "auto_apply"| tail -n1 | awk '{print $1" "$2}')")
fi 
if [ -z $LAST_APPLY_RESULT ] ; then 
LAST_APPLY_RESULT=$(zcat /var/log/auto_apply.log-$(date +"%Y%m%d").gz | grep -oP "RESULT=.*" | tail -n1 |awk  -F '=' '{print $2}')
fi 
DELETED=$(mysql -uroot -h$DB -pnagiosxi -BN nagiosql -e "select exists(select * from tbl_logbook where unix_timestamp(time) >= '$LAST_APPLY' and entry like '%deleted%')")
if [ $DELETED -eq 1 ]
then 
COUNTER=$(($COUNTER + 1))
fi
if [ $LAST_APPLY_RESULT -eq 1 ]
then 
COUNTER=$(($COUNTER + 1))
fi
IFS=','
for TABLE in ${TABLES} 
do 
TABLE_MTIME=$(query $TABLE)
if [ "w$TABLE_MTIME" == "wNULL" ] ; then TABLE_MTIME=$LAST_APPLY ; fi  ## NULL  means there is no record in the table. so make TABLE_MTIME equal to LAST_APPLY to tell the script there is no change on this table
compare $TABLE_MTIME 
done
if [ $COUNTER -eq 0 ]
then 
echo -e "$(date +'%F %T')\t auto_apply: No change was found. Nothing to do. RESULT=0" >> $LOG
else 
echo -e "$(date +'%F %T')\t auto_apply: Found Modification on one or more table. applying configuration." >> $LOG
nagios_export_script
fi 
