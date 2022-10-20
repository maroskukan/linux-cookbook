# Linux Cookbook

- [Linux Cookbook](#linux-cookbook)
  - [Boot Process](#boot-process)
    - [Emergency Mode](#emergency-mode)
    - [Password Recovery](#password-recovery)
      - [Option A](#option-a)
      - [Option B](#option-b)
    - [Default Kernel](#default-kernel)
    - [Default Target](#default-target)
  - [Service Control](#service-control)
    - [Service Unit File](#service-unit-file)
    - [Managing Services](#managing-services)
  - [Networking](#networking)
  - [Date and Time](#date-and-time)
  - [Tools](#tools)
    - [Input-output Redirection](#input-output-redirection)
    - [Text analysis](#text-analysis)
    - [Searching](#searching)
    - [Archiving and Compressing](#archiving-and-compressing)
    - [System logs](#system-logs)
  - [Managing Software](#managing-software)
    - [Package managers](#package-managers)
      - [RPM](#rpm)
      - [DNF](#dnf)
  - [Kernel](#kernel)
    - [Runtime management](#runtime-management)
    - [Documentation](#documentation)
    - [Kernel Files](#kernel-files)
    - [Initial RAM disk](#initial-ram-disk)
      - [Initrd](#initrd)
      - [Initramfs](#initramfs)
    - [Development packages](#development-packages)
    - [Compilation](#compilation)
  - [Device Drivers](#device-drivers)
  - [Tips](#tips)
    - [SSH Session Hangout](#ssh-session-hangout)

## Boot Process

### Emergency Mode

In order to enter emergency mode or target press `e` at default grub entry. Then append `systemd.unit=emergecy.targed` to kernel line (contains `vmlinuz` keyword). Press `Ctrl-x` to finish booting. Once booted provide root password, once maintenance is completed press `Ctrk+d` to finish the boot process.

### Password Recovery

#### Option A

In order to stop the boot process at `initramfs`. Press `e` at the main grub entry and append `rd.break` to kernel line (contains `vmlinuz` keyword). Press `Ctrl-x` to finish booting. Press `Ctrl-X` to boot. After boot System automatically mounts the existing root file system in read only mode at `/sysroot`. You need to remount using read write mode. Afterwards, change the root file system path and update the root password.

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

#### Option B

Once again, you need to stop the boot process at `initramfs`. Press `e` at the main grub entry and append `rd.break` and `enforcing=0` to the line containing `vmlinuz` keyword. Press `Ctrl+x` to continue the boot process.

> **Info**: You can optionally remove the `rhgb` and `quiet` arguments.

```bash
# Mount sysroot using read write mode
mount -o remount,rw /sysroot

# Change root file system to /sysroot
chroot /sysroot

# Update root password and exit chroot
passwd ; exit

# Mount sysroot using read-only mode and exit
mount -o remount,ro /sysroot ; exit
```

Once you log as `root` with new password, restore the SElinix security context of the `/etc/shadow` from `unlabeled_t` to `shadow_t`.

```bash
# Restore the context for /etc/shadow
restorecon -v /etc/shadow

# Update SElinux configuration from Permissive to Enforcing
setenforce 1
```


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


## Service Control

Services in Linux are often referred to as daemons. In modern Linux distributions `systemd` is responsible for managing other services and is the first process that is started by kernel.

Alternatives to Systemd include OpenRC, s6, SysVinit, Upstart and more.

In order to quickly determine which one is used, look at first process.

```bash
# Output from Centos 6.10
ps -fp 1
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 20:00 ?        00:00:00 /sbin/init

# Output from Centos 7.x
ps -fp 1
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  1 20:13 ?        00:00:01 /usr/lib/systemd/systemd --switched-root --system --deserialize 22
```


### Service Unit File

Systemd uses unit files. In order to display service unit file's state you can use the following command:

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

Tee is especially useful when you need to perform a redirection using `sudo`. For example, consider this scenario:

```bash
sudo echo '127.0.0.1 bhole' >> /etc/hosts
```

You will receive a `Permission denied` error because the redirection falls back to standard user permission. To resolve this you can use `tee`.

```bash
echo '127.0.0.1   bhole' | sudo tee -a /etc/hosts
```

You can also redirect file into a command input (STDIN) using `<`.

```bash
sort < /home/lsout.txt > /home/sorted.txt
```

Named pipe care often used for inter process communications. To create a named pipe use the `mkfifo` command.

```bash
mkfifo mypipe

stat -c %F $_
fifo
```

To test this pipe, open a another terminal session and send some STDOUT to the pipe.

```bash
ls > mypipe
```

On the first session, read the pipe content:

```bash
wc -l < mypipe
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
# Case Insensitive Search
grep -i 'root' /etc/passwd

# Find all files ending with .txt that contain apache in their name
find / -name *.txt | grep apache

# Exclude empty lines using anchors (^,$) and -v (invert) option
grep -v '^$' /etc/ssh/sshd_config

# Character class placement
grep 'user[0-9]' file.txt
grep 'user[[:digit:]]' file.txt
grep 'user[[:digit:][:spaces:]]' file.txt

# Negating Character Class
grep 'user[![:digit:]]' file.txt

# Basic regular expression
grep '^http.*tcp.*services$' /etc/services

# Extended regular expression
egrep '^http.*(tcp|udp).*service$' /etc/services
grep -E '^http.*(tcp|udp).*service$' /etc/services
```


### Searching

Find utility is great for locating files and folders based on text patterns.

Below are some examples:

```bash
# Find all files ending with .pdf in /usr/share/doc folder and sub-folders
# and print them (default action)
find /usr/share/doc -name '*.pdf' -print

# Find all files ending with .pdf in /usr/share/doc folder and sub-folders
# and copy them to current directory
find /usr/share/doc -name '*.pdf' -exec cp {} . \;

# Find all files ending with .pdf in current directory and sub-sub-directories
# and delete them
find -name '*.pdf' -delete

# Find all symlinks in the /etc directory
find /etc -maxdepth 1 -type l

# Find all files with size larger then 10M and print their size
find /boot -size +10000k -type f -exec du -h {} \;
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


## Managing Software

### Package managers

The difference between repository based package managers such as (`apt`, `yum`, `dnf`) and software installation tools such as `dpkg` and `rpm` is that the installation tools handles installation and managers handle searching and downloading software from repository and handle any dependencies.


#### RPM

Qeurying database

```bash
# Query RPM Database
rpm -qa

# Query specific package
rpm -qi bash

# Query list of file paths for package
rpm -ql yum

# Query a list of documentation file paths for package
rpm -qd yum

# Query a list of configuration file paths for package
rpm -qc yum

# Query file to determine the source package
rpm -qf /bin/bash

# Query for features that a package provides
rpm -q --provides bash

# Query package dependencies
rpm -q --requires bash

# Query package changes
rpm -q --changelog bash
```

Inspecing a package

```bash
# Download packaged and dependencies
dnf download httpd --resolve

# Inspect a package
rpm -qip httpd-*
rpm -qlp httpd-*
```

#### DNF

Originially `YUM` package manager was created for Yellow Dog Linux and was later enhanced and named `DNF` which became the default package manager since RHEL8. The benefit of DNF is that it resolves the package dependencies automatically. It also supports package groups (e.g. `Develoment Tools`).

Repositories contain RPM packages and client maintains local list of repositories.

```bash
# Display the configured software repositories
dnf repolist
Updating Subscription Management repositories.
repo id                                   repo name
rhel-8-for-x86_64-appstream-rpms          Red Hat Enterprise Linux 8 for x86_64 - AppStream (RPMs)
rhel-8-for-x86_64-baseos-rpms             Red Hat Enterprise Linux 8 for x86_64 - BaseOS (RPMs)

# Show duplicates, in repos, in list/search commands
dnf --showduplicates list firewalld-0.9.3-7*


# List a package or groups of packages
dnf list --all | head
Last metadata expiration check: 14:01:38 ago on Tue 15 Mar 2022 07:38:34 PM CET.
Installed Packages
GConf2.x86_64                                          3.2.6-22.el8                                        @AppStream
ModemManager.x86_64                                    1.10.8-4.el8                                        @anaconda
ModemManager-glib.x86_64                               1.10.8-4.el8                                        @anaconda
NetworkManager.x86_64                                  1:1.32.10-4.el8                                     @anaconda
NetworkManager-adsl.x86_64                             1:1.32.10-4.el8                                     @anaconda
NetworkManager-bluetooth.x86_64                        1:1.32.10-4.el8                                     @anaconda
NetworkManager-config-server.noarch                    1:1.32.10-4.el8                                     @anaconda

# List installed packages
dnf list --installed

# List installed packages for which udpate exists
dnf list --updates

# List packages available in repository but not installed
dnf list --available

# Display details about a package or group of packages
dnf info firewalld
Last metadata expiration check: 14:06:03 ago on Tue 15 Mar 2022 07:38:34 PM CET.
Installed Packages
Name         : firewalld
Version      : 0.9.3
Release      : 7.el8
Architecture : noarch
Size         : 2.0 M
Source       : firewalld-0.9.3-7.el8.src.rpm
Repository   : @System
From repo    : anaconda
Summary      : A firewall daemon with D-Bus interface providing a dynamic firewall
URL          : http://www.firewalld.org
License      : GPLv2+
Description  : firewalld is a firewall service daemon that provides a dynamic customizable
             : firewall with a D-Bus interface.

Available Packages
Name         : firewalld
Version      : 0.9.3
Release      : 7.el8_5.1
Architecture : noarch
Size         : 502 k
Source       : firewalld-0.9.3-7.el8_5.1.src.rpm
Repository   : rhel-8-for-x86_64-baseos-rpms
Summary      : A firewall daemon with D-Bus interface providing a dynamic firewall
URL          : http://www.firewalld.org
License      : GPLv2+
Description  : firewalld is a firewall service daemon that provides a dynamic customizable
             : firewall with a D-Bus interface.

# List package's dependencies and what packages provide them
dnf repoquery --deplist firewalld
```

Managing packege groups.

```bash
# List installed and available package groups
dnf group list [--all | --installed | --hidden]
Last metadata expiration check: 14:10:13 ago on Tue 15 Mar 2022 07:38:34 PM CET.
Available Environment Groups:
   Server
   Minimal Install
   Workstation
   Virtualization Host
   Custom Operating System
Installed Environment Groups:
   Server with GUI
Installed Groups:
   Container Management
   Headless Management
Available Groups:
   RPM Development Tools
   .NET Core Development
   Scientific Support
   Smart Card Support
   Security Tools
   Development Tools
   Legacy UNIX Compatibility
   Network Servers
   Graphical Administration Tools
   System Tools

# Display information about a group
dnf group info "Development Tools"
```

Search for a package.

```bash
dnf search firewalld
```

Install and remove a package or package group.

```bash
# Install package
dnf install -y tree

# Uninstall package
dnf remove tree

# Uninstall unused dependencies
dnf autoremove tree

# Reinstall package
dnf reinstall tree

# Upgrade package
dnf upgrade firewalld
```


## Kernel

### Runtime management

In order to retrieve details about current running kernel use the `uname` command. It supports various options such as `-s` for Kernel name, `-n` for computer name. Full list can be displayed using `--help`.

```bash
uname -a
Linux centos6.localdomain 2.6.32-754.35.1.el6.x86_64 #1 SMP Sat Nov 7 12:42:14 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux
```

The arguments are useful in situations, where you need to refer to current running kernel. For example the following command displays the kernel options that were configured.

```bash
cat /boot/config-$(uname -r)
```

It uses the `/proc/version` as backend for retrieving this information.

In order to view options that were supplied to kernel at boot time, view the `/proc/cmdline` file.

```bash
cat /proc/cmdline
ro root=/dev/mapper/vg_centos6-lv_root rd_NO_LUKS LANG=en_US.UTF-8 rd_LVM_LV=vg_centos6/lv_swap net.ifnames=0 biosdevname=0 elevator=noop no_timer_check  rd_NO_MD SYSFONT=latarcyrheb-sun16 crashkernel=129M@48M rd_LVM_LV=vg_centos6/lv_root  KEYBOARDTYPE=pc KEYTABLE=us rd_NO_DM rhgb quiet
```

### Documentation

For rpm based systems the kernel documentation is available through the `kernel-doc` package. Once installed the docs are available at `/usr/share/doc/kernel-doc-$(uname -r | cut -d"-" -f1)/Documentation`

For Ubuntu the documentation is installed with the kernel source code.

Finally, the web based version is avaialble at [kernel.org](https://www.kernel.org/doc/)


### Kernel Files

The kernel files are located in `/boot` directory.

Here you an find the compressed kernel `vmlinuz-$(uname -r)`. In order to get more detail about compression used use `file` command.

```bash
file /boot/vmlinuz-2.6.32-754.35.1.el6.x86_64
/boot/vmlinuz-2.6.32-754.35.1.el6.x86_64: Linux kernel x86 boot executable bzImage, version 2.6.32-754.35.1.el6.x86_64 (moc, RO-rootFS, swap_dev 0x4, Normal VGA
```


### Initial RAM disk

The Initial RAM disk is also located in this folder. It is responsible for loading a temporary root file system during the boot processs. It allows for the real root fs to be checked and modules to be loaded.

There are two types of Initial RAM disks:

#### Initrd

The `initrd` used prior to kernel 2.6.13 , is compressed file-system image mounted through `/dev/ram`. The file-system module used in initrd must be compiled into the kernel, ofthen `ext2` but some use `cramfs`.

As you can see below Ubuntu 5.04 (2.6.10) uses initial RAM disk `initrd` as our Initial RAM disk:

```bash
sudo -i
file /boot/initrd.img-$(uname -r)
initrd.img-2.6.10-5-amd64-generic: Linux Compressed ROM File System data, little endian size 4083712 version #2 sorted_dirs CRC 0x36ffcfdc, edition 0, 2807 blocks, 289 files
```

Since this is a file system by itself, we can access files by mounting it using `mount`.

```bash
sudo -i
mount -t sysfs /boot/initrd.img-$(uname -r) /mnt
ls /mnt
block  bus  class  devices  firmware  kernel  module  power
```

#### Initramfs

The `initramfs` used with kernel 2.6.13 onwards. This is `cpio` archive which is unpacked by kernel to `tmpfs` which becomes the initial root file system. Does not require file system or block device drivers to be compiled into the kernel.

As you can see below Centos 6 uses initial RAM File System `initramfs` as our Initial RAM disk:

```bash
sudo -i
file /boot/initramfs-$(uname -r).img
/boot/initramfs-2.6.32-754.35.1.el6.x86_64.img: gzip compressed data, from Unix, last modified: Tue Oct  4 02:30:14 2022, max compression
```

Upon copying this file and adding a `.gz` extension it can be decompressed.

```bash
cp /boot/initramfs-$(uname -r).img /tmp/initramfs-$(uname -r).img.gz
gunzip /tmp/initramfs-$(uname -r).img.gz
```

Now we can extract the content using `cpio`.

```bash
mkdir /tmp/init
cd /tmp/init
cpio -id < ../initramfs-$(uname -r).img

ls
bin      dracut-004-411.el6  init                initqueue-settled  lib64    pre-mount    pre-udev  sys      usr
cmdline  emergency           initqueue           initqueue-timeout  mount    pre-pivot    proc      sysroot  var
dev      etc                 initqueue-finished  lib                netroot  pre-trigger  sbin      tmp
```


### Development packages

The `kernel-devel` package provides kernel headers and makefiles for building kernel modules. After installation, these are located under `/usr/src/kernels/$(uname -r)` folder.

### Compilation

In order to compile a kernel we first need to download and unpack the source code.

```bash
wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.9.9.tar.xz
sudo tar -Jxvf linux-3.9.9.tar.xz -C /usr/src/kernels
```
> Note: Running the `wget` in CentOS 6.10 I had to include `--no-check-certificate` argument to download the kernel source files.

Next, we need to creata symlink for the `/usr/src/linux` to point to this directory.

```bash
sudo ln -s /usr/src/kernels/linux-3.9.9 /usr/src/linux
```

Next, we need to install `Development Tools` group package and `ncurses-devel`, `bc` package.

```bash
sudo yum groupinfo "Development Tools"
sudo yum groupinstall -y "Development Tools"
sudo yum install -y ncurses-devel bc
```

The process for compiling a kernel is as follows:

1. Navigate to `/usr/src/linux` folder
2. Clean the environment with `make clean` or `make mrproper`
3. Configure kernel options with `make menuconfig`
4. Compile the kernel `make bzImage`
5. Compile the loadable modules with `make modules`
6. Copy modules to correct directory with `make modules_install`
7. Copy kernel to `/boot` create initramfs and update Grub config with `make install`

> Note: I recommend to follow above steps with root prileges, for example using interactive session with `sudo -i`

Once completed, verify the Grub configuration at `/etc/grub.conf`. There should be new entry corresponding to new kernel which you can select in boot menu. When happy copy it to `/boot/grub/grub.cfg` to ensure it is picked up on next boot.

> Note: In order to add support for Hyper-V host, in step 3, you need to include some more [flags](https://dietrichschroff.blogspot.com/2013/03/hyper-v-compile-linux-kernel-with.html).


## Device Drivers

Device drivers often referred to as modules are loaded as required into the running kernel. The currently loaded modules can be seen using `lsmod` command wich uses `/proc/modules` as backend. The `modprobe -l` lists all available modules.

To load a module you can use `modprobe` following with a name of the module. You can also specify an module option (e.g. `modprobe -v sr_mod xa_test=1`). In order to persist this change you need to create a new file in `/etc/modprobe.d/sr_mod.conf` with content of `options sr_mod xa_test=1` for example.

To unload use `modprobe` with `-r` argument following with a name of the module.

To view module dependencies and options use `modinfo` following with a name of the module. In order to display the loaded module options values, use in case of `sr_mod` module `cat /sys/module/sr_mod/parameters/xa_test`.


## Tips

### SSH Session Hangout

To close an unresponsive SSH session where your terminal hangs, press `Enter` and then type `~.`. The session closes immediately returning you back to prompt.
