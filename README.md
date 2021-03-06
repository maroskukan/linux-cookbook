# Linux Cookbook

- [Linux Cookbook](#linux-cookbook)
  - [Boot Process](#boot-process)
    - [Emergecy Mode](#emergecy-mode)
    - [Password Recovery](#password-recovery)
    - [Default Kernel](#default-kernel)
    - [Default Target](#default-target)
  - [Services](#services)
    - [Service Unit File](#service-unit-file)
    - [Managing Services](#managing-services)
  - [Networking](#networking)
  - [Date and Time](#date-and-time)
  - [Tools](#tools)
    - [Input-output Redirection](#input-output-redirection)
    - [Text analysis](#text-analysis)
    - [Archiving and Compressing](#archiving-and-compressing)
    - [System logs](#system-logs)

## Boot Process

### Emergecy Mode

In order to enter emergency mode or target press `e` at default grub entry. Then append `systemd.unit=emergecy.targed` to kernel line (contains `vmlinuz` keyword). Press `Ctrl-x` to finish booting. Once booted provide root password, once maintenance is completed press `Ctrk+d` to finish the boot process.

### Password Recovery

At main grub entry, press `e`. And append `rd.break` to kernel line (contains `vmlinuz` keyword). Press `Ctrl-x` to finish booting. Press `Ctrl-X` to boot. After boot System automatically mounts the existing root file system in read only mode at `/sysroot`. You need to remount using read write mode. Afterwards, change the root file system path and update the root password.

```bash
# Verify existing mount settings
mount | grep sysroot
/dev/mapper/rhel-root on /sysroot type dxfs (ro,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota)

# Mount sysroot using read write mode
mount -o remount,rw /sysroot

# Change root file system to /sysroot
chroot /sysroot

# Update root password
passwd

# Finally SElinux needs to update files on next reboot
touch /.autorelabel

# Exit chroot shell
exit

# exit password recovery
exit
```

Once the `selinux-autorelabel` is completed the machine is restarted and you can log in using newly set password.

### Default Kernel

When you have multiple kernels available you can change which one is selected by default using `grub2-set-default` command.

```bash
sudo grub2-set-default 1
```

### Default Target

```bash
# Display the current default target e.g graphical.target
systemctl get-default

# Change default target
systemctl set-default multi-user.target
```


## Services

Services in Linux are often referred to as daemons. In modern Linux distributions `systemd` is usually responsible for managing other services and is the first process that is started.

### Service Unit File

In order to display service unit file's state you can use the following command:

```bash
# State options:
#               enabled = starts automatically at boot
#               disabled = will not start automatically at boot
#               static = service is not enabled
systemctl list-unit-files -at service
```

To retrieve more information about enabled (running and not running) service:

```bash
systemctl list-units -at service [--state running]
```

To view unit file for a service

```bash
systemctl cat rsyslog
# /usr/lib/systemd/system/rsyslog.service
[Unit]
Description=System Logging Service
;Requires=syslog.socket
Wants=network.target network-online.target
After=network.target network-online.target
Documentation=man:rsyslogd(8)
Documentation=https://www.rsyslog.com/doc/

[Service]
Type=notify
EnvironmentFile=-/etc/sysconfig/rsyslog
ExecStart=/usr/sbin/rsyslogd -n $SYSLOGD_OPTIONS
UMask=0066
StandardOutput=null
Restart=on-failure

# Increase the default a bit in order to allow many simultaneous
# files to be monitored, we might need a lot of fds.
LimitNOFILE=16384

[Install]
WantedBy=multi-user.target
;Alias=syslog.service
```

To view service status:

```bash
systemctl status rsyslog
```

### Managing Services

```bash
# Stop a service
systemctl stop atd.service

# Start a service
systemctl start atd

# Verify service status
systemctl status atd
systemctl is-active atd

# Restart a service
systemctl restart atd

# ( Disallow | Allow ) service from starting
systemctl ( mask | unmask ) atd

# ( Disable | Enable ) automatic start at boot
systemctl (disable | enable ) atd

# Verify if service automatic start is enabled
systemctl is-enabled atd
```


## Networking

To update system name:

```bash
hostnamectl set-hostname linux.example.com
```

To update network settings

```bash
# Menu based settings
nmtui

# CLI based settings
nmcli con mod ens192 ipv4.addresses 192.168.1.10/24
nmcli con mod ens192 ipv4.gateway 192.168.1.1
nmcli con mod ens192 ipv4.dns "1.1.1.1 1.0.0.1"
nmcli con mod ens192 ipv4.method manual
nmcli con up ens192

# Configuration file
vi /etc/sysconfig/network-scripts/ifcfg-ens192
```

## Date and Time

```bash
timedatectl

# Enable NTP
timedatectl set-ntp yes

# Display all timezones
timedatectl list-timezones

# Set timezone
timedatectl set-timezone America/Sao_Paulo
```

## Tools

### Input-output Redirection

Unnamed pipe `|` sends output of one command as input to another.

```bash
ip add show dev eth0 | grep global
```

Redirect can change the default output  `>` (overwrite), `>>` (append) for STDOUT  and `2>`, `2>>` for STDERR or all output `&>` pr `&>>` from screen to filesystem.

In order to send output to a file and screen:

```bash
# -a option appends to a file
ls | tee [-a] lsout.txt

# Finds all files in etc/ folder, redirect STDERR to file, sorts, prints and saves files to result and prints number of lines
find /etc 2> etcerr.txt | sort | tee etcsort.txt | wc -l

# Redirect STDOUT and STDERR to Sinkhole
find /etc &> /dev/null
```

You can also redirect file into a command input (STDIN) using `<`.

```bash
sort < /home/lsout.txt > /home/sorted.txt
```

### Text analysis

Grep utility is one of the most popular tools when it comes to analyzing text. It supports basic as well as extended regular expressions. Some common command line options include:

- `-i` - Ignore case
- `-v` - Invert search
- `-c` - Counts match results
- `-o` - Only characters that match
- `-r` - Read files recursively
- `-E` - Use extended regular expression

Below are some examples:

```bash
# Case Insitive Search
grep -i 'root' /etc/passwd

# Find all files ending with .txt that contain apache in their name
find / -name *.txt | grep apache

# Exlcude empty lines using anchors (^,$) and -v (invert) option
grep -v '^$' /etc/ssh/sshd_config

# Character class placement
grep 'user[0-9]' file.txt
grep 'user[[:digit:]]' file.txt
grep 'user[[:digit:][:spaces:]]' file.txt

# Negating Character Class
grep 'user[![:digit:]]' file.txt

# Basic regular expression
grep '^http.*tcp.*services$' /etc/services

# Exnteded regular expression
egrep '^http.*(tcp|udp).*service$' /etc/services
grep -E '^http.*(tcp|udp).*service$' /etc/services
```

### Archiving and Compressing

```bash
# Create archive, preserve extended attributes (ACL,SElinux security context)
# verbose, save ownership and permission
tar --xattrs -cvpf etc.tar /etc

# Retrieve archive size
du -h etc.tar
32M     etc.tar

# Archive and compres with gzip, display size
tar --gzip --xattrs -cpf etc.tar.gz /etc && du -h etc.tar.gz
7.6M    etc.tar.gz

# Archive and compress with bzip, display size
tar --bzip2 --xattrs -cpf etc.tar.bz2 /etc && du -h etc.tar.bz2
5.9M    etc.tar.bz2

# Archive and compress with xz, display size
sudo tar --xz --xattrs -cpf etc.tar.xz /etc && du -h etc.tar.xz
5.2M    etc.tar.xz

# Display archive contents
tar -tf etc.tar
tar --gzip -tf etc.tar.gz
tar --bzip2 -tf etc.tar.bz2
tar --xz -tf etc.tar.xz

# Extract archive contents in current folder and in a specific one
tar --xattrs -xvpf etc.tar
tar --xattrs -xvpf etc.tar -C ~/Downloads
```

Is it also possible to use `gzip` directly, without `tar`. Same approach works for `bzip2`, `xz` and `zip`.

```bash
# Display size before compression
du -h services
680K    services

# Compress file
gzip services

# Display size after compression
du -h services.gz
140K    services.gz

# Unzip file
gunzip services.gz
```

### System logs

There are two logging systems by default, rsyslog and journald.

**rsyslog**

- Compatible with syslogd
- Persistent logs
- Logs are text files
- Can log remotely

```bash
# Verify rsyslog status
systemctl status rsyslog

# Configuration file describing log rules
cat /etc/rsyslog.conf

# Display log messages excluding systemd
grep -v 'systemd' /var/log/messages

# Follow new messages
tail -f /var/log/messages

# Log rotation cron job and settings
cat /etc/cron.daily/logrotate
cat /etc/logrotate.conf

# Writing a log message
logger "My custom log message"
```

**journald**

- Part of systemd
- Nonpresistent by default
- Logs are binary
- Logs in to RAM `/var/run`
- Very fast

```bash
# View all entries
journalctl

# View kernel entries
journalctl -k

# View cron command entries
journalctl /sbin/crond

# View systemd unit entries
journalctl -u crond

# Follow new messages
journalctl -f

# Storing logs persistently
mkdir -p /var/log/journal
systemctl restart systemd-journald

# View contents of journal directory
ll /var/log/journal
total 0
drwxr-xr-x. 2 root root 28 Mar 15 11:47 75eca5b7822e46a2b16e7ffca28ad943

# Filter entries by date and time
journalctl --since "2022-02-22 22:22:22"
journalctl --since "2022-02-22" --until "2022-02-28"
journalctl --since yesterdat
journalctl --since 09:00 --until "1 hour ago"
```