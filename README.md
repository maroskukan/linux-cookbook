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
  - [Job Control](#job-control)
  - [Networking](#networking)
  - [Date and Time](#date-and-time)
  - [Tools](#tools)
    - [Input-output Redirection](#input-output-redirection)
    - [Text analysis](#text-analysis)
      - [Grep](#grep)
      - [Gawk](#gawk)
    - [Searching](#searching)
    - [Archiving and Compressing](#archiving-and-compressing)
    - [System logs](#system-logs)
  - [Managing Software](#managing-software)
    - [Package managers](#package-managers)
      - [RPM](#rpm)
      - [DNF](#dnf)
    - [Installation tools](#installation-tools)
      - [Dpkg](#dpkg)
  - [Kernel](#kernel)
    - [Runtime management](#runtime-management)
    - [Documentation](#documentation)
    - [Kernel Files](#kernel-files)
    - [Initial RAM disk](#initial-ram-disk)
      - [Initrd](#initrd)
      - [Initramfs](#initramfs)
    - [Development packages](#development-packages)
    - [Compilation](#compilation)
    - [Removal](#removal)
  - [Bootloader](#bootloader)
    - [Menu Style and Timeout](#menu-style-and-timeout)
  - [Power](#power)
    - [Gnome 43 specifics](#gnome-43-specifics)
    - [Lid action](#lid-action)
  - [Firmware](#firmware)
  - [UEFI BIOS](#uefi-bios)
    - [Verify](#verify)
    - [SecureBoot](#secureboot)
  - [Device Drivers](#device-drivers)
    - [Kernel Installation](#kernel-installation)
  - [Tips](#tips)
    - [SSH Session Hangout](#ssh-session-hangout)
    - [Bash Session Recording](#bash-session-recording)

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


## Job Control

In order to start a long running application in background, append `&` at the end of the line.

```bash
sleep 1000&
```

To list existing running jobs use `jobs` command. The following `+` sign displays the currently selected job. To put in in foreground just use `fg` command.

```bash
fg
```

In order to suspend a running job send control signal `SIGTSTP` using `CTRL-Z` also described as `^Z`.

In order to kill a running job send control signal `SIGINT` using `CTRL-C` also described as `^C`.

To list all available control signals use `stty -a`.

```bash
stty -a
speed 38400 baud; rows 96; columns 116; line = 0;
intr = ^C; quit = ^\; erase = ^?; kill = ^U; eof = ^D; eol = <undef>; eol2 = <undef>; swtch = <undef>; start = ^Q;
stop = ^S; susp = ^Z; rprnt = ^R; werase = ^W; lnext = ^V; flush = ^O; min = 1; time = 0;
-parenb -parodd -cmspar cs8 -hupcl -cstopb cread -clocal -crtscts
-ignbrk -brkint -ignpar -parmrk -inpck -istrip -inlcr -igncr icrnl ixon -ixoff -iuclc -ixany -imaxbel -iutf8
opost -olcuc -ocrnl onlcr -onocr -onlret -ofill -ofdel nl0 cr0 tab0 bs0 vt0 ff0
isig icanon iexten echo echoe echok -echonl -noflsh -xcase -tostop -echoprt echoctl echoke
```


## Networking

### Configuration

To update system name:

```bash
hostnamectl set-hostname linux.example.com
```

To update runtime settings you can use the `ip` command.

To update persistent network settings you can use `nmtui` or `nmcli`.

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


### Monitoring

Some traditional tools for monitoring and troubleshooting network activity include `ip`,  `ping`, `tracepath`, `ss` and `nmap`. Some newer tools like `mtr`.

```bash
# Display all available network interfaces
ip link show
```

```bash
# Display device address information
ip addr show eth0

# Display device summary
ip -br addr show eth0
```

```bash
# Display device statistics
ip -s link show eth0
```

```bash
# Check reachability
ping -c3 1.1.1.1
```

```bash
# Display routing table
ip route
```

```bash
# Trace network traffic
tracepath github.com
```

```bash
# Display socket statistics
ss -plunt
```

```bash
# Can localhost for open ports
nmap -sS localhost
```

```bash
# Path report with statistics
mtr --report -c 10 example.com
```


## Storage

### Block Devices

List block davices from `/dev`

```bash
find /dev -type b
```

List available block devices including their filesystem type.

```bash
lsblk --fs
```

List block device attributes.

```bash
blkid /dev/sda1
```

Display data utilization on root mountpoint.

```bash
df -h /
```

Display data utilization for a specific directory.

```bash
du -sh /usr
```

Summary of mountpoints and their respective options.

```bash
findmnt -s
```


### Filesystem

Create `ext4` filesystem on first partition of second sata block device.

```bash
mkfs.ext4 /dev/sdb1
```


### Mountpoints

To mount an existing filesystem using device name or more preferably using device UUID.

```bash
# Create mountpoint
mkdir /mnt/data

# Mount fs using device Name
mount /dev/sdb1 /mnt/data

# Mount fs using device UUID
mount UUID=$(lsblk -no uuid /dev/sda1) /mnt/data
```

To umnount a filesystem.

```bash
umount /mnt/data
```

When you receive an error `target is busy` you can identify which processes are using the data on mountpoint using `lsof` or `fuser -m`.

```bash
lsof /mnt/data

fuser -m /mnt/data
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

Redirect can change the default output  `>` or `1>` (overwrite), `>>` or `1>>` (append) for STDOUT and `2>`, `2>>` for STDERR or all output `&>` pr `&>>` from screen to filesystem.

To prevent accidental overwrites using `>` we can change bash option `noclobber` to `on` with `set -o clobber` command.

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

For programs that cannot accept STDIN as argument using unnamed pipe, you can use the `xargs` utility:

```bash
# Prints 1 2 3 4 5
seq 5 | xargs echo

# Alphabetically print all users on system
cut -d: -f1 < /etc/passwd | sort | xargs

# Print full path for all files in current folder
/bin/ls | xargs -I {} echo "$PWD/{}"

# Print an argument in new process each second
seq 5 | xargs -n 1 -P 1 bash -c 'echo sequence no.$0 ran in process $$; sleep 1'

# Speeding up find exec flag with xargs
find -type f -name "*.text" -exec rm {} \;
find -type f -name "*.text" | xargs rm {}
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

#### Grep

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


#### Gawk

Gawk is another popular utility when it comes to analyzing and filtering text data.

```bash
# Display default shell for root user
awk -F: '/^root/{ print $1 " is using " $7}' /etc/passwd
```


### Searching

#### Find

Find is an utility that searches for files and directories in a file system based on certain criteria, such as name, size, type, and more. It can also perform actions on the matched files and directories, such as deleting, moving, or executing commands. It is commonly used for searching for files and directories in a specific location, and can be combined with other commands to perform advanced tasks.

```bash
find <path> <tests> <actions>
```

The `path` defaults to current working directory, `tests` can include properties such as name, size, depth, ownership, access time. Finally the `actions` which defaults to print can include delete, exec, ok.

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
find /boot -size +10M -type f -exec du -h {} \;

# Find all files with size larger than 100M and list their attributes
find /usr -size +100 -exec ls -lh {} \;

# Find all files that belong to user which does not exist
# add -delete to also cleanup these files
find /home /var -nouser

# Find all files that belong to user who has atleast write permission
find /var -type f -user vagrant -perm /u=w

# Find all files that were changed 60 minutes ago
find / -mmin 60

# Find files (hardlinks) with same inode as "target" file and delete them interactively
find / -inum $(stat -c %i target) -exec rm -i {} \;
```

You can also leverage a pipe to redirect standard output to `xargs`, which then allows you to pass standard input as an argument for next command.

```bash
# Find files (softlinks) that point to "target" file and perform a long listing
find / -lname target 2>/dev/null | xargs ls -l
```


#### Locate

Locate is a program that quickly finds files and directories on a Unix-based system by searching a prebuilt database of file names. It is faster than a regular search using find and does not require real-time scanning of the file system. It is useful for quickly finding files or directories, but it may not find recently added or modified files.

Below are some examples:

```bash
# Trigger database update (otherwise it is updated every day)
updatedb

# Search for partial match
locate image
```

#### Whereis

The `whereis` command locates the binary, source and manual files for a given command.

For example, to find the location of the binary, manual page, and source code for the `lsblk` command, you would run the command:

```bash
whereis lsblk
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

# Query database for file to determine the source package
rpm -qf /bin/bash

# Query for features that a package provides
rpm -q --provides bash

# Query package dependencies
rpm -q --requires bash

# Query package changes
rpm -q --changelog bash

# Query package for binaries
rpm -ql procps-ng | grep '^/usr/bin/'
```

Inspcting a package

```bash
# Download packaged and dependencies
dnf download httpd --resolve

# Inspect a package
rpm -qip httpd-*
rpm -qlp httpd-*
```

Downloading and extracting a package

```bash
# Download a package
yumdownloader nmap

file nmap-7.91-10.el9.x86_64.rpm
nmap-7.91-10.el9.x86_64.rpm: RPM v3.0 bin i386/x86_64 nmap-3:7.91-10.el9

# Extract package
rpm2cpio nmap-7.91-10.el9.x86_64.rpm | cpio -duim

# Inspect package
ls
nmap-7.91-10.el9.x86_64.rpm  usr

tree -F usr | head
usr
├── bin/
│   ├── nmap*
│   └── nping*
├── lib/
└── share/
    ├── doc/
    │   └── nmap/
    │       ├── nmap.usage.txt
    │       └── README

# Query local file
rpm -qpl nmap-7.91-10.el9.x86_64.rpm | head -5
/usr/bin/nmap
/usr/bin/nping
/usr/lib/.build-id
/usr/lib/.build-id/9b
/usr/lib/.build-id/9b/d6db681c980c017fbe25daeb051a7ba4049386
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


### Installation tools

#### Dpkg

The package manager for Debian is called `dpkg`. It is a low level tool used for managing lifecycle of `.deb` packages.

Query for binary packages.

```bash
# List installed packages
dpkg-query -f '${binary:Package}\n' -W
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

Once completed, verify the Grub configuration at `/etc/default/grub.conf`. There should be new entry corresponding to new kernel which you can select in boot menu. When happy copy it to `/boot/grub/grub.cfg` to ensure it is picked up on next boot.

> Note: In order to add support for Hyper-V host, in step 3, you need to include some more [flags](https://dietrichschroff.blogspot.com/2013/03/hyper-v-compile-linux-kernel-with.html).

### Removal

In order to remove a custom compiled kernel you need to remove `vmlinuz`, `initrd`, `System.map` and `config` from `/boot` folder. Also remove the modules.

```bash
sudo rm /boot/*6.1.0
sudo rm -rf /lib/modules/6.1.0
```

Finally, don't forget to update the grub configuration.

```bash
sudo update-grub
```


## Bootloader

### Menu Style and Timeout

Grub2 configuration file is located at `/etc/default/grub.conf`. This is where you can change the default timeout and menu style. For example to add 10 second time out and display menu change the following lines.

Change the timeout style from `hidden` to `menu` and add a `10` second timeout.

```bash
sudo sed -i 's/GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
sudo sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub
```

Afterwards you need to apply the changes with `sudo update-grub`.

```bash
sudo update-grub
```

> Note: If you need to invoke Grub menu just one time, use the `shift` key during boot process.


## Power

### Gnome 43 specifics

When using `Gnome 43` you can disable the 60 second Poweroff timer by changing the following setting:

```bash
gsettings set org.gnome.SessionManager logout-prompt false
```

### Lid action

This applies to laptops. In order to change the default action when lid is closed you need to edit the `/etc/systemd/logind.conf` file.

```bash
HandleLidSwitch=poweroff
HandleLidSwitchEsternalPower=suspend
```

You can choose from following values:
- `lock` - lock when lid closed
- `ignore` - do nothing
- `poweroff` - shutdown
- `hibernate` - hibernate


## Firmware

In order to manage firmware updates through OS your device needs to support Linux Vendor Firmware Service (LVFS). This can be confirmed in devices BIOS settings or via device datasheet.


First, install the `fwupd` package. 

```bash
sudo apt install -y fwupd
```

Next, enable and start `fwupd` service.

```bash
sudo systemctl enable --now fwupd
```

Optionally, display supported devices.

```bash
fwupmgr get-devices
```

Download latest metadata from LVFS.

```bash
fwupmgr refresh
```

Check for available firmware updates.

```bash
fwupdmgr get-updates
```

Update the device firmware.

```bash
fwupdmgr update
```


## UEFI BIOS

### Verify 

In order to verify if the system booted into EUFI mode you can check the presence of `/sys/firmware/efi`.

```bash
[ -d /sys/firmware/efi ] && echo "Installed in UEFI mode" || echo "Installed in Legacy mode"
```


### SecureBoot

In order to verify from OS if SecureBoot is enabled use the following command:

```bash
mokutil --sb-state
```


## Device Drivers

Device drivers often referred to as modules are loaded as required into the running kernel. The currently loaded modules can be seen using `lsmod` command wich uses `/proc/modules` as backend. The `modprobe -l` lists all available modules.

To load a module you can use `modprobe` following with a name of the module. You can also specify an module option (e.g. `modprobe -v sr_mod xa_test=1`). In order to persist this change you need to create a new file in `/etc/modprobe.d/sr_mod.conf` with content of `options sr_mod xa_test=1` for example.

To unload use `modprobe` with `-r` argument following with a name of the module.

To view module dependencies and options use `modinfo` following with a name of the module. In order to display the loaded module options values, use in case of `sr_mod` module `cat /sys/module/sr_mod/parameters/xa_test`.


### Kernel Installation

Sometimes you need to install a specific kernel version. In order to do so, first list all available packages in the repository.

```bash
yum list --showduplicates kernel
```

Then, pick one of them and install:

```bash
yum install kernel-3.10.0-1160.66.1.el7
```

This will also update the GRUB2 configuration file `/boot/grub2/grub.cfg` (in case of BIOS based machine). The newly installed kernel will be selected as the default one.

To change the default kernel selection, you can use `grubby`.

```bash
grubby --default-kernel
```

```bash
grubby --set-default grubby --set-default /boot/vmlinuz-3.10.0-1160.76.1.el7.x86_64
```

To display kernel settings for all or specific kernel:

```bash
grubby --info=ALL
grubby --info /boot/vmlinuz-3.10.0-1160.76.1.el7.x86_64
```

To change the options for specific entry:

```bash
grubby --remove-args="rhgb quiet" --update-kernel /boot/vmlinuz-3.10.0-1160.76.1.el7.x86_64
```

## Access Control

### File Permissions

There are six permissions available, out of which three are regular (read,write,execute) and other three are special (sticky bit, SetGID bit, SetUID bit)

#### Special permissions

`Sticky bit` applies to directories only. When set, only the owning user can delete a file from a directory. It is identifed in permission for `others` therefore to set this bit use the `chmod o+t <direrctory>` or `chmod 1NNN <directory>` where `N` sets the regular permissions.

For example to find all directories with sticky bit set, use the following filter with find.

```bash
find / -perm /o+t 2>/dev/null
/dev/mqueue
/dev/shm
/sys/fs/bpf
/tmp
/tmp/.X11-unix
/tmp/.ICE-unix
/tmp/.XIM-unix
/tmp/.font-unix
/var/tmp
```

`SetGID bit` applies to directories and files. When set, the owning group of a newly created file is derived fro the directory that the file is created in (for directories). Executable files run with permission of the owning group of the executable (for files). To set this bit use `chmod g+s <directory | file>` or `chmod 2NNN <directory | file>` where `N` sets the regular permissions. It is then identified in permission for `owning group`.

For example to find all directories with SetGID bit set, use the following filter with find.

```bash
find / -perm /g+s 2>/dev/null
/run/tpm2-tss/eventlog
/run/log/journal
/run/log/journal/3daaeb8406f245d7952ae590d1d88c36
/run/log/journal/b49add15b13048b28c526bdd37a5b91d
/var/lib/tpm2-tss/system/keystore
/usr/bin/write
/usr/bin/locate
/usr/libexec/utempter/utempter
/usr/libexec/openssh/ssh-keysign
```

`SetUID bit` applies to files only. When set, the executables run with permissions of the owning user of the executable. To set this bit use the `chmod u+s <file>` or `chmod 4NNN <file>` where `N` sets the regular permissions. It is then identified in permission for `owning user`.

For example to find all files with SetUID bit set, use the following filter with find.

```bash
find / -perm /u+s 2>/dev/null
/usr/bin/chage
/usr/bin/gpasswd
/usr/bin/newgrp
/usr/bin/su
/usr/bin/mount
/usr/bin/umount
/usr/bin/crontab
/usr/bin/passwd
/usr/bin/sudo
/usr/bin/pkexec
/usr/sbin/unix_chkpwd
/usr/sbin/pam_timestamp_check
/usr/sbin/userhelper
/usr/sbin/grub2-set-bootflag
/usr/lib/polkit-1/polkit-agent-helper-1
```

#### Default permissions

The the default permissions on vanilla linux based system is `777` for directories and `666` for newly created files resulting in quite open permission model for all users.

In order to manage this behavior you can use `umask <value>` command on time or place it in your login script. The value meaning is how much we are going to subtrack from the default permissions. This applies for both directories and files alike. The common default value is `0022` and is defined in global login script `/etc/bashrc`.

For example `umask 0077` results in folder permission of `700` and file permission of `600` as no negative values are allowed. This makes folders and files more private.


## Tips

### SSH Session Hangout

To close an unresponsive SSH session where your terminal hangs, press `Enter` and then type `~.`. The session closes immediately returning you back to prompt.


### Bash Session Recording

The `script` utility can be used to record the current session to named pipe where it can be seen by other user.

```bash
# User 1 creates a new named pipe and redirects output of script
mkfifo /tmp/mypipe
script -f /tmp/mypipe
```

```bash
# User 2 read the pipe
cat /tmp/mypipe
```

This also works using a standard file and doing a tail on another session.

```bash
# User 1 creates a new file and redirects output of script
> /tmp/mypipe
script -f /tmp/mypipe

# User 2 tails the file
tail /tmp/mypipe
```