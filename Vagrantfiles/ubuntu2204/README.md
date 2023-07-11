# Ubuntu 22.04 LTS VM Blueprint

The purpose of this Vagrantfile is to provide a ready to use Ubuntu 22.04.2 LTS environment. This version was selected as it uses GRUB2 and Systemd.

Vagrant will automatically install the version of Ansible from `ppa:ansible/ansible` repository and then executes a sample playbook.

## How to provision this VM

The blueprint supports Hyper-V and VirtualBox backends, simply provision and connect to this VM using Vagrant.

```bash
vagrant up && vagrant ssh
```
