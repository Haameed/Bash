#!/bin/bash
###################
#  Hamed Maleki
#  Thanks to my friend Mehdi Mohammadzadeh 
###################
# This script will count number of running processes on database continuously  to Stop plese press "CTRL+C" on terminal
# prerequisites: "innotop" package 
# checking if innotop is installed
DEBUG=0
INNOTOP_OUT=2     #Options are 1 or 2
TMP_FILE='/tmp/inno.log'
HIGH_QUERIES='/var/log/proc/high_queries.log'
LOG_FILE='/var/log/proc/proc.log'
DB_USER='myuser'
DB_PASS='mypass'
DB_HOST='localhost'
DB_NAME='mydb'
MYSQL_CLIENT='/usr/bin/mysql'
ALERT=300
WARNING=700
ERROR=1000
SLEEP_TIME=$1
: ${SLEEP_TIME:=1}

check_other_instance(){
PIDFILE=/var/run/proc.pid
if [ -e ${PIDFILE} ] && kill -0 `cat ${PIDFILE}` 2>/dev/null
  then
    echo "Info: another instance of '$(basename $0)' is already running (PID `cat ${PIDFILE}`). See the log file '$LOG_FILE' ..."
    read  -n1 -p "Would you like to tail the log file? (y/n):"  INPUT
    if [[ "$INPUT" = "y" || "$INPUT" = "Y"  ]]
      then
        printf '\n'
		clear
        tail -f $LOG_FILE
      else
        printf '\n'
        exit 1
    fi
else 
echo $$ > ${PIDFILE}
truncate -s 0 $LOG_FILE 2>&1 >/dev/null
fi
}


fproc()
{
check_other_instance
echo "Press [CTRL+C] to stop.." | tee -a $LOG_FILE
while true ;do
FREE_MEM=$(free -m | grep Mem | awk '{print $4}')
LOAD=`cat /proc/loadavg | cut -d' ' -f-3`
IOW=$(top -bn2| awk -F"," '/Cpu/{if(p==0){p=1}else{split($5,a,"%");print a[1]}}' | sed 's/ //g')
$INNOTOP --count 1 -d 1 -n --mode O > $TMP_FILE
INNOTOP_OUT1=`cat $TMP_FILE | head -n2 | tail -n1 | cut -f2-3 | sed -e "s/[[:space:]]\+/ /g"`
INNOTOP_OUT2=`cat $TMP_FILE | head -n3 | tail -n1 | cut -f2-3 | sed -e "s/[[:space:]]\+/ /g"`
if [ "w$INNOTOP_OUT" = "w1" ]
then
INNOTOP_OUT2=""
fi
INNOTOP_OUT="$INNOTOP_OUT1 $INNOTOP_OUT2"
COUNT=`$MYSQL_CLIENT -s -N -u$DB_USER -p$DB_PASS -e "SELECT count(*) FROM information_schema.PROCESSLIST where COMMAND != 'Sleep'" 2>/dev/null`
echo -en "`date "+%F %T"`\t" | tee -a $LOG_FILE
if [[ "$COUNT" -ge "$ALERT" && "$COUNT" -lt "$WARNING" ]]
then
echo -e "| Process Count: \033[0;33m$COUNT\t| Free Mem: $FREE_MEM MB\t| Load: $LOAD\t| iow: $IOW\t| Top Tables: $INNOTOP_OUT\033[m" | tee -a $LOG_FILE
echo -e "`date "+%F %T"`\n-------------------" >> $HIGH_QUERIES
$MYSQL_CLIENT -BN -u$DB_USER -p$DB_PASS information_schema -e "select TIME, STATE, INFO from PROCESSLIST where INFO is not NULL order by TIME desc limit 10" >> $HIGH_QUERIES 2>/dev/null
echo -en "\n" >> $HIGH_QUERIES
elif [[ "$COUNT" -ge "$WARNING" && "$COUNT" -lt "$ERROR" ]]
then
echo -e "| Process Count: \033[1;33m$COUNT\t| Free Mem: $FREE_MEM MB\t| Load: $LOAD\t| iow: $IOW\t| Top Tables: $INNOTOP_OUT\033[m" | tee -a $LOG_FILE
echo -e "`date "+%F %T"`\n-------------------" >> $HIGH_QUERIES
$MYSQL_CLIENT -BN -u$DB_USER -p$DB_PASS information_schema -e "select TIME, STATE, INFO from PROCESSLIST where INFO is not NULL order by TIME desc limit 10" >> $HIGH_QUERIES 2>/dev/null
echo -en "\n" >> $HIGH_QUERIES
elif  [[ "$COUNT" -ge "$ERROR" ]]
then
echo -e "| Process Count: \033[1;5;31m$COUNT\t| Free Mem: $FREE_MEM MB\t| Load: $LOAD\t| iow: $IOW\t| Top Tables: $INNOTOP_OUT\033[m" | tee -a $LOG_FILE
echo -e "`date "+%F %T"`\n-------------------" >> $HIGH_QUERIES
$MYSQL_CLIENT -BN -u$DB_USER -p$DB_PASS information_schema -e "select TIME, STATE, INFO from PROCESSLIST where INFO is not NULL order by TIME desc limit 10" >> $HIGH_QUERIES 2>/dev/null
echo -en "\n" >> $HIGH_QUERIES
else
if [ "$DEBUG" -eq 1 ]
then
echo -e "| Process Count: $COUNT\t| Free Mem: $FREE_MEM MB\t| Load: $LOAD\t| iow: $IOW\|t| Top Tables: $INNOTOP_OUT" | tee -a $LOG_FILE
echo -e "`date "+%F %T"`\n-------------------" >> $HIGH_QUERIES
$MYSQL_CLIENT -BN -u$DB_USER -p$DB_PASS information_schema -e "select TIME, STATE, INFO from PROCESSLIST where INFO is not NULL order by TIME desc limit 10" >> $HIGH_QUERIES 2>/dev/null
echo -en "\n" >> $HIGH_QUERIES
else
echo -e "| Process Count: $COUNT\t| Free Mem: $FREE_MEM MB\t| Load: $LOAD\t| iow: $IOW" | tee -a $LOG_FILE
fi
fi

sleep $SLEEP_TIME
done
rm -f ${PIDFILE}
}

RMP_CHECK_PATH=' /tmp/proc_rpm_check.txt'
if [ ! -f  $RMP_CHECK_PATH ]
  then 
    echo "seems this is the first time you are using this script . checking prerequisites:" 
    RPM_STATUS=$(rpm -qa |grep innotop )
    if [ -z $RPM_STATUS ] 
      then
	    mkdir /var/log/proc
        echo  -e  "\033[1;33m innotop is not installed on the server Please install it by using \033[1;32myum install innotop\033[m \033[m"
        read  -n1 -p "If you want  to install  innotop automatically  please enter 'y ' otherwise please enter 'n'? (y/n):"  INSTALL_INPUT
        if [[ "$INSTALL_INPUT" = "y" || "$INSTALL_INPUT" = "Y"  ]]
          then
            printf '\n'
            yum install innotop -y
			if [ $? -eq 0 ]
				then 
				touch  ${RMP_CHECK_PATH}
				chattr +i ${RMP_CHECK_PATH}
				echo "prerequisites is OK"
				RUN=1
				else
				echo "Installing pckages entered in failed status. Please install it manually"
				RUN=0
			fi 
          else
            printf '\n'
            echo "Good Bye!"
            RUN=0
        fi
    else
      touch  ${RMP_CHECK_PATH}
      chattr +i ${RMP_CHECK_PATH}
      echo "prerequisites is OK"
	  RUN=1
    fi
  else
    RUN=1
fi
if [ $RUN -eq 1 ]
  then
    INNOTOP=`which innotop`
    INNOTOP="$INNOTOP -u$DB_USER -p$DB_PASS"
    clear
    fproc
  else
    exit 1
fi 
