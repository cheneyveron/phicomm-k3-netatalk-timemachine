#/bin/sh

init(){
# tell which etc
/bin/touch /tmp/media/nand/etc/nandetc
# /etc not mounted
/usr/bin/[ ! -e /etc/nandetc ] && {
# mount /etc
/bin/rm -rf /tmp/media/nand/etc2
/bin/cp /etc /tmp/media/nand/etc2 -r
/bin/rm -f /tmp/media/nand/etc2/crontabs
/bin/rm -f /tmp/media/nand/etc2/dropbear
/bin/cp /tmp/media/nand/etc/* /tmp/media/nand/etc2/ -r
/bin/rm -rf /tmp/media/nand/etc
/bin/mv /tmp/media/nand/etc2 /tmp/media/nand/etc
/bin/mount --bind /tmp/media/nand/etc /etc
}
# shadow exists
/usr/bin/[ -e /etc/shadow ] && {
    /bin/echo "begining to reintialize /etc/passwd and /etc/group and /etc/shadow!"
}
/bin/echo "echo \"Please use \\\"echo 'admin:passwd'|chpasswd\\\" instead!\"" > /tmp/media/nand/netatalk/passwd
/bin/mount --bind /tmp/media/nand/netatalk/passwd /usr/bin/passwd
# modify /etc/passwd
/bin/echo "admin:x:0:0:Administrator:/root:/bin/sh" > /etc/passwd
/bin/echo "root:x:0:0:root:/root:/bin/sh" >> /etc/passwd
/bin/echo "support:x:0:0:Technical Support:/:/bin/false" >> /etc/passwd
/bin/echo "user:*:101:101:Normal User:/:/bin/false" >> /etc/passwd
/bin/echo "tmuser:x:1000:1001:user for timemachine:/:/bin/false" >> /etc/passwd
/bin/echo "nobody:*:65534:65534:nobody:/:/bin/false" >> /etc/passwd
# modify /etc/shadow
/bin/echo "admin:$1$MRBDY0Tt$wR4WrrZnlMmS6z3syhHAy1:17659:0:99999:7:::" > /etc/shadow # admin
/bin/echo "root:*:0:0:99999:7:::" >> /etc/shadow
/bin/echo "support:*:0:0:99999:7:::" >> /etc/shadow
/bin/echo "user:*:0:0:99999:7:::" >> /etc/shadow
/bin/echo "tmuser:$1$MRBDY0Tt$wR4WrrZnlMmS6z3syhHAy1:17659:0:99999:7:::" >> /etc/shadow # admin
/bin/echo "nobody:*:0:0:99999:7:::" >> /etc/shadow
# modify /etc/group
/bin/echo "root::0:root,admin,support" > /etc/group
/bin/echo "users:x:100:" >> /etc/group
/bin/echo "nogroup:x:65534:" >> /etc/group
/bin/echo "timemachine:x:1000:tmuser" >> /etc/group
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
}

start(){
# disable passwd
/bin/echo "echo \"Please use \\\"echo 'admin:passwd'|chpasswd\\\" instead!\"" > /tmp/media/nand/netatalk/passwd
/bin/mount --bind /tmp/media/nand/netatalk/passwd /usr/bin/passwd
# if mounted /etc
/usr/bin/[ ! -e /etc/nandetc ] && /bin/mount --bind /tmp/media/nand/etc /etc
# wait for usb to mount
sleep 10
/etc/init.d/*dbus restart
/etc/init.d/*cnid_metad restart
/etc/init.d/*avahi-daemon restart
/etc/init.d/*afpd restart
}

check(){
# if mounted /etc
/usr/bin/[ ! -e /etc/nandetc ] && /bin/mount --bind /tmp/media/nand/etc /etc
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

case "$1" in
  start)
    start >/dev/null 2>&1
    echo "started"
  ;;
  stop)
    stop >/dev/null 2>&1
    echo "stoped"
  ;;
  re|restart)
    stop >/dev/null 2>&1
    echo "stoped"
    start >/dev/null 2>&1
    echo "started"
  ;;
  init)
    init >/dev/null 2>&1
    echo "inited"
  ;;
  check)
    check >/dev/null 2>&1
    echo "checked"
  ;;
esac