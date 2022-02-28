#!/bin/bash 
#############
#       Author: Hamed Maleki
#############
function message () {
local MESSAGE=$@
echo  "$MESSAGE"  >> $LOG_FILE
logger -t backup -p local1.info "$MESSAGE" 
}
function send_sms() {
local MESSAGE=$@
if [ "w$NOTIFY" == "wTrue" ]
then
echo $CONTACTS | while IFS=',' read -r contact_number
do 
sendsms $contact_number "$MESSAGE"
done
fi
}

LOG_FILE="/backup/backup.log"
BACKUP_PATH="/backup"
CONTACTS="0912xxxxxxx"
USER_NAME="backupuser"
PASS="somepassword"
DBS=" DW,jiradb,mysql"
FTP_SERVER='someftpserver'
FTP_USER='ftpuser'
FTP_PASS='myuserpasswd'
DATABASES=$(echo $DBS | sed 's/,/ /g')
DATE=$(date +"%Y%m%d_%H%M")
MYSQL="mysql -u$USER_NAME -p$PASS -BN "
case $1 in 
	all)
	if [ -z $2 ]
	then
	NOTIFY="True"
	else
	NOTIFY="False"
	fi
	OPTIONS="--routines --triggers --databases $DATABASES"
	FILE_NAME='Jira_DB_ALL'
	;;
	*)
	if [ $# -lt 2 ]
	then 
	echo "Check inputs and try again"
	message "error in inputs"
	send_sms "error in inputs"
	exit 1
	else 
	DATABASE=$1
	TABLE=$2
	if [ -z $3 ]
	then
	NOTIFY="True"
	else
	NOTIFY="False"
	fi
	OPTIONS="$DATABASE $TABLE"
	FILE_NAME="Jira_DB_${DATABASE}_${TABLE}"
	fi
	;;
esac
echo "-------------------- Starting backup process : $(date +"%F %T") --------------------" >> $LOG_FILE
CLUSTER_SIZE=$($MYSQL -e "SHOW GLOBAL STATUS WHERE Variable_name = 'wsrep_cluster_size'" | awk '{print $2}')
WSREP_CONNECTED=$($MYSQL -e "SHOW GLOBAL STATUS WHERE Variable_name = 'wsrep_connected'" | awk '{print $2}')
LOCAL_COMMENT=$($MYSQL -e "SHOW GLOBAL STATUS WHERE Variable_name = 'wsrep_local_state_comment'" | awk '{print $2}')
WSRE_READY=$($MYSQL -e "SHOW GLOBAL STATUS WHERE Variable_name = 'wsrep_ready'" | awk '{print $2}')

if [[ $CLUSTER_SIZE -eq 3 ]] && [[ "w$WSREP_CONNECTED" == "wON" ]] &&  [[ "w$LOCAL_COMMENT" == "wSynced" ]] && [[ "w$WSRE_READY" == "wON" ]]
then 
CLUSTER_STATUS="running"
CLUSTER_MESSAGE="wsrep_cluster_size=$CLUSTER_SIZE, wsrep_connected=$WSREP_CONNECTED, wsrep_local_state_comment=$LOCAL_COMMENT, wsrep_ready=$WSRE_READY"
elif [[ $CLUSTER_SIZE -eq 2 ]] && [[ "w$WSREP_CONNECTED" == "wON" ]] &&  [[ "w$LOCAL_COMMENT" == "wSynced" ]] && [[ "w$WSRE_READY" == "wON" ]]
then 
CLUSTER_STATUS="warning"
else 
CLUSTER_STATUS="critical"
CLUSTER_MESSAGE="Cluster status is \"$CLUSTER_STATUS\". Please check the cluster nodes in order to prevent data loss or split brain. stoping process....."
fi 


case $CLUSTER_STATUS in 
	running|warning)
	message "Cluster Status is $CLUSTER_STATUS $CLUSTER_MESSAGE. going to dump databases"
	mysqldump -u$USER_NAME -p$PASS $OPTIONS  > $BACKUP_PATH/$FILE_NAME-${DATE}.sql
	if [ $? -eq 0 ]; then message "dump is finished. Compressing dump file. " ; fi
	gzip $BACKUP_PATH/${FILE_NAME}-${DATE}.sql
	message "Dump process finished successfully"
	message "removing old backup files"
	find /backup/Jira_DB_ALL* -mtime +5 -exec rm -f  {} +
	find /backup/Jira_DB_*_* -mtime +3 -exec rm -f  {} +
	cd /backup
	ftp -n $FTP_SERVER <<EOF 
	quote user $FTP_USER
	quote pass $FTP_PASS
	binary
	cd jira_db
	put ${FILE_NAME}-${DATE}.sql.gz
	quit
EOF
	send_sms "Dump process finished successfully. cluster status is $CLUSTER_STATUS"
	;;
	*)
	message "$CLUSTER_MESSAGE"
	send_sms "Galera is not replicating. databases are not synce. failed to backup databases... \n $CLUSTER_MESSAGE"
	exit 1
	;;
esac
