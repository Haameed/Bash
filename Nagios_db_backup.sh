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
do sendsms $contact_number "$MESSAGE"
done
fi
}

LOG_FILE="/var/log/backup.log"
BACKUP_PATH="/var/lib/mysql"
CONTACTS="0912xxxxxxx"
USER_NAME="someuser"
PASS="somepasswd"
DBS="nagios,nagiosql,nagiosxi,reporting,mysql"
FTP_SERVER='someftpserver'
FTP_USER='ftpuser'
FTP_PASS='ftppasswd'
DATABASES=$(echo $DBS | sed 's/,/ /g')
DATE=$(date +"%Y%m%d_%H%M")
SLAVE_IO=$(mysql -u$USER_NAME -p$PASS -e "show slave status \G" |grep Slave_IO_Running | awk '{print $2}' )
case $1 in 
	all)
	if [ -z $2 ]
	then
	NOTIFY="True"
	else
	NOTIFY="False"
	fi
	OPTIONS="--routines --triggers --events --databases $DATABASES"
	FILE_NAME='Nagios_DB_B2B_ALL'	
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
	FILE_NAME="Nagios_DB_B2B_${DATABASE}_${TABLE}"
	fi
	;;
esac
echo "-------------------- Starting backup process : $(date +"%F %T") --------------------" >> $LOG_FILE
case $SLAVE_IO in 
	Yes)
	message "Slvae IO is running. going to dump databases"
	mysqldump -u$USER_NAME -p$PASS $OPTIONS  > $BACKUP_PATH/$FILE_NAME-${DATE}.sql
	if [ $? -eq 0 ]; then message "dump is finished. Compressing dump file. " ; fi
	gzip $BACKUP_PATH/${FILE_NAME}-${DATE}.sql
	message "Dump process finished successfully"
	message "removing old backup files"
	find /var/lib/mysql/Nagios_DB_B2B_ALL* -mtime +5 -exec rm -f  {} +
	find /var/lib/mysql/Nagios_DB_B2B_*_* -mtime +1 -exec rm -f  {} +
	cd /var/lib/mysql/
	ftp -n $FTP_SERVER <<EOF 
	quote user $FTP_USER
	quote pass $FTP_PASS
	binary
	cd nagios_b2b
	put ${FILE_NAME}-${DATE}.sql.gz
	quit
EOF
	send_sms "Dump process finished successfully"
	;;
	*)
	message "Slave is not replicating. stoping process....."
	send_sms "Slave is not replicating. databases are not synce. failed to backup databases..."
	exit 1
	;;
esac
