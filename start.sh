#/bin/sh

# 本程序目录
dir=/root/netatalk
# 定时任务文件路径
cronf=/var/spool/cron/crontabs/admin
# 用作备份的硬盘挂载点
device=/tmp/share/sda2
# Time Machine 登录用户
tmuser=tmuser
# Time Machine 用户组
tmgroup=timemachine
# SSH admin账号密码
# 此后SSH密码与网页隔离，互不影响
# 修改密码请使用chpasswd，方法：
# echo "admin:password"|chpasswd
# !!!请勿使用passwd修改密码,会导致SSH登录不上!!!
adminpass=admin
# Time Machine 用户的密码
tmuserpass=tmuser
# Time Machine 容量（单位GB，最大容量，与实际硬盘容量无关）
tmcap=250

createPri(){
  echo "creating passwd and shdow and group"
  encadminpass=`openssl passwd -1 ${password}`
  enctmuserpass=`openssl passwd -1 ${password}`
# modify /etc/passwd
/bin/cat <<EOM >/etc/passwd
admin:x:0:0:Administrator:/root:/bin/sh
root:x:0:0:root:/root:/bin/sh
support:x:0:0:Technical Support:/:/bin/false
user:*:101:101:Normal User:/:/bin/false
${tmuser}:x:1000:1001:user for ${tmgroup}:/:/bin/false
nobody:*:65534:65534:nobody:/:/bin/false
EOM
# modify /etc/shadow
/bin/cat <<EOM >/etc/shadow
admin:${encadminpass}:17659:0:99999:7:::
root:*:0:0:99999:7:::
support:*:0:0:99999:7:::
user:*:0:0:99999:7:::
${tmuser}:${enctmuserpass}:17659:0:99999:7:::
nobody:*:0:0:99999:7:::
EOM
# modify /etc/group
/bin/cat <<EOM >/etc/group
root::0:root,admin,support
users:x:100:
nogroup:x:65534:
${tmgroup}:x:1000:${tmuser}
EOM
}
mountEtc(){
  echo "mounting etc"
  # tell which etc
  /usr/bin/[ ! -e /etc/nandetc ] && {
    /bin/touch /tmp/media/nand/etc/nandetc
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
}
mountNetatalk(){
  echo "mounting /opt/var/Netatalk"
  # tell which netatalk
  /usr/bin/[ ! -e /opt/var/netatalk/.sda ] && {
    umount -l /opt/var/netatalk
    /bin/rm -rf ${device}/opt/var/netatalk
    /bin/mkdir -p ${device}/opt/var
    /bin/cp /opt/var/netatalk/* ${device}/opt/var/netatalk -r
    /bin/touch ${device}/opt/var/netatalk/.sda
    /bin/mount --bind ${device}/opt/var/netatalk /opt/var/netatalk
  }
}
mountDest(){
  echo "mounting /root/backups/tm1"
  mkdir -p /tmp/media/nand/backups/tm1
  # tell which tm1
  /usr/bin/[ ! -e /tmp/media/nand/backups/tm1/.sda ] && {
    /bin/mkdir -p ${device}/backups/tm1
    /bin/touch ${device}/backups/tm1/.sda
    /bin/mount --bind ${device}/backups/tm1 /tmp/media/nand/backups/tm1
    chown -R ${tmuser}:${tmgroup} /tmp/media/nand/backups/tm1
    chmod -R 777 /tmp/media/nand/backups/tm1
  }
}

init(){
  echo "start initializing"
  # mount /etc 
  mountEtc
  # if no usb disk
  /usr/bin/[ ! -e ${device} ] && {
    /bin/echo "conntect usb device first!"
    exit
  }
  # mount netatalk
  mountNetatalk
  # mount backup destination
  mountDest
  # write localhost to /etc/hosts
  /usr/bin/[ -z "$(grep localhost /etc/hosts)" ] /bin/echo "127.0.0.1 localhost" >> /etc/hosts
  # shadow not exists
  /usr/bin/[ ! -e /etc/shadow ] && {
    createPri
  }
  #install netatalk and avahi-utils
  opkg update && opkg install netatalk avahi-utils
  # write afp.conf
  /bin/rm -rf /etc/afp.conf-opkg
  realcap=$((tmcap*953))
/bin/cat <<EOM >/etc/afp.conf
[Global]
 mimic model = TimeCapsule6,106
 uam path = /opt/lib/uams
 uam list = uams_dhx.so uams_dhx2.so

[TimeMachine]
 path = /tmp/media/nand/backups/tm1
 time machine = yes
 vol size limit = ${realcap}
 valid users = @${tmgroup}
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
  /bin/chown -R ${tmuser}:${tmgroup} /etc/afp.conf
  /bin/chmod -R 777 /etc/afp.conf
  /bin/chown -R ${tmuser}:${tmgroup} /etc/avahi/
  /bin/chmod -R 777 /etc/avahi/
  # modify dbus config
  /bin/sed -i s/netdev/${tmgroup}/g /etc/dbus-1/system.d/avahi-dbus.conf
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
  /usr/bin/[ -z "$(grep netatalk_start /opt/started_script.sh)" ] /bin/echo "$dir/start.sh start >/dev/null 2>&1 # netatalk_start" >> /opt/started_script.sh
  /usr/bin/[ -z "$(grep netatalk_check $cronf)" ] /bin/echo "*/30 * * * * $dir/start.sh check >/dev/null 2>&1 # netatalk_check" >> $cronf #30minutes check once
  /usr/bin/[ -z "$(grep localhost /etc/hosts)" ] /bin/echo "127.0.0.1 localhost" >> /etc/hosts #30minutes check once
  # wait for usb to mount
  sleep 30
  # if no usb disk
  /usr/bin/[ ! -e ${device}/backups ] && {
    /bin/echo "conntect usb device first!"
    stop
    exit
  }
  # if not mounted /opt/var/netatalk
  /usr/bin/[ ! -e /opt/var/netatalk/.sda ] && {
    /bin/mount --bind ${device}/opt/var/netatalk /opt/var/netatalk
  }
  # tell which tm1
  /usr/bin/[ ! -e /tmp/media/nand/backups/tm1/.sda ] && /bin/mount --bind ${device}/backups/tm1 /tmp/media/nand/backups/tm1
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
  # if no usb disk
  /usr/bin/[ ! -e ${device}/backups ] && {
    /bin/echo "conntect usb device first!"
    stop
    exit
  }
  # if not mounted /opt/var/netatalk
  /usr/bin/[ ! -e /opt/var/netatalk/.sda ] && {
    /bin/mount --bind ${device}/opt/var/netatalk /opt/var/netatalk
  }
  # tell which tm1
  /usr/bin/[ ! -e /tmp/media/nand/backups/tm1/.sda ] && /bin/mount --bind ${device}/backups/tm1 /tmp/media/nand/backups/tm1
  /usr/bin/[ -z "$(grep netatalk_start /opt/started_script.sh)" ] /bin/echo "$dir/start.sh start >/dev/null 2>&1 # netatalk_start" >> /opt/started_script.sh
  /usr/bin/[ -z "$(grep netatalk_check $cronf)" ] /bin/echo "*/30 * * * * $dir/start.sh check >/dev/null 2>&1 # netatalk_check" >> $cronf #30minutes check once
  /usr/bin/[ -z "$(grep localhost /etc/hosts)" ] /bin/echo "127.0.0.1 localhost" >> /etc/hosts
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
  /etc/init.d/*avahi-daemon stop
  /etc/init.d/*afpd stop
  /etc/init.d/*dbus stop
  /etc/init.d/*cnid_metad stop
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