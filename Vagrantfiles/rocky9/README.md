# Rocky 9 VM Blueprint

The purpose of this Vagrantfile is to provide a ready to use Rocky 9.1 environment. This version was selected as it uses GRUB2 and Systemd.

## How to provision this VM

The blueprint supports Microsoft Hyper-V, VMware Workstation and Oracle VirtualBox backends, simply provision and connect to this VM using Vagrant.

```bash
vagrant up && vagrant ssh
```
