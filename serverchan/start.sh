#!/bin/sh
# ver: 2017-05-10 by tianbaoha

SCKEY=XXXXXXX

WAN_IP=1
TEMP=1
TEMP_N=85
PC_NEW=1
PC_ON_OFF=1


# check interval (1-59)min
interval=10

# disable time (00-24)hour
disable_begin=6
disable_end=16

dir=/media/nand/serverchan
dirt=/var/tmp
staf=/tmp/serverchan_on
rcf=/opt/etc/init.d/S98serverchan
cronf=/var/spool/cron/crontabs/admin
img_url=http://oofxy4e74.bkt.clouddn.com
server=http://sc.ftqq.com

check_network() {
  curl -s $server
  if [ "$?" = "0" ]; then
    ntpclient -sh clock.fmt.he.net
    DT=`date '+%Y-%m-%d %H:%M:%S'`
  else
    echo "network error"
    exit
  fi
}

get_ip() {
  IP=`curl -s http://members.3322.org/dyndns/getip 2>/dev/null` || IP=`curl -s http://1212.ip138.com/ic.asp 2>/dev/null | grep -Eo '([0-9]+\.){3}[0-9]+'` || IP=`curl http://whatismyip.akamai.com/ 2>/dev/null`
  case "$IP" in
    [1-9][0-9]*)
      echo "$IP"
    ;;
  esac
}

check_ip() {
  lastIP=`cat $dir/IP 2>/dev/null`
  IP=`get_ip`
  if [ "$IP" != "$lastIP" -a -n "$IP" ]; then
    text="\[K3\]-WAN-IP"
    desp="$DT
####Wan IP address has changed
####New IP: $IP
[![k3]($img_url/phicomm.png \"k3\")](http://$LAN_IP)"
    api_post "$text" "$desp" && echo "$IP" > $dir/IP
  fi
}

get_arp() {
  echo "K3" > $dirt/ARP
  arp -a | sed 's/[()]//g;/incomplete/d' | grep "${LAN_IP%.*}\." | awk '{print "IP: "$2," MAC: "$4}' >> $dirt/ARP
}

api_post() {
  curl -s "$server/$SCKEY.send?text=$1" -d "desp=$2"
}

check_temp() {
  T_CPU=`awk '/CPU/ {printf substr($4,1,length($4)-2)}' /proc/dmu/temperature 2>/dev/null` || T_CPU=00
  T_2G=`wl -i eth1 phy_tempsense 2>/dev/null | awk '{printf $1}'`
  T_5G=`wl -i eth2 phy_tempsense 2>/dev/null | awk '{printf $1}'`
  [ -z "$T_2G" ] && T_2G=00
  [ -z "$T_5G" ] && T_5G=00
  if [ "$T_CPU" -gt "$TEMP_N" -o "$T_2G" -gt "$TEMP_N" -o "$T_5G" -gt "$TEMP_N" ]; then
    UP2=`cat $dirt/UP 2>/dev/null` || UP2=0
    if [ "$(expr $UP1 - $UP2)" -gt "1700" ]; then
      text="\[K3\]-TEMP"
      desp="$DT
####Temperature Warning:
####CPU: ${T_CPU}℃  2.4G: ${T_2G}℃  5G: ${T_5G}℃
[![temp]($img_url/k3-02.jpg \"k3\")](http://$LAN_IP)"
      api_post "$text" "$desp" && echo "$UP1" > $dirt/UP
    fi
  fi
}

check_pc_new() {
  get_arp
  [ ! -s "$dir/PC_DB" ] && echo "K3" > $dir/PC_DB
  awk 'NR==FNR{a[$0]++} NR>FNR&&a[$0]' $dir/PC_DB $dirt/ARP > $dirt/PCTMP
  awk 'NR==FNR{a[$0]++} NR>FNR&&!a[$0]' $dirt/PCTMP $dirt/ARP > $dirt/PC_NEW
  if [ -s "$dirt/PC_NEW" ]; then
    text="\[K3\]-NEW-DEVICE"
    desp="$DT
####New Device Join:
`cat $dirt/PC_NEW | grep -v "^$" | sed 's/^/######/g'`
[![k3]($img_url/phicomm.png \"k3\")](http://$LAN_IP)"
    api_post "$text" "$desp" && cat $dirt/PC_NEW | grep -v "^$" >> $dir/PC_DB
  fi
}

check_smart_status() {
SMARTSTATS=`smartctl --all -d sat -i /dev/sda|sed -n 's/SMART overall-health self-assessment test result: \(.*\)/\1/p'`
echo "$SMARTSTATS"
if [ "$SMARTSTATS"x != "PASSED"x ];then
      text="\[K3\]-S.M.A.R.T-${SMARTSTATS}"
      desp="$DT
####Device Smart: ${SMARTSTATS}"
      api_post "$text" "$desp"
fi
}

check_pc_on_off() {
  get_arp
  [ ! -s "$dir/PC_ON" ] && echo "K3" > $dir/PC_ON
  awk 'NR==FNR{a[$0]++} NR>FNR&&a[$0]' $dir/PC_ON $dirt/ARP > $dirt/PCTMP
  awk 'NR==FNR{a[$0]++} NR>FNR&&!a[$0]' $dirt/PCTMP $dirt/ARP > $dirt/NEW_ON
  if [ -s "$dirt/NEW_ON" ]; then
    text="\[K3\]-Device-On-line"
    desp="$DT
####Device On-line:
`cat $dirt/NEW_ON | grep -v "^$" | sed 's/^/######/g'`
[![k3]($img_url/phicomm.png \"k3\")](http://$LAN_IP)"
    api_post "$text" "$desp" && cat $dirt/NEW_ON | grep -v "^$" >> $dir/PC_ON
  fi
  awk 'NR==FNR{a[$0]++} NR>FNR&&!a[$0]' $dirt/ARP $dir/PC_ON > $dirt/PC_OFF
  if [ -s "$dirt/PC_OFF" ]; then
    text="\[K3\]-Device-Off-line"
    desp="$DT
####Device Off-line:
`cat $dirt/PC_OFF | grep -v "^$" | sed 's/^/######/g'`
[![k3]($img_url/phicomm.png \"k3\")](http://$LAN_IP)"
    api_post "$text" "$desp" && cat $dirt/ARP | grep -v "^$" > $dir/PC_ON
  fi
}

monitor(){
  if [ "$(grep -c serverchan_check $cronf)" != "1" ];then
    sed -i '/serverchan_check/d' $cronf
    echo "*/$interval * * * * $dir/start.sh check >/dev/null 2>&1 # serverchan_check" >> $cronf
    killall crond
    crond
  fi
}

startup() {
  sed -i '/serverchan_start/d' /opt/started_script.sh
  rm -rf $rcf
  if [ "$1" = "on" ]; then
  [ -x "/opt/etc/init.d/rc.unslung" ] && ln -sf $dir/start.sh $rcf || echo "sleep 30 && $dir/start.sh start >/dev/null 2>&1 # serverchan_start" >> /opt/started_script.sh
  fi
}

start() {
  monitor
  D_D=`date +%k`
  [ "$D_D" -lt "$disable_begin" -o "$D_D" -ge "$disable_end" ] && echo "Have some rest" && return
  UP1=`awk -F. '{print $1}' /proc/uptime`
  [ "$UP1" -le "500" ] && echo "$UP1 less then 500" && return
  check_network
  check_smart_status
  LAN_IP=`nvram get lan_ipaddr`
  #[ "$WAN_IP" = "1" ] && check_ip
  [ "$TEMP" = "1" ] && check_temp
  #[ "$PC_NEW" = "1" ] && check_pc_new
  #[ "$PC_ON_OFF" = "1" ] && check_pc_on_off
}

stop() {
  rm -rf $staf
  sed -i '/serverchan_check/d' $cronf
  killall crond
  crond
}

send_test() {
  local text desp
  text=$1
  desp=$2
  case "$text" in
    info)
      api_post "System-Info"  "`date '+%Y-%m-%d %H:%M:%S'`
`inittb info | sed 's/^/######/g'`"
      return
    ;;
  esac
  [ -z "$text" -o -z "$desp" ] && echo "Usage: $0 send text desp" && return
  api_post "$text" "$desp"
}

case "$1" in
  start)
    touch $staf
    startup on
    start
  ;;
  stop)
    startup
    stop
    echo "stoped"
  ;;
  restart)
    [ -f "$staf" ] && {
      stop
      touch $staf
      startup on
      start
    } || echo "start first"
  ;;
  check)
    [ -f "$staf" ] && start >/dev/null 2>&1
  ;;
  send)
    send_test "$2" "$3"
  ;;
  *)
  echo "Usage: $0 [start stop restart]"
  ;;
esac
