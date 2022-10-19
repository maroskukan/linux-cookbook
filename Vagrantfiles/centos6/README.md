# Centos 6 VM Blueprint

The purpose of this Vagrantfile is to provide a ready to use Centos 6.10 environment. This version was selected as it uses legacy GRUB and System V Init scripts.

## How to provision this VM

The blueprint supports Hyper-V and VirtualBox backends, simply provision and connect to this VM using Vagrant.

```bash
vagrant up && vagrant ssh
```