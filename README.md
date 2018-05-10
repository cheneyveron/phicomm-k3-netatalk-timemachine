# Phicomm k3 netatalk timemachine

斐讯(Phicomm) K3路由器官方Root固件，使用Netatalk支持AFP传输及Time Machine备份。

修改了/etc/passwd和/etc/group,增加/etc/shadow，恢复了linux的权限管理功能。

# 注意

## SSH密码

- 安装后，请使用`echo "admin:password"|chpasswd`来改密码。

- 安装后，请勿使用`passwd`改密码！

- 安装后，SSH密码与网页密码会隔离，互不影响。

## 拯救SSH密码

如果你不小心用了passwd改密码，或者没读注意事项就自信上手了，导致SSH连不上。

1. 请在U盘/硬盘第一个分区中放置一个没有扩展名的文件，名为`k3_safe_mode`，然后重启路由器。
2. 这样路由器开机以后就会覆盖挂载/root，此时的SSH密码就是你的`Web页面`密码了。
3. 进入SSH后，再执行`umount -l /root`即可显示出原本的`/root`内容。
4. 覆盖挂载/etc：`mount --bind /root/etc /etc`。
5. 把admin的密码改为password：`echo "admin:password"|chpasswd`。

当然啦，更推荐的方式是使用密钥登录，这样无论怎么改，都可以顺利通过验证：）

## 移动硬盘分区格式

- Netatalk建议，用于Tima Machine的AFP容器中仅放置Time Machine备份，因为Netatalk进行容量计算时仅会读取Time Machine备份卷的大小，从而导致卷的大小超过设定的值。

- 装AFP容器的分区不能格式化为NTFS格式，AFPD会无权限创建文件。

- 目前唯一可行的方法是分区格式化为ext*格式，AFP容器路径指定为/root下的文件夹，然后用`mount --bind /source /destination`将移动硬盘的分区覆盖挂载到这个文件夹下。

- 由于ext4默认在Windows和Mac下均不可读写，所以建议单独分一个ext4区备份，其他区格式化成NTFS放数据。

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