# Phicomm k3 netatalk timemachine

斐讯(Phicomm) K3路由器官方Root固件，使用Netatalk支持AFP传输及Time Machine备份。

修改了/etc/passwd和/etc/group,增加/etc/shadow，恢复了linux的权限管理功能。

# 注意

- 安装后，请使用`echo "admin:password"|chpasswd`来改密码。

- 安装后，请勿使用`passwd`改密码！

- 安装后，SSH密码与网页密码会隔离，互不影响。

# 安装

1. 下载`start.sh`，放到`/root/netatalk`目录中。
2. 执行`chmod +x /root/netatalk/start.sh`。
3. 接下来根据实际情况修改`/root/netatalk/start.sh`。
4. 执行`/root/netatalk/start.sh init`。

# 用法

- 初始化：`/root/netatalk/start.sh init`。一次就好，请勿重复初始化。
- 启动：`/root/netatalk/start.sh start`
- 停止：`/root/netatalk/start.sh stop`
- 重新启动：`/root/netatalk/start.sh stop`