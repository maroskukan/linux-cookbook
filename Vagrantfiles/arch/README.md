# Arch VM Blueprint

The purpose of this Vagrantfile is to provide a ready to use Arch Rolling environment. This version was selected as it uses GRUB2 and Systemd.

## How to provision this VM

The blueprint supports Hyper-V and VirtualBox backends, simply provision and connect to this VM using Vagrant.

```bash
vagrant up && vagrant ssh
```
