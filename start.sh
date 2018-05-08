#/bin/sh

dir=/root/netatalk
cronf=/var/spool/cron/crontabs/admin

createPri(){
echo "creating passwd and shdow and group"
# modify /etc/passwd
/bin/cat <<EOM >/etc/passwd
admin:x:0:0:Administrator:/root:/bin/sh
root:x:0:0:root:/root:/bin/sh
support:x:0:0:Technical Support:/:/bin/false
user:*:101:101:Normal User:/:/bin/false
tmuser:x:1000:1001:user for timemachine:/:/bin/false
nobody:*:65534:65534:nobody:/:/bin/false
EOM
# modify /etc/shadow
/bin/cat <<EOM >/etc/shadow
admin:$1$2etwQ.0k$clahXj54YnqHClpg84r0W1:17659:0:99999:7:::
root:*:0:0:99999:7:::
support:*:0:0:99999:7:::
user:*:0:0:99999:7:::
tmuser:$1$rcgsFiYh$B4IIfLPVeDEELKmkOzeR..:17659:0:99999:7:::
nobody:*:0:0:99999:7:::
EOM
# modify /etc/group
/bin/cat <<EOM >/etc/group
root::0:root,admin,support
users:x:100:
nogroup:x:65534:
timemachine:x:1000:tmuser
EOM
}
mountEtc(){
echo "mounting etc"
/bin/rm -rf /tmp/media/nand/etc2
/bin/cp /etc /tmp/media/nand/etc2 -r
/bin/rm -f /tmp/media/nand/etc2/crontabs
/bin/rm -f /tmp/media/nand/etc2/dropbear
/bin/rm -f /tmp/media/nand/etc2/passwd
/bin/rm -f /tmp/media/nand/etc2/group
/bin/cp /tmp/media/nand/etc/* /tmp/media/nand/etc2/ -r
/bin/rm -rf /tmp/media/nand/etc
/bin/mv /tmp/media/nand/etc2 /tmp/media/nand/etc
/bin/mount --bind /tmp/media/nand/etc /etc
}

init(){
echo "start initializing"
# tell which etc
/bin/touch /tmp/media/nand/etc/nandetc
# /etc not mounted
/usr/bin/[ ! -e /etc/nandetc ] && {
mountEtc
}
# shadow not exists
/usr/bin/[ ! -e /etc/shadow ] && {
createPri
}
#install netatalk and avahi-utils
opkg update && opkg install netatalk avahi-utils
# write afp.conf
/bin/rm -rf /etc/afp.conf-opkg
/bin/cat <<EOM >/etc/afp.conf
[Global]
 mimic model = TimeCapsule6,106
 uam path = /opt/lib/uams
 uam list = uams_dhx.so uams_dhx2.so

[TimeMachine]
 path = /backups
 time machine = yes
 vol size limit = 250000
 valid users = @timemachine
EOM
UUID=`/bin/cat /proc/sys/kernel/random/uuid`
/bin/cat <<EOM >/etc/avahi/services/afpd.service
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
 <name replace-wildcards="yes">%h</name>
  <service>
   <type>_afpovertcp._tcp</type>
   <port>548</port>
  </service>
  <service>
   <type>_device-info._tcp</type>
   <port>0</port>
   <txt-record>model=TimeCapsule</txt-record>
  </service>
  <service>
   <type>_adisk._tcp</type>
   <port>9</port>
   <txt-record>sys=waMa=0,adVF=0x100,adVU=${UUID}</txt-record>
   <txt-record>dk0=adVN=TimeMachine,adVF=0x81</txt-record>
  </service>
</service-group>
EOM
/bin/chown -R tmuser:timemachine /etc/afp.conf
/bin/chmod -R 777 /etc/afp.conf
/bin/chown -R tmuser:timemachine /etc/avahi/
/bin/chmod -R 777 /etc/avahi/
# modify dbus config
/bin/sed -i s/netdev/timemachine/g /etc/dbus-1/system.d/avahi-dbus.conf
# start services
/etc/init.d/*dbus restart
/etc/init.d/*cnid_metad restart
/etc/init.d/*avahi-daemon restart
/etc/init.d/*afpd restart
/usr/bin/[ -z "$(grep netatalk_start /opt/started_script.sh)" ] /bin/echo "$dir/start.sh start >/dev/null 2>&1 # netatalk_start" >> /opt/started_script.sh
/usr/bin/[ -z "$(grep netatalk_check $cronf)" ] /bin/echo "*/30 * * * * $dir/start.sh check >/dev/null 2>&1 # netatalk_check" >> $cronf #30minutes check once
}

start(){
# if mounted /etc
/usr/bin/[ ! -e /etc/nandetc ] && /bin/mount --bind /tmp/media/nand/etc /etc
# if still dont have nandetc
/usr/bin/[ ! -e /etc/nandetc ] && {
    /bin/echo "initializing before start!"
    init
}
# wait for usb to mount
sleep 30
/etc/init.d/*dbus restart
/etc/init.d/*cnid_metad restart
/etc/init.d/*avahi-daemon restart
/etc/init.d/*afpd restart
}

check(){
# if not mounted /etc
/usr/bin/[ ! -e /etc/nandetc ] && /bin/mount --bind /tmp/media/nand/etc /etc
# if still dont have nandetc
/usr/bin/[ ! -e /etc/nandetc ] && {
    /bin/echo "please init before check!"
    init
}
# empty cnid_metad
/usr/bin/[ -z "$(ps | grep cnid_metad | grep -v grep)" ] && /etc/init.d/*cnid_metad restart
# empty dbus-daemon 
/usr/bin/[ -z "$(ps | grep dbus-daemon | grep -v grep)" ] && /etc/init.d/*dbus restart
# empty avhi-daemon 
/usr/bin/[ -z "$(ps | grep avahi-daemon | grep -v grep)" ] && /etc/init.d/*avahi-daemon restart
# empty afpd
/usr/bin/[ -z "$(ps | grep afpd | grep -v grep)" ] && /etc/init.d/*afpd restart
}

stop(){
/etc/init.d/*dbus stop
/etc/init.d/*cnid_metad stop
/etc/init.d/*avahi-daemon stop
/etc/init.d/*afpd stop
}

# if installed opkg
/usr/bin/[ ! -e /opt/bin/opkg ] && {
    /bin/echo "install entware first!"
    exit
}

case "$1" in
  start)
    start
    echo "started"
  ;;
  stop)
    stop
    echo "stoped"
  ;;
  re|restart)
    stop
    echo "stoped"
    start
    echo "started"
  ;;
  init)
    init
    echo "inited"
  ;;
  check)
    check
    echo "checked"
  ;;
esac