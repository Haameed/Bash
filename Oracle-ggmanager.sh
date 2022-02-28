#!/bin/bash 

EXTRACTS='EXKTEST3,EXMD,EXOR,EXSP'
LOG_FILE="/var/log/ggmanager.log"
finall_message=""
#CONTACTS="98912xxxxxxx,98912xxxxxxx,98912xxxxxxx"
CONTACTS="98912xxxxxxx"
THRESHOLD=1800

function sendsms() {
 local message=$@
 IFS=','
 for contact in $CONTACTS
 do 
 /usr/bin/sendsms.py -c $contact -m "$message" >> $LOG_FILE
 done 
 unset IFS
}


source /home/oracle/.bash_profile
STATUS=$(echo "info mgr" | /u01/app/oracle/product/gg/ggsci | grep Manager)
if [[ $STATUS == *"running"* ]]
 then
 echo "$(date +'%F %T') ==> Manager service is running. going to check extracts ..." >> $LOG_FILE
 IFS=','
 for ext in $EXTRACTS
 do
 ext_status=$(echo "lag $ext" | /u01/app/oracle/product/gg/ggsci)
 if [[ $ext_status == *"ERROR"* ]]
 then 
 finall_message+="Warning: EXTRACT \"$ext\" is stopped."
 echo "$(date +'%F %T') ==> $ext is stopped" >> $LOG_FILE
 else 
 ext_lag=$(echo "lag $ext" | /u01/app/oracle/product/gg/ggsci | grep -oP "Last record.*" | awk '{print $4}')
	if [ $ext_lag -gt $THRESHOLD ]
	then
	echo "$(date +'%F %T') ==> Lag for \"$ext\" is equal to $ext_lag which is  greater than 30 minutes." >> $LOG_FILE
    finall_message+="Lag for \"$ext\" is equal to $ext_lag which is  greater than 30 minutes."
	else 
	echo "$(date +'%F %T') ==> $ext has been checked and everthing is ok with value equal to $ext_lag." >> $LOG_FILE
	fi 
 fi 
 done
 unset IFS
 if [[ ! -z $finall_message ]]
 then 
 sendsms $finall_message
 fi 
else
 echo "$(date +'%F %T') ==> Manager is stopped. Notifying contacts" >> $LOG_FILE
 sendsms "Warning: Manager service is stopped"

fi 
