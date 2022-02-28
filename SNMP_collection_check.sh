#!/bin/bash
#################################
#  Author: Hamed Maleki
#  Date: 2019-02-26
#       notes:
#       Expected device type are : mikrotik,cpe,radio
#       In all conditions we should create graph for three interface (LAN,WAN,L2TP) becuase there is possible ECS team change devices and we need an unique standard to create same graph for all devices no matter how many interfaces they have.
#       if the desier intefaces are exist, I show the interface values, if not, I create output to show zero value for graph. a standard for all devices reduce overhead for me, you,software team and ...
#       mikrotik: have 5 physical interface named ether1 to ether5 with at least on virtual interface for tunnel with is l2tp-out. the first interface in /tmp/ether.txt is WAN which is the interface that connected to our network.
#       The Second one is LAN which is connected to customer network. and finally l2tp-out presents tunnel and its traffic.
#       Radio: Radio devices have two types (mmd,radio). mmd devices are same as regular mikrotiks and have 5 ethers and possible virtual l2tp interface. Radios have multiple interfaces such as WLAN, in this type of device we monitor Only 
#       one interface which is "ether1". other interfaces are not important in this project. but I'm adding two extra output to the graph part (after pupline) becuse the above standart I mentioned. 
#       CPE: CPE Devices have some parameters to monitor. some of them such as ports status, their traffic and device uptime are monitoring in regular intervall but some of them have no frequent change and some of the are fixed
#       so I'm monitoring them in some intervalls. there current intervalls are 5 minutes and 24 hour. you can change them as needed 
#       MMD and mikrotik devices are typicaly RB750 
###################### Functions ######################
function debug () {
VAR=$1
if [ $DEBUG -eq 1 ] ; then echo "$VAR=`echo "${!VAR}" `";fi
}
function final_out_put () {
OUT_PUT_SERVICE=""
OUT_PUT_GRAPH="|"
case $DEVICE_TYPE in
        mmd750|mmd433|radio)
        LAN=$(echo $PORTS | awk -F ',' '{print $2}')
        WAN=$(echo $PORTS | awk -F ',' '{print $1}')
        L2TP=$(echo $PORTS | awk -F ',' '{print $3}')
        while read line
        do 
        if  [[ $line  == *"PORT_STATUS"* ]] && [[ $line  == *"Down"* ]]
        then 
        OUT_PUT_SERVICE+=$(echo "<font color=red>$(echo $line |awk -F'|' '{print $1}')</font>\n")
        elif [[ $line  == *"PORT_STATUS"* ]] && [[ $line  == *"UP"* ]]
        then 
        OUT_PUT_SERVICE+=$(echo "<font color=green>$(echo $line |awk -F'|' '{print $1}')</font>\n")
        else 
        OUT_PUT_SERVICE+=$(echo "$(echo $line |awk -F'|' '{print $1}')\n")
        fi
        done< <( grep -v -e "CHECK_SHORT_PERIOD" -e "CHECK_TIME_LONG_PERIOD" -e "NODE_STATUS" -e "STATUS_TIME" -e "DEVICE_TYPE" -e "COUNTER" $OUTPUT_FILE )
        for i in LAN L2TP WAN
        do
        if [ "w${!i}" == "w-" ] || [ "w${!i}" == "w" ]
        then 
        OUT_PUT_GRAPH+="${i}_in="0"Mbps;0 ${i}_out="0"Mbps;0"
        else
        OUT_CHECK=$(cat $OUTPUT_FILE  2> /dev/null| grep ${!i} 2>/dev/null| grep TRAFFIC | awk -F '|' '{print $2}' | sed "s/${!i}/$i/g")
        debug OUT_CHECK
        OUT_CHAR_COUNT=$(echo $OUT_CHECK |wc -L)
        debug OUT_CHAR_COUNT
        if [ $OUT_CHAR_COUNT -gt 1 ]
        then 
        OUT_PUT_GRAPH+="$OUT_CHECK"
        else 
        OUT_PUT_GRAPH+="${i}_in="0"Mbps;0 ${i}_out="0"Mbps;0"
        fi
        fi
        done
        ;;
        saf-integra|racom|netronics|nera)
        ether=$(echo $PORTS | awk -F ',' '{print $1}')
        OUT_PUT_GRAPH+="LAN_in="0"Mbps;0 LAN_out="0"Mbps;0 L2TP_in="0"Mbps;0 L2TP_out="0"Mbps;0" #### fake output
        while read line
        do 
        if  [[ $line  == *"PORT_STATUS"* ]] && [[ $line  == *"Down"* ]]
        then 
        OUT_PUT_SERVICE+=$(echo "<font color=red>$(echo $line |awk -F'|' '{print $1}')</font>\n")
        elif [[ $line  == *"PORT_STATUS"* ]] && [[ $line  == *"UP"* ]]
        then 
        OUT_PUT_SERVICE+=$(echo "<font color=green>$(echo $line |awk -F'|' '{print $1}')</font>\n")
        else 
        OUT_PUT_SERVICE+=$(echo "$(echo $line |awk -F'|' '{print $1}')\n")
        fi
        done< <( grep -v -e "CHECK_SHORT_PERIOD" -e "CHECK_TIME_LONG_PERIOD" -e "NODE_STATUS" -e "STATUS_TIME" -e "DEVICE_TYPE" -e "COUNTER" $OUTPUT_FILE )
        OUT_CHECK=$(cat $OUTPUT_FILE  2> /dev/null| grep ${ether} 2>/dev/null| grep TRAFFIC | awk -F '|' '{print $2}' |sed -e "s/${ether}/WAN/g" -e "s/$(echo $ether | tr [A-Z] [a-z])/WAN/g" )
        debug OUT_CHECK
        OUT_CHAR_COUNT=$(echo $OUT_CHECK |wc -L)
        debug OUT_CHAR_COUNT
        if [ $OUT_CHAR_COUNT -gt 1 ]
        then 
        OUT_PUT_GRAPH+="$OUT_CHECK"
        else 
        OUT_PUT_GRAPH+=" WAN_in="0"Mbps;0 WAN_out="0"Mbps;0"
        fi
        ;;
        cpe)
        while read line
        do 
        if  [[ $line  == *"PORT_STATUS"* ]] && [[ $line  == *"Down"* ]]
        then 
        OUT_PUT_SERVICE+=$(echo "<font color=red>$(echo $line |awk -F'|' '{print $1}')</font>\n")
        elif [[ $line  == *"PORT_STATUS"* ]] && [[ $line  == *"UP"* ]]
        then 
        OUT_PUT_SERVICE+=$(echo "<font color=green>$(echo $line |awk -F'|' '{print $1}')</font>\n")
        else 
        OUT_PUT_SERVICE+=$(echo "$(echo $line |awk -F'|' '{print $1}')\n")
        fi
        OUT_CHECK=$(echo $line | awk -F'|' '{print $2}')
        debug OUT_CHECK
        OUT_CHAR_COUNT=$(echo $OUT_CHECK |wc -L)
        debug OUT_CHAR_COUNT
        if [ $OUT_CHAR_COUNT -gt 1 ]
        then 
        OUT_PUT_GRAPH+="$OUT_CHECK"
        fi
        done< <( grep -v -e "CHECK_SHORT_PERIOD" -e "CHECK_TIME_LONG_PERIOD" -e "NODE_STATUS" -e "STATUS_TIME" -e "DEVICE_TYPE" -e "COUNTER" $OUTPUT_FILE )
        ;;
esac
debug OUT_PUT_SERVICE
debug OUT_PUT_GRAPH
echo -e "$OUT_PUT_SERVICE $OUT_PUT_GRAPH" 
}
function snmp_port_status () {
local action=$1

case $DEVICE_TYPE in  
        radio)
        local ether_list='ether1 l2tp-out'
        ;;
        mmd433)
        local ether_list='ether1 ether2 ether3 l2tp-out'
        ;;
        mmd750)
        local ether_list='ether1 ether2 ether3 ether4 ether5 l2tp-out'
        ;;
        saf-integra)
        local ether_list='LAN1 LAN2 LAN3 WAN'
        ;;
        nera)
        #local ether_list='wlan1 ether1 ether2 ether3 bridge-HotSpot l2tp-out1'
        local ether_list='eth0'
        ;;
esac

debug ether_list
if [ $action == check ]
        then 
        for i in $ether_list
        do 
        PORT_STATUS=$(eval $COMMANDS_PATH/snmp_port_status $HOST $COMMUNITY $i check )
        debug PORT_STATUS
        echo -e "PORT_STATUS_$i=$PORT_STATUS" >> $OUTPUT_FILE 
        done
        else 
        for i in $ether_list
        do 
        PORT_TRAFFIC=$(eval $COMMANDS_PATH/snmp_port_status $HOST $COMMUNITY $i traffic)
        debug PORT_TRAFFIC
        echo -e "PORT_TRAFFIC_$i=$PORT_TRAFFIC" >> $OUTPUT_FILE
        done
fi
}
function cpe_last_variables () {
CURRTIME=$(date +%s)
LAST_CHECK_SHORT_PERIOD=$(grep CHECK_SHORT_PERIOD  $OUTPUT_FILE 2>/dev/null |awk -F '=' '{print $2}')
if [ -z $LAST_CHECK_SHORT_PERIOD ] ; then LAST_CHECK_SHORT_PERIOD=$(date +%s -d "$$((SHORT_PERIOD + 1 )) minutes ago"); fi
debug LAST_CHECK_SHORT_PERIOD
LAST_CHECK_LONG_PERIOD=$(grep CHECK_TIME_LONG_PERIOD   $OUTPUT_FILE 2>/dev/null|awk -F '=' '{print $2}')
if [ -z $LAST_CHECK_LONG_PERIOD ] ; then LAST_CHECK_LONG_PERIOD=$(date +%s -d "$(($LONG_PERIOD + 1 )) hours ago"); fi
debug LAST_CHECK_LONG_PERIOD
LAST_RSSI=$(grep RSSI $OUTPUT_FILE 2>/dev/null | awk -F '=' '{print $2}')
debug LAST_RSSI
LAST_RSRP=$(grep RSRP $OUTPUT_FILE 2>/dev/null |awk -F '=' '{print $2}')
debug LAST_RSRP
LAST_RSRQ=$(grep RSRQ $OUTPUT_FILE 2>/dev/null | awk -F '=' '{print $2}')
debug LAST_RSRQ
LAST_SNR=$(grep SNR $OUTPUT_FILE 2>/dev/null | awk -F '=' '{print $2}')
debug LAST_SNR
LAST_TX_POWER=$(grep TX_POWER $OUTPUT_FILE 2>/dev/null | awk -F '=' '{print $2}')
debug LAST_TX_POWER
LAST_PRODUCT_NAME=$(grep PRODUCT_NAME $OUTPUT_FILE 2>/dev/null | awk -F '=' '{print $2}')
debug LAST_PRODUCT_NAME
LAST_SERIAL_NUMBER=$(grep SERIAL_NUMBER $OUTPUT_FILE 2>/dev/null | awk -F '=' '{print $2}')
debug LAST_SERIAL_NUMBER
LAST_IMEI=$(grep IMEI $OUTPUT_FILE  2>/dev/null  | awk -F '=' '{print $2}')
debug LAST_IMEI
LAST_IMSI=$(grep IMSI $OUTPUT_FILE   2>/dev/null | awk -F '=' '{print $2}')
debug LAST_IMSI
}
function packet_loss () {
local ip=$1
PACKET_LOSS=$( grep pl /tmp/.${ip}.txt 2>/dev/null | awk -F '=' '{print $2}')
if [ -z $PACKET_LOSS ]
 then
 PACKET_LOSS=0
fi 
debug PACKET_LOSS
}
function last_status_parameters () {
last_status=$(grep  NODE_STATUS $OUTPUT_FILE | awk  -F '=' '{print $2}')
debug last_status
last_status_change=$(grep STATUS_TIME $OUTPUT_FILE | awk  -F '=' '{print $2}') 
debug last_status_change
device_type=$(grep DEVICE_TYPE $OUTPUT_FILE | awk  -F '=' '{print $2}') 
debug device_type
counter=$(grep COUNTER $OUTPUT_FILE | awk  -F '=' '{print $2}') 
if [ -z $counter ] ; then counter=0 ; fi 
debug counter
}
function last_status_check () {
if [ ! -z $last_status ] && [ $NODE_STATUS -eq $last_status ]
then 
STATUS_TIME=$last_status_change
else 
STATUS_TIME=$EXECUTION_TIME
fi
debug STATUS_TIME
}
function device_type () {
local ip=$1
debug ip
if [ -z $device_type ] || [ $counter -le 0 ] || [ "w$device_type" == "wnone" ]
then 
DEVICE_TYPE=$(/usr/bin/device_type_finder $ip)
COUNTER=$DEV_COUNT
else
DEVICE_TYPE=$device_type
COUNTER=$(($counter - 1))
fi
debug DEVICE_TYPE
debug COUNTER
}
function data_writer () {
local writer_input=$@
if [ "w$writer_input" == "w-r" ]
then 
echo "DEVICE_TYPE=$DEVICE_TYPE"  >> $OUTPUT_FILE
echo "COUNTER=$COUNTER"  >> $OUTPUT_FILE
echo  "NODE_STATUS=$NODE_STATUS"  >> $OUTPUT_FILE
echo  "STATUS_TIME=$STATUS_TIME" >> $OUTPUT_FILE
else 
local output_field="$writer_input"
echo  "service_monitor,*$HOST_NAME,*$MAIN_IP,*$NODE_STATUS,*$output_field,*$OUT_PUT_SERVICE,*$EXECUTION_TIME,*$STATUS_TIME" | nc -U /usr/local/nagios/nagios_data_writer.sock 
#if [ $? -eq 0 ]
#then
#echo "$(date +"%F %T") sending data for host_name : $HOST_NAME" >> /tmp/hamed.log 
#else 
#echo "$(date +"%F %T") failed to send data for host_name : $HOST_NAME : $error" >> /tmp/hamed.log
#fi 
#echo  "$HOST_NAME*$MAIN_IP*$NODE_STATUS*$output_field*$OUT_PUT_SERVICE*$EXECUTION_TIME*$STATUS_TIME" >> "$MONITORING_PATH/service_check_b2b_${FILE_DATE}"
fi
}

########################## Script Body ################################
MAIN_IP=$1
HOST_NAME=$2
COMMUNITY=$3
SECONDARY_IP=$4
COMMANDS_PATH="/usr/local/nagios/libexec"
MONITORING_PATH='/var/log/monitoring_result'
PL_PATH='/var/log/ping_result'
PACKET_LOSS_THRESHOLD='3'
DEBUG=0
CONDITION="0"
MESSAGE=""
SHORT_PERIOD=5 # in minutes
LONG_PERIOD=24 # in hour
FILE_DATE=$(date +"%Y%m%d_%H%M%S")
DEV_COUNT=9

################### Checkin packet loss ############
packet_loss $MAIN_IP
if [ -z ${SECONDARY_IP} ] 
then 
        HOST=$MAIN_IP
elif [ ! -z ${SECONDARY_IP} ] && [ ${PACKET_LOSS} -ne 100 ] 
then 
        HOST=$MAIN_IP
elif [ ! -z ${SECONDARY_IP} ] && [ ${PACKET_LOSS} -eq 100 ] 
then
    HOST=$SECONDARY_IP
fi 
if [ "w$HOST" == "w$SECONDARY_IP" ]
then 
SECONDARY_MESSAGE=$(echo "Monitoring $HOST: ")
fi 

OUTPUT_FILE="/tmp/.${HOST}_SNMP_RESULT.txt"
if [ ! -f "$OUTPUT_FILE" ] ; then touch $OUTPUT_FILE ; fi 
PORTS=$(cat /tmp/ether.txt | awk -F '=' -v host=$HOST '$1==host {print $2}')
last_status_parameters

################### check if secondary IP is exists and decide which IP should be used for checking 


if [ "w$HOST" == "w$MAIN_IP" ] && [ $PACKET_LOSS -eq 100 ] 
then
        truncate -s0 $OUTPUT_FILE
        EXECUTION_TIME=$(date +'%F %T')
        NODE_STATUS=2
        last_status_check
        DEVICE_TYPE="none"
		COUNTER=0
        data_writer -r
        OUT_PUT_SERVICE="-"
        data_writer "Critical: Node is Down"
        echo "Critical: Node is Down "
        echo "| LAN_in=0Mbps;0 LAN_out=0Mbps;0 L2TP_in=0Mbps;0 L2TP_out=0Mbps;0 WAN_in=0Mbps;0 WAN_out=0Mbps;0"
        exit 2
elif  [[ $PACKET_LOSS -ge $PACKET_LOSS_THRESHOLD ]] && [ $PACKET_LOSS -lt 100 ]
then 
        MESSAGE+=" Packet loss is  $PACKET_LOSS %."
        CONDITION=$(($CONDITION + 5))
fi 
################### Checking important ports and device snmp parameters #############################
device_type $HOST
debug DEVICE_TYPE
truncate -s0 $OUTPUT_FILE
case $DEVICE_TYPE in 
        mmd750|mmd433|radio|saf-integra)
                snmp_port_status check
                snmp_port_status traffic
                UPTIME=$(eval $COMMANDS_PATH/check_uptime_human $COMMUNITY $HOST )
                echo -e "UPTIME=$UPTIME" >> $OUTPUT_FILE
                debug UPTIME
        ;;
        nera)
                COMMUNITY="public"
                snmp_port_status check
                snmp_port_status traffic
                UPTIME=$(snmpwalk -r 1 -t 1 -v2c -c $COMMUNITY $HOST sysUpTimeInstance | awk '{print $5" "$6" "$7}')
                echo -e "UPTIME=$UPTIME" >> $OUTPUT_FILE
                debug UPTIME
        ;;
        netronics) ### Use SNMP Version 1 
				COMMUNITY="netman"
                PORT_STATUS=$(eval $COMMANDS_PATH/netronics_port_status $HOST $COMMUNITY "Management" check )
                echo -e "PORT_STATUS_Management=$PORT_STATUS" >> $OUTPUT_FILE
                PORT_STATUS=$(eval $COMMANDS_PATH/netronics_port_status $HOST $COMMUNITY "radio" check )
                echo -e "PORT_STATUS_radio=$PORT_STATUS" >> $OUTPUT_FILE
                PORT_TRAFFIC=$(eval $COMMANDS_PATH/netronics_port_status $HOST $COMMUNITY "Management" traffic)
                echo -e "PORT_TRAFFIC_Management=$PORT_TRAFFIC" >> $OUTPUT_FILE
                PORT_TRAFFIC=$(eval $COMMANDS_PATH/netronics_port_status $HOST $COMMUNITY "radio" traffic)
                echo -e "PORT_TRAFFIC_radio=$PORT_TRAFFIC" >> $OUTPUT_FILE
                UPTIME=$(snmpwalk -r1 -t1 -v1 -c $COMMUNITY $HOST sysUpTimeInstance 2>&1| awk '{print $5,$6,$7}' |cut -d'.' -f1 )
                echo -e "UPTIME=$UPTIME" >> $OUTPUT_FILE
        ;;
        racom)
				COMMUNITY="racom-public"
                for i in p2_data_e1 p4_data_e2 p6_air
                do 
                PORT_STATUS=$(eval $COMMANDS_PATH/racom_port_status $HOST $COMMUNITY "$i" check )
                echo -e "PORT_STATUS_${i}=$PORT_STATUS" >> $OUTPUT_FILE
                done 
                for i in p2_data_e1 p4_data_e2 p6_air
                do
                PORT_TRAFFIC=$(eval $COMMANDS_PATH/racom_port_status $HOST $COMMUNITY "$i" traffic)
                echo -e "PORT_TRAFFIC_${i}=$PORT_TRAFFIC" >> $OUTPUT_FILE
                done 
                UPTIME=$(eval $COMMANDS_PATH/check_uptime_human $COMMUNITY $HOST )
                echo -e "UPTIME=$UPTIME" >> $OUTPUT_FILE
                ;;
                cpe)
        cpe_last_variables
        PORT_STATUS_LAN=$(eval $COMMANDS_PATH/check_cpe_port_status $HOST LAN $COMMUNITY)
        debug PORT_STATUS_LAN
        echo -e "PORT_STATUS_LAN=$PORT_STATUS_LAN" >> $OUTPUT_FILE
        PORT_STATUS_L2TP=$(eval $COMMANDS_PATH/check_cpe_port_status $HOST L2TP $COMMUNITY)
        debug PORT_STATUS_L2TP
        echo -e "PORT_STATUS_L2TP=$PORT_STATUS_L2TP" >> $OUTPUT_FILE
        TRAFFIC_LAN=$(eval $COMMANDS_PATH/check_traffic_cpe $HOST LAN $COMMUNITY)   
        debug TRAFFIC_LAN
        echo -e "TRAFFIC_LAN=$TRAFFIC_LAN" >> $OUTPUT_FILE
        TRAFFIC_L2TP=$(eval $COMMANDS_PATH/check_traffic_cpe $HOST L2TP $COMMUNITY)
        debug TRAFFIC_L2TP
        echo -e "TRAFFIC_L2TP=$TRAFFIC_L2TP" >> $OUTPUT_FILE
        THROUGHPUT=$(eval $COMMANDS_PATH/check_throughput_cpe $HOST $COMMUNITY) 
        debug THROUGHPUT
        echo -e "THROUGHPUT=$THROUGHPUT" >> $OUTPUT_FILE
################################ checking some parameters evey 5 minutes #########################
                if [[ $(expr $CURRTIME - $LAST_CHECK_SHORT_PERIOD) -gt $(( $SHORT_PERIOD * 60 )) ]]
                then
                RSSI=$(eval $COMMANDS_PATH/check_snmp -H $HOST -o .1.3.6.1.4.1.33908.1.1.42.3.17.0 -C $COMMUNITY |awk -F '"' '{print $2}' | head -n1) 
                debug RSSI
                echo -e "RSSI=$RSSI" >> $OUTPUT_FILE
                RSRP=$(eval $COMMANDS_PATH/check_snmp -H $HOST -o .1.3.6.1.4.1.33908.1.1.42.3.18.0 -C $COMMUNITY |awk -F '"' '{print $2}' | head -n1)
                debug RSRP
                echo -e "RSRP=$RSRP" >> $OUTPUT_FILE
                RSRQ=$(eval $COMMANDS_PATH/check_snmp -H $HOST -o .1.3.6.1.4.1.33908.1.1.42.3.19.0 -C $COMMUNITY |awk -F '"' '{print $2}' | head -n1)
                debug RSRQ
                echo -e "RSRQ=$RSRQ" >> $OUTPUT_FILE
                SNR=$(eval $COMMANDS_PATH/check_snmp -H $HOST -o .1.3.6.1.4.1.33908.1.1.42.3.20.0 -C $COMMUNITY |awk -F '"' '{print $2}' | head -n1)
                debug SNR
                echo -e "SNR=$SNR" >> $OUTPUT_FILE
                TX_POWER=$(eval $COMMANDS_PATH/check_snmp -H $HOST -o .1.3.6.1.4.1.33908.1.1.42.3.24.0 -C $COMMUNITY |awk -F '"' '{print $2}' | head -n1)
                debug TX_POWER
                echo -e "TX_POWER=$TX_POWER" >> $OUTPUT_FILE
                CHECK_SHORT_PERIOD=$CURRTIME
                debug CHECK_SHORT_PERIOD
                echo -e "CHECK_SHORT_PERIOD=$CHECK_SHORT_PERIOD" >> $OUTPUT_FILE     
                else 
                RSSI=$LAST_RSSI
                debug RSSI
                echo -e "RSSI=$RSSI" >> $OUTPUT_FILE
                RSRP=$LAST_RSRP
                debug RSRP
                echo -e "RSRP=$RSRP" >> $OUTPUT_FILE
                RSRQ=$LAST_RSRQ
                debug RSRQ
                echo -e "RSRQ=$RSRQ" >> $OUTPUT_FILE
                SNR=$LAST_SNR
                debug SNR
                echo -e "SNR=$SNR" >> $OUTPUT_FILE
                TX_POWER=$LAST_TX_POWER
                debug TX_POWER
                echo -e "TX_POWER=$TX_POWER" >> $OUTPUT_FILE
                CHECK_SHORT_PERIOD=$LAST_CHECK_SHORT_PERIOD
                debug CHECK_SHORT_PERIOD
                echo -e "CHECK_SHORT_PERIOD=$CHECK_SHORT_PERIOD" >> $OUTPUT_FILE
                fi
################################ checking some parameters evey 24 HOURS  #########################
        if [[ $(expr $CURRTIME - $LAST_CHECK_LONG_PERIOD) -gt $(( $LONG_PERIOD * 60 *60)) ]] 
        then
                        PRODUCT_NAME=$(eval $COMMANDS_PATH/check_snmp -H $HOST -o .1.3.6.1.4.1.33908.1.1.42.1.2.0 -C $COMMUNITY |awk -F '"' '{print $2}' | head -n1)
                        debug PRODUCT_NAME
                        echo -e "PRODUCT_NAME=$PRODUCT_NAME" >> $OUTPUT_FILE
                        SERIAL_NUMBER=$(eval $COMMANDS_PATH/check_snmp -H $HOST -o .1.3.6.1.4.1.33908.1.1.42.1.4.0 -C $COMMUNITY |awk -F '"' '{print $2}' | head -n1)
                        debug SERIAL_NUMBER
                        echo -e "SERIAL_NUMBER=$SERIAL_NUMBER"  >> $OUTPUT_FILE
                        IMEI=$(eval $COMMANDS_PATH/check_snmp -H $HOST -o .1.3.6.1.4.1.33908.1.1.42.3.5.0 -C $COMMUNITY |awk -F '"' '{print $2}' | head -n1)
                        debug IMEI
                        echo -e "IMEI=$IMEI" >> $OUTPUT_FILE
                        IMSI=$(eval $COMMANDS_PATH/check_snmp -H $HOST -o .1.3.6.1.4.1.33908.1.1.42.3.6.0 -C $COMMUNITY |awk -F '"' '{print $2}' | head -n1)
                        debug IMSI
                        echo -e "IMSI=$IMSI" >> $OUTPUT_FILE
                        CHECK_TIME_LONG_PERIOD=$CURRTIME
                        debug CHECK_TIME_LONG_PERIOD
                        echo -e "CHECK_TIME_LONG_PERIOD=$CHECK_TIME_LONG_PERIOD" >> $OUTPUT_FILE
                else 
                        PRODUCT_NAME=$LAST_PRODUCT_NAME
                        debug PRODUCT_NAME
                        echo -e "PRODUCT_NAME=$PRODUCT_NAME" >> $OUTPUT_FILE
                        SERIAL_NUMBER=$LAST_SERIAL_NUMBER
                        debug SERIAL_NUMBER
                        echo -e "SERIAL_NUMBER=$SERIAL_NUMBER"  >> $OUTPUT_FILE
                        IMEI=$LAST_IMEI
                        debug IMEI
                        echo -e "IMEI=$IMEI" >> $OUTPUT_FILE
                        IMSI=$LAST_IMSI
                        debug IMSI
                        echo -e "IMSI=$IMSI" >> $OUTPUT_FILE
                        CHECK_TIME_LONG_PERIOD=$LAST_CHECK_LONG_PERIOD
                        debug LAST_CHECK_LONG_PERIOD
                        echo -e "CHECK_TIME_LONG_PERIOD=$CHECK_TIME_LONG_PERIOD" >> $OUTPUT_FILE
                fi
        UPTIME=$(eval $COMMANDS_PATH/check_uptime_human_cpe $COMMUNITY $HOST)
        debug UPTIME
        echo -e "UPTIME=$UPTIME" >> $OUTPUT_FILE 
        ;;
        fiber)
                FILE_DATE=$(date +"%Y%m%d_%H%M%S")
                EXECUTION_TIME=$(date +'%F %T')
                MESSAGE+="Non SNMP support device"
                NODE_STATUS=0
                last_status_check
                data_writer -r 
                OUT_PUT_SERVICE="-"
                data_writer "${SECONDARY_MESSAGE}Service is OK: $MESSAGE"
                echo  "${SECONDARY_MESSAGE}Service is OK: $MESSAGE"
                echo "| LAN_in=0Mbps;0 LAN_out=0Mbps;0 L2TP_in=0Mbps;0 L2TP_out=0Mbps;0 WAN_in=0Mbps;0 WAN_out=0Mbps;0"
                exit 0
        ;;
                none)
                FILE_DATE=$(date +"%Y%m%d_%H%M%S")
                EXECUTION_TIME=$(date +'%F %T')
                MESSAGE+=" SNMP error."
                for i in `echo $PORTS |sed 's/,/ /g'` ; do MESSAGE+=" Port $i is warning."; done 
                NODE_STATUS=1
                last_status_check
                data_writer -r
                OUT_PUT_SERVICE="-"
                data_writer "${SECONDARY_MESSAGE}Warning: $MESSAGE"
                echo  "${SECONDARY_MESSAGE}Warning: $MESSAGE"
                echo "| LAN_in=0Mbps;0 LAN_out=0Mbps;0 L2TP_in=0Mbps;0 L2TP_out=0Mbps;0 WAN_in=0Mbps;0 WAN_out=0Mbps;0"
                exit 1
                ;;
esac 
########################## Checking ports to decide if status is warning/critical/ok or unknown  
for i in `echo $PORTS |sed 's/,/ /g'` 
do
        if [[ $i == *"l2tp-out"* ]]; then i=$(echo $i | sed 's/l2tp-out.*/l2tp-out/g') ; fi
        if [ "w$i" != "w-" ]
        then 
        if [[ `grep STATUS_$i  $OUTPUT_FILE 2>/dev/null` == *"UP"* ]] 
        then
        CONDITION=$(($CONDITION + 0))
        elif  [[ `grep STATUS_$i $OUTPUT_FILE 2>/dev/null` == *"Down"* ]]
        then
        MESSAGE+=" Port $i is Down."
        CONDITION=$(($CONDITION + 50))
        elif [[ `grep STATUS_$i  $OUTPUT_FILE 2>/dev/null` == *"Warning"* ]] || [[ w`grep STATUS_$i  $OUTPUT_FILE 2>/dev/null` == w ]]
        then
        MESSAGE+=" Port $i is warning."
        CONDITION=$(($CONDITION + 5))
        elif [[ `grep STATUS_$i  $OUTPUT_FILE 2>/dev/null` == *"Unknown"* ]]  
        then
        MESSAGE+=" Port $i is unknown."
        CONDITION=$(($CONDITION + 1000))
        else 
        MESSAGE=" Please check SNMP conditions"
        fi
        fi
done

FILE_DATE=$(date +"%Y%m%d_%H%M%S")
EXECUTION_TIME=$(date +'%F %T')
if [ $CONDITION -eq 0 ] 
then
        NODE_STATUS=0
        last_status_check
        data_writer -r 
        echo  "${SECONDARY_MESSAGE} Service is OK"
        final_out_put
                data_writer "${SECONDARY_MESSAGE}Service is OK"
        exit 0
elif [ $CONDITION -gt 0 ] && [ $CONDITION -lt 50 ]
then 
        NODE_STATUS=1
        last_status_check
        data_writer -r 
        echo  "${SECONDARY_MESSAGE}Warning: $MESSAGE"
        final_out_put
                data_writer "${SECONDARY_MESSAGE}Warning: $MESSAGE"
        exit 1
elif [ $CONDITION -ge 50 ] && [ $CONDITION -lt 1000 ]
then 
        NODE_STATUS=2
        last_status_check
                data_writer -r
        echo "$SECONDARY_MESSAGE Critical: $MESSAGE"
        final_out_put
                data_writer "${SECONDARY_MESSAGE}Critical: $MESSAGE"
        exit 2
 else 
        NODE_STATUS=3
        last_status_check
        data_writer -r 
        echo "Unknown: $MESSAGE"
        final_out_put
                data_writer "${SECONDARY_MESSAGE}Unknown: $MESSAGE"
        exit 3
fi
